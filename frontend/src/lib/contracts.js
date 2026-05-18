// ─── Deployed contract addresses (Arbitrum Sepolia, chainId 421614) ───────────

export const ADDRESSES = {
  AethToken:      '0x05cd03555f9b070ef5157cd596ac0d1b921e9122',
  GuildTreasury:  '0x5ed48f7cfbd815194e1c1da41c9b3a374bd5a26d',
  AMMMarketplace: '0xbdb3eb8c39e0f58de1ce8890fe5965bb21e407bf',
  CraftingEngine: '0x1312959b19eea8d1eaf15326ac1595d68de5db51',
  MercenaryGuild: '0x77ded34f2d48438b79555d346820ccb1efe80756',
  HeroNFT:        '0x7323fa4f5c60ed45a08f7b68bc99e1ad731c23d7',
  PvPArena:       '0xf0ea2405965ed381742ecd0a4288b8162f429ebd',
  AetherGovernor: '0x01f85400901dd98e1d48056740b7fe66cfd691cc',
  AetherTimelock: '0x5321f62960cead392d248a4249d2e4a5f30dbcc3',
}

// ─── Minimal ABIs ─────────────────────────────────────────────────────────────

export const AETH_ABI = [
  { name: 'balanceOf',    type: 'function', stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'allowance',   type: 'function', stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }, { name: 'spender', type: 'address' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'getVotes',    type: 'function', stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'delegates',   type: 'function', stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'address' }] },
  { name: 'totalSupply', type: 'function', stateMutability: 'view',
    inputs: [], outputs: [{ type: 'uint256' }] },
  { name: 'approve',     type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'spender', type: 'address' }, { name: 'amount', type: 'uint256' }],
    outputs: [{ type: 'bool' }] },
  { name: 'delegate',    type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'delegatee', type: 'address' }], outputs: [] },
]

export const TREASURY_ABI = [
  { name: 'totalAssets', type: 'function', stateMutability: 'view',
    inputs: [], outputs: [{ type: 'uint256' }] },
  { name: 'totalSupply', type: 'function', stateMutability: 'view',
    inputs: [], outputs: [{ type: 'uint256' }] },
  { name: 'balanceOf',   type: 'function', stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'previewDeposit', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'assets', type: 'uint256' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'previewRedeem', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'shares', type: 'uint256' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'deposit',     type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'assets', type: 'uint256' }, { name: 'receiver', type: 'address' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'redeem',      type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'shares', type: 'uint256' },
      { name: 'receiver', type: 'address' },
      { name: 'owner', type: 'address' },
    ],
    outputs: [{ type: 'uint256' }] },
]

export const AMM_ABI = [
  // ── View ──────────────────────────────────────────────────────────────────
  { name: 'getReserves', type: 'function', stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: '_reserveA', type: 'uint256' },
      { name: '_reserveB', type: 'uint256' },
    ] },
  { name: 'getAmountOut', type: 'function', stateMutability: 'view',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
    ],
    outputs: [{ name: 'amountOut', type: 'uint256' }] },
  { name: 'tokenA', type: 'function', stateMutability: 'view',
    inputs: [], outputs: [{ type: 'address' }] },
  { name: 'tokenB', type: 'function', stateMutability: 'view',
    inputs: [], outputs: [{ type: 'address' }] },
  { name: 'balanceOf', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }] },
  // ── Write ─────────────────────────────────────────────────────────────────
  { name: 'swap', type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'minAmountOut', type: 'uint256' },
    ],
    outputs: [{ name: 'amountOut', type: 'uint256' }] },
  { name: 'addLiquidity', type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'amountADesired', type: 'uint256' },
      { name: 'amountBDesired', type: 'uint256' },
      { name: 'minLpOut', type: 'uint256' },
    ],
    outputs: [{ name: 'lpMinted', type: 'uint256' }] },
  { name: 'removeLiquidity', type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'lpAmount', type: 'uint256' },
      { name: 'minA', type: 'uint256' },
      { name: 'minB', type: 'uint256' },
    ],
    outputs: [
      { name: 'amountA', type: 'uint256' },
      { name: 'amountB', type: 'uint256' },
    ] },
  { name: 'approve', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'spender', type: 'address' }, { name: 'amount', type: 'uint256' }],
    outputs: [{ type: 'bool' }] },
]

export const CRAFTING_ABI = [
  { name: 'craft', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'recipeId', type: 'uint256' }], outputs: [] },
  { name: 'recipes', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'recipeId', type: 'uint256' }],
    outputs: [
      { name: 'aethCost', type: 'uint256' },
      { name: 'outputItemId', type: 'uint256' },
      { name: 'outputAmount', type: 'uint256' },
    ] },
]

export const HERO_ABI = [
  // ── View ──────────────────────────────────────────────────────────────────
  { name: 'balanceOf', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'heroes', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [
      { name: 'heroClass', type: 'uint8' },
      { name: 'level', type: 'uint8' },
      { name: 'attack', type: 'uint16' },
      { name: 'defense', type: 'uint16' },
      { name: 'agility', type: 'uint16' },
      { name: 'luck', type: 'uint16' },
      { name: 'vitality', type: 'uint16' },
      { name: 'battleWins', type: 'uint32' },
      { name: 'battleLosses', type: 'uint32' },
      { name: 'equippedWeapon', type: 'uint256' },
      { name: 'equippedArmor', type: 'uint256' },
    ] },
  // ── Access control (needed for minting UI) ────────────────────────────────
  { name: 'hasRole', type: 'function', stateMutability: 'view',
    inputs: [
      { name: 'role', type: 'bytes32' },
      { name: 'account', type: 'address' },
    ],
    outputs: [{ type: 'bool' }] },
  // ── Write ─────────────────────────────────────────────────────────────────
  // mintHero(address to, uint8 heroClass) — requires MINTER_ROLE
  { name: 'mintHero', type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'heroClass', type: 'uint8' },
    ],
    outputs: [{ name: 'tokenId', type: 'uint256' }] },
]

