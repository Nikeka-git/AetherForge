// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {AMMMarketplace} from "../../contracts/marketplace/AMMMarketplace.sol";
import {AethToken} from "../../contracts/token/AethToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev Minimal ERC-20 used as the "other side" of the AMM pair in tests.
 */
contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title AMMFuzzTest
 * @notice Fuzz tests for AMMMarketplace.
 *         Run with: forge test --match-contract AMMFuzzTest -vv
 *
 * Tests
 * ──────
 * 1. fuzz_SwapNeverViolatesKInvariant  - for any valid swap, k never decreases
 * 2. fuzz_GetAmountOutMatchesActualSwap - view quote matches actual execution
 * 3. fuzz_AddLiquidityProportionalShares - LP share proportional to input
 */
contract AMMFuzzTest is Test {
    // System under test

    AMMMarketplace amm;
    MockERC20 tokenA;
    MockERC20 tokenB;

    // Actors

    address lp = makeAddr("lp");       // Liquidity provider
    address trader = makeAddr("trader");

    // Initial pool seeding

    uint256 constant SEED_A = 100_000 * 1e18;
    uint256 constant SEED_B = 200_000 * 1e18;

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        amm = new AMMMarketplace(address(tokenA), address(tokenB), "AetherForge LP", "AF-LP");

        // Seed the liquidity provider and the pool
        tokenA.mint(lp, 1_000_000 * 1e18);
        tokenB.mint(lp, 2_000_000 * 1e18);

        vm.startPrank(lp);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        amm.addLiquidity(SEED_A, SEED_B, 0);
        vm.stopPrank();
    }

    // Fuzz test 1: k never decreases after any swap

    /**
     * @dev For any amountIn in [1, resIn/2], swapping tokenA→tokenB must leave
     *      k = reserveA * reserveB >= the pre-swap k.
     */
    function testFuzz_SwapNeverViolatesKInvariant(uint256 amountIn) public {
        (uint256 resA, uint256 resB) = amm.getReserves();
        // Bound input to prevent "InsufficientLiquidity" - don't drain more than half the pool
        amountIn = bound(amountIn, 1, resA / 2);

        uint256 kBefore = resA * resB;

        // Give trader enough tokenA
        tokenA.mint(trader, amountIn);
        vm.startPrank(trader);
        tokenA.approve(address(amm), amountIn);
        amm.swap(address(tokenA), amountIn, 0); // minOut = 0, we only care about k
        vm.stopPrank();

        (uint256 resAAfter, uint256 resBAfter) = amm.getReserves();
        uint256 kAfter = resAAfter * resBAfter;

        assertGe(kAfter, kBefore, "k invariant violated: k decreased after swap");
    }

    // Fuzz test 2: getAmountOut quote matches actual swap output

    /**
     * @dev The view function getAmountOut must return exactly the same value
     *      as what the actual swap produces.
     */
    function testFuzz_GetAmountOutMatchesActualSwap(uint256 amountIn) public {
        (uint256 resA,) = amm.getReserves();
        amountIn = bound(amountIn, 1, resA / 2);

        // Quote before the swap
        uint256 quoted = amm.getAmountOut(address(tokenA), amountIn);

        uint256 balBefore = tokenB.balanceOf(trader);

        tokenA.mint(trader, amountIn);
        vm.startPrank(trader);
        tokenA.approve(address(amm), amountIn);
        uint256 actual = amm.swap(address(tokenA), amountIn, 0);
        vm.stopPrank();

        uint256 received = tokenB.balanceOf(trader) - balBefore;

        assertEq(quoted, actual, "quoted amountOut != returned amountOut");
        assertEq(actual, received, "returned amountOut != tokens actually received");
    }

    // Fuzz test 3: LP shares are proportional to deposit

    /**
     * @dev Adding liquidity in ratio resA:resB must give LP tokens proportional
     *      to the existing pool size. The second depositor's LP share must equal
     *      their proportional contribution.
     */
    function testFuzz_AddLiquidityProportionalShares(uint256 depositA) public {
        (uint256 resA, uint256 resB) = amm.getReserves();
        // Bound: deposit 0.001% to 10% of existing pool to stay realistic
        depositA = bound(depositA, resA / 100_000, resA / 10);

        // Calculate matching B
        uint256 depositB = (depositA * resB) / resA;

        address lp2 = makeAddr("lp2");
        tokenA.mint(lp2, depositA);
        tokenB.mint(lp2, depositB + 1); // +1 for rounding

        vm.startPrank(lp2);
        tokenA.approve(address(amm), depositA);
        tokenB.approve(address(amm), depositB + 1);

        uint256 lpBefore = amm.totalSupply();
        uint256 lp2BalBefore = amm.balanceOf(lp2);
        amm.addLiquidity(depositA, depositB, 0);
        uint256 lp2Minted = amm.balanceOf(lp2) - lp2BalBefore;
        vm.stopPrank();

        // lp2 should have received ~ depositA/resA fraction of total supply (before their deposit)
        uint256 expectedLp = (depositA * lpBefore) / resA;

        // Allow 1 wei rounding tolerance
        assertApproxEqAbs(lp2Minted, expectedLp, 1, "LP minted not proportional to deposit");
    }
}
