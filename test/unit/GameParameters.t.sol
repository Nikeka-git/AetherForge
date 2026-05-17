// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { GameParametersV1 } from "../../contracts/proxy/GameParametersV1.sol";
import { GameParametersV2 } from "../../contracts/proxy/GameParametersV2.sol";

/**
 * @title GameParametersTest
 * @notice Unit tests for the UUPS upgrade path GameParametersV1 -> V2.
 *
 * Run:
 *   forge test --match-contract GameParametersTest -vv
 *
 * Coverage
 * ────────
 * - V1 initialisation and default values
 * - V1 parameter setters (happy path + revert paths)
 * - Access control on all privileged functions
 * - Pause / circuit breaker
 * - UUPS upgrade: V1 -> V2 preserves all V1 storage
 * - V2 new parameter setters
 * - Unauthorised upgrade attempt reverts
 */
contract GameParametersTest is Test {
    // Actors

    address internal admin = makeAddr("admin");
    address internal manager = makeAddr("manager");
    address internal attacker = makeAddr("attacker");

    // Contracts (always accessed via the proxy)

    GameParametersV1 internal proxy; // cast to V1 interface
    ERC1967Proxy internal rawProxy;

    // Setup

    function setUp() public {
        // 1. Deploy V1 implementation.
        GameParametersV1 impl1 = new GameParametersV1();

        // 2. Encode initializer calldata.
        bytes memory initData = abi.encodeCall(GameParametersV1.initialize, (admin, manager));

        // 3. Deploy ERC1967 proxy pointing at V1 impl.
        rawProxy = new ERC1967Proxy(address(impl1), initData);

        // 4. Cast proxy to V1 interface for convenience.
        proxy = GameParametersV1(address(rawProxy));
    }

    // V1 - initialisation

    function test_v1_DefaultValues() public view {
        assertEq(proxy.lootDropRateCommon(), 3000);
        assertEq(proxy.lootDropRateRare(), 500);
        assertEq(proxy.arenaEntryFeeUsd(), 5e8);
        assertEq(proxy.maxCraftingIngredients(), 10);
        assertEq(proxy.treasuryFeeBps(), 500);
        assertEq(proxy.maxRentalDuration(), 7 days);
    }

    function test_v1_Version() public view {
        assertEq(proxy.version(), "1.0.0");
    }

    function test_v1_ImplementationCannotBeInitialised() public {
        // Calling initialize on the implementation directly must revert
        // because _disableInitializers() was called in the constructor.
        GameParametersV1 impl = new GameParametersV1();
        vm.expectRevert();
        impl.initialize(admin, manager);
    }

    // V1 - loot drop rates

    function test_v1_SetLootDropRates_Success() public {
        vm.prank(manager);
        proxy.setLootDropRates(4000, 1000);

        assertEq(proxy.lootDropRateCommon(), 4000);
        assertEq(proxy.lootDropRateRare(), 1000);
    }

    function test_v1_SetLootDropRates_RevertsWhenSumExceedsBPS() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(GameParametersV1.GameParameters__DropRatesTooHigh.selector, 8000, 4000));
        proxy.setLootDropRates(8000, 4000); // 12_000 > 10_000
    }

    function test_v1_SetLootDropRates_RevertsForNonManager() public {
        vm.prank(attacker);
        vm.expectRevert();
        proxy.setLootDropRates(1000, 500);
    }

    // V1 - arena entry fee

    function test_v1_SetArenaEntryFee_Success() public {
        vm.prank(manager);
        proxy.setArenaEntryFee(10e8); // $10

        assertEq(proxy.arenaEntryFeeUsd(), 10e8);
    }

    function test_v1_SetArenaEntryFee_RevertsOnZero() public {
        vm.prank(manager);
        vm.expectRevert(GameParametersV1.GameParameters__ZeroValue.selector);
        proxy.setArenaEntryFee(0);
    }

    // V1 - max crafting ingredients

    function test_v1_SetMaxCraftingIngredients_Success() public {
        vm.prank(manager);
        proxy.setMaxCraftingIngredients(5);

        assertEq(proxy.maxCraftingIngredients(), 5);
    }

    function test_v1_SetMaxCraftingIngredients_RevertsOnZero() public {
        vm.prank(manager);
        vm.expectRevert(GameParametersV1.GameParameters__ZeroValue.selector);
        proxy.setMaxCraftingIngredients(0);
    }

    // V1 - treasury fee

    function test_v1_SetTreasuryFeeBps_Success() public {
        vm.prank(manager);
        proxy.setTreasuryFeeBps(1000); // 10 %

        assertEq(proxy.treasuryFeeBps(), 1000);
    }

    function test_v1_SetTreasuryFeeBps_RevertsAbove10000() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(GameParametersV1.GameParameters__FeeTooHigh.selector, 10_001));
        proxy.setTreasuryFeeBps(10_001);
    }

    // V1 - pause / circuit breaker

    function test_v1_Pause_BlocksSetters() public {
        vm.prank(admin);
        proxy.pause();

        vm.prank(manager);
        vm.expectRevert();
        proxy.setArenaEntryFee(10e8);
    }

    function test_v1_Unpause_ResumesSetters() public {
        vm.prank(admin);
        proxy.pause();

        vm.prank(admin);
        proxy.unpause();

        vm.prank(manager);
        proxy.setArenaEntryFee(10e8); // must not revert
        assertEq(proxy.arenaEntryFeeUsd(), 10e8);
    }

    function test_v1_Pause_RevertsForNonPauser() public {
        vm.prank(attacker);
        vm.expectRevert();
        proxy.pause();
    }

    // UUPS upgrade - V1 -> V2

    function test_upgrade_UnauthorisedRevertsForAttacker() public {
        GameParametersV2 impl2 = new GameParametersV2();

        vm.prank(attacker);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(impl2), "");
    }

    function test_upgrade_PreservesV1Storage() public {
        // First change some V1 state so we can verify it survives the upgrade.
        vm.prank(manager);
        proxy.setArenaEntryFee(20e8); // $20
        vm.prank(manager);
        proxy.setTreasuryFeeBps(750); // 7.5 %

        // Deploy V2 implementation.
        GameParametersV2 impl2 = new GameParametersV2();

        // Admin (holds UPGRADER_ROLE) authorises upgrade.
        vm.prank(admin);
        proxy.upgradeToAndCall(address(impl2), "");

        // Cast proxy to V2.
        GameParametersV2 proxyV2 = GameParametersV2(address(rawProxy));

        // All V1 state must be preserved.
        assertEq(proxyV2.arenaEntryFeeUsd(), 20e8, "arenaEntryFeeUsd lost");
        assertEq(proxyV2.treasuryFeeBps(), 750, "treasuryFeeBps lost");
        assertEq(proxyV2.lootDropRateCommon(), 3000, "lootDropRateCommon lost");
        assertEq(proxyV2.lootDropRateRare(), 500, "lootDropRateRare lost");
        assertEq(proxyV2.maxCraftingIngredients(), 10, "maxCraftingIngredients lost");
        assertEq(proxyV2.maxRentalDuration(), 7 days, "maxRentalDuration lost");
    }

    function test_upgrade_V2VersionString() public {
        GameParametersV2 impl2 = new GameParametersV2();

        vm.prank(admin);
        proxy.upgradeToAndCall(address(impl2), "");

        GameParametersV2 proxyV2 = GameParametersV2(address(rawProxy));
        assertEq(proxyV2.version(), "2.0.0");
    }

    function test_upgrade_V2InitializerSetsNewParams() public {
        GameParametersV2 impl2 = new GameParametersV2();

        // Upgrade then call initializeV2.
        bytes memory v2Init = abi.encodeCall(GameParametersV2.initializeV2, (100, 200));
        vm.prank(admin);
        proxy.upgradeToAndCall(address(impl2), v2Init);

        GameParametersV2 proxyV2 = GameParametersV2(address(rawProxy));
        assertEq(proxyV2.pvpWinStreakBonus(), 100);
        assertEq(proxyV2.craftingDiscountBps(), 200);
    }

    function test_upgrade_V2InitializerCannotRunTwice() public {
        GameParametersV2 impl2 = new GameParametersV2();
        bytes memory v2Init = abi.encodeCall(GameParametersV2.initializeV2, (100, 200));

        vm.prank(admin);
        proxy.upgradeToAndCall(address(impl2), v2Init);

        GameParametersV2 proxyV2 = GameParametersV2(address(rawProxy));
        vm.expectRevert();
        proxyV2.initializeV2(100, 200); // second call must revert
    }

    // V2 setters (after upgrade)

    function _upgradeToV2() internal returns (GameParametersV2 proxyV2) {
        GameParametersV2 impl2 = new GameParametersV2();
        bytes memory v2Init = abi.encodeCall(GameParametersV2.initializeV2, (50, 100));
        vm.prank(admin);
        proxy.upgradeToAndCall(address(impl2), v2Init);
        proxyV2 = GameParametersV2(address(rawProxy));
    }

    function test_v2_SetWinStreakBonus_Success() public {
        GameParametersV2 proxyV2 = _upgradeToV2();

        vm.prank(manager);
        proxyV2.setWinStreakBonus(200);

        assertEq(proxyV2.pvpWinStreakBonus(), 200);
    }

    function test_v2_SetCraftingDiscount_Success() public {
        GameParametersV2 proxyV2 = _upgradeToV2();

        vm.prank(manager);
        proxyV2.setCraftingDiscount(300);

        assertEq(proxyV2.craftingDiscountBps(), 300);
    }

    function test_v2_SetCraftingDiscount_RevertsAboveBPS() public {
        GameParametersV2 proxyV2 = _upgradeToV2();

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(GameParametersV1.GameParameters__FeeTooHigh.selector, 10_001));
        proxyV2.setCraftingDiscount(10_001);
    }
}
