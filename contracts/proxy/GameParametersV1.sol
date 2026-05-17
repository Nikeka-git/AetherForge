// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";

/**
 * @title GameParametersV1
 * @notice UUPS-upgradeable contract that stores DAO-governed game parameters
 *         for the AetherForge GameFi economy (Option B requirement).
 *
 * Why upgradeable?
 * ────────────────
 * Game balance must evolve after launch. Rather than redeploying a new
 * contract (which would break all integrations), the Timelock/DAO can
 * propose upgrades via governance and the UUPS proxy routes calls to the
 * new implementation automatically.  All protocol contracts (CraftingEngine,
 * PvPArena, MercenaryGuild) read their tunable parameters from this contract
 * via the proxy address - they never need to be redeployed.
 *
 * Storage layout (V1)
 * ────────────────────
 * Slots 0-49:  inherited from Initializable (1 slot used)
 * Slots 50-99: inherited from AccessControlUpgradeable
 * Slots 100+:  V1-specific parameters below
 *
 * The _gap array at the end reserves 50 slots so V2 can add new variables
 * without colliding with any downstream contract's storage.
 *
 * V1 -> V2 upgrade path (documented per Section 3.1)
 * ──────────────────────────────────────────────────
 * V2 (GameParametersV2.sol) extends V1 storage by appending new variables
 * AFTER the existing ones and BEFORE the gap array.  The gap size shrinks
 * accordingly.  The upgrade is authorised only by the Timelock (UPGRADER_ROLE).
 *
 * Upgrade procedure:
 *   1. Deploy GameParametersV2 implementation.
 *   2. Governance proposes: proxy.upgradeToAndCall(v2Impl, initData)
 *   3. Timelock queues -> 2-day delay -> execute.
 *   4. All callers transparently use V2 logic with V1 state intact.
 *
 * Roles
 * ─────
 * DEFAULT_ADMIN_ROLE - grant/revoke roles (transferred to Timelock post-deploy).
 * PARAM_MANAGER_ROLE - update individual parameters.
 * UPGRADER_ROLE      - authorise UUPS upgrades (held by Timelock).
 * PAUSER_ROLE        - emergency pause.
 *
 * Design patterns used
 * ─────────────────────
 * - Proxy / UUPS (upgradeability)
 * - Access Control / Role-based permissions
 * - Pausable / Circuit Breaker
 * - State Machine: parameters only readable when not paused
 */
