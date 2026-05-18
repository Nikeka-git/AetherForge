# AetherForge Arena — Architecture Document

> **BChT2 Final Project · Option B — GameFi Economy**  
> Revision: 1.0 · May 2026

---

## 1. System Context (C4 Level 1)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         External Actors                             │
│                                                                     │
│   [Player / DAO Member]  ──>  [AetherForge dApp]                   │
│         Browser wallet           React + Wagmi + RainbowKit        │
│                                          │                          │
│                                          |                          │
│                           [Arbitrum Sepolia L2]                     │
│                                          │                          │
│          ┌───────────────────────────────┼──────────────────┐      │
│          |                               |                  |      │
│  [Chainlink VRF v2.5]         [Protocol Contracts]   [The Graph]   │
│  randomness for battles        (12 contracts)         subgraph     │
│                                          │                          │
│          ┌───────────────────────────────┘                          │
│          |                                                          │
│  [Chainlink Price Feed]                                             │
│  AETH/USD for crafting costs                                        │
└─────────────────────────────────────────────────────────────────────┘
```

**Deployed network:** Arbitrum Sepolia (chainId 421614)  
**Block time:** 0.25 s (Arbitrum AnyTrust)  
**Frontend:** Vite + React 18, hosted locally or static CDN

---

## 2. Container / Component Diagram

### 2.1 Contract Relationships

```
                        ┌─────────────────┐
                        │   AethToken      │  ERC-20 + ERC20Votes
                        │   (governance)   │  + ERC20Permit
                        └────────┬────────┘
                     mint/burn   │   votes snapshot
          ┌──────────────────────┼──────────────────────┐
          |                      |                      |
  ┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
  │GuildTreasury │    │  CraftingEngine  │    │  AetherGovernor  │
  │  (ERC-4626)  │<───│  burns AETH fee  │    │  + Timelock (2d) │
  │  gAETH share │    │  burns resources │    │  DAO proposals   │
  └──────────────┘    └────────┬─────────┘    └────────┬─────────┘
                               │                        │
                               |                        │ controls
                     ┌──────────────────┐               |
                     │  ItemRegistry    │    ┌──────────────────────┐
                     │  (ERC-1155)      │    │  GameParametersV1    │
                     │  resources +     │    │  (UUPS proxy)        │
                     │  equipment       │    │  entry fees, rates   │
                     └──────────────────┘    └──────────────────────┘
                                                         │ reads params
          ┌──────────────────────────────────────────────┘
          |
  ┌──────────────────┐         ┌──────────────────┐
  │    PvPArena      │────────>│  BattleMath      │
  │  State machine   │ Yul lib │  (inline Yul)    │
  │  Chainlink VRF   │         └──────────────────┘
  │  pull payments   │
  └────────┬─────────┘
           │ reads heroes
           |
  ┌──────────────────┐         ┌──────────────────┐
  │    HeroNFT       │<────────│ HeroNFTFactory   │
  │  (UUPS proxy)    │ CREATE  │ CREATE + CREATE2  │
  │  ERC-721 heroes  │ CREATE2 │ deploys proxies  │
  └──────────────────┘         └──────────────────┘

  ┌──────────────────┐         ┌──────────────────┐
  │  AMMMarketplace  │         │ MercenaryGuild   │
  │  x·y=k AMM       │         │ NFT rental vault  │
  │  LP tokens        │         │ escrow + fees    │
  └──────────────────┘         └──────────────────┘

  ┌──────────────────────────────────────────────┐
  │           ChainlinkPriceAdapter              │
  │  staleness check + oracle adapter pattern    │
  │  wraps AggregatorV3Interface                 │
  └──────────────────────────────────────────────┘
```

### 2.2 Proxy Layout

```
  User / Timelock
       │
       |
  ERC1967Proxy  ──>  HeroNFT V1 (implementation)
  (state lives here)       │
                           └──> HeroNFT V2 (future upgrade)
                                 appends storage slots 11+
                                 never overwrites slots 0–10

  ERC1967Proxy  ──>  GameParametersV1 (implementation)
  (state lives here)       │
                           └──> GameParametersV2 (adds arena XP rate)
