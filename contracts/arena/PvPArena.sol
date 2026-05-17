// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AethToken } from "../token/AethToken.sol";
import { HeroNFT } from "../nft/HeroNFT.sol";
import { BattleMath } from "../assembly/BattleMath.sol";
import { IVRFCoordinatorV2Plus } from "../interfaces/IVRFCoordinatorV2Plus.sol";

// Chainlink VRF v2.5 consumer base

/// @dev Minimal base that lets the coordinator call back into fulfillRandomWords.
abstract contract VRFConsumerBaseV2Plus {
    IVRFCoordinatorV2Plus internal immutable i_vrfCoordinator;

    error VRFConsumerBaseV2Plus__OnlyCoordinator(address caller, address coordinator);

    constructor(address vrfCoordinator_) {
        i_vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinator_);
    }

    // solhint-disable-next-line func-name-mixedcase
    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        if (msg.sender != address(i_vrfCoordinator)) {
            revert VRFConsumerBaseV2Plus__OnlyCoordinator(msg.sender, address(i_vrfCoordinator));
        }
        fulfillRandomWords(requestId, randomWords);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal virtual;
}

/**
 * @title PvPArena
 * @notice On-chain PvP battle arena for AetherForge.
 *
 * State machine (Design Pattern — State Machine)
 * ───────────────────────────────────────────────
 *   Idle -> Registered -> Matched -> Resolved
 *                                  -> Cancelled  (VRF timeout)
 *
 * Battle flow
 * ───────────
 * 1. player1 calls register(heroId)  -> pays entryFee; battle state -> Registered.
 * 2. player2 calls register(heroId)  -> pays entryFee; matchmaking fires immediately;
 *    state -> Matched; Chainlink VRF request is sent.
 * 3. Coordinator calls fulfillRandomWords() -> outcome resolved; state -> Resolved.
 * 4. winner calls claimReward(battleId) -> pull-over-push; funds transferred.
 *
 * Battle power formula (via BattleMath.battlePowerYul)
 * ─────────────────────────────────────────────────────
 * Base stats are derived from heroClass and level (since HeroNFT V1 only stores those).
 * equipBonus is hardcoded to 0 in V1; HeroNFT V2 will expose equipped items.
 *
 *   power = (atk*120 + def*80 + (agi*randMod)/1e18 + equipBonus) / 100
 *
 * Design patterns implemented
 * ────────────────────────────
 * State Machine      — BattleState enum with guarded transitions.
 * Pull-over-push     — pendingRewards[battleId], winner calls claimReward().
 * Pausable           — circuit breaker if VRF becomes unavailable.
 * CEI                — checks/effects/interactions order in every write function.
 * ReentrancyGuard    — on register() and claimReward().
 * AccessControl      — ADMIN_ROLE (Timelock), PAUSER_ROLE.
 *
 * Governance-controlled parameters (via Timelock)
 * ─────────────────────────────────────────────────
 * entryFee, treasuryFeeBps, vrfCancelWindow
 */
