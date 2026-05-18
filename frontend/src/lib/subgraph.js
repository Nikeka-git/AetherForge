// ─── Subgraph endpoint ────────────────────────────────────────────────────────
// Set VITE_SUBGRAPH_URL in your .env file.
// The URL is available in Graph Studio → your subgraph → Details tab.
const SUBGRAPH_URL =
  import.meta.env.VITE_SUBGRAPH_URL ||
  'https://api.studio.thegraph.com/query/REPLACE_ME/aetherforge-arena/version/latest'

async function query(gql, variables = {}) {
  const res = await fetch(SUBGRAPH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: gql, variables }),
  })
  if (!res.ok) throw new Error(`Subgraph HTTP ${res.status}`)
  const json = await res.json()
  if (json.errors) throw new Error(json.errors[0].message)
  return json.data
}

// ─── Query 1 — Hero inventory by owner ────────────────────────────────────────
export async function fetchHeroesByOwner(owner) {
  const data = await query(
    `query HerosByOwner($owner: Bytes!) {
       heros(where: { owner: $owner }, orderBy: mintedAt, orderDirection: desc) {
         id
         heroClass
         level
         mintedAt
         mintTx
       }
     }`,
    { owner: owner.toLowerCase() }
  )
  return data.heros || []
}

// ─── Query 2 — Recent AMM swaps ───────────────────────────────────────────────
export async function fetchRecentSwaps(first = 20) {
  const data = await query(
    `query RecentSwaps($first: Int!) {
       ammSwaps(first: $first, orderBy: timestamp, orderDirection: desc) {
         id
         user
         tokenIn
         amountIn
         tokenOut
         amountOut
         timestamp
         blockNumber
       }
     }`,
    { first }
  )
  return data.ammSwaps || []
}

// ─── Query 3 — Active battles ─────────────────────────────────────────────────
export async function fetchActiveBattles() {
  const data = await query(
    `query ActiveBattles {
       battles(
         where: { status_in: ["REGISTERED", "MATCHED"] }
         orderBy: registeredAt
         orderDirection: desc
         first: 50
       ) {
         id
         player1
         player2
         hero1Id
         hero2Id
         status
         vrfRequestId
         registeredAt
       }
     }`
  )
  return data.battles || []
}

// ─── Query 4 — Available rentals ─────────────────────────────────────────────
export async function fetchAvailableRentals() {
  const data = await query(
    `query AvailableRentals {
       rentalListings(
         where: { status: "LISTED" }
         orderBy: listedAt
         orderDirection: desc
         first: 100
       ) {
         id
         lender
         nftContract
         tokenId
         amount
         assetType
         pricePerDay
         minDuration
         maxDuration
         listedAt
       }
     }`
  )
  return data.rentalListings || []
}

// ─── Query 5 — Crafting history by player ────────────────────────────────────
export async function fetchCraftHistory(player, first = 20) {
  const data = await query(
    `query CraftHistory($player: Bytes!, $first: Int!) {
       craftEvents(
         where: { player: $player }
         first: $first
         orderBy: timestamp
         orderDirection: desc
       ) {
         id
         recipeId
         outputItemId
         outputAmount
         aethCharged
         timestamp
       }
     }`,
    { player: player.toLowerCase(), first }
  )
  return data.craftEvents || []
}
