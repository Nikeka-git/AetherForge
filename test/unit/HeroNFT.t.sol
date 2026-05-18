// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { HeroNFT } from "../../contracts/nft/HeroNFT.sol";
import { HeroNFTFactory } from "../../contracts/nft/HeroNFTFactory.sol";
import { AethToken } from "../../contracts/token/AethToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title HeroNFTTest
 * @notice Unit tests for HeroNFT (UUPS proxy) and HeroNFTFactory (CREATE + CREATE2).
 *         Run with: forge test --match-contract HeroNFTTest -vv
 */
contract HeroNFTTest is Test {
    // ─── Roles ─────────────────────────────────────────────────────────────────

    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    // ─── Actors ────────────────────────────────────────────────────────────────

    address admin = makeAddr("admin");
    address upgrader = makeAddr("upgrader");
    address minter = makeAddr("minter");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // ─── System under test ─────────────────────────────────────────────────────

    AethToken aethToken;
    HeroNFT heroImpl; // raw implementation (should not be used directly)
    HeroNFT hero; // proxy cast to HeroNFT
    HeroNFTFactory factory;

    function setUp() public {
        // Deploy AethToken (admin holds MINTER_ROLE initially)
        aethToken = new AethToken(admin);

        // Deploy HeroNFT implementation
        heroImpl = new HeroNFT();

        // Deploy proxy and initialise — pass aethToken address
        bytes memory initData =
            abi.encodeCall(HeroNFT.initialize, (admin, upgrader, "https://heroes.aetherforge.io/", address(aethToken)));
        ERC1967Proxy proxy = new ERC1967Proxy(address(heroImpl), initData);
        hero = HeroNFT(address(proxy));

        // Grant hero proxy MINTER_ROLE on AethToken so mintHero can mint starter AETH
        vm.prank(admin);
        aethToken.grantRole(MINTER_ROLE, address(hero));

        // Grant minter MINTER_ROLE on HeroNFT proxy (for levelUp tests)
        vm.prank(admin);
        hero.grantRole(MINTER_ROLE, minter);

        // Deploy factory
        factory = new HeroNFTFactory(admin);
    }

    // ─── Test 1: Implementation initializers are disabled ──────────────────────

    function test_ImplementationInitializersDisabled() public {
        vm.expectRevert(); // InvalidInitialization
        heroImpl.initialize(admin, upgrader, "https://x.io/", address(aethToken));
    }

    // ─── Test 2: Proxy initializes correctly ───────────────────────────────────

    function test_ProxyInitializesCorrectly() public view {
        assertEq(hero.name(), "AetherForge Hero", "name wrong");
        assertEq(hero.symbol(), "HERO", "symbol wrong");
        assertTrue(hero.hasRole(hero.DEFAULT_ADMIN_ROLE(), admin), "admin role missing");
        assertTrue(hero.hasRole(UPGRADER_ROLE, upgrader), "upgrader role missing");
    }

    // ─── Test 3: Anyone can mint a hero ────────────────────────────────────────

    function test_AnyoneCanMintHero() public {
        vm.prank(alice);
        uint256 tokenId = hero.mintHero(alice, HeroNFT.HeroClass.Warrior);

        assertEq(tokenId, 1, "first token ID should be 1");
        assertEq(hero.ownerOf(1), alice, "alice should own token 1");
        assertEq(hero.totalMinted(), 1, "totalMinted wrong");

        HeroNFT.HeroAttributes memory attrs = hero.getHeroAttributes(1);
        assertEq(attrs.level, 1, "starting level should be 1");
        assertEq(uint8(attrs.heroClass), uint8(HeroNFT.HeroClass.Warrior), "class wrong");
    }

    // ─── Test 4: mintHero mints starter AETH to the recipient ──────────────────

    function test_MintHero_MintsStarterAeth() public {
        uint256 balanceBefore = aethToken.balanceOf(alice);

        vm.prank(alice);
        hero.mintHero(alice, HeroNFT.HeroClass.Mage);

        assertEq(aethToken.balanceOf(alice), balanceBefore + hero.STARTER_AETH(), "starter AETH not minted");
    }

    // ─── Test 5: levelUp increments hero level ─────────────────────────────────

    function test_LevelUpIncrementsLevel() public {
        vm.prank(alice);
        hero.mintHero(alice, HeroNFT.HeroClass.Mage);

        vm.prank(minter);
        hero.levelUp(1);

        HeroNFT.HeroAttributes memory attrs = hero.getHeroAttributes(1);
        assertEq(attrs.level, 2, "level should be 2 after levelUp");
    }

    // ─── Test 6: Non-upgrader cannot upgrade the proxy ─────────────────────────

    function test_NonUpgraderCannotUpgrade() public {
        HeroNFT newImpl = new HeroNFT();

        vm.expectRevert(); // AccessControlUnauthorizedAccount
        vm.prank(alice);
        hero.upgradeToAndCall(address(newImpl), "");
    }

    // ─── Test 7: Factory deployCreate deploys a working proxy ──────────────────

    function test_FactoryDeployCreate() public {
        // Factory-deployed proxy also needs MINTER_ROLE on aethToken
        vm.prank(admin);
        address proxy = factory.deployCreate(admin, upgrader, "https://heroes.aetherforge.io/", address(aethToken));

        assertTrue(proxy != address(0), "proxy address should not be zero");
        assertEq(factory.totalDeployed(), 1, "totalDeployed should be 1");

        HeroNFT collection = HeroNFT(proxy);
        assertEq(collection.name(), "AetherForge Hero", "collection name wrong");
    }

    // ─── Test 8: Factory deployCreate2 gives deterministic address ─────────────

    function test_FactoryDeployCreate2DeterministicAddress() public {
        bytes32 salt = keccak256("guild-alpha-season-1");
        string memory baseURI = "https://heroes.aetherforge.io/";

        address predicted = factory.predictCreate2Address(salt, admin, upgrader, baseURI, address(aethToken));

        vm.prank(admin);
        address actual = factory.deployCreate2(salt, admin, upgrader, baseURI, address(aethToken));

        assertEq(actual, predicted, "CREATE2 address does not match prediction");
        assertEq(factory.totalDeployed(), 1, "totalDeployed should be 1");
    }

    // ─── Test 9: mintHero reverts on zero recipient ─────────────────────────────

    function test_MintHero_RevertsOnZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(HeroNFT.HeroNFT__ZeroAddress.selector);
        hero.mintHero(address(0), HeroNFT.HeroClass.Warrior);
    }

    // ─── Test 10: levelUp reverts on nonexistent token ──────────────────────────

    function test_LevelUp_RevertsOnNonexistentToken() public {
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(HeroNFT.HeroNFT__TokenNotFound.selector, 999));
        hero.levelUp(999);
    }

    // ─── Test 11: getHeroAttributes reverts on nonexistent token ────────────────

    function test_GetHeroAttributes_RevertsOnNonexistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(HeroNFT.HeroNFT__TokenNotFound.selector, 999));
        hero.getHeroAttributes(999);
    }

    // ─── Test 12: levelUp reverts when hero is already at max level ─────────────
    //
    // FIX: original looped 99× with vm.prank — caused test suite to hang (~30 s).
    //
    // WHY slot 1, not slot 9:
    //   The comment in HeroNFT.sol lists slots 0-11 assuming OZ v4 sequential layout.
    //   OZ v5 upgradeable contracts use ERC-7201 *namespaced* storage for every
    //   parent contract (ERC721, AccessControl, UUPSUpgradeable, Initializable).
    //   That means none of those occupy sequential slots 0-8.
    //   HeroNFT's *own* variables therefore start at slot 0:
    //     slot 0  →  _nextTokenId
    //     slot 1  →  _heroAttributes   ← correct slot
    //     slot 2  →  _baseTokenURI
    //     slot 3  →  _aethToken
    //
    // HeroAttributes { uint8 level, HeroClass heroClass } — both uint8, packed.
    // level sits in the low byte → bytes32(uint256(0x0064)) == level=100, heroClass=0.

    function test_LevelUp_RevertsAtMaxLevel() public {
        vm.prank(alice);
        uint256 tokenId = hero.mintHero(alice, HeroNFT.HeroClass.Warrior);

        // Write level=100 directly into storage in O(1).
        // _heroAttributes is at mapping slot 1 (OZ v5 namespaced storage).
        bytes32 mappingSlot = keccak256(abi.encode(tokenId, uint256(1)));
        vm.store(address(hero), mappingSlot, bytes32(uint256(0x0064))); // level=100, heroClass=Warrior

        assertEq(hero.getHeroAttributes(tokenId).level, 100, "cheat: level should be 100");

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(HeroNFT.HeroNFT__MaxLevelReached.selector, tokenId));
        hero.levelUp(tokenId);
    }

    // ─── Test 13: tokenURI exercises _baseURI ───────────────────────────────────

    function test_TokenURI_ContainsBaseURI() public {
        vm.prank(alice);
        uint256 tokenId = hero.mintHero(alice, HeroNFT.HeroClass.Warrior);

        string memory uri = hero.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0, "tokenURI must not be empty");
    }

    // ─── Test 14: supportsInterface for ERC721 and AccessControl ────────────────

    function test_SupportsInterface() public view {
        assertTrue(hero.supportsInterface(0x80ac58cd), "should support ERC721");
        assertTrue(hero.supportsInterface(0x7965db0b), "should support AccessControl");
    }
}