contract PvPArena is VRFConsumerBaseV2Plus, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Roles

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // State machine

    enum BattleState {
        Idle,
        Registered,
        Matched,
        Resolved,
        Cancelled
    }

    // Storage

    struct Battle {
        address player1;
        address player2;
        uint256 hero1Id;
        uint256 hero2Id;
        uint256 entryFeeSnapshot; // fee locked at registration time
        BattleState state;
        uint256 vrfRequestId;
        uint256 matchedAt; // timestamp when VRF was requested (cancel-window start)
        address winner; // address(0) until Resolved
        bool claimed;
    }

    uint256 public nextBattleId;

    // battleId -> Battle
    mapping(uint256 => Battle) public battles;

    // vrfRequestId -> battleId  (reverse lookup in fulfillRandomWords)
    mapping(uint256 => uint256) public requestToBattle;

    // battleId -> claimable AETH for the winner (pull-over-push)
    mapping(uint256 => uint256) public pendingRewards;

    // heroId -> battleId - prevents the same hero entering two battles at once
    mapping(uint256 => uint256) public heroInBattle;

    // The open slot: battleId of the first registration waiting for an opponent.
    // 0 means no open slot (valid because nextBattleId starts at 1).
    uint256 public openSlot;

    // External contracts

    AethToken public immutable aethToken;
    HeroNFT public immutable heroNFT;
    address public treasury;

    // VRF config

    bytes32 public vrfKeyHash;
    uint256 public vrfSubscriptionId;
    uint32 public vrfCallbackGasLimit;
    uint16 public vrfRequestConfirmations;

    // Governance parameters

    /// @notice AETH cost per player to enter a battle.
    uint256 public entryFee;

    /// @notice Basis points of the total prize sent to treasury. 1000 = 10 %.
    uint256 public treasuryFeeBps;

    /// @notice Seconds after which a Matched battle can be cancelled if VRF never arrives.
    uint256 public vrfCancelWindow;

    // Constants

    uint256 private constant BPS_DENOM = 10_000;

    // Base stats per class (index = uint8(HeroClass)).
    // [Warrior, Mage, Rogue, Paladin]
    function _baseAtk(uint256 c) private pure returns (uint256) {
        uint256[4] memory v = [uint256(80), 120, 100, 60];
        return v[c];
    }

    function _baseDef(uint256 c) private pure returns (uint256) {
        uint256[4] memory v = [uint256(100), 40, 60, 120];
        return v[c];
    }

    function _baseAgi(uint256 c) private pure returns (uint256) {
        uint256[4] memory v = [uint256(60), 80, 120, 60];
        return v[c];
    }

    // Errors

    error PvPArena__ZeroAddress();
    error PvPArena__ZeroFee();
    error PvPArena__NotHeroOwner(address caller, uint256 heroId);
    error PvPArena__HeroAlreadyInBattle(uint256 heroId);
    error PvPArena__SamePlayer(address player);
    error PvPArena__InvalidState(uint256 battleId, BattleState got, BattleState want);
    error PvPArena__NotWinner(address caller, uint256 battleId);
    error PvPArena__AlreadyClaimed(uint256 battleId);
    error PvPArena__CancelWindowNotElapsed(uint256 battleId, uint256 elapsed, uint256 required);
    error PvPArena__TreasuryFeeTooHigh(uint256 bps);

    // Events

    event Registered(uint256 indexed battleId, address indexed player, uint256 indexed heroId);
    event Matched(uint256 indexed battleId, address player1, address player2, uint256 vrfRequestId);
    event Resolved(uint256 indexed battleId, address indexed winner, uint256 reward, uint256 treasuryCut);
    event RewardClaimed(uint256 indexed battleId, address indexed winner, uint256 amount);
    event Cancelled(uint256 indexed battleId, address indexed requester);
    event EntryFeeSet(uint256 oldFee, uint256 newFee);
    event TreasuryFeeSet(uint256 oldBps, uint256 newBps);
    event TreasurySet(address oldTreasury, address newTreasury);
    event VrfCancelWindowSet(uint256 oldWindow, uint256 newWindow);

    // Constructor

    /**
     * @param vrfCoordinator_       Chainlink VRF coordinator address.
     * @param aethToken_            AETH governance token.
     * @param heroNFT_              HeroNFT proxy address.
     * @param treasury_             GuildTreasury (receives fee cut).
     * @param admin_                Receives ADMIN_ROLE (should be Timelock post-deploy).
     * @param pauser_               Receives PAUSER_ROLE.
     * @param vrfKeyHash_           VRF key hash (gas lane).
     * @param vrfSubscriptionId_    Active Chainlink VRF subscription ID.
     * @param entryFee_             Initial entry fee in AETH (18-decimal).
     * @param treasuryFeeBps_       Initial treasury cut in basis points (e.g. 1000 = 10 %).
     */
    constructor(
        address vrfCoordinator_,
        address aethToken_,
        address heroNFT_,
        address treasury_,
        address admin_,
        address pauser_,
        bytes32 vrfKeyHash_,
        uint256 vrfSubscriptionId_,
        uint256 entryFee_,
        uint256 treasuryFeeBps_
    ) VRFConsumerBaseV2Plus(vrfCoordinator_) {
        if (aethToken_ == address(0) || heroNFT_ == address(0) || treasury_ == address(0)) {
            revert PvPArena__ZeroAddress();
        }
        if (admin_ == address(0) || pauser_ == address(0)) revert PvPArena__ZeroAddress();
        if (entryFee_ == 0) revert PvPArena__ZeroFee();
        if (treasuryFeeBps_ > 3000) revert PvPArena__TreasuryFeeTooHigh(treasuryFeeBps_); // max 30 %

        aethToken = AethToken(aethToken_);
        heroNFT = HeroNFT(heroNFT_);
        treasury = treasury_;

        vrfKeyHash = vrfKeyHash_;
        vrfSubscriptionId = vrfSubscriptionId_;
        vrfCallbackGasLimit = 200_000;
        vrfRequestConfirmations = 3;

        entryFee = entryFee_;
        treasuryFeeBps = treasuryFeeBps_;
        vrfCancelWindow = 24 hours;

        // battleId 0 is the sentinel for "no open slot"; start IDs at 1.
        nextBattleId = 1;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(PAUSER_ROLE, pauser_);
    }

    // Player actions

    /**
     * @notice Register a hero into the matchmaking queue.
     *
     * @dev    CEI order:
     *         CHECKS  - ownership, hero not already in battle, paused check.
     *         EFFECTS - create/update Battle in storage, mark hero as locked,
     *                   update openSlot, snapshot entryFee.
     *         INTERACTIONS - transferFrom AETH (external call comes last).
     *
     *         If an open slot exists, both players are matched immediately and
     *         a VRF request is fired inside this same call.
     *
     * @dev    Slither reentrancy-no-eth is suppressed: b.vrfRequestId cannot be written before
     *         _requestRandomness() because it depends on the return value. The function is
     *         protected by nonReentrant; the VRF coordinator is a trusted Chainlink contract.
     *
     * @param heroId  The caller's hero token ID.
     */
    // slither-disable-next-line reentrancy-no-eth
    function register(uint256 heroId) external nonReentrant whenNotPaused {
        // CHECKS
        if (heroNFT.ownerOf(heroId) != msg.sender) {
            revert PvPArena__NotHeroOwner(msg.sender, heroId);
        }
        if (heroInBattle[heroId] != 0) {
            revert PvPArena__HeroAlreadyInBattle(heroId);
        }

        uint256 fee = entryFee; // snapshot before any state changes

        if (openSlot == 0) {
            // EFFECTS (first player, no match yet)
            uint256 battleId = nextBattleId++;
            battles[battleId] = Battle({
                player1: msg.sender,
                player2: address(0),
                hero1Id: heroId,
                hero2Id: 0,
                entryFeeSnapshot: fee,
                state: BattleState.Registered,
                vrfRequestId: 0,
                matchedAt: 0,
                winner: address(0),
                claimed: false
            });
            heroInBattle[heroId] = battleId;
            openSlot = battleId;

            // INTERACTIONS
            IERC20(address(aethToken)).safeTransferFrom(msg.sender, address(this), fee);
            emit Registered(battleId, msg.sender, heroId);
        } else {
            // EFFECTS (second player, immediate match)
            uint256 battleId = openSlot;
            Battle storage b = battles[battleId];

            if (b.player1 == msg.sender) revert PvPArena__SamePlayer(msg.sender);

            b.player2 = msg.sender;
            b.hero2Id = heroId;
            b.state = BattleState.Matched;
            b.matchedAt = block.timestamp;
            heroInBattle[heroId] = battleId;
            openSlot = 0;

            // INTERACTIONS
            IERC20(address(aethToken)).safeTransferFrom(msg.sender, address(this), fee);
            emit Registered(battleId, msg.sender, heroId);

            // Fire VRF — external call last (CEI).
            uint256 vrfReqId = _requestRandomness();
            b.vrfRequestId = vrfReqId;
            requestToBattle[vrfReqId] = battleId;
            emit Matched(battleId, b.player1, b.player2, vrfReqId);
        }
    }

    /**
     * @notice Claim a pending battle reward (pull-over-push pattern).
     * @dev    Only the resolved winner can call this.
     *         CEI: checks → zero-out reward (effect) → transfer (interaction).
     * @param battleId  The resolved battle ID.
     */
    function claimReward(uint256 battleId) external nonReentrant {
        // CHECKS
        Battle storage b = battles[battleId];

        if (b.state != BattleState.Resolved) {
            revert PvPArena__InvalidState(battleId, b.state, BattleState.Resolved);
        }
        if (b.winner != msg.sender) {
            revert PvPArena__NotWinner(msg.sender, battleId);
        }
        if (b.claimed) {
            revert PvPArena__AlreadyClaimed(battleId);
        }

        uint256 reward = pendingRewards[battleId];

        // EFFECTS
        b.claimed = true;
        pendingRewards[battleId] = 0;

        // INTERACTIONS
        IERC20(address(aethToken)).safeTransfer(msg.sender, reward);
        emit RewardClaimed(battleId, msg.sender, reward);
    }

    /**
     * @notice Cancel a Matched battle if VRF has not responded within vrfCancelWindow.
     * @dev    Anyone can call this once the window has elapsed - refunds both players.
     *         CEI: checks -> state change -> transfers.
     * @param battleId  The stuck battle ID.
     */
    function cancelStuckBattle(uint256 battleId) external nonReentrant {
        Battle storage b = battles[battleId];

        // CHECKS
        if (b.state != BattleState.Matched) {
            revert PvPArena__InvalidState(battleId, b.state, BattleState.Matched);
        }
        uint256 elapsed = block.timestamp - b.matchedAt;
        if (elapsed < vrfCancelWindow) {
            revert PvPArena__CancelWindowNotElapsed(battleId, elapsed, vrfCancelWindow);
        }

        uint256 fee = b.entryFeeSnapshot;
        address p1 = b.player1;
        address p2 = b.player2;
        uint256 h1 = b.hero1Id;
        uint256 h2 = b.hero2Id;

        // EFFECTS
        b.state = BattleState.Cancelled;
        heroInBattle[h1] = 0;
        heroInBattle[h2] = 0;

        // INTERACTIONS
        IERC20(address(aethToken)).safeTransfer(p1, fee);
        IERC20(address(aethToken)).safeTransfer(p2, fee);
        emit Cancelled(battleId, msg.sender);
    }

    // VRF callback

    /**
     * @notice Called by the VRF coordinator when randomness is ready.
     * @dev    Resolves the battle: computes battle power for each hero,
     *         determines winner, calculates prize split, stores reward.
     *         Cannot revert (coordinator does not retry) — edge cases gracefully
     *         fall through to a deterministic tie-break.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 battleId = requestToBattle[requestId];
        Battle storage b = battles[battleId];

        // Guard: battle may have been cancelled between request and callback.
        if (b.state != BattleState.Matched) return;

        uint256 rand = randomWords[0];

        // Derive randMod is [0, 1e18] for each hero from a single VRF word.
        uint256 randMod1 = rand % 1e18;
        uint256 randMod2 = (rand >> 128) % 1e18;

        // Compute battle power via BattleMath.battlePowerYul (Yul assembly).
        (uint256 atk1, uint256 def1, uint256 agi1) = _heroStats(b.hero1Id);
        (uint256 atk2, uint256 def2, uint256 agi2) = _heroStats(b.hero2Id);

        uint256 power1 = BattleMath.battlePowerYul(atk1, def1, agi1, 0, randMod1);
        uint256 power2 = BattleMath.battlePowerYul(atk2, def2, agi2, 0, randMod2);

        // Tie-break: player1 wins on tie (deterministic, no further randomness needed).
        address winner = (power1 >= power2) ? b.player1 : b.player2;

        // Prize calculation.
        uint256 totalPot = b.entryFeeSnapshot * 2;
        uint256 treasuryCut = (totalPot * treasuryFeeBps) / BPS_DENOM;
        uint256 winnerReward = totalPot - treasuryCut;

        // EFFECTS
        b.state = BattleState.Resolved;
        b.winner = winner;
        pendingRewards[battleId] = winnerReward;
        heroInBattle[b.hero1Id] = 0;
        heroInBattle[b.hero2Id] = 0;

        // INTERACTIONS
        if (treasuryCut > 0) {
            IERC20(address(aethToken)).safeTransfer(treasury, treasuryCut);
        }

        emit Resolved(battleId, winner, winnerReward, treasuryCut);
    }

    // Governance (ADMIN_ROLE = Timelock)

    function setEntryFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        if (newFee == 0) revert PvPArena__ZeroFee();
        emit EntryFeeSet(entryFee, newFee);
        entryFee = newFee;
    }

    function setTreasuryFeeBps(uint256 newBps) external onlyRole(ADMIN_ROLE) {
        if (newBps > 3000) revert PvPArena__TreasuryFeeTooHigh(newBps);
        emit TreasuryFeeSet(treasuryFeeBps, newBps);
        treasuryFeeBps = newBps;
    }

    function setTreasury(address newTreasury) external onlyRole(ADMIN_ROLE) {
        if (newTreasury == address(0)) revert PvPArena__ZeroAddress();
        emit TreasurySet(treasury, newTreasury);
        treasury = newTreasury;
    }

    function setVrfCancelWindow(uint256 newWindow) external onlyRole(ADMIN_ROLE) {
        emit VrfCancelWindowSet(vrfCancelWindow, newWindow);
        vrfCancelWindow = newWindow;
    }

    // Pause (PAUSER_ROLE)

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Internal helpers

    /**
     * @dev Submit a VRF randomness request to the coordinator.
     *      VRF v2.5 uses LINK-over-native payment determined by extraArgs;
     *      passing empty bytes selects the default (LINK) path.
     */
    function _requestRandomness() private returns (uint256 requestId) {
        requestId = i_vrfCoordinator.requestRandomWords(
            IVRFCoordinatorV2Plus.RandomWordsRequest({
                keyHash: vrfKeyHash,
                subId: vrfSubscriptionId,
                requestConfirmations: vrfRequestConfirmations,
                callbackGasLimit: vrfCallbackGasLimit,
                numWords: 1,
                extraArgs: "" // default: LINK payment
            })
        );
    }

    /**
     * @dev Derive (atk, def, agi) from a hero's class and level.
     *      HeroNFT V1 only stores {level, heroClass}; V2 will expose equipped items.
     *      Formula: baseStat[class] * level / 10 + baseStat[class]
     *      (level 1 -> 110 % of base, level 100 -> 1100 % of base).
     */
    function _heroStats(uint256 heroId) private view returns (uint256 atk, uint256 def, uint256 agi) {
        HeroNFT.HeroAttributes memory attrs = heroNFT.getHeroAttributes(heroId);
        uint256 classIdx = uint256(attrs.heroClass);
        uint256 lvl = uint256(attrs.level);

        atk = _baseAtk(classIdx) + (_baseAtk(classIdx) * lvl) / 10;
        def = _baseDef(classIdx) + (_baseDef(classIdx) * lvl) / 10;
        agi = _baseAgi(classIdx) + (_baseAgi(classIdx) * lvl) / 10;
    }

    // View helpers

    /// @notice Return the full Battle struct for a given battleId.
    function getBattle(uint256 battleId) external view returns (Battle memory) {
        return battles[battleId];
    }

    /// @notice Return pending claimable reward for a battle.
    function getPendingReward(uint256 battleId) external view returns (uint256) {
        return pendingRewards[battleId];
    }
}
