// ─── Deployed contract addresses (Arbitrum Sepolia, chainId 421614) ───────────

export const ADDRESSES = {
  AethToken:      '0x7aa8834926c783f69c5cad7fcd008a140176c34d',
  GuildTreasury:  '0x117abc28a926df44746d36e56a04a4332aa25c3b',
  AMMMarketplace: '0x8451f2f5e7bb375764358ec2cbfd15385ff3549f',
  CraftingEngine: '0x18f8ff91674a71c79ae7bc6f3f59d039c307a02a',
  MercenaryGuild: '0x55318d07f1ad22f21334d6f41b22503273fd4fc1',
  HeroNFT:        '0x2c40df51d53cb9ff32f031d0840d2b8d8c0b7252',
  PvPArena:       '0x7d508b563f8c8a2d70bca4fa7967f1b9dcd785b4',
  AetherGovernor: '0x8a7ef55437aeebd6e2b9dde1bfbc143e90d50e80',
  AetherTimelock: '0x3e31dc90cf05410f062788a9cd9128172f529a18',
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
  { name: 'pools', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'itemId', type: 'uint256' }],
    outputs: [
      { name: 'reserveAeth', type: 'uint256' },
      { name: 'reserveItem', type: 'uint256' },
      { name: 'totalLPSupply', type: 'uint256' },
      { name: 'lpToken', type: 'address' },
    ] },
  { name: 'swap', type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'itemId', type: 'uint256' },
      { name: 'aethToItem', type: 'bool' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'minAmountOut', type: 'uint256' },
    ],
    outputs: [{ name: 'amountOut', type: 'uint256' }] },
  { name: 'addLiquidity', type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'itemId', type: 'uint256' },
      { name: 'aethAmount', type: 'uint256' },
      { name: 'itemAmount', type: 'uint256' },
    ],
    outputs: [{ type: 'uint256' }] },
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

export const HERO_CLASSES = ['Warrior', 'Mage', 'Rogue', 'Ranger', 'Paladin']

export const HERO_CLASS_ICONS = ['⚔️', '🔮', '🗡️', '🏹', '🛡️']

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
  { label: 'Pending',  cls: 'badge-pending'  },
  { label: 'Active',   cls: 'badge-active'   },
  { label: 'Canceled', cls: 'badge-canceled' },
  { label: 'Defeated', cls: 'badge-defeated' },
  { label: 'Succeeded',cls: 'badge-succeeded'},
  { label: 'Queued',   cls: 'badge-queued'   },
  { label: 'Expired',  cls: 'badge-expired'  },
  { label: 'Executed', cls: 'badge-executed' },
]
