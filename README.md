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
├── crafting/     CraftingEngine — Recipe-based crafting, AETH burn, Chainlink price
├── arena/        PvPArena       — State machine, Chainlink VRF, pull payments
├── marketplace/  AMMMarketplace — x·y=k AMM, 0.3% fee, LP tokens
├── vault/        GuildTreasury  — ERC-4626 staking vault (gAETH shares)
├── rental/       MercenaryGuild — NFT rental with escrow
├── oracle/       ChainlinkPriceAdapter / MockAggregator
├── governance/   AetherGovernor + AetherTimelock
├── assembly/     BattleMath     — Inline Yul vs pure-Solidity benchmarks
├── security/     Reproduced & fixed reentrancy + access-control vulnerabilities
└── proxy/        GameParametersV1 / V2 — UUPS upgradeable DAO-controlled params
```

**Design patterns (9):** Factory, Proxy/UUPS, Checks-Effects-Interactions, Pull-over-push, Access Control, Pausable/Circuit Breaker, State Machine, Oracle Adapter, Timelock.

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
| L2 | Arbitrum Sepolia (chainId 421614) |
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
forge install
```

### Build

```bash
forge build
```

### Test

```bash
# All tests (without fork tests)
forge test -vvv

# With fork tests (requires RPC URLs)
SEPOLIA_RPC_URL=<url> forge test --match-contract GovernanceForkTest -vvv

# Coverage (must be ≥ 90%)
forge coverage --report summary | tee coverage/coverage.md
```

### Lint & Format

```bash
forge fmt          # format
forge fmt --check  # check only (used in CI)
solhint "contracts/**/*.sol"
```

### Frontend

```bash
cd frontend1
cp env.example .env
# Fill in contract addresses if needed (already pre-filled in contracts.js)
npm install
npm run dev
# Open http://localhost:5173
```

---

## Deployed Contracts (Arbitrum Sepolia)

| Contract | Address | Arbiscan |
|---|---|---|
| AethToken | `0x7aa8834926c783f69c5cad7fcd008a140176c34d` | [View](https://sepolia.arbiscan.io/address/0x7aa8834926c783f69c5cad7fcd008a140176c34d) |
| GuildTreasury | `0x117abc28a926df44746d36e56a04a4332aa25c3b` | [View](https://sepolia.arbiscan.io/address/0x117abc28a926df44746d36e56a04a4332aa25c3b) |
| AMMMarketplace | `0x8451f2f5e7bb375764358ec2cbfd15385ff3549f` | [View](https://sepolia.arbiscan.io/address/0x8451f2f5e7bb375764358ec2cbfd15385ff3549f) |
| CraftingEngine | `0x18f8ff91674a71c79ae7bc6f3f59d039c307a02a` | [View](https://sepolia.arbiscan.io/address/0x18f8ff91674a71c79ae7bc6f3f59d039c307a02a) |
| MercenaryGuild | `0x55318d07f1ad22f21334d6f41b22503273fd4fc1` | [View](https://sepolia.arbiscan.io/address/0x55318d07f1ad22f21334d6f41b22503273fd4fc1) |
| HeroNFT (Proxy) | `0x2c40df51d53cb9ff32f031d0840d2b8d8c0b7252` | [View](https://sepolia.arbiscan.io/address/0x2c40df51d53cb9ff32f031d0840d2b8d8c0b7252) |
| PvPArena | `0x7d508b563f8c8a2d70bca4fa7967f1b9dcd785b4` | [View](https://sepolia.arbiscan.io/address/0x7d508b563f8c8a2d70bca4fa7967f1b9dcd785b4) |
| AetherGovernor | `0x8a7ef55437aeebd6e2b9dde1bfbc143e90d50e80` | [View](https://sepolia.arbiscan.io/address/0x8a7ef55437aeebd6e2b9dde1bfbc143e90d50e80) |
| AetherTimelock | `0x3e31dc90cf05410f062788a9cd9128172f529a18` | [View](https://sepolia.arbiscan.io/address/0x3e31dc90cf05410f062788a9cd9128172f529a18) |

**Subgraph:** deployed on The Graph (Arbitrum Sepolia) — see `subgraph1/subgraph.yaml`

---

## Governance Parameters

| Parameter | Value |
|---|---|
| Voting delay | 1 day (~7 200 blocks) |
| Voting period | 1 week (~50 400 blocks) |
| Quorum | 4% of total supply |
| Proposal threshold | 1% of total supply |
| Timelock delay | 2 days |

---

## Testing Summary

| Category | Count |
|---|---|
| Unit tests | 170+ |
| Fuzz tests | 12 |
| Invariant tests | 5 |
| Fork tests | 3 |
| **Total** | **208+** |

Coverage target: ≥ 90% line coverage (see `coverage/coverage.md`).

---

## Minting Heroes

Hero minting requires `MINTER_ROLE` on the `HeroNFT` contract. To grant access:

```bash
# Deployer grants MINTER_ROLE to an address
cast send 0x2c40df51d53cb9ff32f031d0840d2b8d8c0b7252 \
  "grantRole(bytes32,address)" \
  $(cast keccak "MINTER_ROLE") \
  <YOUR_ADDRESS> \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Mint a hero (classes: 0=Warrior, 1=Mage, 2=Rogue, 3=Paladin)
cast send 0x2c40df51d53cb9ff32f031d0840d2b8d8c0b7252 \
  "mintHero(address,uint8)(uint256)" \
  <RECIPIENT_ADDRESS> 0 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Or use the **Heroes** tab in the dApp (the mint form appears automatically if your wallet holds `MINTER_ROLE`).

---

## Post-Deployment Verification

```bash
forge script script/Verify.s.sol \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  -vvv
```

This script checks:
- Timelock min delay = 2 days
- Governor votingDelay / votingPeriod / quorum match spec
- AethToken DEFAULT_ADMIN_ROLE held by Timelock only
- HeroNFT UPGRADER_ROLE held by Timelock
- Timelock PROPOSER_ROLE held by Governor
- No deployer admin backdoor remains

---

## Documentation

- `docs/architecture.md` — C4 diagrams, component layout, storage layouts, trust assumptions, ADRs
- `docs/audit-report.md` — Internal security audit (8+ pages): findings, governance attack analysis, oracle analysis, Slither output
- `docs/gas-report.md` — Yul benchmarks, L1 vs L2 gas comparison table
- `coverage/coverage.md` — Line coverage report (`forge coverage`)

---

## Team

| Member | Area of Ownership |
|---|---|
| _TBD_ | Smart contracts: tokens, NFTs, AMM, vault |
| _TBD_ | Smart contracts: governance, oracle, arena; Frontend; DevOps |

---

## License

MIT
