// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BattleMath } from "../../contracts/assembly/BattleMath.sol";

/**
 * @title BattleMathBench
 * @notice Gas benchmark and correctness tests for BattleMath.sol.
 *
 *  Run:
 *    forge test --match-contract BattleMathBench -vv
 *
 *  The test names follow the convention:
 *    test_<function>_<Solidity|Yul>_[scenario]
 *
 *  Benchmark methodology
 *  ─────────────────────
 *  vm.startSnapshotGas / vm.stopSnapshotGas (Foundry >= 0.2.0) measure the
 *  gas consumed by the assembly inside the snapshot, excluding test harness
 *  overhead.  Each snapshot name is logged; run with -vv to see the table.
 *
 *  Results are summarised in docs/gas-report.md (committed to the repo).
 */
contract BattleMathBench is Test {
    // Shared test fixtures

    // Typical mid-game hero stats (within uint16 range).
    uint256 constant ATK = 450;
    uint256 constant DEF = 320;
    uint256 constant AGI = 280;
    uint256 constant EQUIP = 150;
    // randMod = 0.75 * 1e18  (75 % modifier from VRF)
    uint256 constant RAND_MOD = 750_000_000_000_000_000;

    // battlePower - correctness

    function test_battlePower_SolidityAndYul_returnSameValue() public pure {
        uint256 sol = BattleMath.battlePowerSolidity(ATK, DEF, AGI, EQUIP, RAND_MOD);
        uint256 yul = BattleMath.battlePowerYul(ATK, DEF, AGI, EQUIP, RAND_MOD);
        assertEq(sol, yul, "battlePower: Solidity != Yul");
    }

    function test_battlePower_ZeroRandMod_returnsBaseScore() public pure {
        // With randMod=0, agi contribution is zero.
        uint256 expected = (ATK * 120 + DEF * 80 + EQUIP) / 100;
        assertEq(BattleMath.battlePowerYul(ATK, DEF, AGI, EQUIP, 0), expected);
        assertEq(BattleMath.battlePowerSolidity(ATK, DEF, AGI, EQUIP, 0), expected);
    }

    function test_battlePower_MaxRandMod_includesFullAgi() public pure {
        uint256 randFull = 1e18;
        uint256 expected = (ATK * 120 + DEF * 80 + AGI + EQUIP) / 100;
        assertEq(BattleMath.battlePowerYul(ATK, DEF, AGI, EQUIP, randFull), expected);
    }

    function test_battlePower_AllZeros_returnsZero() public pure {
        assertEq(BattleMath.battlePowerYul(0, 0, 0, 0, 0), 0);
        assertEq(BattleMath.battlePowerSolidity(0, 0, 0, 0, 0), 0);
    }

    /// @dev Fuzz: Yul and Solidity always agree, regardless of input.
    function testFuzz_battlePower_YulMatchesSolidity(uint16 atk, uint16 def, uint16 agi, uint16 equip, uint256 randMod)
        public
        pure
    {
        // Cap randMod to [0, 1e18] - same bound PvPArena enforces.
        randMod = bound(randMod, 0, 1e18);
        uint256 sol = BattleMath.battlePowerSolidity(atk, def, agi, equip, randMod);
        uint256 yul = BattleMath.battlePowerYul(atk, def, agi, equip, randMod);
        assertEq(sol, yul, "fuzz: battlePower mismatch");
    }

    // sqrt - correctness

    function test_sqrt_EdgeCases() public pure {
        assertEq(BattleMath.sqrtYul(0), 0);
        assertEq(BattleMath.sqrtYul(1), 1);
        assertEq(BattleMath.sqrtYul(2), 1);
        assertEq(BattleMath.sqrtYul(3), 1);
        assertEq(BattleMath.sqrtYul(4), 2);
        assertEq(BattleMath.sqrtYul(9), 3);
        assertEq(BattleMath.sqrtYul(16), 4);
        assertEq(BattleMath.sqrtYul(1e18), 1_000_000_000); // sqrt(1e18) = 1e9
    }

    function test_sqrt_SolidityAndYul_returnSameValue() public pure {
        uint256[8] memory inputs = [uint256(0), 1, 2, 4, 100, 1337, 1e18, type(uint128).max];
        for (uint256 i = 0; i < inputs.length; i++) {
            assertEq(BattleMath.sqrtSolidity(inputs[i]), BattleMath.sqrtYul(inputs[i]), "sqrt: Solidity != Yul");
        }
    }

    function test_sqrt_ResultIsFloor() public pure {
        // For any perfect square n^2, result == n.
        for (uint256 n = 0; n <= 100; n++) {
            assertEq(BattleMath.sqrtYul(n * n), n);
        }
        // For n^2 + 1, result is still n (floor).
        for (uint256 n = 1; n <= 100; n++) {
            assertEq(BattleMath.sqrtYul(n * n + 1), n);
        }
    }

    /// @dev Fuzz: sqrtYul(x)^2 <= x < (sqrtYul(x)+1)^2 for all x.
    function testFuzz_sqrt_FloorProperty(uint256 x) public pure {
        // Bound to avoid (z+1)^2 overflow.
        x = bound(x, 0, type(uint128).max);
        uint256 z = BattleMath.sqrtYul(x);
        assertLe(z * z, x, "z^2 > x");
        if (z < type(uint128).max) {
            assertGt((z + 1) * (z + 1), x, "(z+1)^2 <= x");
        }
    }

    /// @dev Fuzz: Yul always matches Solidity.
    function testFuzz_sqrt_YulMatchesSolidity(uint256 x) public pure {
        x = bound(x, 0, type(uint128).max);
        assertEq(BattleMath.sqrtSolidity(x), BattleMath.sqrtYul(x), "fuzz: sqrt mismatch");
    }

    // clampedSub — correctness

    function test_clampedSub_Normal() public pure {
        assertEq(BattleMath.clampedSubYul(10, 3), 7);
        assertEq(BattleMath.clampedSubSolidity(10, 3), 7);
    }

    function test_clampedSub_Equal_ReturnsZero() public pure {
        assertEq(BattleMath.clampedSubYul(5, 5), 0);
    }

    function test_clampedSub_Underflow_ReturnsZero() public pure {
        assertEq(BattleMath.clampedSubYul(3, 10), 0);
        assertEq(BattleMath.clampedSubSolidity(3, 10), 0);
    }

    /// @dev Fuzz: Yul and Solidity always agree.
    function testFuzz_clampedSub_YulMatchesSolidity(uint256 a, uint256 b) public pure {
        assertEq(BattleMath.clampedSubSolidity(a, b), BattleMath.clampedSubYul(a, b));
    }

    // Gas benchmarks  (results printed with -vv, logged to docs/gas-report.md)

    function test_GasBenchmark_battlePower() public {
        vm.startSnapshotGas("battlePower_Solidity");
        BattleMath.battlePowerSolidity(ATK, DEF, AGI, EQUIP, RAND_MOD);
        uint256 gasSol = vm.stopSnapshotGas("battlePower_Solidity");

        vm.startSnapshotGas("battlePower_Yul");
        BattleMath.battlePowerYul(ATK, DEF, AGI, EQUIP, RAND_MOD);
        uint256 gasYul = vm.stopSnapshotGas("battlePower_Yul");

        emit log_named_uint("battlePower Solidity gas", gasSol);
        emit log_named_uint("battlePower Yul     gas", gasYul);
    }

    function test_GasBenchmark_sqrt() public {
        uint256 x = 123_456_789_012_345_678;

        vm.startSnapshotGas("sqrt_Solidity");
        BattleMath.sqrtSolidity(x);
        uint256 gasSol = vm.stopSnapshotGas("sqrt_Solidity");

        vm.startSnapshotGas("sqrt_Yul");
        BattleMath.sqrtYul(x);
        uint256 gasYul = vm.stopSnapshotGas("sqrt_Yul");

        emit log_named_uint("sqrt Solidity gas", gasSol);
        emit log_named_uint("sqrt Yul     gas", gasYul);
    }

    function test_GasBenchmark_clampedSub() public {
        vm.startSnapshotGas("clampedSub_Solidity");
        BattleMath.clampedSubSolidity(1000, 300);
        uint256 gasSol = vm.stopSnapshotGas("clampedSub_Solidity");

        vm.startSnapshotGas("clampedSub_Yul");
        BattleMath.clampedSubYul(1000, 300);
        uint256 gasYul = vm.stopSnapshotGas("clampedSub_Yul");

        emit log_named_uint("clampedSub Solidity gas", gasSol);
        emit log_named_uint("clampedSub Yul     gas", gasYul);
    }
}
