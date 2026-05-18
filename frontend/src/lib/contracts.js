// ─── Deployed contract addresses (Arbitrum Sepolia, chainId 421614) ───────────

export const ADDRESSES = {
  AethToken:      '0x447e4d33c64b992244ac0495afe6b8a58347c360',
  GuildTreasury:  '0xcb20697fd237e4eba74175560236a0b350594151',
  AMMMarketplace: '0x0ecca53c3499e3b428d9edb724bb7c4c474e2419',
  CraftingEngine: '0x928b72056ab8497cb0fe33834f1299c4c9f28260',
  MercenaryGuild: '0xc208ade9a9e988f3873cf7a037eb0f0870b586d6',
  HeroNFT:        '0xf36cc159efdb132b0d1a7a95da8fb43c0e1fa1e4',
  PvPArena:       '0xd868590dab35096ddb4c665c09ac5e74b5c3a129',
  AetherGovernor: '0x131ea59599daee4189c9ce50d9ad1df98dfcba47',
  AetherTimelock: '0xcec73a960b437291992f4101932e7c0e808b5d12',
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
  // getRecipe returns the full Recipe struct
  { name: 'getRecipe', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'recipeId', type: 'uint256' }],
    outputs: [{
      name: '', type: 'tuple',
      components: [
        { name: 'ingredientIds',  type: 'uint256[]' },
        { name: 'ingredientAmts', type: 'uint256[]' },
        { name: 'usdCost',        type: 'uint256'   },
        { name: 'outputItemId',   type: 'uint256'   },
        { name: 'outputAmount',   type: 'uint256'   },
        { name: 'active',         type: 'bool'      },
      ],
    }] },
  // previewAethCost — useful for showing cost in UI before craft
  { name: 'previewAethCost', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'recipeId', type: 'uint256' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'craft', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'recipeId', type: 'uint256' }], outputs: [] },
]

export const HERO_ABI = [
  // ── View ──────────────────────────────────────────────────────────────────
  { name: 'balanceOf', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }] },
  // getHeroAttributes(uint256 tokenId) → { level: uint8, heroClass: uint8 }
  { name: 'getHeroAttributes', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [
      { name: 'level',     type: 'uint8' },
      { name: 'heroClass', type: 'uint8' },
    ] },
  { name: 'totalMinted', type: 'function', stateMutability: 'view',
    inputs: [], outputs: [{ type: 'uint256' }] },
  { name: 'ownerOf', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'address' }] },
  // ── Access control ────────────────────────────────────────────────────────
  { name: 'hasRole', type: 'function', stateMutability: 'view',
    inputs: [
      { name: 'role', type: 'bytes32' },
      { name: 'account', type: 'address' },
    ],
    outputs: [{ type: 'bool' }] },
  // ── Write ─────────────────────────────────────────────────────────────────
  // mintHero(address to, uint8 heroClass) — open to all callers
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
  { name: 'openSlot', type: 'function', stateMutability: 'view',
    inputs: [], outputs: [{ type: 'uint256' }] },
  // pendingRewards(uint256 battleId) — NOT address
  { name: 'pendingRewards', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'battleId', type: 'uint256' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'getBattle', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'battleId', type: 'uint256' }],
    outputs: [{
      name: '', type: 'tuple',
      components: [
        { name: 'player1',          type: 'address' },
        { name: 'player2',          type: 'address' },
        { name: 'hero1Id',          type: 'uint256' },
        { name: 'hero2Id',          type: 'uint256' },
        { name: 'entryFeeSnapshot', type: 'uint256' },
        { name: 'state',            type: 'uint8'   },
        { name: 'vrfRequestId',     type: 'uint256' },
        { name: 'matchedAt',        type: 'uint256' },
        { name: 'winner',           type: 'address' },
        { name: 'claimed',          type: 'bool'    },
      ],
    }] },
  { name: 'heroInBattle', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'heroId', type: 'uint256' }],
    outputs: [{ type: 'uint256' }] },
  { name: 'register', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'heroId', type: 'uint256' }], outputs: [] },
  { name: 'claimReward', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'battleId', type: 'uint256' }], outputs: [] },
  { name: 'cancelRegistration', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'battleId', type: 'uint256' }], outputs: [] },
  { name: 'cancelStuckBattle', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'battleId', type: 'uint256' }], outputs: [] },
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
  { name: 'propose', type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'targets',     type: 'address[]' },
      { name: 'values',      type: 'uint256[]' },
      { name: 'calldatas',   type: 'bytes[]'   },
      { name: 'description', type: 'string'    },
    ],
    outputs: [{ name: 'proposalId', type: 'uint256' }] 
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
  { id: 10_000, name: 'Flaming Sword',  icon: '🔥', rarity: 'Rare' },
  { id: 10_001, name: 'Frost Staff',    icon: '❄️', rarity: 'Rare' },
  { id: 10_002, name: 'Dragon Armor',   icon: '🐲', rarity: 'Epic' },
]

export const RECIPES = [
  {
    id: 0,
    name: 'Flaming Sword',
    icon: '🔥',
    ingredients: [
      { itemId: 1, name: 'Iron Ore',     amount: 2 },
      { itemId: 3, name: 'Mana Crystal', amount: 1 },
    ],
    usdCost: '50',
    outputItemId: 10_000,
    outputAmount: 1,
  },
  {
    id: 1,
    name: 'Frost Staff',
    icon: '❄️',
    ingredients: [
      { itemId: 5, name: 'Ancient Wood',  amount: 2 },
      { itemId: 3, name: 'Mana Crystal',  amount: 2 },
    ],
    usdCost: '60',
    outputItemId: 10_001,
    outputAmount: 1,
  },
  {
    id: 2,
    name: 'Dragon Armor',
    icon: '🐲',
    ingredients: [
      { itemId: 4, name: 'Dragon Scale', amount: 3 },
      { itemId: 2, name: 'Mythril',      amount: 2 },
    ],
    usdCost: '120',
    outputItemId: 10_002,
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