contract GameParametersV1 is Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    // Roles

    bytes32 public constant PARAM_MANAGER_ROLE = keccak256("PARAM_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Constants

    uint256 public constant BPS_DENOMINATOR = 10_000;

    // V1 Parameters

    /// @notice Loot drop rate for common items (basis points, 0-10_000).
    ///         Example: 3000 = 30 % chance of a common drop per arena match.
    uint256 public lootDropRateCommon;

    /// @notice Loot drop rate for rare items (basis points).
    ///         Must satisfy: lootDropRateCommon + lootDropRateRare <= 10_000.
    uint256 public lootDropRateRare;

    /// @notice Base arena entry fee in USD-8-decimal Chainlink format.
    ///         Example: 5e8 = $5.00 per match.
    uint256 public arenaEntryFeeUsd;

    /// @notice Maximum number of ingredients allowed per crafting recipe.
    ///         Governed to prevent DoS via unbounded loops in CraftingEngine.
    uint256 public maxCraftingIngredients;

    /// @notice Percentage of arena entry fees sent to GuildTreasury (basis points).
    ///         Remainder is burned. Example: 500 = 5 % to treasury.
    uint256 public treasuryFeeBps;

    /// @notice Mercenary rental period in seconds.
    ///         Example: 86_400 = 1 day maximum rental.
    uint256 public maxRentalDuration;

    // Events

    event LootDropRatesUpdated(uint256 commonBps, uint256 rareBps);
    event ArenaEntryFeeUpdated(uint256 oldFee, uint256 newFee);
    event MaxCraftingIngredientsUpdated(uint256 oldMax, uint256 newMax);
    event TreasuryFeeBpsUpdated(uint256 oldBps, uint256 newBps);
    event MaxRentalDurationUpdated(uint256 oldDuration, uint256 newDuration);

    // Errors

    error GameParameters__DropRatesTooHigh(uint256 common, uint256 rare);
    error GameParameters__FeeTooHigh(uint256 bps);
    error GameParameters__ZeroValue();

    // Constructor - disable direct initialisation on the implementation

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // Initializer (replaces constructor for the proxy)

    /**
     * @notice Initialise V1 with sensible defaults.
     * @param admin     Receives DEFAULT_ADMIN_ROLE + UPGRADER_ROLE.
     *                  Should be transferred to the Timelock after deployment.
     * @param manager   Receives PARAM_MANAGER_ROLE (e.g., a multisig or DAO).
     */
    function initialize(address admin, address manager) external initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(PARAM_MANAGER_ROLE, manager);

        // Sensible V1 defaults
        lootDropRateCommon = 3000; // 30 %
        lootDropRateRare = 500; // 5 %
        arenaEntryFeeUsd = 5e8; // $5.00
        maxCraftingIngredients = 10;
        treasuryFeeBps = 500; // 5 %
        maxRentalDuration = 7 days;
    }

    // Parameter setters - callable by PARAM_MANAGER_ROLE (via Timelock)

    /**
     * @notice Update loot drop rates.
     * @param commonBps Common item drop probability in basis points.
     * @param rareBps   Rare item drop probability in basis points.
     */
    function setLootDropRates(uint256 commonBps, uint256 rareBps) external onlyRole(PARAM_MANAGER_ROLE) whenNotPaused {
        if (commonBps + rareBps > BPS_DENOMINATOR) {
            revert GameParameters__DropRatesTooHigh(commonBps, rareBps);
        }
        lootDropRateCommon = commonBps;
        lootDropRateRare = rareBps;
        emit LootDropRatesUpdated(commonBps, rareBps);
    }

    /**
     * @notice Update arena entry fee.
     * @param newFeeUsd New fee in Chainlink 8-decimal USD format.
     */
    function setArenaEntryFee(uint256 newFeeUsd) external onlyRole(PARAM_MANAGER_ROLE) whenNotPaused {
        if (newFeeUsd == 0) revert GameParameters__ZeroValue();
        uint256 old = arenaEntryFeeUsd;
        arenaEntryFeeUsd = newFeeUsd;
        emit ArenaEntryFeeUpdated(old, newFeeUsd);
    }

    /**
     * @notice Update max crafting ingredients per recipe.
     */
    function setMaxCraftingIngredients(uint256 newMax) external onlyRole(PARAM_MANAGER_ROLE) whenNotPaused {
        if (newMax == 0) revert GameParameters__ZeroValue();
        uint256 old = maxCraftingIngredients;
        maxCraftingIngredients = newMax;
        emit MaxCraftingIngredientsUpdated(old, newMax);
    }

    /**
     * @notice Update treasury fee (bps of arena entry fee).
     */
    function setTreasuryFeeBps(uint256 newBps) external onlyRole(PARAM_MANAGER_ROLE) whenNotPaused {
        if (newBps > BPS_DENOMINATOR) revert GameParameters__FeeTooHigh(newBps);
        uint256 old = treasuryFeeBps;
        treasuryFeeBps = newBps;
        emit TreasuryFeeBpsUpdated(old, newBps);
    }

    /**
     * @notice Update maximum NFT rental duration.
     */
    function setMaxRentalDuration(uint256 newDuration) external onlyRole(PARAM_MANAGER_ROLE) whenNotPaused {
        if (newDuration == 0) revert GameParameters__ZeroValue();
        uint256 old = maxRentalDuration;
        maxRentalDuration = newDuration;
        emit MaxRentalDurationUpdated(old, newDuration);
    }

    // Pause / unpause

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // UUPS: only UPGRADER_ROLE (held by Timelock) can authorise upgrades

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    // Version

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    // Storage gap - reserves 50 slots for future V2+ variables

    // slither-disable-next-line unused-state,naming-convention
    uint256[50] private __gap;
}
