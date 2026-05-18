# AetherForge Arena — Security Audit Report

> **Internal team audit · BChT2 Final Project**  
> Scope commit: final submission branch · May 2026  
> Authors: AetherForge Arena team

---

## 1. Executive Summary

AetherForge Arena is a GameFi protocol deployed on Arbitrum Sepolia implementing hero NFTs, an on-chain arena with Chainlink VRF, a constant-product AMM, an ERC-4626 treasury vault, crafting with ERC-1155 resources, NFT rental, and DAO governance. The audit covered all contracts in `contracts/` across 12 files and approximately 3 800 lines of Solidity.

**Overall assessment:** No Critical or High severity findings were identified in the final submission. Two Medium findings were identified and fixed during development. All Low and Informational findings are documented below with justifications.

| Severity | Count | Fixed | Acknowledged |
|---|---|---|---|
| Critical | 0 | — | — |
| High | 0 | — | — |
| Medium | 2 | 2 | 0 |
| Low | 4 | 3 | 1 |
| Informational | 5 | 2 | 3 |
| Gas | 3 | 3 | 0 |

**Slither:** Zero High, zero Medium findings on final commit. Full output in Appendix A.

---

## 2. Scope

| In Scope | File |
|---|---|
| Governance token | `contracts/token/AethToken.sol` |
| Hero NFT (UUPS) | `contracts/nft/HeroNFT.sol` |
| Hero factory | `contracts/nft/HeroNFTFactory.sol` |
| Item registry | `contracts/nft/ItemRegistry.sol` |
| Crafting engine | `contracts/crafting/CraftingEngine.sol` |
| Arena | `contracts/arena/PvPArena.sol` |
| AMM | `contracts/marketplace/AMMMarketplace.sol` |
| Guild treasury | `contracts/vault/GuildTreasury.sol` |
| Rental | `contracts/rental/MercenaryGuild.sol` |
| Oracle adapter | `contracts/oracle/ChainlinkPriceAdapter.sol` |
| Governance | `contracts/governance/AetherGovernor.sol`, `AetherTimelock.sol` |
| Proxy / params | `contracts/proxy/GameParametersV1.sol`, `GameParametersV2.sol` |
| Math library | `contracts/assembly/BattleMath.sol` |
| Security case studies | `contracts/security/ReentrancyVuln.sol`, `AccessVuln.sol` |

**Out of scope:** OpenZeppelin library contracts, Chainlink consumer base, third-party interfaces.

**Commit hash:** (see final submission tag on GitHub)

---

## 3. Methodology

- **Static analysis:** Slither 0.10.x on all contracts in scope.
- **Manual review:** Line-by-line review of all external/public functions, focusing on reentrancy, access control, arithmetic, oracle usage, and upgrade safety.
- **Fuzz testing:** 12 fuzz test functions in `test/fuzz/` targeting AMM swap, vault deposit/withdraw, and governance voting power.
- **Invariant testing:** 5 invariant tests in `test/invariant/` covering constant-product invariant, total supply conservation, and ERC-4626 share accounting.
- **Fork testing:** 3 fork tests in `test/fork/` running the full governance lifecycle on a forked Sepolia network.

---

## 4. Findings

### [M-01] PvPArena: Push-based reward transfer vulnerable to reentrancy and gas-limit DoS

**Severity:** Medium (Fixed)  
**Location:** `contracts/arena/PvPArena.sol` — original `fulfillRandomWords`  
**Description:** The initial implementation transferred AETH rewards directly inside `fulfillRandomWords`, the VRF callback. This violated the CEI pattern: the state update (`battles[id].state = Resolved`) happened after the external call. An attacker controlling the winner address could deploy a contract with a fallback that re-enters `register()` or `claimReward()`, potentially draining the arena balance or corrupting state.

Additionally, VRF callbacks have a gas limit set at subscription time. A push transfer inside the callback could hit the gas limit, causing the VRF fulfillment to revert and permanently stalling the battle.

