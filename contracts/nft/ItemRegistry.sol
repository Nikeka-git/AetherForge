// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ItemRegistry
 * @notice ERC-1155 registry for AetherForge in-game items.
 *
 * Item categories
 * ───────────────
 * IDs 1–9 999        RESOURCE  - fungible crafting materials (Iron, Wood, Mana Crystal…)
 * IDs 10 000–19 999  EQUIPMENT - semi-fungible gear (Sword of Dawn, Dragon Armour…)
 *
 * Roles
 * ─────
 * DEFAULT_ADMIN_ROLE - grant / revoke roles (transferred to Timelock post-deploy)
 * MINTER_ROLE        - CraftingEngine, GuildTreasury: mint items
 * BURNER_ROLE        - CraftingEngine: burn items when used as recipe ingredients
 */
contract ItemRegistry is ERC1155, ERC1155Supply, AccessControl {
    // Constants

    uint256 public constant RESOURCE_ID_MAX = 9999;
    uint256 public constant EQUIPMENT_ID_MIN = 10_000;
    uint256 public constant EQUIPMENT_ID_MAX = 19_999;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Errors

    error ItemRegistry__ZeroAddress();
    error ItemRegistry__ZeroAmount();
    error ItemRegistry__InvalidItemId(uint256 id);
    error ItemRegistry__LengthMismatch();

    // Events

    event ResourceMinted(address indexed to, uint256 indexed id, uint256 amount);
    event EquipmentMinted(address indexed to, uint256 indexed id, uint256 amount);
    event ItemBurned(address indexed from, uint256 indexed id, uint256 amount);

    // Constructor

    /**
     * @param admin  Address that receives DEFAULT_ADMIN_ROLE.
     * @param uri_   Base URI for token metadata (e.g. "https://api.aetherforge.io/items/{id}.json").
     */
    constructor(address admin, string memory uri_) ERC1155(uri_) {
        if (admin == address(0)) revert ItemRegistry__ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // Minting

    /**
     * @notice Mint fungible resource tokens (IDs 1–9 999).
     * @param to     Recipient address.
     * @param id     Resource token ID (must be in [1, RESOURCE_ID_MAX]).
     * @param amount Number of tokens to mint.
     */
    function mintResource(address to, uint256 id, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ItemRegistry__ZeroAddress();
        if (amount == 0) revert ItemRegistry__ZeroAmount();
        if (id == 0 || id > RESOURCE_ID_MAX) revert ItemRegistry__InvalidItemId(id);

        _mint(to, id, amount, "");
        emit ResourceMinted(to, id, amount);
    }

    /**
     * @notice Mint equipment tokens (IDs 10 000–19 999).
     * @dev    Equipment is semi-fungible: amount > 1 is valid for identical copies
     *         (e.g. a common drop), but unique legendaries should use amount = 1.
     */
    function mintEquipment(address to, uint256 id, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ItemRegistry__ZeroAddress();
        if (amount == 0) revert ItemRegistry__ZeroAmount();
        if (id < EQUIPMENT_ID_MIN || id > EQUIPMENT_ID_MAX) revert ItemRegistry__InvalidItemId(id);

        _mint(to, id, amount, "");
        emit EquipmentMinted(to, id, amount);
    }

    /**
     * @notice Mint a batch of items in one transaction.
     * @dev    Caller must ensure all IDs are within valid ranges.
     */
    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts) external onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ItemRegistry__ZeroAddress();
        if (ids.length != amounts.length) revert ItemRegistry__LengthMismatch();
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            if ((id == 0 || id > RESOURCE_ID_MAX) && (id < EQUIPMENT_ID_MIN || id > EQUIPMENT_ID_MAX)) {
                revert ItemRegistry__InvalidItemId(id);
            }
            if (amounts[i] == 0) revert ItemRegistry__ZeroAmount();
        }

        _mintBatch(to, ids, amounts, "");
    }

    /**
     * @notice Burn a single item from an account (called by CraftingEngine during recipes).
     */
    function burn(address from, uint256 id, uint256 amount) external onlyRole(BURNER_ROLE) {
        if (from == address(0)) revert ItemRegistry__ZeroAddress();
        if (amount == 0) revert ItemRegistry__ZeroAmount();

        _burn(from, id, amount);
        emit ItemBurned(from, id, amount);
    }

    /**
     * @notice Burn multiple items in a single call (batch version used by CraftingEngine).
     * @dev    Using _burnBatch avoids N external calls inside a loop in CraftingEngine,
     *         eliminating the Slither calls-loop Medium finding while keeping gas lower.
     */
    function burnBatch(address from, uint256[] calldata ids, uint256[] calldata amounts)
        external
        onlyRole(BURNER_ROLE)
    {
        if (from == address(0)) revert ItemRegistry__ZeroAddress();
        if (ids.length != amounts.length) revert ItemRegistry__LengthMismatch();

        _burnBatch(from, ids, amounts);
    }

    // View helpers

    function isResource(uint256 id) public pure returns (bool) {
        return id >= 1 && id <= RESOURCE_ID_MAX;
    }

    function isEquipment(uint256 id) public pure returns (bool) {
        return id >= EQUIPMENT_ID_MIN && id <= EQUIPMENT_ID_MAX;
    }

    // OZ overrides

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
