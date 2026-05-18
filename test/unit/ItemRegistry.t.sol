// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ItemRegistry } from "../../contracts/nft/ItemRegistry.sol";

/**
 * @title ItemRegistryTest
 * @notice 5 unit tests for ItemRegistry.
 *         Run with: forge test --match-contract ItemRegistryTest -vv
 */
contract ItemRegistryTest is Test {
    // Constants

    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 constant IRON_ID = 1; // resource
    uint256 constant WOOD_ID = 2; // resource
    uint256 constant SWORD_ID = 10_000; // equipment

    // Actors

    address admin = makeAddr("admin");
    address minter = makeAddr("minter");
    address burner = makeAddr("burner");

    // Use address(this) as recipient — the test contract implements ERC1155 receiver hooks below
    address alice = address(this);

    // System under test

    ItemRegistry registry;

    function setUp() public {
        vm.startPrank(admin);
        registry = new ItemRegistry(admin, "https://api.aetherforge.io/items/{id}.json");
        registry.grantRole(MINTER_ROLE, minter);
        registry.grantRole(BURNER_ROLE, burner);
        vm.stopPrank();
    }

    // ─── ERC-1155 receiver hooks ───────────────────────────────────────────────
    // Required so that address(this) can receive ERC-1155 tokens via _safeMint.

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    // ─── Test 1: mintResource credits the correct balance ─────────────────────

    function test_MintResourceCreditsBalance() public {
        vm.prank(minter);
        registry.mintResource(alice, IRON_ID, 100);

        assertEq(registry.balanceOf(alice, IRON_ID), 100, "iron balance wrong");
        assertEq(registry.totalSupply(IRON_ID), 100, "iron total supply wrong");
    }

    // ─── Test 2: mintEquipment credits the correct balance ────────────────────

    function test_MintEquipmentCreditsBalance() public {
        vm.prank(minter);
        registry.mintEquipment(alice, SWORD_ID, 1);

        assertEq(registry.balanceOf(alice, SWORD_ID), 1, "sword balance wrong");
    }

    // ─── Test 3: Invalid item ID reverts ──────────────────────────────────────

    function test_InvalidResourceIdReverts() public {
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSignature("ItemRegistry__InvalidItemId(uint256)", 0));
        registry.mintResource(alice, 0, 10);
    }

    // ─── Test 4: BURNER_ROLE can burn items ───────────────────────────────────

    function test_BurnerCanBurnItems() public {
        vm.prank(minter);
        registry.mintResource(alice, IRON_ID, 50);

        vm.prank(burner);
        registry.burn(alice, IRON_ID, 30);

        assertEq(registry.balanceOf(alice, IRON_ID), 20, "balance after burn wrong");
        assertEq(registry.totalSupply(IRON_ID), 20, "total supply after burn wrong");
    }

    // ─── Test 5: mintBatch mints multiple items in one call ───────────────────

    function test_MintBatchMintsMultipleItems() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = IRON_ID;
        ids[1] = WOOD_ID;
        ids[2] = SWORD_ID;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 1;

        vm.prank(minter);
        registry.mintBatch(alice, ids, amounts);

        assertEq(registry.balanceOf(alice, IRON_ID), 100, "iron batch balance wrong");
        assertEq(registry.balanceOf(alice, WOOD_ID), 200, "wood batch balance wrong");
        assertEq(registry.balanceOf(alice, SWORD_ID), 1, "sword batch balance wrong");
    }
}