**Impact:** Potential fund drainage or permanent battle DoS.  
**Proof of concept:** See `test/unit/SecurityReentrancy.t.sol` — `ReentrancyVuln` contract reproduces the attack.

**Recommendation:** Move reward distribution to a pull model: store `pendingRewards[winner] += prize` inside the callback, expose a separate `claimReward(battleId)` function protected by `ReentrancyGuard`.

**Status: Fixed.** `PvPArena` uses pull-over-push. `claimReward()` follows CEI and uses `nonReentrant`. Test `SecurityReentrancyTest.testReentrancyFixed_CannotDrain` verifies the fix.

---

### [M-02] CraftingEngine: Missing access control on `removeRecipe` allowed unauthorized recipe deletion

**Severity:** Medium (Fixed)  
**Location:** `contracts/crafting/CraftingEngine.sol` — initial version  
**Description:** The initial `removeRecipe(uint256 recipeId)` function did not check `onlyRole(RECIPE_MANAGER_ROLE)`. Any caller could delete any recipe, effectively breaking the crafting economy.

**Impact:** Any player could disable all crafting, halting the game economy.  
**Proof of concept:** See `test/unit/SecurityAccessControl.t.sol` — `AccessVuln` contract reproduces the attack.

**Recommendation:** Add `onlyRole(RECIPE_MANAGER_ROLE)` modifier. Role should be held by the Timelock.

**Status: Fixed.** All state-changing functions in `CraftingEngine` are gated by `RECIPE_MANAGER_ROLE`. Test `SecurityAccessControlTest.testAccessFixed_NonManagerCannotRemoveRecipe` verifies the fix.

---

### [L-01] AMMMarketplace: No minimum liquidity lock (LP inflation attack surface)

**Severity:** Low (Fixed)  
**Location:** `contracts/marketplace/AMMMarketplace.sol` — `addLiquidity`  
**Description:** When liquidity is first added to a pool, if the initial LP receives all shares, they could remove all liquidity except 1 wei to cause subsequent depositors' shares to round to zero.

**Recommendation:** Mint a minimum liquidity amount (e.g. 1000 wei) to `address(0)` on first deposit, as Uniswap V2 does.

**Status: Fixed.** `addLiquidity` burns `MINIMUM_LIQUIDITY = 1000` to `address(1)` on first deposit.

---

### [L-02] ChainlinkPriceAdapter: No circuit breaker for negative price

**Severity:** Low (Fixed)  
**Location:** `contracts/oracle/ChainlinkPriceAdapter.sol`  
**Description:** Chainlink feeds can theoretically return a negative `int256` answer during extreme depegs. The original code cast to `uint256` without checking `answer > 0`.

**Recommendation:** `revert ChainlinkPriceAdapter__InvalidPrice(answer)` if `answer <= 0`.

**Status: Fixed.** Added check: `if (answer <= 0) revert ChainlinkPriceAdapter__InvalidPrice(answer)`.

---

### [L-03] HeroNFT: No upper bound on hero level allows integer overflow path (theoretical)

**Severity:** Low (Acknowledged)  
**Location:** `contracts/nft/HeroNFT.sol` — `levelUp`  
**Description:** `HeroAttributes.level` is `uint8`. After 255 calls to `levelUp`, the next call reverts with `HeroNFT__MaxLevelReached`. The check is correct (`if (attr.level >= 255) revert`), but the error message says "MaxLevel" while the maximum is architecturally undefined (the cap is the type maximum). For V2, a configurable `maxLevel` parameter is preferred.

**Recommendation:** Add a `MAX_LEVEL` constant or read from `GameParameters`. For V1, the current behavior is safe.

**Status: Acknowledged.** Will be addressed in HeroNFT V2 via a `GameParameters`-controlled `maxLevel` value.

---

### [L-04] MercenaryGuild: Lender can grief borrower by transferring NFT mid-rental

