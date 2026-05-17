// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { AMMMarketplace } from "../../contracts/marketplace/AMMMarketplace.sol";

// Helper

/// @dev Minimal ERC-20 with an open mint, used to stand in for any fungible resource.
///      Named AMMTestToken to avoid collision with the MockERC20 in AMMFuzz.t.sol.
contract AMMTestToken is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Tests

/**
 * @title  AMMMarketplaceTest
 * @notice Unit tests for AMMMarketplace (x·y = k AMM with 0.3 % fee).
 *
 * Run:
 *   forge test --match-contract AMMMarketplaceTest -vv
 *
 * Coverage target: every public/external function + all custom revert paths.
 *
 * Test inventory (20 tests)
 * ─────────────────────────
 *  Constructor
 *   1.  test_Constructor_SetsTokensAndLpMetadata
 *   2.  test_Constructor_RevertsOnZeroTokenA
 *   3.  test_Constructor_RevertsOnZeroTokenB
 *   4.  test_Constructor_RevertsOnSameTokens
 *  addLiquidity
 *   5.  test_AddLiquidity_FirstDeposit_MintsLpAndUpdatesReserves
 *   6.  test_AddLiquidity_SubsequentDeposit_MaintainsRatioAndMintsLP
 *   7.  test_AddLiquidity_RevertsOnZeroAmountA
 *   8.  test_AddLiquidity_RevertsOnZeroAmountB
 *   9.  test_AddLiquidity_RevertsOnSlippageTooHigh
 *  removeLiquidity
 *  10.  test_RemoveLiquidity_ProportionalTokenReturn
 *  11.  test_RemoveLiquidity_RevertsOnZeroLpAmount
 *  12.  test_RemoveLiquidity_RevertsOnMinASlippage
 *  13.  test_RemoveLiquidity_RevertsOnMinBSlippage
 *  swap
 *  14.  test_Swap_TokenAForTokenB_CorrectOutput
 *  15.  test_Swap_TokenBForTokenA_CorrectOutput
 *  16.  test_Swap_RevertsOnZeroAmount
 *  17.  test_Swap_RevertsOnInvalidToken
 *  18.  test_Swap_RevertsOnSlippage
 *  19.  test_Swap_FeeAccumulatesInKInvariant
 *  view helpers
 *  20.  test_GetAmountOut_MatchesSwapOutput_BothDirections
 */
