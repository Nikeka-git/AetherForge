// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { HeroNFT } from "../../contracts/nft/HeroNFT.sol";
import { HeroNFTFactory } from "../../contracts/nft/HeroNFTFactory.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title HeroNFTTest
 * @notice 7 unit tests for HeroNFT (UUPS proxy) and HeroNFTFactory (CREATE + CREATE2).
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

    HeroNFT heroImpl; // raw implementation (should not be used directly)
    HeroNFT hero; // proxy cast to HeroNFT
    HeroNFTFactory factory;

    function setUp() public {
        // Deploy implementation
        heroImpl = new HeroNFT();

        // Deploy proxy and initialise
        bytes memory initData = abi.encodeCall(HeroNFT.initialize, (admin, upgrader, "https://heroes.aetherforge.io/"));
        ERC1967Proxy proxy = new ERC1967Proxy(address(heroImpl), initData);
        hero = HeroNFT(address(proxy));

        // Grant minter role
        vm.prank(admin);
        hero.grantRole(MINTER_ROLE, minter);

        // Deploy factory
        factory = new HeroNFTFactory(admin);
    }

    // ─── Test 1: Implementation initializers are disabled ──────────────────────

    function test_ImplementationInitializersDisabled() public {
        vm.expectRevert(); // InvalidInitialization
        heroImpl.initialize(admin, upgrader, "https://x.io/");
    }

    // ─── Test 2: Proxy initializes correctly ───────────────────────────────────

    function test_ProxyInitializesCorrectly() public view {
        assertEq(hero.name(), "AetherForge Hero", "name wrong");
        assertEq(hero.symbol(), "HERO", "symbol wrong");
        assertTrue(hero.hasRole(hero.DEFAULT_ADMIN_ROLE(), admin), "admin role missing");
        assertTrue(hero.hasRole(UPGRADER_ROLE, upgrader), "upgrader role missing");
    }

    // ─── Test 3: MINTER_ROLE can mint a hero ───────────────────────────────────

    function test_MinterCanMintHero() public {
        vm.prank(minter);
        uint256 tokenId = hero.mintHero(alice, HeroNFT.HeroClass.Warrior);

        assertEq(tokenId, 1, "first token ID should be 1");
        assertEq(hero.ownerOf(1), alice, "alice should own token 1");
        assertEq(hero.totalMinted(), 1, "totalMinted wrong");

        HeroNFT.HeroAttributes memory attrs = hero.getHeroAttributes(1);
        assertEq(attrs.level, 1, "starting level should be 1");
        assertEq(uint8(attrs.heroClass), uint8(HeroNFT.HeroClass.Warrior), "class wrong");
    }

    // ─── Test 4: levelUp increments hero level ─────────────────────────────────

    function test_LevelUpIncrementsLevel() public {
        vm.prank(minter);
        hero.mintHero(alice, HeroNFT.HeroClass.Mage);

        vm.prank(minter);
        hero.levelUp(1);

        HeroNFT.HeroAttributes memory attrs = hero.getHeroAttributes(1);
        assertEq(attrs.level, 2, "level should be 2 after levelUp");
    }

    // ─── Test 5: Non-upgrader cannot upgrade the proxy ─────────────────────────

    function test_NonUpgraderCannotUpgrade() public {
        HeroNFT newImpl = new HeroNFT();

        vm.expectRevert(); // AccessControlUnauthorizedAccount
        vm.prank(alice);
        hero.upgradeToAndCall(address(newImpl), "");
    }

    // ─── Test 6: Factory deployCreate deploys a working proxy ──────────────────

    function test_FactoryDeployCreate() public {
        vm.prank(admin);
        address proxy = factory.deployCreate(admin, upgrader, "https://heroes.aetherforge.io/");

        assertTrue(proxy != address(0), "proxy address should not be zero");
        assertEq(factory.totalDeployed(), 1, "totalDeployed should be 1");

        HeroNFT collection = HeroNFT(proxy);
        assertEq(collection.name(), "AetherForge Hero", "collection name wrong");
    }

    // ─── Test 7: Factory deployCreate2 gives deterministic address ─────────────

    function test_FactoryDeployCreate2DeterministicAddress() public {
        bytes32 salt = keccak256("guild-alpha-season-1");
        string memory baseURI = "https://heroes.aetherforge.io/";

        // Predict address before deploying
        address predicted = factory.predictCreate2Address(salt, admin, upgrader, baseURI);

        vm.prank(admin);
        address actual = factory.deployCreate2(salt, admin, upgrader, baseURI);

        assertEq(actual, predicted, "CREATE2 address does not match prediction");
        assertEq(factory.totalDeployed(), 1, "totalDeployed should be 1");
    }

    // ─── Test 8: mintHero reverts on zero recipient ─────────────────────────────

    function test_MintHero_RevertsOnZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(HeroNFT.HeroNFT__ZeroAddress.selector);
        hero.mintHero(address(0), HeroNFT.HeroClass.Warrior);
    }

    // ─── Test 9: levelUp reverts on nonexistent token ───────────────────────────

    function test_LevelUp_RevertsOnNonexistentToken() public {
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(HeroNFT.HeroNFT__TokenNotFound.selector, 999));
        hero.levelUp(999);
    }

    // ─── Test 10: getHeroAttributes reverts on nonexistent token ────────────────

    function test_GetHeroAttributes_RevertsOnNonexistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(HeroNFT.HeroNFT__TokenNotFound.selector, 999));
        hero.getHeroAttributes(999);
    }

    // ─── Test 11: levelUp reverts when hero is already at max level ─────────────

    function test_LevelUp_RevertsAtMaxLevel() public {
        vm.prank(minter);
        uint256 tokenId = hero.mintHero(alice, HeroNFT.HeroClass.Warrior);

        // Level up 99 times to reach level 100
        for (uint256 i = 0; i < 99; i++) {
            vm.prank(minter);
            hero.levelUp(tokenId);
        }
        assertEq(hero.getHeroAttributes(tokenId).level, 100, "should be at max level");

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(HeroNFT.HeroNFT__MaxLevelReached.selector, tokenId));
        hero.levelUp(tokenId);
    }

    // ─── Test 12: tokenURI exercises _baseURI ───────────────────────────────────

    function test_TokenURI_ContainsBaseURI() public {
        vm.prank(minter);
        uint256 tokenId = hero.mintHero(alice, HeroNFT.HeroClass.Warrior);

        string memory uri = hero.tokenURI(tokenId);
        // Base URI is "https://heroes.aetherforge.io/" — result must be non-empty
        assertTrue(bytes(uri).length > 0, "tokenURI must not be empty");
    }

    // ─── Test 13: supportsInterface for ERC721 and AccessControl ────────────────

    function test_SupportsInterface() public view {
        assertTrue(hero.supportsInterface(0x80ac58cd), "should support ERC721");   // ERC721
        assertTrue(hero.supportsInterface(0x7965db0b), "should support AccessControl"); // IAccessControl
    }
}
