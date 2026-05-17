// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { GameParametersV1 } from "./GameParametersV1.sol";

/**
 * @title GameParametersV2
 * @notice V2 upgrade of GameParametersV1.
 *
 * What changed in V2
 * ──────────────────
 * 1. Added 'pvpWinStreakBonus' - bonus loot-drop BPS awarded for consecutive
 *    arena wins.  Incentivises active gameplay without changing V1 economics.
 * 2. Added 'craftingDiscountBps' - discount on crafting USD cost for players
 *    holding >= DISCOUNT_THRESHOLD AETH, readable by CraftingEngine.
 * 3. 'version()' now returns "2.0.0".
 *
 * Storage safety
 * ──────────────
 * V1 storage layout is untouched.  New variables are appended in the gap
 * left by V1's __gap[50].  V2 consumes 2 of those 50 slots, so __gap shrinks
 * to 48.  The upgrade is verified with `forge inspect` storage-layout diffs.
 *
 * Upgrade procedure (reproduce exactly)
 * ──────────────────────────────────────
 * 1. Deploy GameParametersV2 implementation (no constructor args - it calls
 *    _disableInitializers() via inheritance).
 * 2. Governance proposal:
 *      target  = proxy address
 *      calldata = upgradeToAndCall(v2Impl, "")   // no re-initialisation needed
 * 3. Timelock queues -> 2-day delay -> execute.
 * 4. Call initializeV2(winStreakBonusBps, discountBps) once after upgrade
 *    (idempotent: guarded by reinitializer(2)).
 *
 * Proof that V1 state is preserved
 * ──────────────────────────────────
 * The test GameParameters.t.sol::test_upgrade_PreservesV1Storage() forks a
 * local environment, upgrades the proxy, and asserts that every V1 variable
 * retains its value after the upgrade.
 */
contract GameParametersV2 is GameParametersV1 {
    // New V2 parameters (appended after V1 slots, before __gap shrinks)

    /// @notice Extra loot-drop rate (BPS) awarded per consecutive arena win.
    ///         Applied on top of lootDropRateCommon by PvPArena.
    ///         Example: 50 = +0.5 % per win in a streak.
    uint256 public pvpWinStreakBonus;

    /// @notice Crafting cost discount (BPS) for high AETH holders.
    ///         Applied by CraftingEngine when msg.sender holds >= DISCOUNT_THRESHOLD.
    uint256 public craftingDiscountBps;

    // Events

    event WinStreakBonusUpdated(uint256 oldBps, uint256 newBps);
    event CraftingDiscountUpdated(uint256 oldBps, uint256 newBps);

    // V2 initialiser - called once after upgradeToAndCall

    /**
     * @notice Initialise V2-specific parameters.
     * @dev    Uses reinitializer(2) so it can only run once on the V2 impl.
     *         V1 initializer has already run; this only sets the new fields.
     */
    function initializeV2(uint256 winStreakBonusBps, uint256 discountBps) external reinitializer(2) {
        if (winStreakBonusBps + lootDropRateCommon + lootDropRateRare > BPS_DENOMINATOR) {
            revert GameParameters__DropRatesTooHigh(winStreakBonusBps, lootDropRateCommon);
        }
        if (discountBps > BPS_DENOMINATOR) revert GameParameters__FeeTooHigh(discountBps);

        pvpWinStreakBonus = winStreakBonusBps;
        craftingDiscountBps = discountBps;

        emit WinStreakBonusUpdated(0, winStreakBonusBps);
        emit CraftingDiscountUpdated(0, discountBps);
    }

    // V2 setters

    function setWinStreakBonus(uint256 newBps) external onlyRole(PARAM_MANAGER_ROLE) whenNotPaused {
        if (newBps + lootDropRateCommon + lootDropRateRare > BPS_DENOMINATOR) {
            revert GameParameters__DropRatesTooHigh(newBps, lootDropRateCommon);
        }
        uint256 old = pvpWinStreakBonus;
        pvpWinStreakBonus = newBps;
        emit WinStreakBonusUpdated(old, newBps);
    }

    function setCraftingDiscount(uint256 newBps) external onlyRole(PARAM_MANAGER_ROLE) whenNotPaused {
        if (newBps > BPS_DENOMINATOR) revert GameParameters__FeeTooHigh(newBps);
        uint256 old = craftingDiscountBps;
        craftingDiscountBps = newBps;
        emit CraftingDiscountUpdated(old, newBps);
    }

    // Version

    function version() external pure override returns (string memory) {
        return "2.0.0";
    }

    // Storage gap - 48 slots remain (V1 had 50, V2 used 2)

    // slither-disable-next-line unused-state,naming-convention
    uint256[48] private __gap;
}
