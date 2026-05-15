// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC721Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

/**
 * @title HeroNFT
 * @notice ERC-721 hero NFT for AetherForge Arena. Deployed behind a UUPS proxy.
 * @dev    V1 tracks hero level and class. V2 will add skill trees (storage appended,
 *         never overwriting existing slots — see Architecture doc §4 Storage Layout).
 *
 * Upgrade path
 * ────────────
 * V1 → V2: deploy new implementation, call upgradeToAndCall() through the Timelock
 * proposal. The UPGRADER_ROLE (held by the Timelock) is the only account authorised
 * to trigger an upgrade, preventing unilateral admin upgrades.
 *
 * Storage layout (V1)
 * ───────────────────
 * Slot 0  (Initializable)  _initialized / _initializing
 * Slot 1  (ERC721)         _name
 * Slot 2  (ERC721)         _symbol
 * Slot 3  (ERC721)         _owners
 * Slot 4  (ERC721)         _balances
 * Slot 5  (ERC721)         _tokenApprovals
 * Slot 6  (ERC721)         _operatorApprovals
 * Slot 7  (AccessControl)  _roles
 * Slot 8  (this)           _nextTokenId
 * Slot 9  (this)           _heroAttributes
 * Slot 10 (this)           _baseTokenURI
 */
contract HeroNFT is Initializable, ERC721Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    // ─── Roles ────────────────────────────────────────────────────────────────

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ─── Storage (V1) ─────────────────────────────────────────────────────────

    /// @dev Hero classes: 0=Warrior, 1=Mage, 2=Rogue, 3=Paladin
    enum HeroClass {
        Warrior,
        Mage,
        Rogue,
        Paladin
    }

    struct HeroAttributes {
        uint8 level;
        HeroClass heroClass;
    }

    uint256 private _nextTokenId;
    mapping(uint256 => HeroAttributes) private _heroAttributes;
    string private _baseTokenURI;

    // ─── Errors ───────────────────────────────────────────────────────────────

    error HeroNFT__ZeroAddress();
    error HeroNFT__TokenNotFound(uint256 tokenId);
    error HeroNFT__MaxLevelReached(uint256 tokenId);

    // ─── Events ───────────────────────────────────────────────────────────────

    event HeroMinted(address indexed to, uint256 indexed tokenId, HeroClass heroClass);
    event HeroLevelUp(uint256 indexed tokenId, uint8 newLevel);

    // ─── Constructor (disabled for proxy) ─────────────────────────────────────

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ─── Initializer (replaces constructor for proxies) ───────────────────────

    /**
     * @param admin    Receives DEFAULT_ADMIN_ROLE (should be deployer, then transferred to Timelock).
     * @param upgrader Receives UPGRADER_ROLE (should be the Timelock from day 1).
     * @param baseURI  Base URI for token metadata.
     */
    function initialize(address admin, address upgrader, string memory baseURI) external initializer {
        if (admin == address(0) || upgrader == address(0)) revert HeroNFT__ZeroAddress();

        __ERC721_init("AetherForge Hero", "HERO");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, upgrader);

        _baseTokenURI = baseURI;
        _nextTokenId = 1; // start from 1, 0 is reserved as "null"
    }

    // ─── Minting ──────────────────────────────────────────────────────────────

    /**
     * @notice Mint a new hero NFT.
     * @param to        Recipient address.
     * @param heroClass Class of the hero (0=Warrior … 3=Paladin).
     * @return tokenId  The minted token ID.
     */
    function mintHero(address to, HeroClass heroClass) external onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        if (to == address(0)) revert HeroNFT__ZeroAddress();

        tokenId = _nextTokenId++;
        _heroAttributes[tokenId] = HeroAttributes({ level: 1, heroClass: heroClass });
        _safeMint(to, tokenId);

        emit HeroMinted(to, tokenId, heroClass);
    }

    // ─── Hero mechanics ───────────────────────────────────────────────────────

    /**
     * @notice Level up a hero by 1. Max level is 100.
     * @dev    Called by the ArenaEngine after a successful battle.
     *         Only MINTER_ROLE (ArenaEngine) can trigger level-ups.
     */
    function levelUp(uint256 tokenId) external onlyRole(MINTER_ROLE) {
        if (_ownerOf(tokenId) == address(0)) revert HeroNFT__TokenNotFound(tokenId);
        HeroAttributes storage attrs = _heroAttributes[tokenId];
        if (attrs.level >= 100) revert HeroNFT__MaxLevelReached(tokenId);

        attrs.level++;
        emit HeroLevelUp(tokenId, attrs.level);
    }

    // ─── View helpers ─────────────────────────────────────────────────────────

    function getHeroAttributes(uint256 tokenId) external view returns (HeroAttributes memory) {
        if (_ownerOf(tokenId) == address(0)) revert HeroNFT__TokenNotFound(tokenId);
        return _heroAttributes[tokenId];
    }

    function totalMinted() external view returns (uint256) {
        return _nextTokenId - 1;
    }

    // ─── OZ overrides ─────────────────────────────────────────────────────────

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Only UPGRADER_ROLE (the Timelock) can authorise an upgrade.
     *      This prevents the admin from unilaterally upgrading the contract.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
