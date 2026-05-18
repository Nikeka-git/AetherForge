/**
 * AetherForge Arena — The Graph Mappings
 * ───────────────────────────────────────
 * Handles events from 6 data sources:
 *   HeroNFT · AMMMarketplace · CraftingEngine · PvPArena · MercenaryGuild · GuildTreasury
 *
 * Each handler follows the same pattern:
 *   1. Load or create the entity by its natural ID.
 *   2. Set / update fields from the event parameters.
 *   3. Save.
 */

import { BigInt, Bytes } from "@graphprotocol/graph-ts"

import {
  Hero,
  AmmSwap,
  CraftEvent,
  Battle,
  RentalListing,
  TreasuryDeposit,
} from "../generated/schema"

// HeroNFT events
import {
  HeroMinted as HeroMintedEvent,
  HeroLevelUp as HeroLevelUpEvent,
} from "../generated/HeroNFT/HeroNFT"

// AMMMarketplace events
import { Swap as SwapEvent } from "../generated/AMMMarketplace/AMMMarketplace"

// CraftingEngine events
import { ItemCrafted as ItemCraftedEvent } from "../generated/CraftingEngine/CraftingEngine"

// PvPArena events
import {
  Registered as RegisteredEvent,
  Matched as MatchedEvent,
  Resolved as ResolvedEvent,
  Cancelled as CancelledEvent,
} from "../generated/PvPArena/PvPArena"

// MercenaryGuild events
import {
  Listed as ListedEvent,
  Rented as RentedEvent,
  Returned as ReturnedEvent,
  ListingCancelled as ListingCancelledEvent,
} from "../generated/MercenaryGuild/MercenaryGuild"

