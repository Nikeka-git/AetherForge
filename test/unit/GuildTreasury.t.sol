// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { GuildTreasury } from "../../contracts/vault/GuildTreasury.sol";
import { AethToken } from "../../contracts/token/AethToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title GuildTreasuryTest
 * @notice 8 unit tests for GuildTreasury (ERC-4626 vault).
 *         Run with: forge test --match-contract GuildTreasuryTest -vv
 */
contract GuildTreasuryTest is Test {
    // Roles

    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");

    // Actors

    address admin = makeAddr("admin");
    address yieldManager = makeAddr("yieldManager");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // System under test

    AethToken aeth;
    GuildTreasury vault;

    // Setup

    function setUp() public {
        vm.startPrank(admin);
        aeth = new AethToken(admin);
        vault = new GuildTreasury(IERC20(address(aeth)), admin);
        vault.grantRole(YIELD_MANAGER_ROLE, yieldManager);
        // Give admin MINTER_ROLE on AethToken to fund test actors
        aeth.grantRole(MINTER_ROLE, admin);
        vm.stopPrank();

        // Fund alice and bob with AETH
        vm.prank(admin);
        aeth.mint(alice, 10_000 * 1e18);
        vm.prank(admin);
        aeth.mint(bob, 10_000 * 1e18);

        // Fund yieldManager for injectYield calls
        vm.prank(admin);
        aeth.mint(yieldManager, 50_000 * 1e18);
    }

    // Test 1: Vault metadata

    function test_VaultMetadata() public view {
        assertEq(vault.name(), "Guild Treasury Share", "name wrong");
        assertEq(vault.symbol(), "gAETH", "symbol wrong");
        assertEq(vault.asset(), address(aeth), "asset wrong");
        assertEq(vault.decimals(), aeth.decimals() + 3, "decimals offset wrong");
    }

    // Test 2: Deposit mints shares

    function test_DepositMintsShares() public {
        uint256 depositAmount = 1000 * 1e18;

        vm.startPrank(alice);
        aeth.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);
        vm.stopPrank();

        assertGt(shares, 0, "should receive shares");
        assertEq(vault.balanceOf(alice), shares, "alice share balance wrong");
        assertEq(vault.totalAssets(), depositAmount, "totalAssets wrong");
    }

    // Test 3: Redeem returns assets

    function test_RedeemReturnsAssets() public {
        uint256 depositAmount = 1000 * 1e18;

        vm.startPrank(alice);
        aeth.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);

        uint256 balBefore = aeth.balanceOf(alice);
        vault.redeem(shares, alice, alice);
        vm.stopPrank();

        uint256 received = aeth.balanceOf(alice) - balBefore;
        // Allow 1 wei rounding due to _decimalsOffset
        assertApproxEqAbs(received, depositAmount, 1, "redeemed assets wrong");
        assertEq(vault.balanceOf(alice), 0, "alice should have no shares left");
    }

    // Test 4: Yield injection raises share price

    function test_YieldInjectionRaisesSharePrice() public {
        uint256 depositAmount = 1000 * 1e18;

        vm.startPrank(alice);
        aeth.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        uint256 assetsBefore = vault.totalAssets();

        // Inject yield
        uint256 yieldAmount = 100 * 1e18;
        vm.startPrank(yieldManager);
        aeth.approve(address(vault), yieldAmount);
        vault.injectYield(yieldAmount);
        vm.stopPrank();

        assertEq(vault.totalAssets(), assetsBefore + yieldAmount, "totalAssets should include yield");

        // Alice's shares are now worth more
        uint256 aliceAssets = vault.convertToAssets(vault.balanceOf(alice));
        assertGt(aliceAssets, depositAmount, "share price should have increased");
    }

    // Test 5: Two depositors get proportional shares

    function test_TwoDepositorsGetProportionalShares() public {
        uint256 aliceDeposit = 1000 * 1e18;
        uint256 bobDeposit = 3000 * 1e18;

        vm.startPrank(alice);
        aeth.approve(address(vault), aliceDeposit);
        uint256 aliceShares = vault.deposit(aliceDeposit, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        aeth.approve(address(vault), bobDeposit);
        uint256 bobShares = vault.deposit(bobDeposit, bob);
        vm.stopPrank();

        // Bob deposited 3× alice, should have ~3× shares (allow 1 wei rounding)
        assertApproxEqAbs(bobShares, aliceShares * 3, 1e15, "bob shares should be 3x alice");
    }

    // Test 6: Non-yield-manager cannot inject yield

    function test_NonYieldManagerCannotInjectYield() public {
        vm.prank(admin);
        aeth.mint(alice, 100 * 1e18);

        vm.startPrank(alice);
        aeth.approve(address(vault), 100 * 1e18);
        vm.expectRevert();
        vault.injectYield(100 * 1e18);
        vm.stopPrank();
    }

    // Test 7: previewDeposit matches actual shares minted

    function test_PreviewDepositMatchesActual() public {
        uint256 depositAmount = 2500 * 1e18;

        uint256 preview = vault.previewDeposit(depositAmount);

        vm.startPrank(alice);
        aeth.approve(address(vault), depositAmount);
        uint256 actual = vault.deposit(depositAmount, alice);
        vm.stopPrank();

        assertEq(preview, actual, "previewDeposit must match actual shares");
    }

    // Test 8: maxWithdraw equals deposited amount (no yield)

    function test_MaxWithdrawEqualsDepositedAmount() public {
        uint256 depositAmount = 500 * 1e18;

        vm.startPrank(alice);
        aeth.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        uint256 maxWithdraw = vault.maxWithdraw(alice);
        assertApproxEqAbs(maxWithdraw, depositAmount, 1, "maxWithdraw should equal deposit (no yield)");
    }

    // Test 9: constructor reverts on zero admin address

    function test_Constructor_RevertsOnZeroAdmin() public {
        vm.expectRevert(GuildTreasury.GuildTreasury__ZeroAddress.selector);
        new GuildTreasury(IERC20(address(aeth)), address(0));
    }

    // Test 10: injectYield reverts on zero amount

    function test_InjectYield_RevertsOnZeroAmount() public {
        vm.expectRevert(GuildTreasury.GuildTreasury__ZeroAmount.selector);
        vm.prank(yieldManager);
        vault.injectYield(0);
    }

    // Test 11: supportsInterface returns true for AccessControl interface

    function test_SupportsInterface() public view {
        // IAccessControl interfaceId = 0x7965db0b
        assertTrue(vault.supportsInterface(type(IAccessControl).interfaceId));
    }
}
