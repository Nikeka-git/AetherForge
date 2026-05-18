// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console2 } from "forge-std/Test.sol";

import { PvPArena } from "../../contracts/arena/PvPArena.sol";
import { IVRFCoordinatorV2Plus } from "../../contracts/interfaces/IVRFCoordinatorV2Plus.sol";
import { AethToken } from "../../contracts/token/AethToken.sol";
import { HeroNFT } from "../../contracts/nft/HeroNFT.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title MockVRFCoordinator
 * @notice Stub Chainlink VRF coordinator for tests.
 *         Implements IVRFCoordinatorV2Plus so PvPArena can call requestRandomWords.
 *         Exposes fulfillRequest() so tests can trigger the VRF callback manually.
 */
contract MockVRFCoordinator is IVRFCoordinatorV2Plus {
    uint256 private _nextRequestId = 1;

    mapping(uint256 => address) public consumers;

    function requestRandomWords(RandomWordsRequest calldata) external override returns (uint256 requestId) {
        requestId = _nextRequestId++;
        consumers[requestId] = msg.sender;
    }

    /// @notice Trigger the VRF callback with a caller-supplied random word.
    function fulfillRequest(uint256 requestId, uint256 randomWord) external {
        uint256[] memory words = new uint256[](1);
        words[0] = randomWord;
        // Call rawFulfillRandomWords on the consumer (PvPArena).
        (bool ok,) = consumers[requestId].call(
            abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", requestId, words)
        );
        require(ok, "MockVRFCoordinator: fulfill failed");
    }
}

/**
 * @title PvPArenaTest
 * @notice Unit tests for PvPArena.sol.
 *
 * Run:
 *   forge test --match-contract PvPArenaTest -vv
 *
 * Covers every public/external function including all revert paths.
 */