// GuildTreasury events
import { YieldInjected as YieldInjectedEvent } from "../generated/GuildTreasury/GuildTreasury"

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Stable ID for single-event entities: txHash-logIndex */
function eventId(txHash: Bytes, logIndex: BigInt): string {
  return txHash.toHexString() + "-" + logIndex.toString()
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. HeroNFT handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Fired when a new hero is minted.
 * Creates a Hero entity with level = 1.
 */
export function handleHeroMinted(event: HeroMintedEvent): void {
  let id = event.params.tokenId.toString()
  let hero = new Hero(id)

  hero.owner     = event.params.to
  hero.heroClass = event.params.heroClass
  hero.level     = 1
  hero.mintedAt  = event.block.timestamp
  hero.mintTx    = event.transaction.hash

  hero.save()
}

/**
 * Fired when a hero's level increases.
 * Loads the existing Hero and updates its level.
 */
export function handleHeroLevelUp(event: HeroLevelUpEvent): void {
  let id   = event.params.tokenId.toString()
  let hero = Hero.load(id)

  // Guard: hero should always exist before levelling up
  if (hero == null) return

  hero.level = event.params.newLevel
  hero.save()
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. AMMMarketplace handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Fired on every token swap.
 * Creates an immutable AmmSwap record (one per swap).
 */
export function handleSwap(event: SwapEvent): void {
  let id   = eventId(event.transaction.hash, event.logIndex)
  let swap = new AmmSwap(id)

  swap.user        = event.params.user
  swap.tokenIn     = event.params.tokenIn
  swap.amountIn    = event.params.amountIn
  swap.tokenOut    = event.params.tokenOut
  swap.amountOut   = event.params.amountOut
  swap.timestamp   = event.block.timestamp
  swap.blockNumber = event.block.number

  swap.save()
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. CraftingEngine handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Fired when a player successfully crafts an item.
 * Creates an immutable CraftEvent record.
 */
export function handleItemCrafted(event: ItemCraftedEvent): void {
  let id    = eventId(event.transaction.hash, event.logIndex)
  let craft = new CraftEvent(id)

  craft.player       = event.params.player
  craft.recipeId     = event.params.recipeId
  craft.outputItemId = event.params.outputItemId
  craft.outputAmount = event.params.outputAmount
  craft.aethCharged  = event.params.aethCharged
  craft.timestamp    = event.block.timestamp

  craft.save()
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. PvPArena handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * First player registers for a battle.
 * Creates a Battle entity with status REGISTERED.
 */
export function handleRegistered(event: RegisteredEvent): void {
  let id     = event.params.battleId.toString()
  let battle = new Battle(id)

  battle.player1      = event.params.player
  battle.hero1Id      = event.params.heroId
  battle.status       = "REGISTERED"
  battle.registeredAt = event.block.timestamp

  // Nullable fields — set to null explicitly for clarity
  battle.player2      = null
  battle.hero2Id      = null
  battle.vrfRequestId = null
  battle.winner       = null
  battle.reward       = null
  battle.treasuryCut  = null
  battle.resolvedAt   = null

  battle.save()
}

/**
 * Second player matched — VRF request sent.
 * Updates Battle: adds player2 data, status → MATCHED.
 */
export function handleMatched(event: MatchedEvent): void {
  let id     = event.params.battleId.toString()
  let battle = Battle.load(id)
  if (battle == null) return

  // The second player is the one who triggered Matched
  // (Registered stores player1; player2 is inferred from the event address)
  battle.player2      = event.params.player2
  battle.vrfRequestId = event.params.vrfRequestId
  battle.status       = "MATCHED"

  battle.save()
}

/**
 * VRF fulfilled, winner determined.
 * Updates Battle: winner / reward / treasuryCut, status → RESOLVED.
 */
export function handleResolved(event: ResolvedEvent): void {
  let id     = event.params.battleId.toString()
  let battle = Battle.load(id)
  if (battle == null) return

  battle.winner      = event.params.winner
  battle.reward      = event.params.reward
  battle.treasuryCut = event.params.treasuryCut
  battle.status      = "RESOLVED"
  battle.resolvedAt  = event.block.timestamp

  battle.save()
}

/**
 * Battle cancelled (VRF timeout or player request).
 * Updates Battle: status → CANCELLED.
 */
export function handleCancelled(event: CancelledEvent): void {
  let id     = event.params.battleId.toString()
  let battle = Battle.load(id)
  if (battle == null) return

  battle.status     = "CANCELLED"
  battle.resolvedAt = event.block.timestamp

  battle.save()
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. MercenaryGuild handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Lender lists an NFT for rent.
 * Creates a RentalListing entity with status LISTED.
 */
export function handleListed(event: ListedEvent): void {
  let id      = event.params.listingId.toString()
  let listing = new RentalListing(id)

  listing.lender      = event.params.lender
  listing.nftContract = event.params.nftContract
  listing.tokenId     = event.params.tokenId
  listing.amount      = event.params.amount
  listing.assetType   = event.params.assetType
  listing.pricePerDay = event.params.pricePerDay
  listing.minDuration = event.params.minDuration
  listing.maxDuration = event.params.maxDuration
  listing.status      = "LISTED"
  listing.listedAt    = event.block.timestamp

  listing.borrower      = null
  listing.rentalEndTime = null

  listing.save()
}

/**
 * Borrower rents a listing.
 * Updates RentalListing: adds borrower + endTime, status → RENTED.
 */
export function handleRented(event: RentedEvent): void {
  let id      = event.params.listingId.toString()
  let listing = RentalListing.load(id)
  if (listing == null) return

  listing.borrower      = event.params.borrower
  listing.rentalEndTime = event.params.endTime
  listing.status        = "RENTED"

  listing.save()
}

/**
 * NFT returned (early return or expiry reclaim).
 * Updates RentalListing: clears borrower, status → RETURNED.
 */
export function handleReturned(event: ReturnedEvent): void {
  let id      = event.params.listingId.toString()
  let listing = RentalListing.load(id)
  if (listing == null) return

  listing.status        = "RETURNED"
  listing.borrower      = null
  listing.rentalEndTime = null

  listing.save()
}

/**
 * Lender cancels listing before it was rented.
 * Updates RentalListing: status → CANCELLED.
 */
export function handleListingCancelled(event: ListingCancelledEvent): void {
  let id      = event.params.listingId.toString()
  let listing = RentalListing.load(id)
  if (listing == null) return

  listing.status = "CANCELLED"

  listing.save()
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. GuildTreasury handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * YIELD_MANAGER_ROLE injects AETH into the vault.
 * Creates an immutable TreasuryDeposit record.
 */
export function handleYieldInjected(event: YieldInjectedEvent): void {
  let id      = eventId(event.transaction.hash, event.logIndex)
  let deposit = new TreasuryDeposit(id)

  deposit.from        = event.params.from
  deposit.amount      = event.params.amount
  deposit.timestamp   = event.block.timestamp
  deposit.blockNumber = event.block.number

  deposit.save()
}
