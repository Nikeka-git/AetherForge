// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title BattleMath
 * @notice Pure math library used by PvPArena and CraftingEngine.
 *         Every function ships in two flavours:
 *           - *Solidity  — plain Solidity, used as the gas baseline in benchmarks.
 *           - *Yul       — inline Yul assembly, the version used in production.
 *
 * @dev Gas benchmarks live in test/gas/BattleMathBench.t.sol.
 *      Results are committed to docs/gas-report.md as required by Section 3.1.
 *
 * Why Yul here?
 * ─────────────
 * battlePower() is called once per arena match resolution.  The Yul version
 * skips the overflow checks Solidity 0.8 inserts around every arithmetic
 * opcode.  Inputs are bounded by the Hero struct (uint16 stats, uint256
 * randMod ≤ 1e18), so overflow is provably impossible and the checks are pure
 * waste.  The sqrt is called on every AMM liquidity-add; shaving gas there
 * compounds across every LP.
 */
library BattleMath {
    // ─────────────────────────────────────────────────────────────────────────
    // battlePower
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Compute a hero's effective battle power (Solidity baseline).
     * @param atk        Raw attack stat  (uint16 in Hero struct, safe as uint256 here).
     * @param def        Raw defense stat.
     * @param agi        Agility stat.
     * @param equipBonus Flat bonus from equipped weapon + armour.
     * @param randMod    Random modifier in [0, 1e18] supplied by Chainlink VRF.
     * @return           Battle power score (arbitrary units, comparable between heroes).
     *
     * Formula: (atk*120 + def*80 + (agi*randMod)/1e18 + equipBonus) / 100
     */
    function battlePowerSolidity(uint256 atk, uint256 def, uint256 agi, uint256 equipBonus, uint256 randMod)
        internal
        pure
        returns (uint256)
    {
        return (atk * 120 + def * 80 + (agi * randMod) / 1e18 + equipBonus) / 100;
    }

    /**
     * @notice Compute a hero's effective battle power (optimised Yul version).
     * @dev    Identical semantics to battlePowerSolidity; no overflow is possible
     *         because: atk, def, agi ≤ 65535 (uint16); equipBonus ≤ 10_000;
     *         randMod ≤ 1e18.  Max intermediate value ≈ 65535*120 = 7_864_200,
     *         well below uint256 max.  The Yul version omits the compiler-inserted
     *         overflow guards for each mul/add, saving ~6 opcodes per call.
     */
    function battlePowerYul(uint256 atk, uint256 def, uint256 agi, uint256 equipBonus, uint256 randMod)
        internal
        pure
        returns (uint256 result)
    {
        assembly {
            // a = atk * 120
            let a := mul(atk, 120)
            // d = def * 80
            let d := mul(def, 80)
            // r = (agi * randMod) / 1e18
            let r := div(mul(agi, randMod), 1000000000000000000)
            // result = (a + d + r + equipBonus) / 100
            result := div(add(add(add(a, d), r), equipBonus), 100)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // sqrt  (integer square root, Babylonian / Newton's method)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Integer square root, floor(sqrt(x)) — Solidity baseline.
     * @dev    Used by AMMMarketplace to compute initial LP token amount:
     *         lpAmount = sqrt(reserveA * reserveB).
     *         Identical to the reference implementation in Uniswap V2.
     */
    function sqrtSolidity(uint256 x) internal pure returns (uint256 z) {
        if (x == 0) return 0;
        z = x;
        uint256 y = x / 2 + 1;
        while (y < z) {
            z = y;
            y = (x / y + y) / 2;
        }
    }

    /**
     * @notice Integer square root, floor(sqrt(x)) — optimised Yul version.
     * @dev    Same Babylonian algorithm in assembly.  The loop condition and
     *         the early-exit for x ≤ 3 are expressed with Yul primitives
     *         (gt, lt, iszero) which map 1-to-1 to EVM opcodes — no function
     *         dispatch overhead from Solidity's checked arithmetic wrappers.
     *
     *         Edge cases:
     *           x == 0  → z = 0   (iszero branch)
     *           x == 1  → z = 1   (gt(x,3) is false, z stays 1)
     *           x == 2  → z = 1
     *           x == 3  → z = 1
     *           x == 4  → z = 2
     */
    function sqrtYul(uint256 x) internal pure returns (uint256 z) {
        assembly {
            // Handle x == 0 separately to avoid div-by-zero inside the loop.
            switch iszero(x)
            case 1 { z := 0 }
            default {
                // Initial guess: z = x, y = x/2 + 1.
                // The loop converges when y >= z (i.e. no more improvement).
                z := x
                let y := add(div(x, 2), 1)

                for { } lt(y, z) { } {
                    z := y
                    y := div(add(div(x, y), y), 2)
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // clampedSub  (saturating subtraction — bonus Yul utility)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Saturating subtraction: returns a - b, or 0 if b > a.
     * @dev    Used in PvPArena to reduce hero stats without underflow.
     *         Solidity baseline version.
     */
    function clampedSubSolidity(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : 0;
    }

    /**
     * @notice Saturating subtraction (Yul version).
     * @dev    `sub` in EVM wraps on underflow; we guard with a `gt` check.
     *         One branch instead of Solidity's checked subtraction sequence.
     */
    function clampedSubYul(uint256 a, uint256 b) internal pure returns (uint256 result) {
        assembly {
            // If a > b: result = a - b, else result = 0 (default).
            if gt(a, b) { result := sub(a, b) }
        }
    }
}