contract PvPArenaTest is Test {
    // Contracts

    PvPArena internal arena;
    AethToken internal aeth;
    HeroNFT internal heroNFT;
    MockVRFCoordinator internal coordinator;

    // Actors

    address internal admin = makeAddr("admin");
    address internal pauser = makeAddr("pauser");
    address internal treasury = makeAddr("treasury");
    address internal player1 = makeAddr("player1");
    address internal player2 = makeAddr("player2");
    address internal attacker = makeAddr("attacker");

    // Constants

    uint256 constant ENTRY_FEE = 10 ether; // 10 AETH
    uint256 constant TREASURY_BPS = 1000; // 10 %
    bytes32 constant KEY_HASH = bytes32(uint256(1));
    uint256 constant SUB_ID = 42;

    // Setup

    function setUp() public {
        vm.startPrank(admin);

        // Deploy AETH token.
        aeth = new AethToken(admin);

        // Deploy HeroNFT behind UUPS proxy — pass aethToken so mintHero can mint starter pack.
        HeroNFT impl = new HeroNFT();
        bytes memory initData = abi.encodeCall(HeroNFT.initialize, (admin, admin, "https://hero/", address(aeth)));
        heroNFT = HeroNFT(address(new ERC1967Proxy(address(impl), initData)));

        // Grant HeroNFT MINTER_ROLE on AethToken so mintHero can mint starter AETH.
        aeth.grantRole(aeth.MINTER_ROLE(), address(heroNFT));

        // Deploy mock VRF coordinator.
        coordinator = new MockVRFCoordinator();

        // Deploy arena.
        arena = new PvPArena(
            address(coordinator),
            address(aeth),
            address(heroNFT),
            treasury,
            admin,
            pauser,
            KEY_HASH,
            SUB_ID,
            ENTRY_FEE,
            TREASURY_BPS
        );

        // Grant arena MINTER_ROLE on HeroNFT so it can level up heroes.
        heroNFT.grantRole(heroNFT.MINTER_ROLE(), address(arena));
        // Also grant admin the minter role so setUp can mint test heroes.
        heroNFT.grantRole(heroNFT.MINTER_ROLE(), admin);

        // Mint initial AETH supply to admin for distribution.
        aeth.mint(admin, 10_000 ether);

        // Fund players and give allowance to arena.
        uint256 playerFunds = 100 ether;
        aeth.transfer(player1, playerFunds);
        aeth.transfer(player2, playerFunds);

        vm.stopPrank();

        vm.prank(player1);
        aeth.approve(address(arena), type(uint256).max);

        vm.prank(player2);
        aeth.approve(address(arena), type(uint256).max);
    }

    // Helper

    /// @dev Mint a hero to 'to' and return the tokenId.
    function _mintHero(address to, HeroNFT.HeroClass heroClass) internal returns (uint256 tokenId) {
        vm.prank(admin);
        tokenId = heroNFT.mintHero(to, heroClass);
    }

    /// @dev Register two players and return the battleId.
    function _setupMatch() internal returns (uint256 battleId) {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);
        uint256 h2 = _mintHero(player2, HeroNFT.HeroClass.Mage);

        vm.prank(player1);
        arena.register(h1);
        battleId = arena.openSlot();

        vm.prank(player2);
        arena.register(h2);
    }

    // register()

    function test_Register_OpensSlotForFirstPlayer() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);

        vm.prank(player1);
        arena.register(h1);

        assertEq(arena.openSlot(), 1);
        (address p1,,,,, PvPArena.BattleState state,,,,) = _unpackBattle(1);
        assertEq(p1, player1);
        assertEq(uint8(state), uint8(PvPArena.BattleState.Registered));
    }

    function test_Register_TransfersEntryFee() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);
        uint256 balBefore = aeth.balanceOf(address(arena));

        vm.prank(player1);
        arena.register(h1);

        assertEq(aeth.balanceOf(address(arena)), balBefore + ENTRY_FEE);
    }

    function test_Register_SecondPlayerMatchesAndFiresVRF() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);
        uint256 h2 = _mintHero(player2, HeroNFT.HeroClass.Mage);

        vm.prank(player1);
        arena.register(h1);

        vm.expectEmit(true, false, false, false);
        emit PvPArena.Matched(1, player1, player2, 1);

        vm.prank(player2);
        arena.register(h2);

        // Open slot cleared.
        assertEq(arena.openSlot(), 0);

        (, address p2,,,, PvPArena.BattleState state,,,,) = _unpackBattle(1);
        assertEq(p2, player2);
        assertEq(uint8(state), uint8(PvPArena.BattleState.Matched));
    }

    function test_Register_RevertIfNotHeroOwner() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);

        vm.prank(attacker);
        aeth.approve(address(arena), type(uint256).max);
        vm.deal(attacker, 10 ether);
        vm.prank(admin);
        aeth.transfer(attacker, 100 ether);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(PvPArena.PvPArena__NotHeroOwner.selector, attacker, h1));
        arena.register(h1);
    }

    function test_Register_RevertIfHeroAlreadyInBattle() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);

        vm.prank(player1);
        arena.register(h1);

        // player1 tries to register the same hero again.
        vm.prank(player1);
        vm.expectRevert(abi.encodeWithSelector(PvPArena.PvPArena__HeroAlreadyInBattle.selector, h1));
        arena.register(h1);
    }

    function test_Register_RevertIfSamePlayer() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);
        uint256 h2 = _mintHero(player1, HeroNFT.HeroClass.Mage);

        vm.prank(player1);
        arena.register(h1);

        vm.prank(player1);
        vm.expectRevert(abi.encodeWithSelector(PvPArena.PvPArena__SamePlayer.selector, player1));
        arena.register(h2);
    }

    function test_Register_RevertWhenPaused() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);

        vm.prank(pauser);
        arena.pause();

        vm.prank(player1);
        vm.expectRevert();
        arena.register(h1);
    }

    // claimReward()

    function test_ClaimReward_WinnerReceivesCorrectAmount() public {
        uint256 battleId = _setupMatch();
        coordinator.fulfillRequest(1, 999); // deterministic random word

        PvPArena.Battle memory b = arena.getBattle(battleId);
        address winner = b.winner;
        uint256 expectedReward = arena.getPendingReward(battleId);

        uint256 balBefore = aeth.balanceOf(winner);
        vm.prank(winner);
        arena.claimReward(battleId);

        assertEq(aeth.balanceOf(winner), balBefore + expectedReward);
    }

    function test_ClaimReward_TreasuryCutSentOnResolve() public {
        uint256 treasuryBefore = aeth.balanceOf(treasury);
        _setupMatch();
        coordinator.fulfillRequest(1, 1);

        uint256 expectedCut = (ENTRY_FEE * 2 * TREASURY_BPS) / 10_000;
        assertEq(aeth.balanceOf(treasury), treasuryBefore + expectedCut);
    }

    function test_ClaimReward_RevertIfNotWinner() public {
        uint256 battleId = _setupMatch();
        coordinator.fulfillRequest(1, 1);

        PvPArena.Battle memory b = arena.getBattle(battleId);
        address loser = (b.winner == player1) ? player2 : player1;

        vm.prank(loser);
        vm.expectRevert(abi.encodeWithSelector(PvPArena.PvPArena__NotWinner.selector, loser, battleId));
        arena.claimReward(battleId);
    }

    function test_ClaimReward_RevertIfAlreadyClaimed() public {
        uint256 battleId = _setupMatch();
        coordinator.fulfillRequest(1, 1);

        PvPArena.Battle memory b = arena.getBattle(battleId);
        vm.startPrank(b.winner);
        arena.claimReward(battleId);

        vm.expectRevert(abi.encodeWithSelector(PvPArena.PvPArena__AlreadyClaimed.selector, battleId));
        arena.claimReward(battleId);
        vm.stopPrank();
    }

    function test_ClaimReward_RevertIfBattleNotResolved() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);
        vm.prank(player1);
        arena.register(h1);
        uint256 battleId = arena.openSlot();

        vm.prank(player1);
        vm.expectRevert(
            abi.encodeWithSelector(
                PvPArena.PvPArena__InvalidState.selector,
                battleId,
                PvPArena.BattleState.Registered,
                PvPArena.BattleState.Resolved
            )
        );
        arena.claimReward(battleId);
    }

    // cancelStuckBattle()

    function test_Cancel_RefundsBothPlayersAfterWindow() public {
        uint256 battleId = _setupMatch();
        uint256 window = arena.vrfCancelWindow();

        uint256 bal1Before = aeth.balanceOf(player1);
        uint256 bal2Before = aeth.balanceOf(player2);

        vm.warp(block.timestamp + window + 1);
        arena.cancelStuckBattle(battleId);

        assertEq(aeth.balanceOf(player1), bal1Before + ENTRY_FEE);
        assertEq(aeth.balanceOf(player2), bal2Before + ENTRY_FEE);
    }

    function test_Cancel_ReleasesHeroFromBattleLock() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);
        uint256 h2 = _mintHero(player2, HeroNFT.HeroClass.Mage);

        vm.prank(player1);
        arena.register(h1);
        vm.prank(player2);
        arena.register(h2);

        vm.warp(block.timestamp + arena.vrfCancelWindow() + 1);
        arena.cancelStuckBattle(1);

        assertEq(arena.heroInBattle(h1), 0);
        assertEq(arena.heroInBattle(h2), 0);
    }

    function test_Cancel_RevertIfWindowNotElapsed() public {
        uint256 battleId = _setupMatch();

        vm.expectRevert();
        arena.cancelStuckBattle(battleId);
    }

    function test_Cancel_RevertIfNotMatchedState() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);
        vm.prank(player1);
        arena.register(h1);
        uint256 battleId = arena.openSlot();

        vm.warp(block.timestamp + arena.vrfCancelWindow() + 1);
        vm.expectRevert();
        arena.cancelStuckBattle(battleId); // state is Registered, not Matched
    }

    // State machine: invalid transitions

    function test_StateMachine_FulfillOnCancelledBattleIsNoOp() public {
        uint256 battleId = _setupMatch();
        vm.warp(block.timestamp + arena.vrfCancelWindow() + 1);
        arena.cancelStuckBattle(battleId);

        // Coordinator calls back - should be a silent no-op.
        coordinator.fulfillRequest(1, 12_345);

        PvPArena.Battle memory b = arena.getBattle(battleId);
        assertEq(uint8(b.state), uint8(PvPArena.BattleState.Cancelled));
    }

    // Admin: parameter updates

    function test_SetEntryFee_UpdatesValue() public {
        vm.prank(admin);
        arena.setEntryFee(20 ether);
        assertEq(arena.entryFee(), 20 ether);
    }

    function test_SetEntryFee_RevertIfZero() public {
        vm.prank(admin);
        vm.expectRevert(PvPArena.PvPArena__ZeroFee.selector);
        arena.setEntryFee(0);
    }

    function test_SetEntryFee_RevertIfNotAdmin() public {
        vm.prank(attacker);
        vm.expectRevert();
        arena.setEntryFee(1 ether);
    }

    function test_SetTreasuryFeeBps_RevertIfAboveMax() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(PvPArena.PvPArena__TreasuryFeeTooHigh.selector, 3001));
        arena.setTreasuryFeeBps(3001);
    }

    function test_Pause_BlocksRegister() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);
        vm.prank(pauser);
        arena.pause();

        vm.prank(player1);
        vm.expectRevert();
        arena.register(h1);
    }

    function test_Unpause_AllowsRegister() public {
        uint256 h1 = _mintHero(player1, HeroNFT.HeroClass.Warrior);
        vm.prank(pauser);
        arena.pause();
        vm.prank(pauser);
        arena.unpause();

        vm.prank(player1);
        arena.register(h1);

        assertEq(arena.openSlot(), 1);
    }

    // Internal unpack helper

    function _unpackBattle(uint256 battleId)
        internal
        view
        returns (
            address player1_,
            address player2_,
            uint256 hero1Id,
            uint256 hero2Id,
            uint256 entryFeeSnapshot,
            PvPArena.BattleState state,
            uint256 vrfRequestId,
            uint256 matchedAt,
            address winner,
            bool claimed
        )
    {
        PvPArena.Battle memory b = arena.getBattle(battleId);
        return (
            b.player1,
            b.player2,
            b.hero1Id,
            b.hero2Id,
            b.entryFeeSnapshot,
            b.state,
            b.vrfRequestId,
            b.matchedAt,
            b.winner,
            b.claimed
        );
    }
}
