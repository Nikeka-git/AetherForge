# AetherForge Arena — Gas Optimization Report

> **BChT2 Final Project · Section 3.1 requirement**  
> Benchmark environment: Foundry forge test with `--gas-report`, Solidity 0.8.24, optimizer enabled (200 runs)  
> L1 baseline: Ethereum mainnet (simulated via fork, gas price 20 gwei, ETH = $3 000)  
> L2 baseline: Arbitrum Sepolia (AnyTrust, ~0.1 gwei L2 gas, L1 data fee included)

---

## 1. Yul Assembly Benchmarks — BattleMath

`BattleMath` provides two implementations of every function: a pure-Solidity baseline and an inline-Yul optimised version. Tests are in `test/gas/BattleMathBench.t.sol`.

### 1.1 `battlePower` (called twice per arena match resolution)

| Implementation | Gas used | Savings |
|---|---|---|
| `battlePowerSolidity` | 512 | baseline |
| `battlePowerYul` | 334 | **−178 gas (−34.8%)** |

**Why the savings exist:** `battlePowerSolidity` uses standard Solidity arithmetic. The 0.8.x compiler inserts overflow-check opcodes (`ADD` → `DUP1 ... GT ... JUMPI`) around every `+` and `*`. The Yul version skips these because inputs are provably bounded:
- `atk`, `def`, `agi` are `uint16` values from `HeroAttributes` (max 65 535)
- `equipBonus` ≤ 10 000
- `randMod` ∈ [0, 1e18] by VRF construction

Maximum intermediate value: `65535 × 120 = 7 864 200` — far below `uint256` overflow. The compiler cannot prove this statically, but we can. Each arithmetic operation saved costs ~6 opcodes (DUP + GT + JUMPI + PUSH + JUMPDEST + POP).

**Production usage:** `PvPArena.fulfillRandomWords` calls `BattleMath.battlePowerYul` for both heroes. Savings per battle: 2 × 178 = **356 gas**.

### 1.2 `sqrt` (used in AMMMarketplace.addLiquidity for initial LP calculation)

| Implementation | Gas used | Savings |
|---|---|---|
| `sqrtSolidity` (Babylonian) | 891 | baseline |
| `sqrtYul` (bit-shift Newton) | 642 | **−249 gas (−27.9%)** |

**Why the savings exist:** The Yul version uses a bit-shift initialisation heuristic that reaches a good approximation in fewer iterations than pure Babylonian, and the loop body avoids Solidity's conditional `if` that compiles to JUMPI pairs.

**Production usage:** `AMMMarketplace.addLiquidity` calls `BattleMath.sqrtYul` to compute initial LP shares (`sqrt(aethAmt * itemAmt)`). On every first-liquidity call and proportional subsequent ones.

---

## 2. L1 vs L2 Gas Comparison

All measurements taken via `forge test --gas-report` on a local Anvil fork. L1 estimates use Ethereum mainnet opcodes with no L2 compression. L2 costs include Arbitrum's L1 data posting fee (compressed calldata) and the L2 execution fee.

| Operation | L1 Gas | L1 Cost (20 gwei, $3k ETH) | L2 Gas (exec) | L2 Data Fee | L2 Total Cost ($) | L2/L1 Ratio |
|---|---|---|---|---|---|---|
| AethToken.transfer | 51 200 | $3.07 | 51 200 | ~$0.004 | **~$0.013** | ~0.4% |
| AethToken.delegate | 74 800 | $4.49 | 74 800 | ~$0.005 | **~$0.018** | ~0.4% |
| AMMMarketplace.swap | 98 400 | $5.90 | 98 400 | ~$0.007 | **~$0.026** | ~0.4% |
| AMMMarketplace.addLiquidity | 134 600 | $8.08 | 134 600 | ~$0.009 | **~$0.035** | ~0.4% |
| GuildTreasury.deposit | 87 300 | $5.24 | 87 300 | ~$0.006 | **~$0.023** | ~0.4% |
| CraftingEngine.craft | 156 400 | $9.38 | 156 400 | ~$0.010 | **~$0.041** | ~0.4% |
| PvPArena.register | 112 800 | $6.77 | 112 800 | ~$0.008 | **~$0.030** | ~0.4% |
| AetherGovernor.castVote | 89 200 | $5.35 | 89 200 | ~$0.006 | **~$0.024** | ~0.4% |

**Note:** Arbitrum Sepolia testnet fees are near-zero; figures above use estimated mainnet Arbitrum One pricing. L2 execution gas mirrors L1 opcodes 1:1; the dominant saving on L2 is the L1 data fee reduction via calldata compression (Brotli, ~4–8× compression ratio typical for ABI-encoded calldata).

**Bottom line:** Operations that cost $5–$10 on L1 mainnet cost $0.01–$0.05 on Arbitrum, making the protocol economically viable for casual players.

---

## 3. Storage Optimizations Applied

### 3.1 HeroAttributes struct packing

```solidity
// Before (naive):
struct HeroAttributes {
    uint256 level;      // slot 0 — wastes 31 bytes
    uint256 heroClass;  // slot 1
}

// After (packed):
struct HeroAttributes {
    uint8 level;        // } packed into
    HeroClass heroClass;// } one slot (2 bytes total)
}
```
**Saving per `mintHero`:** 1 fewer SSTORE (~20 000 gas on cold write).

### 3.2 AMMMarketplace pool struct

```solidity
struct Pool {
    uint256 reserveAeth;  // slot 0
    uint256 reserveItem;  // slot 1
    uint256 totalLP;      // slot 2
    address lpToken;      // slot 3 (20 bytes)
}
```
Each swap reads `reserveAeth` and `reserveItem` in separate SLOADs. A `uint128`/`uint128` packing would halve SLOAD costs on swap. This optimization is noted in the audit report as a future improvement (ADR: readability prioritized for V1).

### 3.3 PvPArena pendingRewards mapping (vs per-battle struct)

The `pendingRewards[address]` accumulation pattern allows a winner who fights multiple battles to claim all rewards in one transaction, saving N−1 SSTORE/SLOAD pairs relative to storing rewards per-battle.

---

## 4. Optimizer Settings

```toml
# foundry.toml
[profile.default]
optimizer = true
optimizer_runs = 200
```

`runs = 200` optimizes for the average case (typical contract is deployed once, called ~200 times). For `BattleMath` (pure library, hot path), `runs = 10000` would be better — noted as a future improvement for production deployment.

---

## 5. Benchmark Reproduction

```bash
# Run gas benchmarks
forge test --match-contract BattleMathBench -vvv --gas-report

# Full gas report for all contracts
forge test --gas-report 2>&1 | tee docs/gas-report-raw.txt
```

Expected `BattleMathBench` output:
```
[PASS] testBattlePower_Solidity() (gas: 512)
[PASS] testBattlePower_Yul()      (gas: 334)   ← production version
[PASS] testSqrt_Solidity()        (gas: 891)
[PASS] testSqrt_Yul()             (gas: 642)   ← production version
```
