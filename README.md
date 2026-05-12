# AetherForge Arena

> **Blockchain Technologies 2 · Final Project · Option B — GameFi Economy**

AetherForge Arena is a fully on-chain GameFi protocol built on Arbitrum Sepolia. Players own heroes (ERC-721), craft equipment from resources (ERC-1155), trade materials through an AMM, compete in the arena, stake tokens in a guild treasury (ERC-4626), and govern game parameters through a DAO.

---

## Architecture Overview

```
contracts/
├── token/        AethToken      — ERC-20 + ERC20Votes + ERC20Permit (governance token)
├── nft/          HeroNFT        — ERC-721, UUPS upgradeable (V1 → V2)
│                 HeroNFTFactory — Factory: CREATE + CREATE2
│                 ItemRegistry   — ERC-1155 resources & equipment
├── crafting/     CraftingEngine — Recipe-based crafting, AETH burn
├── arena/        PvPArena       — State machine, Chainlink VRF, pull payments
├── marketplace/  AMMMarketplace — x·y=k AMM, 0.3% fee, LP tokens
├── vault/        GuildTreasury  — ERC-4626 staking vault
├── rental/       MercenaryGuild — NFT rental with escrow
├── oracle/       ChainlinkPriceFeed / MockAggregator
├── governance/   AetherGovernor + AetherTimelock
├── assembly/     BattleMath     — Inline Yul vs pure-Solidity benchmarks
├── security/     Reproduced & fixed reentrancy + access-control vulnerabilities
└── interfaces/   IHeroNFT, IItemRegistry, IAMMMarketplace, IGuildTreasury, ...
```

**Design patterns:** Factory, Proxy/UUPS, Checks-Effects-Interactions, Pull-over-push, Access Control, Pausable/Circuit Breaker, State Machine, Oracle Adapter, Timelock.

---

## Tech Stack

| Layer | Tech |
|---|---|
| Smart contracts | Solidity 0.8.24, Foundry |
| Token standards | ERC-20 (Votes + Permit), ERC-721, ERC-1155, ERC-4626 |
| Oracles | Chainlink VRF v2.5, Chainlink Price Feed |
| Governance | OpenZeppelin Governor + TimelockController |
| Upgradeability | UUPS Proxy (OpenZeppelin) |
| Indexing | The Graph (Arbitrum Sepolia subgraph) |
| Frontend | React + Viem + Wagmi + RainbowKit |
| L2 | Arbitrum Sepolia |
| CI/CD | GitHub Actions |

---

## Getting Started

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Node.js ≥ 20 (for frontend & tooling)
```

### Install dependencies

```bash
git clone https://github.com/<your-org>/aetherforge-arena --recurse-submodules
cd aetherforge-arena

# Solidity libs (git submodules)
forge install
```

### Build

```bash
forge build
```

### Test

```bash
# All tests
forge test -vvv

# With fork tests (requires RPC URLs)
ARBITRUM_RPC_URL=<url> MAINNET_RPC_URL=<url> forge test -vvv

# Coverage
forge coverage --report summary | tee coverage/coverage.md
```

### Lint & Format

```bash
forge fmt          # format
forge fmt --check  # check only (used in CI)
solhint "contracts/**/*.sol"
```

---

## Deployed Contracts (Arbitrum Sepolia)

> _To be filled after Week 9 deployment._

| Contract | Address | Arbiscan |
|---|---|---|
| AethToken | `TBD` | — |
| HeroNFT (Proxy) | `TBD` | — |
| AMMMarketplace | `TBD` | — |
| GuildTreasury | `TBD` | — |
| AetherGovernor | `TBD` | — |
| AetherTimelock | `TBD` | — |

**Subgraph:** `TBD`

---

## Governance Parameters

| Parameter | Value |
|---|---|
| Voting delay | 1 day |
| Voting period | 1 week |
| Quorum | 4% |
| Proposal threshold | 1% |
| Timelock delay | 2 days |

---

## Milestones

| Week | Goal |
|---|---|
| W6 | Team formed, scenario approved, repo created ✓ |
| W7 | Core contracts compile, first tests pass, CI green |
| W8 | DeFi primitive + tokens complete, 50% coverage |
| W9 | Governance + oracles + L2 deployment, subgraph live |
| W10 | Full submission: all deliverables + presentation |

---

## Team

| Member | Area of Ownership |
|---|---|
| _TBD_ | Smart contracts: tokens, NFTs, AMM, vault |
| _TBD_ | Smart contracts: governance, oracle, arena; Frontend; DevOps |

---

## Documentation

- `docs/architecture.md` — System context, component diagrams, sequence diagrams, storage layouts, ADRs
- `docs/audit-report.md` — Security audit report (8+ pages)
- `docs/gas-report.md` — Gas optimization report (Yul benchmarks + L1 vs L2 table)
- `coverage/coverage.md` — Line coverage report (`forge coverage`)

---

## License

MIT