```

### 2.3 Access-Control Roles

| Contract | Role | Holder (post-deploy) |
|---|---|---|
| AethToken | DEFAULT_ADMIN_ROLE | AetherTimelock |
| AethToken | MINTER_ROLE | GuildTreasury, CraftingEngine |
| AethToken | BURNER_ROLE | CraftingEngine |
| HeroNFT | DEFAULT_ADMIN_ROLE | AetherTimelock |
| HeroNFT | MINTER_ROLE | (deployer; DAO grants via proposal) |
| HeroNFT | UPGRADER_ROLE | AetherTimelock |
| ItemRegistry | MINTER_ROLE / BURNER_ROLE | CraftingEngine |
| PvPArena | ADMIN_ROLE / PAUSER_ROLE | AetherTimelock |
| GuildTreasury | YIELD_MANAGER_ROLE | PvPArena (fees), deployer |
| GameParameters | PARAM_MANAGER_ROLE / UPGRADER_ROLE | AetherTimelock |
| AetherGovernor | (inherits from Governor OZ) | — |
| AetherTimelock | PROPOSER_ROLE | AetherGovernor |
| AetherTimelock | EXECUTOR_ROLE | address(0) = anyone |

### 2.4 External Dependencies

| Dependency | Purpose | Testnet address |
|---|---|---|
| Chainlink VRF v2.5 Coordinator | Randomness for arena battles | Arbitrum Sepolia standard |
| Chainlink AggregatorV3 (AETH/USD mock) | Crafting cost pricing | MockAggregator in tests |
| The Graph | Event indexing | Arbitrum Sepolia subgraph |
| OpenZeppelin v5 | Governor, ERC standards, AccessControl, proxy | npm package |

---

## 3. Deployed Contract Addresses (Arbitrum Sepolia)

| Contract | Address |
|---|---|
| AethToken | `0x7aa8834926c783f69c5cad7fcd008a140176c34d` |
| GuildTreasury | `0x117abc28a926df44746d36e56a04a4332aa25c3b` |
| AMMMarketplace | `0x8451f2f5e7bb375764358ec2cbfd15385ff3549f` |
| CraftingEngine | `0x18f8ff91674a71c79ae7bc6f3f59d039c307a02a` |
| MercenaryGuild | `0x55318d07f1ad22f21334d6f41b22503273fd4fc1` |
| HeroNFT (proxy) | `0x2c40df51d53cb9ff32f031d0840d2b8d8c0b7252` |
| PvPArena | `0x7d508b563f8c8a2d70bca4fa7967f1b9dcd785b4` |
| AetherGovernor | `0x8a7ef55437aeebd6e2b9dde1bfbc143e90d50e80` |
| AetherTimelock | `0x3e31dc90cf05410f062788a9cd9128172f529a18` |

---

## 4. Sequence Diagrams

### 4.1 AMM Swap (AETH → Item)

```
Player            AethToken         AMMMarketplace
  │                   │                   │
  │──approve(amm,amt)>│                   │
  │<──────────────────│                   │
  │──swap(itemId, true, amtIn, minOut)───>│
  │                   │<──transferFrom────│  pull AETH from player
  │                   │───────────────────│
  │                   │                   │──compute amtOut = (y·dx)/(x+dx)·0.997
  │                   │                   │──assert amtOut >= minOut  (slippage)
  │                   │                   │──reserveAeth += amtIn
  │                   │                   │──reserveItem -= amtOut
  │                   │                   │──ItemRegistry.safeTransferFrom(pool, player, itemId, amtOut)
  │<◄>──────────────────────────────────────│ emit Swapped
```

### 4.2 PvP Arena Battle

```
Player1    Player2    PvPArena    VRF Coordinator    BattleMath
   │           │          │              │                │
   │──register(hero1)────>│              │                │
   │           │          │ state=Registered              │
   │           │──register(hero2)────────>               │
   │           │          │──requestRandomWords()────────>│
   │           │          │              │<──fulfillRW()──│
   │           │          │──battlePowerYul(h1) ─────────>│
   │           │          │<─────────────────────────────│
   │           │          │──battlePowerYul(h2) ─────────>│
   │           │          │<─────────────────────────────│
   │           │          │ state=Resolved; pendingRewards[winner]=prize
   │──claimReward(id)─────>│
   │           │          │──AethToken.safeTransfer(player1, prize)
   │<──────────────────────│
```

### 4.3 DAO Governance (propose -> vote -> queue -> execute)

```
Proposer    AetherGovernor    AetherTimelock    Target Contract
   │               │                │                │
   │──propose()───►│                │                │
   │               │ state=Pending  │                │
   │               │ (1 day delay)  │                │
   │──castVote()──►│                │                │
   │               │ state=Active   │                │
   │               │ (1 week window)│                │
   │──queue()──────►│               │                │
   │               │──scheduleBatch()──────────────► │
   │               │ state=Queued   │                │
   │               │               │ (2 day delay)  │
   │──execute()────►│              │                │
   │               │──executeBatch()──────────────► │
   │               │               │──call(calldata)►│
   │               │               │                │ (e.g. updateEntryFee)