contract AMMMarketplaceTest is Test {
    // Contracts

    AMMMarketplace internal amm;
    AMMTestToken internal tokenA;
    AMMTestToken internal tokenB;

    // Actors

    address internal lp = makeAddr("lp");
    address internal trader = makeAddr("trader");
    address internal lp2 = makeAddr("lp2");

    // Constants

    uint256 constant SEED_A = 100_000 * 1e18;
    uint256 constant SEED_B = 200_000 * 1e18; // ratio 1:2

    // Setup

    function setUp() public {
        tokenA = new AMMTestToken("Resource A", "RES-A");
        tokenB = new AMMTestToken("Resource B", "RES-B");
        amm = new AMMMarketplace(address(tokenA), address(tokenB), "AetherForge LP", "AF-LP");

        // Mint and seed liquidity provider
        tokenA.mint(lp, 10_000_000 * 1e18);
        tokenB.mint(lp, 10_000_000 * 1e18);

        vm.startPrank(lp);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        // Initial deposit: 100k A and 200k B
        amm.addLiquidity(SEED_A, SEED_B, 0);
        vm.stopPrank();

        // Mint tokens for trader
        tokenA.mint(trader, 1_000_000 * 1e18);
        tokenB.mint(trader, 1_000_000 * 1e18);
        vm.startPrank(trader);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    // 1. Constructor

    function test_Constructor_SetsTokensAndLpMetadata() public view {
        assertEq(address(amm.tokenA()), address(tokenA), "tokenA wrong");
        assertEq(address(amm.tokenB()), address(tokenB), "tokenB wrong");
        assertEq(amm.name(), "AetherForge LP", "LP name wrong");
        assertEq(amm.symbol(), "AF-LP", "LP symbol wrong");
        assertEq(amm.FEE_NUMERATOR(), 30, "fee numerator wrong");
        assertEq(amm.FEE_DENOMINATOR(), 10_000, "fee denominator wrong");
    }

    function test_Constructor_RevertsOnZeroTokenA() public {
        vm.expectRevert(AMMMarketplace.AMM__ZeroAddress.selector);
        new AMMMarketplace(address(0), address(tokenB), "LP", "LP");
    }

    function test_Constructor_RevertsOnZeroTokenB() public {
        vm.expectRevert(AMMMarketplace.AMM__ZeroAddress.selector);
        new AMMMarketplace(address(tokenA), address(0), "LP", "LP");
    }

    function test_Constructor_RevertsOnSameTokens() public {
        vm.expectRevert(AMMMarketplace.AMM__SameTokens.selector);
        new AMMMarketplace(address(tokenA), address(tokenA), "LP", "LP");
    }

    // 5. addLiquidity – first deposit

    function test_AddLiquidity_FirstDeposit_MintsLpAndUpdatesReserves() public {
        // Deploy a fresh AMM with no liquidity
        AMMMarketplace freshAmm = new AMMMarketplace(address(tokenA), address(tokenB), "Fresh LP", "FLP");

        uint256 amtA = 10_000 * 1e18;
        uint256 amtB = 40_000 * 1e18;

        tokenA.mint(lp2, amtA);
        tokenB.mint(lp2, amtB);
        vm.startPrank(lp2);
        tokenA.approve(address(freshAmm), type(uint256).max);
        tokenB.approve(address(freshAmm), type(uint256).max);
        uint256 lpMinted = freshAmm.addLiquidity(amtA, amtB, 0);
        vm.stopPrank();

        // sqrt(10_000e18 * 40_000e18) - 1000 = 20_000e18 - 1000
        assertGt(lpMinted, 0, "no LP minted");
        (uint256 resA, uint256 resB) = freshAmm.getReserves();
        assertEq(resA, amtA, "reserveA wrong after first deposit");
        assertEq(resB, amtB, "reserveB wrong after first deposit");
        // Minimum liquidity (1000) is permanently locked
        assertEq(freshAmm.totalSupply(), lpMinted + 1000, "total supply wrong");
    }

    // 6. addLiquidity – subsequent deposit

    function test_AddLiquidity_SubsequentDeposit_MaintainsRatioAndMintsLP() public {
        // Ratio is 1:2 (A:B). Deposit 5k A and 10k B.
        uint256 addA = 5000 * 1e18;
        uint256 addB = 10_000 * 1e18; // exact ratio

        tokenA.mint(lp2, addA);
        tokenB.mint(lp2, addB);
        vm.startPrank(lp2);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        uint256 lpBefore = amm.totalSupply();
        uint256 lpMinted = amm.addLiquidity(addA, addB, 0);
        vm.stopPrank();

        assertGt(lpMinted, 0, "no LP minted on second deposit");

        (uint256 resA, uint256 resB) = amm.getReserves();
        assertEq(resA, SEED_A + addA, "reserveA wrong after second deposit");
        assertEq(resB, SEED_B + addB, "reserveB wrong after second deposit");

        // LP is proportional: lp2 deposited 5% of pool, should get around 5% of supply
        uint256 expectedLp = (addA * lpBefore) / SEED_A;
        assertApproxEqAbs(lpMinted, expectedLp, 1, "LP minted not proportional");
    }

    // 7–8. addLiquidity – zero amounts

    function test_AddLiquidity_RevertsOnZeroAmountA() public {
        vm.prank(lp);
        vm.expectRevert(AMMMarketplace.AMM__ZeroAmount.selector);
        amm.addLiquidity(0, 1e18, 0);
    }

    function test_AddLiquidity_RevertsOnZeroAmountB() public {
        vm.prank(lp);
        vm.expectRevert(AMMMarketplace.AMM__ZeroAmount.selector);
        amm.addLiquidity(1e18, 0, 0);
    }

    // 9. addLiquidity – slippage

    function test_AddLiquidity_RevertsOnSlippageTooHigh() public {
        // Deposit 1k A + 2k B (correct ratio) but demand 999_999e18 LP
        uint256 impossibleMin = 999_999 * 1e18;
        vm.prank(lp);
        // We expect InsufficientOutputAmount(actual, min)
        vm.expectRevert();
        amm.addLiquidity(1000 * 1e18, 2000 * 1e18, impossibleMin);
    }

    // 10. removeLiquidity – proportional return

    function test_RemoveLiquidity_ProportionalTokenReturn() public {
        uint256 lpBalance = amm.balanceOf(lp);
        assertGt(lpBalance, 0, "lp has no LP tokens");

        uint256 aBalBefore = tokenA.balanceOf(lp);
        uint256 bBalBefore = tokenB.balanceOf(lp);

        vm.startPrank(lp);
        (uint256 aOut, uint256 bOut) = amm.removeLiquidity(lpBalance, 0, 0);
        vm.stopPrank();

        assertGt(aOut, 0, "no tokenA returned");
        assertGt(bOut, 0, "no tokenB returned");
        assertEq(tokenA.balanceOf(lp), aBalBefore + aOut, "tokenA balance wrong after remove");
        assertEq(tokenB.balanceOf(lp), bBalBefore + bOut, "tokenB balance wrong after remove");
        assertEq(amm.balanceOf(lp), 0, "lp should have no LP tokens left");
    }

    // 11. removeLiquidity - zero LP

    function test_RemoveLiquidity_RevertsOnZeroLpAmount() public {
        vm.prank(lp);
        vm.expectRevert(AMMMarketplace.AMM__InsufficientLpAmount.selector);
        amm.removeLiquidity(0, 0, 0);
    }

    // 12–13. removeLiquidity - slippage guards

    function test_RemoveLiquidity_RevertsOnMinASlippage() public {
        uint256 lpBalance = amm.balanceOf(lp);
        vm.prank(lp);
        vm.expectRevert();
        amm.removeLiquidity(lpBalance, type(uint256).max, 0);
    }

    function test_RemoveLiquidity_RevertsOnMinBSlippage() public {
        uint256 lpBalance = amm.balanceOf(lp);
        vm.prank(lp);
        vm.expectRevert();
        amm.removeLiquidity(lpBalance, 0, type(uint256).max);
    }

    // 14. swap – A->B

    function test_Swap_TokenAForTokenB_CorrectOutput() public {
        uint256 amountIn = 1000 * 1e18;

        // Quote before swap
        uint256 quoted = amm.getAmountOut(address(tokenA), amountIn);

        uint256 bBefore = tokenB.balanceOf(trader);
        vm.prank(trader);
        uint256 amountOut = amm.swap(address(tokenA), amountIn, 0);

        assertEq(amountOut, quoted, "swap output does not match quote");
        assertEq(tokenB.balanceOf(trader), bBefore + amountOut, "trader tokenB balance wrong");
        assertEq(tokenA.balanceOf(trader), 1_000_000 * 1e18 - amountIn, "trader tokenA not debited");

        // Reserve updated
        (uint256 resA, uint256 resB) = amm.getReserves();
        assertEq(resA, SEED_A + amountIn, "reserveA should increase by amountIn");
        assertEq(resB, SEED_B - amountOut, "reserveB should decrease by amountOut");
    }

    // 15. swap – B->A

    function test_Swap_TokenBForTokenA_CorrectOutput() public {
        uint256 amountIn = 2000 * 1e18;

        uint256 quoted = amm.getAmountOut(address(tokenB), amountIn);

        uint256 aBefore = tokenA.balanceOf(trader);
        vm.prank(trader);
        uint256 amountOut = amm.swap(address(tokenB), amountIn, 0);

        assertEq(amountOut, quoted, "B->A output does not match quote");
        assertEq(tokenA.balanceOf(trader), aBefore + amountOut, "trader tokenA balance wrong");

        (uint256 resA, uint256 resB) = amm.getReserves();
        assertEq(resB, SEED_B + amountIn, "reserveB should increase by amountIn");
        assertEq(resA, SEED_A - amountOut, "reserveA should decrease by amountOut");
    }

    // 16. swap - zero amount

    function test_Swap_RevertsOnZeroAmount() public {
        vm.prank(trader);
        vm.expectRevert(AMMMarketplace.AMM__ZeroAmount.selector);
        amm.swap(address(tokenA), 0, 0);
    }

    // 17. swap - invalid token

    function test_Swap_RevertsOnInvalidToken() public {
        address badToken = makeAddr("notAPoolToken");
        vm.prank(trader);
        vm.expectRevert(abi.encodeWithSelector(AMMMarketplace.AMM__InvalidToken.selector, badToken));
        amm.swap(badToken, 1e18, 0);
    }

    // 18. swap - slippage guard

    function test_Swap_RevertsOnSlippage() public {
        uint256 amountIn = 1000 * 1e18;
        uint256 quoted = amm.getAmountOut(address(tokenA), amountIn);

        // Demand 1 wei more than possible
        vm.prank(trader);
        vm.expectRevert();
        amm.swap(address(tokenA), amountIn, quoted + 1);
    }

    // 19. swap - fee grows k

    function test_Swap_FeeAccumulatesInKInvariant() public {
        (uint256 resA0, uint256 resB0) = amm.getReserves();
        uint256 kBefore = resA0 * resB0;

        vm.prank(trader);
        amm.swap(address(tokenA), 10_000 * 1e18, 0);

        (uint256 resA1, uint256 resB1) = amm.getReserves();
        uint256 kAfter = resA1 * resB1;

        // With a 0.3% fee, k must strictly increase after every swap
        assertGt(kAfter, kBefore, "k should increase after swap due to fee");
    }

    // 20. getAmountOut - view matches swap

    function test_GetAmountOut_MatchesSwapOutput_BothDirections() public {
        uint256 amountIn = 500 * 1e18;

        // A->B
        uint256 quotedAB = amm.getAmountOut(address(tokenA), amountIn);
        vm.prank(trader);
        uint256 actualAB = amm.swap(address(tokenA), amountIn, 0);
        assertEq(quotedAB, actualAB, "A->B: quote != actual");

        // B->A (reserves shifted, re-quote)
        uint256 quotedBA = amm.getAmountOut(address(tokenB), amountIn);
        vm.prank(trader);
        uint256 actualBA = amm.swap(address(tokenB), amountIn, 0);
        assertEq(quotedBA, actualBA, "B->A: quote != actual");

        // Invalid token reverts in getAmountOut too
        vm.expectRevert();
        amm.getAmountOut(makeAddr("bad"), amountIn);
    }
}
