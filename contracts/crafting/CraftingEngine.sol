// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AethToken } from "../token/AethToken.sol";
import { ItemRegistry } from "../nft/ItemRegistry.sol";
import { ChainlinkPriceAdapter } from "../oracle/ChainlinkPriceAdapter.sol";

/**
 * @title CraftingEngine
 * @notice Converts raw resources (ERC-1155) + AETH (ERC-20) into equipment via recipes.
 *
 * Flow for a player
 * ─────────────────
 * 1. Player approves CraftingEngine to spend their AETH (ERC-20 allowance).
 * 2. Player calls craft(recipeId).
 * 3. Engine checks they hold all required resources and enough AETH.
 * 4. Resources are burned from the player's balance (via ItemRegistry BURNER_ROLE).
 * 5. AETH cost is burned from the player (via AethToken BURNER_ROLE).
 *    A treasury fee (TREASURY_FEE_BPS bps of the AETH cost) is sent to GuildTreasury
 *    before burning, so the player pays cost + fee in total.
 * 6. Output item is minted to the player (via ItemRegistry MINTER_ROLE).
 *
 * AETH cost — oracle pricing
 * ──────────────────────────
 * Each recipe stores its cost in USD (8-decimal Chainlink format, e.g. 50e8 = $50).
 * At craft time the engine queries ChainlinkPriceAdapter for the AETH/USD price and
 * derives the AETH amount on-the-fly:
 *
 *   aethAmount = usdCost * 1e18 / aethPriceInUsd
 *
 * Example: usdCost = 50e8, aethPrice = 2e8 ($2/AETH) -> aethAmount = 25e18 (25 AETH).
 *
 * Recipes that set usdCost = 0 are free (no AETH charge).
 *
 * Design patterns
 * ───────────────
 * - Checks-Effects-Interactions  : all state mutations before external calls.
 * - ReentrancyGuard              : on craft().
 * - Pausable / Circuit Breaker   : emergency pause without upgrade.
 * - Access Control / Role-based  : ADMIN_ROLE for recipe management, PAUSER_ROLE.
 * - Oracle Adapter               : price read through ChainlinkPriceAdapter interface.
 *
 * Roles
 * ─────
 * DEFAULT_ADMIN_ROLE - grant / revoke roles (transferred to Timelock post-deploy).
 * ADMIN_ROLE         - add / remove / update recipes and set treasury fee.
 * PAUSER_ROLE        - pause / unpause in emergencies.
 */