export const ARENA_ABI = [
  { name: 'entryFee', type: 'function', stateMutability: 'view',
    inputs: [], outputs: [{ type: 'uint256' }] },
  { name: 'register', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'heroId', type: 'uint256' }], outputs: [] },
  { name: 'claimReward', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'battleId', type: 'uint256' }], outputs: [] },
  { name: 'pendingRewards', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'winner', type: 'address' }],
    outputs: [{ type: 'uint256' }] },
]

export const GOVERNOR_ABI = [
  { name: 'state', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'proposalId', type: 'uint256' }],
    outputs: [{ type: 'uint8' }] },
  { name: 'proposalVotes', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'proposalId', type: 'uint256' }],
    outputs: [
      { name: 'againstVotes', type: 'uint256' },
      { name: 'forVotes', type: 'uint256' },
      { name: 'abstainVotes', type: 'uint256' },
    ] },
  { name: 'castVote', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'proposalId', type: 'uint256' }, { name: 'support', type: 'uint8' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'queue', type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'descriptionHash', type: 'bytes32' },
    ],
    outputs: [{ type: 'uint256' }] },
  { name: 'execute', type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'descriptionHash', type: 'bytes32' },
    ],
    outputs: [{ type: 'uint256' }] },
  { name: 'hasVoted', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'proposalId', type: 'uint256' }, { name: 'account', type: 'address' }],
    outputs: [{ type: 'bool' }] },
  {
    name: 'ProposalCreated',
    type: 'event',
    inputs: [
      { name: 'proposalId',  type: 'uint256', indexed: false },
      { name: 'proposer',    type: 'address', indexed: false },
      { name: 'targets',     type: 'address[]', indexed: false },
      { name: 'values',      type: 'uint256[]', indexed: false },
      { name: 'signatures',  type: 'string[]', indexed: false },
      { name: 'calldatas',   type: 'bytes[]', indexed: false },
      { name: 'voteStart',   type: 'uint256', indexed: false },
      { name: 'voteEnd',     type: 'uint256', indexed: false },
      { name: 'description', type: 'string',  indexed: false },
    ],
  },
]

// ─── Game constants ───────────────────────────────────────────────────────────

// NOTE: must match HeroNFT.sol enum HeroClass { Warrior=0, Mage=1, Rogue=2, Paladin=3 }
export const HERO_CLASSES = ['Warrior', 'Mage', 'Rogue', 'Paladin']

export const HERO_CLASS_ICONS = ['⚔️', '🔮', '🗡️', '🛡️']

export const RESOURCES = [
  { id: 1, name: 'Iron Ore',     icon: '🪨' },
  { id: 2, name: 'Mythril',      icon: '💎' },
  { id: 3, name: 'Mana Crystal', icon: '🔷' },
  { id: 4, name: 'Dragon Scale', icon: '🐉' },
  { id: 5, name: 'Ancient Wood', icon: '🌲' },
]

export const EQUIPMENT = [
  { id: 100, name: 'Flaming Sword',  icon: '🔥', rarity: 'Rare' },
  { id: 101, name: 'Frost Staff',    icon: '❄️', rarity: 'Rare' },
  { id: 102, name: 'Dragon Armor',   icon: '🐲', rarity: 'Epic' },
]

export const RECIPES = [
  {
    id: 1,
    name: 'Flaming Sword',
    icon: '🔥',
    ingredients: [
      { itemId: 1, name: 'Iron Ore',     amount: 2 },
      { itemId: 3, name: 'Mana Crystal', amount: 1 },
    ],
    aethCost: '50',
    outputItemId: 100,
    outputAmount: 1,
  },
  {
    id: 2,
    name: 'Frost Staff',
    icon: '❄️',
    ingredients: [
      { itemId: 5, name: 'Ancient Wood',  amount: 2 },
      { itemId: 3, name: 'Mana Crystal',  amount: 2 },
    ],
    aethCost: '60',
    outputItemId: 101,
    outputAmount: 1,
  },
  {
    id: 3,
    name: 'Dragon Armor',
    icon: '🐲',
    ingredients: [
      { itemId: 4, name: 'Dragon Scale', amount: 3 },
      { itemId: 2, name: 'Mythril',      amount: 2 },
    ],
    aethCost: '120',
    outputItemId: 102,
    outputAmount: 1,
  },
]

export const GOVERNOR_STATES = [
  { label: 'Pending',   cls: 'badge-pending'   },
  { label: 'Active',    cls: 'badge-active'    },
  { label: 'Canceled',  cls: 'badge-canceled'  },
  { label: 'Defeated',  cls: 'badge-defeated'  },
  { label: 'Succeeded', cls: 'badge-succeeded' },
  { label: 'Queued',    cls: 'badge-queued'    },
  { label: 'Expired',   cls: 'badge-expired'   },
  { label: 'Executed',  cls: 'badge-executed'  },
]