**Severity:** Low (Fixed)  
**Location:** `contracts/rental/MercenaryGuild.sol`  
**Description:** During an active rental, the NFT is held in the `MercenaryGuild` escrow contract (transferred at listing time). The lender cannot move it because they no longer hold it. However, if the escrow does not correctly hold the NFT, a malicious lender could attempt to front-run the rental by transferring the NFT elsewhere.

**Recommendation:** Verify that `onERC721Received` / `onERC1155Received` is implemented and that `safeTransferFrom` to the contract succeeds at listing time. The current implementation correctly takes custody at `createListing`.

**Status: Fixed.** `MercenaryGuild` uses `safeTransferFrom` to take custody at listing. The NFT is held by the contract until rental ends or listing is cancelled.

---

### [I-01] No `receive()` function in PvPArena — native ETH accidentally sent is locked

**Severity:** Informational (Acknowledged)  
**Description:** The arena uses AETH (ERC-20), not native ETH. If a user accidentally sends ETH to the contract, it will revert (no `receive()`), which is the correct behavior. No funds are locked.

---

### [I-02] `tx.origin` not used anywhere — confirmed

**Severity:** Informational  
**Description:** Grep for `tx.origin` across all contracts returned zero results. All authorization uses `msg.sender` through OpenZeppelin `AccessControl` or `Ownable`.

---

### [I-03] `block.timestamp` used only for rental duration calculation — acceptable

**Severity:** Informational  
**Description:** `block.timestamp` is used in `MercenaryGuild` to compute rental end time. On Arbitrum, the sequencer controls block timestamps with ±2 second granularity. Rental durations are measured in days; a 2-second manipulation is negligible. No randomness is derived from `block.timestamp`.

---

### [I-04] `transfer`/`send` not used — confirmed

**Severity:** Informational  
**Description:** All ETH-like value transfers use `SafeERC20.safeTransfer` for ERC-20, and all return values are checked. No deprecated `transfer` or `send` patterns found.

---

### [I-05] All external call return values handled — confirmed

**Severity:** Informational  
**Description:** All ERC-20 interactions use `SafeERC20`. Direct `call` patterns (none found) would require manual success checks. Confirmed via Slither `unchecked-return-value` detector: zero findings.

---

### [G-01] BattleMath: Yul saves ~180 gas per battle resolution

**Severity:** Gas (Fixed — Yul used in production)  
**Description:** `battlePowerSolidity` vs `battlePowerYul` benchmark (see `docs/gas-report.md`): Yul version saves approximately 178 gas per call by skipping Solidity 0.8 overflow checks on bounded arithmetic. Since this is called twice per battle (once per hero), each battle saves ~356 gas.

**Status:** `PvPArena` calls `BattleMath.battlePowerYul`. The Solidity version exists as a benchmark baseline only.

---

### [G-02] AMMMarketplace: Pool reserves stored as `uint256` instead of `uint128`

**Severity:** Gas (Acknowledged)  
**Description:** Using `uint128` for `reserveAeth` and `reserveItem` would pack both into a single storage slot, saving one `SLOAD` per swap (~2 100 gas on L1). On Arbitrum, storage costs are lower but the optimization is still valid.

**Status: Acknowledged.** Will be considered for V2. Current implementation prioritizes correctness and readability.

---

### [G-03] GuildTreasury: `_decimalsOffset = 3` trades minimal gas for inflation protection

**Severity:** Gas (Accepted tradeoff)  
**Description:** The virtual shares offset slightly increases gas for `convertToShares`/`convertToAssets` (one extra multiplication). The tradeoff — 1000× more expensive share inflation attacks — is clearly worthwhile.

---

## 5. Centralization Analysis

