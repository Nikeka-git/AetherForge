// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AMMMarketplace
 * @notice Constant-product AMM (x·y = k) for AetherForge fungible resources.
 *
 * Features
 * ────────
 * x·y = k invariant with 0.3 % swap fee (30 bps)
 * Slippage protection via minimum-out / maximum-in parameters
 * LP tokens: proportional share of pool reserves, minted on addLiquidity
 * CEI pattern + ReentrancyGuard on all state-changing functions
 * SafeERC20 for all external token interactions
 * Custom errors (gas-efficient reverts)
 *
 * Design decisions
 * ────────────────
 * LP tokens are issued by this contract itself (it IS an ERC20).
 * The first liquidity provider sets the price ratio; subsequent providers
 *   must match the current ratio (within rounding) or they lose value.
 * Fees accumulate in the reserve; LPs collect them through the rising
 *   share-price when they call removeLiquidity.
 * No protocol fee; 100 % of swap fees go to LPs.
 */
contract AMMMarketplace is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants

    /// @dev Swap fee numerator: 30 / 10_000 = 0.30 %
    uint256 public constant FEE_NUMERATOR = 30;
    uint256 public constant FEE_DENOMINATOR = 10_000;

    /// @dev Minimum liquidity locked on first deposit to prevent price manipulation.
    uint256 private constant MINIMUM_LIQUIDITY = 1000;

    // State

    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    // Errors

    error AMM__ZeroAmount();
    error AMM__ZeroAddress();
    error AMM__SameTokens();
    error AMM__InsufficientLiquidity();
    error AMM__InsufficientOutputAmount(uint256 amountOut, uint256 minAmountOut);
    error AMM__InsufficientInputAmount(uint256 amountIn, uint256 maxAmountIn);
    error AMM__InvalidToken(address token);
    error AMM__InvalidRatio();
    error AMM__InsufficientLpAmount();
    error AMM__KInvariantViolated();

    // Events

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpBurned);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut);

    // Constructor

    /**
     * @param _tokenA One side of the pair (e.g. AETH governance token).
     * @param _tokenB Other side of the pair (e.g. an ERC-20 wrapped resource).
     * @param name_   ERC-20 name for the LP token (e.g. "AetherForge AETH-IRON LP").
     * @param symbol_ ERC-20 symbol for the LP token (e.g. "AF-LP").
     */
    constructor(address _tokenA, address _tokenB, string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        if (_tokenA == address(0) || _tokenB == address(0)) revert AMM__ZeroAddress();
        if (_tokenA == _tokenB) revert AMM__SameTokens();
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    // Liquidity management

    /**
     * @notice Deposit tokenA and tokenB, receive LP tokens.
     * @dev    First deposit sets the price; subsequent deposits must match the
     *         current ratio. Excess tokens are NOT refunded — the caller should
     *         calculate the correct amounts off-chain.
     *
     * @param amountADesired Amount of tokenA to deposit.
     * @param amountBDesired Amount of tokenB to deposit.
     * @param minLpOut       Minimum LP tokens to receive (slippage guard).
     * @return lpMinted      Number of LP tokens minted.
     */
    function addLiquidity(uint256 amountADesired, uint256 amountBDesired, uint256 minLpOut)
        external
        nonReentrant
        returns (uint256 lpMinted)
    {
        if (amountADesired == 0 || amountBDesired == 0) revert AMM__ZeroAmount();

        uint256 supply = totalSupply();
        uint256 _resA = reserveA;
        uint256 _resB = reserveB;

        uint256 amountA;
        uint256 amountB;

        if (supply == 0) {
            // First deposit — set the price ratio, lock MINIMUM_LIQUIDITY permanently.
            amountA = amountADesired;
            amountB = amountBDesired;

            // LP minted = sqrt(amountA * amountB) - MINIMUM_LIQUIDITY
            lpMinted = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            // Burn MINIMUM_LIQUIDITY by minting it to address(1) (not address(0), avoids issues)
            _mint(address(1), MINIMUM_LIQUIDITY);
        } else {
            // Subsequent deposits - scale down to maintain the ratio.
            // optimalB = amountADesired * resB / resA
            // slither-disable-next-line divide-before-multiply
            uint256 amountBOptimal = (amountADesired * _resB) / _resA;

            if (amountBOptimal <= amountBDesired) {
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                // amountBDesired is the binding constraint
                // slither-disable-next-line divide-before-multiply
                uint256 amountAOptimal = (amountBDesired * _resA) / _resB;
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }

            // LP proportional to the smaller share contribution
            uint256 lpA = (amountA * supply) / _resA;
            uint256 lpB = (amountB * supply) / _resB;
            lpMinted = lpA < lpB ? lpA : lpB;
        }

        if (lpMinted == 0) revert AMM__InsufficientLiquidity();
        if (lpMinted < minLpOut) revert AMM__InsufficientOutputAmount(lpMinted, minLpOut);

        // Effects - update reserves before external calls
        reserveA = _resA + amountA;
        reserveB = _resB + amountB;

        // Interactions - pull tokens from the caller
        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        _mint(msg.sender, lpMinted);

        emit LiquidityAdded(msg.sender, amountA, amountB, lpMinted);
    }

    /**
     * @notice Burn LP tokens, receive back proportional tokenA and tokenB.
     *
     * @param lpAmount  Amount of LP tokens to burn.
     * @param minA      Minimum tokenA to receive.
     * @param minB      Minimum tokenB to receive.
     * @return amountA  TokenA returned to caller.
     * @return amountB  TokenB returned to caller.
     */
    function removeLiquidity(uint256 lpAmount, uint256 minA, uint256 minB)
        external
        nonReentrant
        returns (uint256 amountA, uint256 amountB)
    {
        if (lpAmount == 0) revert AMM__InsufficientLpAmount();

        uint256 supply = totalSupply();
        uint256 _resA = reserveA;
        uint256 _resB = reserveB;

        amountA = (lpAmount * _resA) / supply;
        amountB = (lpAmount * _resB) / supply;

        if (amountA == 0 || amountB == 0) revert AMM__InsufficientLiquidity();
        if (amountA < minA) revert AMM__InsufficientOutputAmount(amountA, minA);
        if (amountB < minB) revert AMM__InsufficientOutputAmount(amountB, minB);

        // Effects
        reserveA = _resA - amountA;
        reserveB = _resB - amountB;
        _burn(msg.sender, lpAmount);

        // Interactions
        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
    }

    // Swap

    /**
     * @notice Swap an exact amount of `_tokenIn` for as much `_tokenOut` as possible.
     * @dev    Fee is deducted from amountIn: effectiveIn = amountIn * (10000 - 30) / 10000.
     *         The k-invariant check at the end acts as a final safety net.
     *
     * @param tokenIn    Address of the token being sold (must be tokenA or tokenB).
     * @param amountIn    Exact amount of tokenIn to sell.
     * @param minAmountOut Minimum amount of tokenOut to receive (slippage guard).
     * @return amountOut  Actual amount of tokenOut received.
     */
    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert AMM__ZeroAmount();

        bool isAIn = (tokenIn == address(tokenA));
        if (!isAIn && tokenIn != address(tokenB)) revert AMM__InvalidToken(tokenIn);

        uint256 _resA = reserveA;
        uint256 _resB = reserveB;

        (uint256 resIn, uint256 resOut) = isAIn ? (_resA, _resB) : (_resB, _resA);

        // Compute output: dy = resOut * amountInWithFee / (resIn * 10000 + amountInWithFee)
        // where amountInWithFee = amountIn * (10000 - FEE_NUMERATOR)
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        amountOut = (resOut * amountInWithFee) / (resIn * FEE_DENOMINATOR + amountInWithFee);

        if (amountOut == 0) revert AMM__InsufficientLiquidity();
        if (amountOut < minAmountOut) revert AMM__InsufficientOutputAmount(amountOut, minAmountOut);

        // Effects - update reserves
        if (isAIn) {
            reserveA = _resA + amountIn;
            reserveB = _resB - amountOut;
        } else {
            reserveB = _resB + amountIn;
            reserveA = _resA - amountOut;
        }

        // k-invariant safety net: new_k >= old_k (fees make k grow over time)
        // Use unchecked to avoid gas overhead; the ternary above already validates the direction.
        unchecked {
            if (reserveA * reserveB < _resA * _resB) revert AMM__KInvariantViolated();
        }

        // Interactions
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(isAIn ? address(tokenB) : address(tokenA)).safeTransfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, amountIn, isAIn ? address(tokenB) : address(tokenA), amountOut);
    }

    // View helpers

    /**
     * @notice Quote how much tokenOut you get for a given amountIn (including fee).
     * @param tokenIn Address of the input token.
     * @param amountIn Amount of input token.
     * @return amountOut Expected output (before slippage, purely view).
     */
    function getAmountOut(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        bool isAIn = (tokenIn == address(tokenA));
        if (!isAIn && tokenIn != address(tokenB)) revert AMM__InvalidToken(tokenIn);

        (uint256 resIn, uint256 resOut) = isAIn ? (reserveA, reserveB) : (reserveB, reserveA);
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        amountOut = (resOut * amountInWithFee) / (resIn * FEE_DENOMINATOR + amountInWithFee);
    }

    /**
     * @notice Return current reserves.
     */
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        _reserveA = reserveA;
        _reserveB = reserveB;
    }

    // Internal math

    /**
     * @dev Babylonian square root (integer). Used only on the first liquidity deposit.
     */
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
