// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { AccessVuln, AccessFixed } from "../../contracts/security/AccessVuln.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/*─────────────────────────────────────────────────────────────────────────────
 * Security Case Study 2 - Access Control
 *
 * Test structure
 * ──────────────
 * Part A  (VULNERABLE)  - demonstrates two exploits:
 *   A1. Any address can mint unlimited items (unprotected mint).
 *   A2. Any address can seize admin (unclaimed admin role).
 *
 * Part B  (FIXED)       - demonstrates both exploits are prevented:
 *   B1. Unauthorised mint reverts.
 *   B2. Admin is assigned at construction; claimAdmin() does not exist.
 *   B3. Only MINTER_ROLE can mint; role grant requires DEFAULT_ADMIN_ROLE.
 *
 * Run: forge test --match-contract SecurityAccessControlTest -vvv
 *─────────────────────────────────────────────────────────────────────────────*/

contract SecurityAccessControlTest is Test {
    AccessVuln internal vuln;
    AccessFixed internal fixed_;

    address internal admin = makeAddr("admin");
    address internal minter = makeAddr("minter");
    address internal attacker = makeAddr("attacker");
    address internal player = makeAddr("player");

    uint256 constant ITEM_ID = 42;

    function setUp() public {
        vuln = new AccessVuln();
        fixed_ = new AccessFixed(admin);
    }

    // Part A: VULNERABLE

    /**
     * @notice A1 - BEFORE fix: attacker mints items without any role.
     *
     * Because mint() has no onlyRole guard, any address can mint
     * unlimited items and break the in-game economy.
     */
    function test_Vuln_AnyoneCanMint() public {
        // Attacker mints 1_000_000 items to themselves - no role needed
        vm.prank(attacker);
        vuln.mint(attacker, ITEM_ID, 1_000_000);

        uint256 balance = vuln.itemBalances(attacker, ITEM_ID);

        assertEq(balance, 1_000_000, "attacker should have minted without restriction");
    }

    /**
     * @notice A1b - BEFORE fix: attacker mints items FOR another player.
     *
     * The impact is symmetric - the attacker can also mint to any address,
     * enabling item duplication, market manipulation, and gifting exploits.
     */
    function test_Vuln_AttackerMintsForOthers() public {
        vm.prank(attacker);
        vuln.mint(player, ITEM_ID, 9999);

        assertEq(vuln.itemBalances(player, ITEM_ID), 9999);
    }

    /**
     * @notice A2 - BEFORE fix: attacker claims admin role.
     *
     * The constructor never assigns admin, so the first caller of
     * claimAdmin() becomes the permanent admin.
     */
    function test_Vuln_AttackerClaimsAdmin() public {
        // Before any claim, admin is zero
        assertEq(vuln.admin(), address(0));

        vm.prank(attacker);
        vuln.claimAdmin();

        assertEq(vuln.admin(), attacker, "attacker should have claimed admin");
    }

    /**
     * @notice A2b - BEFORE fix: setAdmin() has no caller check.
     *
     * Even after admin is set, the unguarded setAdmin() lets anyone
     * overwrite the admin address at will.
     */
    function test_Vuln_AnyoneCanSetAdmin() public {
        // Legitimate admin claims first
        vm.prank(admin);
        vuln.claimAdmin();
        assertEq(vuln.admin(), admin);

        // Attacker overwrites admin with no restriction
        vm.prank(attacker);
        vuln.setAdmin(attacker);

        assertEq(vuln.admin(), attacker, "attacker should have overwritten admin");
    }

    // Part B: FIXED=

    /**
     * @notice B1 - AFTER fix: unauthorised mint reverts.
     *
     * mint() is guarded by onlyRole(MINTER_ROLE). Attacker has no role
     * and the call must revert with AccessControlUnauthorizedAccount.
     */
    function test_Fixed_UnauthorisedMintReverts() public {
        bytes32 minterRole = fixed_.MINTER_ROLE(); // read before prank
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, attacker, minterRole)
        );
        vm.prank(attacker);
        fixed_.mint(attacker, ITEM_ID, 1_000_000);

        // Attacker's balance is zero
        assertEq(fixed_.itemBalances(attacker, ITEM_ID), 0);
    }

    /**
     * @notice B2 - AFTER fix: admin is set at construction, cannot be claimed.
     *
     * AccessFixed has no claimAdmin() function.  The admin address holds
     * DEFAULT_ADMIN_ROLE from the moment the contract is deployed.
     */
    function test_Fixed_AdminSetAtConstruction() public view {
        assertTrue(
            fixed_.hasRole(fixed_.DEFAULT_ADMIN_ROLE(), admin), "admin should hold DEFAULT_ADMIN_ROLE from constructor"
        );
    }

    /**
     * @notice B3 - AFTER fix: only MINTER_ROLE can mint; granting role requires admin.
     *
     * The full authorised path: admin grants MINTER_ROLE to minter,
     * minter mints successfully, and the balance is correct.
     */
    function test_Fixed_AuthorisedMinterCanMint() public {
        // Admin grants minter role
        vm.startPrank(admin);
        fixed_.grantRole(fixed_.MINTER_ROLE(), minter);
        vm.stopPrank();

        // Minter mints items for player
        vm.startPrank(minter);
        fixed_.mint(player, ITEM_ID, 100);
        vm.stopPrank();

        assertEq(fixed_.itemBalances(player, ITEM_ID), 100, "authorised mint should succeed");
    }

    /**
     * @notice B3b - AFTER fix: attacker cannot grant themselves MINTER_ROLE.
     *
     * grantRole() internally checks that msg.sender holds the admin role
     * for the role being granted.  Attacker has no admin role -> revert.
     */
    function test_Fixed_AttackerCannotGrantOwnRole() public {
        bytes32 adminRole = fixed_.DEFAULT_ADMIN_ROLE(); // read before prank
        bytes32 minterRole = fixed_.MINTER_ROLE(); // read before prank
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, attacker, adminRole)
        );
        vm.prank(attacker);
        fixed_.grantRole(minterRole, attacker);
    }

    /**
     * @notice B4 - AFTER fix: mint to zero address reverts.
     */
    function test_Fixed_MintToZeroAddressReverts() public {
        vm.startPrank(admin);
        fixed_.grantRole(fixed_.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.prank(minter);
        vm.expectRevert("mint to zero address");
        fixed_.mint(address(0), ITEM_ID, 1);
    }

    /**
     * @notice B5 - AFTER fix: mint with zero amount reverts.
     */
    function test_Fixed_MintZeroAmountReverts() public {
        vm.startPrank(admin);
        fixed_.grantRole(fixed_.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.prank(minter);
        vm.expectRevert("amount must be > 0");
        fixed_.mint(player, ITEM_ID, 0);
    }
}