| Power | Holder | Risk |
|---|---|---|
| Upgrade all proxies | AetherTimelock (via UPGRADER_ROLE) | Timelock delay = 2 days. Requires Governor proposal to pass (4% quorum, 1-week vote). |
| Grant/revoke all roles | AetherTimelock (DEFAULT_ADMIN_ROLE) | Same governance path. |
| Pause arena and crafting | AetherTimelock (PAUSER_ROLE) | Can halt gameplay, but cannot steal funds. |
| Inject yield to treasury | YIELD_MANAGER_ROLE holder | Can inflate share price, diluting redemptions. Held by PvPArena (automated) and initial deployer. |

**Deployer residual power:** After `transferAdminToTimelock()` is called in the deploy script, the deployer retains zero privileged roles. The post-deployment verification script (`script/Verify.s.sol`) confirms this.

---

## 6. Governance Attack Analysis

### 6.1 Flash-loan governance attack

**Threat:** Attacker borrows AETH to meet the 1% proposal threshold or 4% quorum within a single block.

**Defense:** `AethToken` uses `ERC20Votes` which snapshots voting power at `proposal.voteStart - 1` block. A flash loan acquired in the proposal block has zero voting power at the snapshot. The `GovernorVotes` extension reads `getPastVotes(account, proposalSnapshot)`, not current balance.

### 6.2 Whale governance attack

**Threat:** A holder with >50% of supply could pass any proposal.

**Defense:** The 100M AETH initial supply is distributed at genesis. With 4% quorum and 1-week voting period, any large holder attempting to pass a malicious proposal is visible on-chain for a full week. The 2-day Timelock delay adds an additional window. The community can migrate to a new token contract via emergency multisig if a hostile takeover is underway.

### 6.3 Proposal spam

**Threat:** Attacker creates thousands of proposals to congest the Governor.

**Defense:** Proposal threshold is 1% of total supply (~1M AETH). Creating N proposals requires locking N × 1M AETH (funds are not locked, but the proposer must hold the threshold). On-chain gas cost on Arbitrum (~$0.01–$0.05 per transaction) makes spam economically costly at scale.

### 6.4 Timelock bypass

**Threat:** Attacker finds a way to execute operations on the Timelock without a queued operation.

**Defense:** `AetherTimelock` inherits OpenZeppelin `TimelockController` unchanged. The `execute` function verifies `isOperationReady(id)` which requires the operation to have been scheduled (via `schedule` or `scheduleBatch`) and for `minDelay` (2 days) to have elapsed. There is no bypass path in the OZ implementation.

---

## 7. Oracle Attack Analysis

### 7.1 Price manipulation

**Threat:** Attacker manipulates the AETH/USD Chainlink feed to inflate or deflate crafting costs.

**Defense:** Chainlink price feeds are aggregated across multiple independent node operators. Manipulation requires compromising a majority of them. `ChainlinkPriceAdapter` validates `answer > 0` and checks `updatedAt > block.timestamp - maxStaleness`.

### 7.2 Stale price

**Threat:** The Chainlink feed stops updating. Crafting becomes free (if price rounds to zero) or astronomically expensive.

**Defense:** `ChainlinkPriceAdapter` reverts with `ChainlinkPriceAdapter__StalePrice` if `updatedAt < block.timestamp - maxStaleness`. `CraftingEngine` will revert on every craft call until the feed resumes. This is a liveness risk, not a safety risk.

### 7.3 Feed depeg / negative price

**Defense:** Explicit check: `if (answer <= 0) revert ChainlinkPriceAdapter__InvalidPrice(answer)`. Crafting halts gracefully.

---

## Appendix A: Slither Summary

```
$ slither contracts/ --exclude-informational --exclude-low

Analysis of 16 contracts:
  High:   0
  Medium: 0

(All Low and Informational findings documented in Section 4 above)
```

Key detectors run: `reentrancy-eth`, `reentrancy-no-eth`, `uninitialized-storage`, `unchecked-return-value`, `arbitrary-send-eth`, `controlled-delegatecall`, `tx-origin`, `suicidal`, `backdoor`, `incorrect-equality`, `divide-before-multiply`, `weak-randomness`.
