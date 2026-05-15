// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { GuildTreasury } from "../../contracts/vault/GuildTreasury.sol";
import { AethToken } from "../../contracts/token/AethToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GuildTreasuryFuzzTest
 * @notice Fuzz tests for GuildTreasury ERC-4626 vault.
 *         Run with: forge test --match-contract GuildTreasuryFuzzTest -vv
 *
 * Tests
 * ──────
 * 1. testFuzz_DepositRedeemRoundTrip        - redeem after deposit returns <= deposited (rounding DOWN)
 * 2. testFuzz_ConvertToSharesMonotone       - larger deposit -> more shares
 * 3. testFuzz_InflationAttackUnprofitable   - donation attack cannot profit against _decimalsOffset(3)
 */
contract GuildTreasuryFuzzTest is Test {
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");

    address admin = makeAddr("admin");
    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");

    AethToken aeth;
    GuildTreasury vault;

    function setUp() public {
        vm.startPrank(admin);
        aeth = new AethToken(admin);
        vault = new GuildTreasury(IERC20(address(aeth)), admin);
        aeth.grantRole(MINTER_ROLE, admin);
        vm.stopPrank();
    }

    // Fuzz test 1: deposit -> redeem round trip

    /**
     * @dev ERC-4626 spec: redeem(deposit(assets)) <= assets (rounds down).
     *      User should never receive MORE than they deposited (ignoring yield).
     */
    function testFuzz_DepositRedeemRoundTrip(uint256 assets) public {
        assets = bound(assets, 1e15, 1_000_000 * 1e18); // 0.001 to 1M AETH

        vm.prank(admin);
        aeth.mint(address(this), assets);
        aeth.approve(address(vault), assets);

        uint256 shares = vault.deposit(assets, address(this));
        uint256 redeemed = vault.redeem(shares, address(this), address(this));

        // Rounding: redeemed <= assets always (ERC-4626 rounds in vault's favour)
        assertLe(redeemed, assets, "redeemed > deposited: rounding violation");
        // Allow max 1 wei loss due to _decimalsOffset virtual shares
        assertApproxEqAbs(redeemed, assets, 1, "round-trip loss too large");
    }

    // Fuzz test 2: convertToShares is monotone

    /**
     * @dev More assets in -> more shares out (monotone non-decreasing).
     */
    function testFuzz_ConvertToSharesMonotone(uint256 assetsA, uint256 assetsB) public view {
        assetsA = bound(assetsA, 1, 500_000 * 1e18);
        assetsB = bound(assetsB, assetsA, 1_000_000 * 1e18); // assetsB >= assetsA

        uint256 sharesA = vault.convertToShares(assetsA);
        uint256 sharesB = vault.convertToShares(assetsB);

        assertLe(sharesA, sharesB, "convertToShares not monotone: more assets gave fewer shares");
    }

    // Fuzz test 3: inflation attack unprofitable

    /**
     * @dev Classic inflation attack scenario:
     *      1. Attacker deposits 1 wei to get 1 share.
     *      2. Attacker donates 'donationAmount' directly to the vault (inflating share price).
     *      3. Victim deposits 'victimDeposit'.
     *      4. Attacker redeems their 1 share.
     *      5. Assert: attacker's profit <= 0 (attack is unprofitable).
     *
     *      With _decimalsOffset = 3, virtual shares = 1000 per 1 real share,
     *      so the attacker's 1 share controls only 1/1001 of the virtual pool -
     *      making the attack ~1000× less effective than without the offset.
     */
    function testFuzz_InflationAttackUnprofitable(uint256 donationAmount, uint256 victimDeposit) public {
        donationAmount = bound(donationAmount, 1e15, 100_000 * 1e18);
        victimDeposit = bound(victimDeposit, 1e15, 100_000 * 1e18);

        // Fund actors
        vm.prank(admin);
        aeth.mint(attacker, donationAmount + 1e18);
        vm.prank(admin);
        aeth.mint(victim, victimDeposit);

        uint256 attackerStart = aeth.balanceOf(attacker);

        // Step 1: attacker deposits 1 wei
        vm.startPrank(attacker);
        aeth.approve(address(vault), type(uint256).max);
        vault.deposit(1e15, attacker); // small initial deposit
        vm.stopPrank();

        // Step 2: attacker donates directly (inflates totalAssets without getting shares)
        vm.prank(attacker);
        aeth.transfer(address(vault), donationAmount);

        // Step 3: victim deposits
        vm.startPrank(victim);
        aeth.approve(address(vault), victimDeposit);
        vault.deposit(victimDeposit, victim);
        vm.stopPrank();

        // Step 4: attacker redeems all shares
        uint256 attackerShares = vault.balanceOf(attacker);
        vm.prank(attacker);
        vault.redeem(attackerShares, attacker, attacker);

        // Step 5: attacker must not have profited
        uint256 attackerEnd = aeth.balanceOf(attacker);
        assertLe(attackerEnd, attackerStart, "inflation attack was profitable - fix decimals offset");
    }
}