```

---

## 5. Storage Layouts

### 5.1 HeroNFT (UUPS proxy — collision-free append-only)

| Slot | Contract | Variable |
|---|---|---|
| 0 | Initializable | `_initialized`, `_initializing` |
| 1 | ERC721Upgradeable | `_name` |
| 2 | ERC721Upgradeable | `_symbol` |
| 3 | ERC721Upgradeable | `_owners` (mapping) |
| 4 | ERC721Upgradeable | `_balances` (mapping) |
| 5 | ERC721Upgradeable | `_tokenApprovals` (mapping) |
| 6 | ERC721Upgradeable | `_operatorApprovals` (mapping) |
| 7 | AccessControlUpgradeable | `_roles` (mapping) |
| 8 | HeroNFT V1 | `_nextTokenId` (uint256) |
| 9 | HeroNFT V1 | `_heroAttributes` (mapping tokenId → HeroAttributes) |
| 10 | HeroNFT V1 | `_baseTokenURI` (string) |
| 11+ | HeroNFT **V2** | skill trees, equipment slots (to be appended) |

**Collision proof:** V2 appends from slot 11 onward. Slots 0–10 are frozen by the existing implementation. OpenZeppelin's `@custom:storage-location` annotation will be added in V2 to enforce this via the Upgrades Defender linter.

### 5.2 GameParametersV1 (UUPS proxy)

| Slot | Variable |
|---|---|
| 0 | Initializable |
| 1–7 | AccessControlUpgradeable |
| 8–9 | PausableUpgradeable |
| 10 | UUPSUpgradeable |
| 11 | `entryFee` (uint256) |
| 12 | `treasuryFeeBps` (uint256) |
| 13 | `craftingFeeBps` (uint256) |
| 14 | `vrfCancelWindow` (uint256) |
| 15 | `rentalFeeBps` (uint256) |

---

## 6. Trust Assumptions

| Actor | Powers | Risk if compromised |
|---|---|---|
| AetherTimelock | Controls DEFAULT_ADMIN on all contracts; can upgrade proxies, set fees, grant/revoke all roles | Full protocol takeover — mitigated by 2-day delay giving community time to detect and react |
| AetherGovernor | Can queue operations into Timelock only via passed proposals | Governance attack — mitigated by 4% quorum, 1% proposal threshold, voting delay |
| Chainlink VRF Coordinator | Provides randomness for battle outcomes | Manipulation of match results — mitigated by using VRF v2.5 (post-commit-reveal) |
| Chainlink Price Feed | AETH/USD price for crafting | Stale price → wrong craft costs — mitigated by staleness check (revert if > N seconds old) |
| The Graph Node | Indexes events for the frontend | Frontend shows stale/wrong data — mitigated by fallback to direct contract reads for critical state |
| MINTER_ROLE holders (HeroNFT) | Can mint unlimited heroes | NFT supply inflation — MINTER_ROLE held only by DAO-approved addresses, grantRole controlled by Timelock |

---

## 7. Design Decision Records (ADRs)

### ADR-01: UUPS over Transparent Proxy

**Context:** HeroNFT needs to be upgradeable (V1 stores level+class; V2 will add skill trees).  
**Options:** Transparent Proxy, UUPS, Beacon Proxy.  
**Decision:** UUPS — upgrade logic lives in the implementation, not the proxy. Cheaper to deploy (one less contract). `upgradeToAndCall` gated by `UPGRADER_ROLE` (held by Timelock only).  
**Consequences:** Implementation must inherit `UUPSUpgradeable`. Storage layout discipline is mandatory — enforced via documented slot table above.

### ADR-02: Pull-over-Push in PvPArena

**Context:** Arena distributes AETH rewards after battle resolution via Chainlink VRF callback.  
**Options:** Push (transfer inside `fulfillRandomWords`), Pull (store pending reward, winner calls `claimReward`).  
**Decision:** Pull — `fulfillRandomWords` only writes `pendingRewards[winner]`. VRF callbacks have limited gas; a push transfer could fail (gas limit, recipient reverting) and brick the battle.  
**Consequences:** Winner must send a separate `claimReward` transaction. Better UX can be added at frontend layer without contract changes.

### ADR-03: Constant-product AMM from scratch

**Context:** The marketplace needs AMM functionality for AETH ↔ item swaps.  
**Options:** Fork Uniswap V2, use minimal reference, build from scratch.  
**Decision:** Built from scratch in `AMMMarketplace.sol` to satisfy the "not forked" requirement (§3.1) and to keep the contract focused on ERC-1155 item IDs as pool keys rather than token pair addresses.  
**Consequences:** Less battle-tested than Uniswap V2. Mitigated by 15 unit tests, 3 fuzz tests, 2 invariant tests covering the k-invariant and LP accounting.

### ADR-04: ERC-4626 decimals offset

**Context:** ERC-4626 share inflation attack: attacker donates 1 wei before first deposit, inflating share price and causing rounding losses for subsequent depositors.  
**Options:** Use offset=0 (vulnerable), use `_decimalsOffset() = 3` (virtual shares 1000:1).  
**Decision:** Override `_decimalsOffset()` to return 3 in `GuildTreasury`. Donation attack cost increases by 1000×.  
**Consequences:** `convertToShares` and `convertToAssets` are still monotone; all ERC-4626 rounding invariants hold (tested in `GuildTreasuryInvariant.t.sol`).

### ADR-05: GameParametersV1 as DAO-controlled parameter store

**Context:** Game parameters (entry fee, crafting costs, fee BPS) need to be updatable by the DAO without upgrading every contract.  
**Options:** Hardcode in each contract, use a shared registry, use a UUPS upgradeable parameter contract.  
**Decision:** UUPS upgradeable `GameParametersV1` controlled by `PARAM_MANAGER_ROLE` (Timelock). Contracts read from it via a typed interface.  
**Consequences:** Single point of DAO control for all game tuning. If the parameter contract is compromised, all game economics are at risk — mitigated by Timelock delay and role gating.
