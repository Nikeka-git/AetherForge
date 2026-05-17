// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { GuildTreasury } from "../../contracts/vault/GuildTreasury.sol";
import { AethToken } from "../../contracts/token/AethToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GuildTreasuryHandler
 * @notice Foundry invariant handler for GuildTreasury.
 *         Exposes deposit / withdraw / redeem / injectYield so the fuzzer
 *         can call them with bounded, valid inputs via targetContract.
 *
 * Actors
 * ──────
 * alice, bob  - regular depositors
 * yieldBot    - holds YIELD_MANAGER_ROLE, injects yield
 */
contract GuildTreasuryHandler is Test {
    GuildTreasury public vault;
    AethToken public aeth;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal yieldBot = makeAddr("yieldBot");

    // Cumulative accounting for the handler (not used in invariants directly,
    // but helpful for debugging via forge test -vvvv)
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    uint256 public totalYieldInjected;

    constructor(GuildTreasury _vault, AethToken _aeth) {
        vault = _vault;
        aeth = _aeth;
    }

    // Deposit

    function deposit(uint256 assets, uint8 actorSeed) external {
        address actor = actorSeed % 2 == 0 ? alice : bob;
        assets = bound(assets, 1, 500_000 * 1e18);

        aeth.mint(actor, assets);
        vm.startPrank(actor);
        aeth.approve(address(vault), assets);
        try vault.deposit(assets, actor) {
            totalDeposited += assets;
        } catch { }
        vm.stopPrank();
    }

    // Withdraw

    function withdraw(uint256 assets, uint8 actorSeed) external {
        address actor = actorSeed % 2 == 0 ? alice : bob;
        uint256 maxAssets = vault.maxWithdraw(actor);
        if (maxAssets == 0) return;
        assets = bound(assets, 1, maxAssets);

        vm.startPrank(actor);
        try vault.withdraw(assets, actor, actor) {
            totalWithdrawn += assets;
        } catch { }
        vm.stopPrank();
    }

    // Redeem

    function redeem(uint256 shares, uint8 actorSeed) external {
        address actor = actorSeed % 2 == 0 ? alice : bob;
        uint256 maxShares = vault.maxRedeem(actor);
        if (maxShares == 0) return;
        shares = bound(shares, 1, maxShares);

        vm.startPrank(actor);
        try vault.redeem(shares, actor, actor) returns (uint256 assets) {
            totalWithdrawn += assets;
        } catch { }
        vm.stopPrank();
    }

    // Inject yield

    function injectYield(uint256 amount) external {
        amount = bound(amount, 1, 100_000 * 1e18);

        aeth.mint(yieldBot, amount);
        vm.startPrank(yieldBot);
        aeth.approve(address(vault), amount);
        try vault.injectYield(amount) {
            totalYieldInjected += amount;
        } catch { }
        vm.stopPrank();
    }
}

/**
 * @title GuildTreasuryInvariantTest
 * @notice Invariant tests for GuildTreasury (ERC-4626 vault).
 *
 * Invariants
 * ──────────
 * invariant_TotalAssetsGeConvertedShares
 *     totalAssets() must always be >= the value the vault owes to all share-
 *     holders (convertToAssets(totalSupply())).  A breach here means the vault
 *     has issued promises it cannot honour — a critical treasury-accounting bug.
 *
 * invariant_SharePriceNeverDecreases
 *     The exchange rate convertToAssets(1 share unit) must never fall below the
 *     rate captured at the end of setUp().  Deposits cannot decrease the rate
 *     (they are proportional); yield injections can only increase it; withdrawals
 *     are proportional.  A monotonically non-decreasing share price is the
 *     central economic guarantee of this ERC-4626 vault.
 *
 * Run: forge test --match-contract GuildTreasuryInvariantTest -vv
 */
contract GuildTreasuryInvariantTest is Test {
    GuildTreasury vault;
    AethToken aeth;
    GuildTreasuryHandler handler;

    // Share price (in AETH per 1e18 shares) captured after seeding.
    uint256 internal sharePriceFloor;

    // One full share unit, accounting for the 3-decimal offset in GuildTreasury.
    // decimals() == 18, _decimalsOffset() == 3  ->  share unit == 1e18
    uint256 internal constant ONE_SHARE = 1e18;

    function setUp() public {
        address admin = makeAddr("admin");
        aeth = new AethToken(admin);
        vault = new GuildTreasury(IERC20(address(aeth)), admin);

        handler = new GuildTreasuryHandler(vault, aeth);

        // Grant roles needed by the handler and its internal actors
        address yieldBot = makeAddr("yieldBot");
        vm.startPrank(admin);
        aeth.grantRole(aeth.MINTER_ROLE(), address(handler));         // handler mints for depositors
        vault.grantRole(vault.YIELD_MANAGER_ROLE(), yieldBot);         // handler's yieldBot injects yield
        vm.stopPrank();

        // Seed the vault with an initial deposit so share price is meaningful.
        // Admin received 100_000_000 AETH in the constructor, so we transfer
        // from admin rather than minting (avoids needing MINTER_ROLE here).
        address seeder = makeAddr("seeder");
        uint256 seedAmount = 10_000 * 1e18;
        vm.prank(admin);
        aeth.transfer(seeder, seedAmount);
        vm.startPrank(seeder);
        aeth.approve(address(vault), seedAmount);
        vault.deposit(seedAmount, seeder);
        vm.stopPrank();

        // Record the initial share price as the floor
        sharePriceFloor = vault.convertToAssets(ONE_SHARE);

        targetContract(address(handler));
    }

    // Invariant 1

    /**
     * @notice totalAssets() must always be >= the sum the vault owes to all
     *         holders: convertToAssets(totalSupply()).
     *
     * Why this holds:
     *   - On deposit   : assets come IN exactly proportional to shares minted.
     *   - On withdraw  : assets go OUT exactly proportional to shares burned.
     *   - On injectYield: assets come IN, shares are NOT minted → ratio improves.
     *
     * A breach would indicate the vault issued more share-value than it holds.
     */
    function invariant_TotalAssetsGeConvertedShares() public view {
        uint256 totalAssets = vault.totalAssets();
        uint256 sharesOwed = vault.convertToAssets(vault.totalSupply());
        assertGe(
            totalAssets,
            sharesOwed,
            "GuildTreasury: totalAssets < convertToAssets(totalSupply)"
        );
    }

    // Invariant 2

    /**
     * @notice The share price (assets per share) must never drop below the
     *         value observed at the end of setUp().
     *
     * Why this holds:
     *   - Deposits are proportional; they do not change the share price.
     *   - Yield injections increase totalAssets without minting shares → price rises.
     *   - Withdrawals / redeems are proportional; they do not change the price.
     *
     * A breach would mean the vault's exchange rate has decreased, breaking the
     * fundamental economic promise to depositors.
     *
     * Note: we use convertToAssets(ONE_SHARE) rather than a per-share asset
     * ratio to avoid any precision loss from integer division.
     */
    function invariant_SharePriceNeverDecreases() public view {
        // Only meaningful once shares exist
        if (vault.totalSupply() == 0) return;

        uint256 currentSharePrice = vault.convertToAssets(ONE_SHARE);
        assertGe(
            currentSharePrice,
            sharePriceFloor,
            "GuildTreasury: share price decreased below initial floor"
        );
    }
}
