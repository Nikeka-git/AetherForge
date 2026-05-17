// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { CraftingEngine } from "../../contracts/crafting/CraftingEngine.sol";
import { AethToken } from "../../contracts/token/AethToken.sol";
import { ItemRegistry } from "../../contracts/nft/ItemRegistry.sol";
import { ChainlinkPriceAdapter } from "../../contracts/oracle/ChainlinkPriceAdapter.sol";
import { MockAggregator } from "../../contracts/oracle/MockAggregator.sol";

/**
 * @title CraftingEngineTest
 * @notice Unit tests for CraftingEngine.sol.
 *
 * Run:
 *   forge test --match-contract CraftingEngineTest -vv
 *
 * Coverage target: every public/external function including all revert paths.
 */
contract CraftingEngineTest is Test {
    // Contracts under test

    CraftingEngine internal engine;
    AethToken internal aeth;
    ItemRegistry internal items;
    ChainlinkPriceAdapter internal adapter;
    MockAggregator internal mockFeed;

    // Actors

    address internal admin = makeAddr("admin");
    address internal player = makeAddr("player");
    address internal treasury = makeAddr("treasury");
    address internal attacker = makeAddr("attacker");

    // Item IDs

    uint256 constant IRON_ORE = 1;
    uint256 constant MANA_CRYSTAL = 3;
    uint256 constant FLAMING_SWORD = 10_000; // equipment id

    // Oracle: AETH price = $2.00 in 8-decimal Chainlink format.
    int256 constant AETH_PRICE_8DEC = 2e8;

    // Setup

    function setUp() public {
        vm.startPrank(admin);

        // Deploy token + registry.
        aeth = new AethToken(admin);
        items = new ItemRegistry(admin, "https://api.aetherforge.io/items/{id}.json");

        // Deploy mock oracle: AETH = $2, fresh price.
        mockFeed = new MockAggregator(AETH_PRICE_8DEC, 8, "AETH / USD");

        adapter = new ChainlinkPriceAdapter(address(mockFeed), 3600, admin);

        // Deploy engine.
        engine = new CraftingEngine(
            address(aeth),
            address(items),
            address(adapter),
            treasury,
            500, // 5 % treasury fee
            admin
        );

        // Grant roles: engine needs MINTER + BURNER on both token & registry.
        aeth.grantRole(aeth.MINTER_ROLE(), address(engine));
        aeth.grantRole(aeth.BURNER_ROLE(), address(engine));
        items.grantRole(items.MINTER_ROLE(), address(engine));
        items.grantRole(items.BURNER_ROLE(), address(engine));

        // Admin also needs MINTER_ROLE / BURNER_ROLE to seed and manipulate
        // player balances directly in tests (setUp seeding, burn-to-drain tests).
        aeth.grantRole(aeth.MINTER_ROLE(), admin);
        items.grantRole(items.MINTER_ROLE(), admin);
        items.grantRole(items.BURNER_ROLE(), admin);

        vm.stopPrank();

        // Give player some items and AETH.
        vm.startPrank(admin);
        items.mintResource(player, IRON_ORE, 10);
        items.mintResource(player, MANA_CRYSTAL, 10);
        aeth.mint(player, 1000e18);
        vm.stopPrank();

        // Player approves engine for AETH.
        vm.prank(player);
        aeth.approve(address(engine), type(uint256).max);
    }

    // Helpers

    /**
     * @dev Add a standard recipe: 2x IRON_ORE + 1x MANA_CRYSTAL + $50 USD -> 1x FLAMING_SWORD.
     *      usdCost = 50e8 (Chainlink 8-dec); at $2/AETH -> costs 25 AETH.
     */
    function _addSwordRecipe() internal returns (uint256 recipeId) {
        uint256[] memory ids = new uint256[](2);
        ids[0] = IRON_ORE;
        ids[1] = MANA_CRYSTAL;

        uint256[] memory amts = new uint256[](2);
        amts[0] = 2;
        amts[1] = 1;

        vm.prank(admin);
        recipeId = engine.addRecipe(ids, amts, 50e8, FLAMING_SWORD, 1);
    }

    // addRecipe

    function test_addRecipe_SuccessByAdmin() public {
        uint256 recipeId = _addSwordRecipe();
        assertEq(recipeId, 0);

        CraftingEngine.Recipe memory r = engine.getRecipe(recipeId);
        assertTrue(r.active);
        assertEq(r.outputItemId, FLAMING_SWORD);
        assertEq(r.usdCost, 50e8);
        assertEq(r.outputAmount, 1);
        assertEq(r.ingredientIds.length, 2);
    }

    function test_addRecipe_RevertsForNonAdmin() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amts = new uint256[](1);
        ids[0] = IRON_ORE;
        amts[0] = 1;

        vm.prank(attacker);
        vm.expectRevert();
        engine.addRecipe(ids, amts, 0, FLAMING_SWORD, 1);
    }

    function test_addRecipe_RevertsOnLengthMismatch() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amts = new uint256[](1);

        vm.prank(admin);
        vm.expectRevert(CraftingEngine.CraftingEngine__InvalidRecipe_LengthMismatch.selector);
        engine.addRecipe(ids, amts, 0, FLAMING_SWORD, 1);
    }

    function test_addRecipe_RevertsOnZeroOutputAmount() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amts = new uint256[](1);
        ids[0] = IRON_ORE;
        amts[0] = 1;

        vm.prank(admin);
        vm.expectRevert(CraftingEngine.CraftingEngine__InvalidRecipe_ZeroOutput.selector);
        engine.addRecipe(ids, amts, 0, FLAMING_SWORD, 0);
    }

    // removeRecipe

    function test_removeRecipe_Success() public {
        uint256 id = _addSwordRecipe();

        vm.prank(admin);
        engine.removeRecipe(id);

        assertFalse(engine.getRecipe(id).active);
    }

    function test_removeRecipe_RevertsOnAlreadyInactive() public {
        uint256 id = _addSwordRecipe();

        vm.prank(admin);
        engine.removeRecipe(id);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(CraftingEngine.CraftingEngine__RecipeInactive.selector, id));
        engine.removeRecipe(id);
    }

    // setRecipeCost

    function test_setRecipeCost_UpdatesValue() public {
        uint256 id = _addSwordRecipe();

        vm.prank(admin);
        engine.setRecipeCost(id, 100e8);

        assertEq(engine.getRecipe(id).usdCost, 100e8);
    }

    function test_setRecipeCost_RevertsForNonAdmin() public {
        uint256 id = _addSwordRecipe();

        vm.prank(attacker);
        vm.expectRevert();
        engine.setRecipeCost(id, 100e8);
    }

    // craft - happy path

    function test_craft_HappyPath_MintsOutputAndBurnsInputs() public {
        uint256 id = _addSwordRecipe();

        uint256 playerAethBefore = aeth.balanceOf(player);
        uint256 playerIronBefore = items.balanceOf(player, IRON_ORE);
        uint256 playerManaBefore = items.balanceOf(player, MANA_CRYSTAL);
        uint256 treasuryAethBefore = aeth.balanceOf(treasury);

        vm.prank(player);
        engine.craft(id);

        // Output minted.
        assertEq(items.balanceOf(player, FLAMING_SWORD), 1);

        // Ingredients burned.
        assertEq(items.balanceOf(player, IRON_ORE), playerIronBefore - 2);
        assertEq(items.balanceOf(player, MANA_CRYSTAL), playerManaBefore - 1);

        // AETH: at $2/AETH, $50 cost = 25 AETH; 5 % fee = 1.25 AETH to treasury.
        uint256 expectedTotal = 25e18;
        uint256 expectedFee = (expectedTotal * 500) / 10_000; // 1.25 AETH

        assertEq(aeth.balanceOf(player), playerAethBefore - expectedTotal);
        assertEq(aeth.balanceOf(treasury), treasuryAethBefore + expectedFee);
    }

    function test_craft_FreeRecipe_NoAethCharged() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amts = new uint256[](1);
        ids[0] = IRON_ORE;
        amts[0] = 1;

        vm.prank(admin);
        uint256 freeRecipeId = engine.addRecipe(ids, amts, 0, MANA_CRYSTAL, 5);

        uint256 aethBefore = aeth.balanceOf(player);

        vm.prank(player);
        engine.craft(freeRecipeId);

        assertEq(aeth.balanceOf(player), aethBefore); // no AETH charged
        assertEq(items.balanceOf(player, MANA_CRYSTAL), 10 + 5); // 5 minted
    }

    // craft — revert paths

    function test_craft_RevertsOnUnknownRecipe() public {
        vm.prank(player);
        vm.expectRevert(abi.encodeWithSelector(CraftingEngine.CraftingEngine__RecipeInactive.selector, 99));
        engine.craft(99);
    }

    function test_craft_RevertsOnRemovedRecipe() public {
        uint256 id = _addSwordRecipe();

        vm.prank(admin);
        engine.removeRecipe(id);

        vm.prank(player);
        vm.expectRevert(abi.encodeWithSelector(CraftingEngine.CraftingEngine__RecipeInactive.selector, id));
        engine.craft(id);
    }

    function test_craft_RevertsOnInsufficientIngredient() public {
        uint256 id = _addSwordRecipe();

        // Burn most of player's iron so they only have 1 (need 2).
        vm.prank(admin);
        items.burn(player, IRON_ORE, 9); // leaves 1

        vm.prank(player);
        vm.expectRevert(
            abi.encodeWithSelector(CraftingEngine.CraftingEngine__InsufficientIngredient.selector, IRON_ORE, 2, 1)
        );
        engine.craft(id);
    }

    function test_craft_RevertsOnInsufficientAethAllowance() public {
        uint256 id = _addSwordRecipe();

        // Reset approval to zero.
        vm.prank(player);
        aeth.approve(address(engine), 0);

        vm.prank(player);
        vm.expectRevert();
        engine.craft(id);
    }

    function test_craft_RevertsWhenPaused() public {
        uint256 id = _addSwordRecipe();

        vm.prank(admin);
        engine.pause();

        vm.prank(player);
        vm.expectRevert();
        engine.craft(id);
    }

    // Pause / unpause

    function test_pause_RevertsForNonPauser() public {
        vm.prank(attacker);
        vm.expectRevert();
        engine.pause();
    }

    function test_unpause_ResumesNormalOperation() public {
        uint256 id = _addSwordRecipe();

        vm.prank(admin);
        engine.pause();

        vm.prank(admin);
        engine.unpause();

        vm.prank(player);
        engine.craft(id); // must not revert
        assertEq(items.balanceOf(player, FLAMING_SWORD), 1);
    }

    // Treasury fee

    function test_setTreasuryFeeBps_UpdatesValue() public {
        vm.prank(admin);
        engine.setTreasuryFeeBps(1000); // 10 %
        assertEq(engine.treasuryFeeBps(), 1000);
    }

    function test_setTreasuryFeeBps_RevertsAboveMax() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(CraftingEngine.CraftingEngine__FeeTooHigh.selector, 2001));
        engine.setTreasuryFeeBps(2001);
    }

    // previewAethCost

    function test_previewAethCost_ReturnsCorrectAmount() public {
        uint256 id = _addSwordRecipe();
        // usdCost = 50e8, aethPrice = 2e8 → expected = 25e18
        assertEq(engine.previewAethCost(id), 25e18);
    }

    function test_previewAethCost_ChangeWithOraclePrice() public {
        uint256 id = _addSwordRecipe();

        // Drop AETH price to $1.
        mockFeed.setAnswer(1e8);

        // Same USD cost now requires 50 AETH.
        assertEq(engine.previewAethCost(id), 50e18);
    }

    // Fuzz

    /**
     * @dev Fuzz: treasury always receives exactly (aethCost * feeBps / 10_000).
     */
    function testFuzz_craft_TreasuryReceivesCorrectFee(uint256 aethPrice, uint256 feeBps) public {
        // Bound inputs to sensible ranges.
        // Price: $0.01 to $10_000 in 8-dec Chainlink format.
        aethPrice = bound(aethPrice, 1e6, 10_000e8);
        feeBps = bound(feeBps, 0, 2000);

        mockFeed.setAnswer(int256(aethPrice));

        vm.prank(admin);
        engine.setTreasuryFeeBps(feeBps);

        // Recipe: 1x IRON_ORE + $10 USD cost.
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amts = new uint256[](1);
        ids[0] = IRON_ORE;
        amts[0] = 1;

        vm.prank(admin);
        uint256 rid = engine.addRecipe(ids, amts, 10e8, MANA_CRYSTAL, 1);

        uint256 expectedTotal = (10e8 * 1e18) / aethPrice;
        uint256 expectedFee = (expectedTotal * feeBps) / 10_000;

        // Give player enough iron and AETH.
        vm.prank(admin);
        items.mintResource(player, IRON_ORE, 5);
        vm.prank(admin);
        aeth.mint(player, expectedTotal);

        uint256 treasuryBefore = aeth.balanceOf(treasury);

        vm.prank(player);
        engine.craft(rid);

        assertEq(aeth.balanceOf(treasury), treasuryBefore + expectedFee);
    }

    /**
     * @dev Fuzz: previewAethCost always equals actual AETH deducted.
     */
    function testFuzz_craft_ActualCostMatchesPreview(uint256 aethPrice) public {
        aethPrice = bound(aethPrice, 1e6, 10_000e8);
        mockFeed.setAnswer(int256(aethPrice));

        uint256 id = _addSwordRecipe();

        uint256 preview = engine.previewAethCost(id);

        // Give player enough resources + AETH.
        vm.prank(admin);
        items.mintResource(player, IRON_ORE, 5);
        vm.prank(admin);
        aeth.mint(player, preview);

        uint256 aethBefore = aeth.balanceOf(player);

        vm.prank(player);
        engine.craft(id);

        assertEq(aethBefore - aeth.balanceOf(player), preview);
    }
}
