// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {AethToken} from "../../contracts/token/AethToken.sol";

/**
 * @title AethTokenTest
 * @notice 7 unit tests for AethToken.
 *         Run with: forge test --match-contract AethTokenTest -vv
 */
contract AethTokenTest is Test {
    // Constant

    uint256 constant INITIAL_SUPPLY = 100_000_000 * 1e18;

    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Actors

    address admin = makeAddr("admin");
    address minter = makeAddr("minter");
    address burner = makeAddr("burner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // System under test

    AethToken token;

    // Setup

    function setUp() public {
        vm.startPrank(admin);
        token = new AethToken(admin);
        token.grantRole(MINTER_ROLE, minter);
        token.grantRole(BURNER_ROLE, burner);
        vm.stopPrank();
    }

    // Test 1: Deployment mints initial supply to admin

    function test_InitialSupplyMintedToAdmin() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY, "wrong total supply");
        assertEq(token.balanceOf(admin), INITIAL_SUPPLY, "admin balance wrong");
    }

    // Test 2: MINTER_ROLE can mint tokens

    function test_MinterCanMint() public {
        uint256 amount = 500 * 1e18;
        vm.prank(minter);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount, "alice balance wrong");
        assertEq(token.totalSupply(), INITIAL_SUPPLY + amount, "total supply wrong");
    }

    // Test 3: Non-minter cannot mint (revert with AccessControl error)

    function test_NonMinterCannotMint() public {
        bytes32 role = MINTER_ROLE;
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, role)
        );
        vm.prank(alice);
        token.mint(alice, 1e18);
    }

    // Test 4: BURNER_ROLE can burn tokens

    function test_BurnerCanBurn() public {
        // Give alice some tokens first
        vm.prank(minter);
        token.mint(alice, 1000 * 1e18);

        uint256 burnAmount = 400 * 1e18;
        vm.prank(burner);
        token.burn(alice, burnAmount);

        assertEq(token.balanceOf(alice), 600 * 1e18, "alice balance wrong after burn");
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 1000 * 1e18 - burnAmount, "total supply wrong after burn");
    }

    // Test 5: Burn more than balance reverts

    function test_BurnMoreThanBalanceReverts() public {
        vm.prank(minter);
        token.mint(alice, 100 * 1e18);

        vm.expectRevert(); // ERC20InsufficientBalance
        vm.prank(burner);
        token.burn(alice, 101 * 1e18);
    }

    // Test 6: Delegation updates voting power

    function test_DelegateUpdatesVotingPower() public {
        // Transfer some tokens to alice
        vm.prank(admin);
        token.transfer(alice, 1000 * 1e18);

        // alice delegates to herself
        vm.prank(alice);
        token.delegate(alice);

        assertEq(token.getVotes(alice), 1000 * 1e18, "alice voting power wrong");
        assertEq(token.getVotes(admin), 0, "admin should have no voting power after transfer");
    }

    // Test 7: Permit (gasless approval) works correctly

    function test_PermitAllowsGaslessApproval() public {
        // Create a wallet with a known private key so we can sign
        uint256 ownerKey = 0xA11CE;
        address owner = vm.addr(ownerKey);

        // Give owner some tokens
        vm.prank(admin);
        token.transfer(owner, 500 * 1e18);

        uint256 allowanceAmount = 200 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;

        // Build the permit digest
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        bytes32 structHash = keccak256(
            abi.encode(permitTypehash, owner, bob, allowanceAmount, token.nonces(owner), deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);

        // Anyone can submit the permit — no ETH from owner required
        vm.prank(bob);
        token.permit(owner, bob, allowanceAmount, deadline, v, r, s);

        assertEq(token.allowance(owner, bob), allowanceAmount, "permit allowance wrong");
        assertEq(token.nonces(owner), 1, "nonce should be incremented");
    }
}