contract CraftingEngine is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Roles

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Constants

    /// @notice Basis-points denominator (100 % = 10 000 bps).
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Maximum treasury fee: 20 % (2 000 bps).
    uint256 public constant MAX_TREASURY_FEE_BPS = 2000;

    /// @notice Maximum ingredients per recipe (gas guard).
    uint256 public constant MAX_INGREDIENTS = 10;

    // Types

    /**
     * @param ingredientIds  Item IDs consumed by the recipe.
     * @param ingredientAmts Quantities matching ingredientIds.
     * @param usdCost        USD cost in 8-decimal Chainlink format (0 = free).
     * @param outputItemId   Item ID produced.
     * @param outputAmount   Quantity produced per craft.
     * @param active         False = recipe removed / disabled.
     */
    struct Recipe {
        uint256[] ingredientIds;
        uint256[] ingredientAmts;
        uint256 usdCost;
        uint256 outputItemId;
        uint256 outputAmount;
        bool active;
    }

    // State

    AethToken public immutable aethToken;
    ItemRegistry public immutable itemRegistry;
    ChainlinkPriceAdapter public immutable priceAdapter;

    /// @notice Address that receives the treasury fee portion of every craft.
    address public treasury;

    /// @notice Fee taken by the treasury from each craft's AETH cost, in bps.
    uint256 public treasuryFeeBps;

    /// @notice recipeId → Recipe.
    mapping(uint256 => Recipe) private _recipes;

    /// @notice Auto-incrementing recipe ID counter.
    uint256 public nextRecipeId;

    // Errors

    error CraftingEngine__ZeroAddress();
    error CraftingEngine__UnknownRecipe(uint256 recipeId);
    error CraftingEngine__RecipeInactive(uint256 recipeId);
    error CraftingEngine__InsufficientIngredient(uint256 itemId, uint256 required, uint256 held);
    error CraftingEngine__InsufficientAeth(uint256 required, uint256 allowance);
    error CraftingEngine__InvalidRecipe_LengthMismatch();
    error CraftingEngine__InvalidRecipe_TooManyIngredients();
    error CraftingEngine__InvalidRecipe_ZeroOutput();
    error CraftingEngine__FeeTooHigh(uint256 bps);
    error CraftingEngine__ZeroPriceFromOracle();

    // Events

    event RecipeAdded(uint256 indexed recipeId, uint256 outputItemId, uint256 usdCost);
    event RecipeRemoved(uint256 indexed recipeId);
    event RecipeCostUpdated(uint256 indexed recipeId, uint256 oldUsdCost, uint256 newUsdCost);
    event ItemCrafted(
        address indexed player,
        uint256 indexed recipeId,
        uint256 indexed outputItemId,
        uint256 outputAmount,
        uint256 aethCharged
    );
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event TreasuryFeeBpsUpdated(uint256 oldBps, uint256 newBps);

    // Constructor

    /**
     * @param aethToken_     AethToken contract (must grant this contract BURNER_ROLE).
     * @param itemRegistry_  ItemRegistry contract (must grant this contract MINTER_ROLE
     *                       and BURNER_ROLE).
     * @param priceAdapter_  ChainlinkPriceAdapter for AETH/USD price.
     * @param treasury_      Initial treasury address (GuildTreasury).
     * @param treasuryFeeBps_ Initial treasury fee in bps (e.g. 500 = 5 %).
     * @param admin          Receives DEFAULT_ADMIN_ROLE (transfer to Timelock post-deploy).
     */
    constructor(
        address aethToken_,
        address itemRegistry_,
        address priceAdapter_,
        address treasury_,
        uint256 treasuryFeeBps_,
        address admin
    ) {
        if (aethToken_ == address(0)) revert CraftingEngine__ZeroAddress();
        if (itemRegistry_ == address(0)) revert CraftingEngine__ZeroAddress();
        if (priceAdapter_ == address(0)) revert CraftingEngine__ZeroAddress();
        if (treasury_ == address(0)) revert CraftingEngine__ZeroAddress();
        if (admin == address(0)) revert CraftingEngine__ZeroAddress();
        if (treasuryFeeBps_ > MAX_TREASURY_FEE_BPS) revert CraftingEngine__FeeTooHigh(treasuryFeeBps_);

        aethToken = AethToken(aethToken_);
        itemRegistry = ItemRegistry(itemRegistry_);
        priceAdapter = ChainlinkPriceAdapter(priceAdapter_);
        treasury = treasury_;
        treasuryFeeBps = treasuryFeeBps_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    // Core: craft

    /**
     * @notice Craft an item using a recipe.
     *
     * @dev CEI order:
     *   CHECKS   - recipe exists & active, player holds all ingredients and AETH allowance.
     *   EFFECTS  - (none: no CraftingEngine state changes mid-function).
     *   INTERACTIONS - burn ingredients, charge AETH, mint output.
     *
     * ReentrancyGuard protects against ERC-1155 reentrancy via onERC1155Received.
     *
     * @param recipeId Recipe to execute.
     */
    function craft(uint256 recipeId) external nonReentrant whenNotPaused {
        Recipe storage recipe = _recipes[recipeId];

        // CHECKS

        if (!recipe.active) {
            // Catches both "never existed" (active=false default) and removed recipes.
            revert CraftingEngine__RecipeInactive(recipeId);
        }

        // Verify ingredient balances — one batched external call instead of N calls in a loop
        // (eliminates Slither calls-loop Medium finding).
        uint256 len = recipe.ingredientIds.length;
        {
            address[] memory accs = new address[](len);
            for (uint256 i = 0; i < len; i++) {
                accs[i] = msg.sender;
            }
            uint256[] memory held = itemRegistry.balanceOfBatch(accs, recipe.ingredientIds);
            for (uint256 i = 0; i < len; i++) {
                if (held[i] < recipe.ingredientAmts[i]) {
                    revert CraftingEngine__InsufficientIngredient(
                        recipe.ingredientIds[i], recipe.ingredientAmts[i], held[i]
                    );
                }
            }
        }

        // Compute AETH cost via oracle (0 if recipe is free).
        uint256 aethCost = _computeAethCost(recipe.usdCost);

        // Verify AETH allowance (player must have approved us for at least aethCost).
        if (aethCost > 0) {
            uint256 allowance = IERC20(address(aethToken)).allowance(msg.sender, address(this));
            if (allowance < aethCost) {
                revert CraftingEngine__InsufficientAeth(aethCost, allowance);
            }
        }

        // INTERACTIONS

        // 1. Burn all ingredients in a single batched call (no external calls in a loop).
        itemRegistry.burnBatch(msg.sender, recipe.ingredientIds, recipe.ingredientAmts);

        // 2. Charge AETH: split into treasury fee + burn.
        if (aethCost > 0) {
            uint256 feeAmount = (aethCost * treasuryFeeBps) / BPS_DENOMINATOR;
            uint256 burnAmount = aethCost - feeAmount;

            if (feeAmount > 0) {
                // Transfer fee portion to GuildTreasury (stays in the ecosystem).
                IERC20(address(aethToken)).safeTransferFrom(msg.sender, treasury, feeAmount);
            }
            if (burnAmount > 0) {
                // Burn the rest via AethToken BURNER_ROLE.
                // We pull from msg.sender first via transferFrom, then burn from this contract.
                // Using safeTransferFrom → burn pattern avoids the caller needing to approve
                // the burn path separately.
                IERC20(address(aethToken)).safeTransferFrom(msg.sender, address(this), burnAmount);
                aethToken.burn(address(this), burnAmount);
            }
        }

        // 3. Mint output item to player.
        if (itemRegistry.isResource(recipe.outputItemId)) {
            itemRegistry.mintResource(msg.sender, recipe.outputItemId, recipe.outputAmount);
        } else {
            itemRegistry.mintEquipment(msg.sender, recipe.outputItemId, recipe.outputAmount);
        }

        emit ItemCrafted(msg.sender, recipeId, recipe.outputItemId, recipe.outputAmount, aethCost);
    }

    // Internal helpers

    /**
     * @dev Convert a USD cost (8-decimal Chainlink format) to an AETH amount (18 decimals).
     *      Returns 0 when usdCost is 0 (free recipe — no oracle call needed).
     *
     *      Formula: aethAmount = usdCost * 1e18 / aethPriceInUsd
     *
     *      Where aethPriceInUsd is returned by the price adapter in 8-decimal format.
     *      Example: usdCost = 50e8, aethPrice = 2e8 -> aethAmount = 25e18 (25 AETH).
     */
    function _computeAethCost(uint256 usdCost) internal view returns (uint256) {
        if (usdCost == 0) return 0;

        uint256 aethPriceInUsd = priceAdapter.latestPriceUint(); // 8-decimal Chainlink price
        if (aethPriceInUsd == 0) revert CraftingEngine__ZeroPriceFromOracle();

        // usdCost (8 dec) * 1e18 / aethPriceInUsd (8 dec) = AETH amount (18 dec).
        return (usdCost * 1e18) / aethPriceInUsd;
    }

    // Admin: recipe management  (controlled by Timelock via governance)

    /**
     * @notice Add a new crafting recipe.
     * @return recipeId  The assigned recipe ID.
     */
    function addRecipe(
        uint256[] calldata ingredientIds,
        uint256[] calldata ingredientAmts,
        uint256 usdCost,
        uint256 outputItemId,
        uint256 outputAmount
    ) external onlyRole(ADMIN_ROLE) returns (uint256 recipeId) {
        if (ingredientIds.length != ingredientAmts.length) {
            revert CraftingEngine__InvalidRecipe_LengthMismatch();
        }
        if (ingredientIds.length > MAX_INGREDIENTS) revert CraftingEngine__InvalidRecipe_TooManyIngredients();
        if (outputAmount == 0) revert CraftingEngine__InvalidRecipe_ZeroOutput();

        recipeId = nextRecipeId++;

        Recipe storage r = _recipes[recipeId];
        r.ingredientIds = ingredientIds;
        r.ingredientAmts = ingredientAmts;
        r.usdCost = usdCost;
        r.outputItemId = outputItemId;
        r.outputAmount = outputAmount;
        r.active = true;

        emit RecipeAdded(recipeId, outputItemId, usdCost);
    }

    /**
     * @notice Disable a recipe (soft-delete; recipeId is never reused).
     */
    function removeRecipe(uint256 recipeId) external onlyRole(ADMIN_ROLE) {
        if (!_recipes[recipeId].active) revert CraftingEngine__RecipeInactive(recipeId);
        _recipes[recipeId].active = false;
        emit RecipeRemoved(recipeId);
    }

    /**
     * @notice Update the USD cost of an existing active recipe.
     * @dev    Callable via a governance proposal routed through the Timelock.
     */
    function setRecipeCost(uint256 recipeId, uint256 newUsdCost) external onlyRole(ADMIN_ROLE) {
        if (!_recipes[recipeId].active) revert CraftingEngine__RecipeInactive(recipeId);
        uint256 old = _recipes[recipeId].usdCost;
        _recipes[recipeId].usdCost = newUsdCost;
        emit RecipeCostUpdated(recipeId, old, newUsdCost);
    }

    // Admin: treasury & fee

    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert CraftingEngine__ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function setTreasuryFeeBps(uint256 newBps) external onlyRole(ADMIN_ROLE) {
        if (newBps > MAX_TREASURY_FEE_BPS) revert CraftingEngine__FeeTooHigh(newBps);
        uint256 old = treasuryFeeBps;
        treasuryFeeBps = newBps;
        emit TreasuryFeeBpsUpdated(old, newBps);
    }

    // Admin: circuit breaker

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Views

    /**
     * @notice Returns the full Recipe struct for a given recipeId.
     */
    function getRecipe(uint256 recipeId) external view returns (Recipe memory) {
        return _recipes[recipeId];
    }

    /**
     * @notice Preview how much AETH a craft will cost at the current oracle price.
     * @dev    Useful for frontend approval flow: call this, then approve, then craft.
     */
    function previewAethCost(uint256 recipeId) external view returns (uint256) {
        Recipe storage recipe = _recipes[recipeId];
        if (!recipe.active) revert CraftingEngine__RecipeInactive(recipeId);
        return _computeAethCost(recipe.usdCost);
    }
}
