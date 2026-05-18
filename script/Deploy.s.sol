// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { AethToken } from "../contracts/token/AethToken.sol";
import { HeroNFT } from "../contracts/nft/HeroNFT.sol";
import { HeroNFTFactory } from "../contracts/nft/HeroNFTFactory.sol";
import { ItemRegistry } from "../contracts/nft/ItemRegistry.sol";
import { AMMMarketplace } from "../contracts/marketplace/AMMMarketplace.sol";
import { GuildTreasury } from "../contracts/vault/GuildTreasury.sol";
import { AetherTimelock } from "../contracts/governance/AetherTimelock.sol";
import { AetherGovernor } from "../contracts/governance/AetherGovernor.sol";
import { ChainlinkPriceAdapter } from "../contracts/oracle/ChainlinkPriceAdapter.sol";
import { CraftingEngine } from "../contracts/crafting/CraftingEngine.sol";
import { MercenaryGuild } from "../contracts/rental/MercenaryGuild.sol";
import { PvPArena } from "../contracts/arena/PvPArena.sol";
import { GameParametersV1 } from "../contracts/proxy/GameParametersV1.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title Deploy
 * @notice Full deterministic deployment script for the AetherForge GameFi protocol.
 *
 * Usage
 * ─────
 * Deploy to Arbitrum Sepolia (dry-run):
 *   forge script script/Deploy.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC --sender $DEPLOYER
 *
 * Deploy and broadcast:
 *   forge script script/Deploy.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC \
 *     --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
 *
 * Required environment variables
 * ───────────────────────────────
 * DEPLOYER_ADDRESS        - deployer EOA (used as initial admin, later transferred to Timelock)
 * CHAINLINK_FEED          - AETH/USD price feed address on target network
 * CHAINLINK_MAX_STALENESS - max acceptable price age in seconds (e.g. 3600)
 * VRF_COORDINATOR         - Chainlink VRF v2.5 coordinator on target network
 * VRF_KEY_HASH            - VRF gas lane key hash
 * VRF_SUBSCRIPTION_ID     - funded VRF subscription ID
 * HERO_NFT_BASE_URI       - base URI for HeroNFT metadata (e.g. https://api.aetherforge.io/hero/)
 * ITEM_REGISTRY_URI       - ERC-1155 metadata URI (e.g. https://api.aetherforge.io/items/{id}.json)
 *
 * Deployment order and rationale
 * ────────────────────────────────
 * 1.  AethToken              — governance token; needed by everyone
 * 2.  GuildTreasury          — ERC-4626 vault backed by AETH
 * 3.  ChainlinkPriceAdapter  — oracle; needed by CraftingEngine
 * 4.  ItemRegistry           — ERC-1155 items; needed by CraftingEngine
 * 5.  HeroNFT (impl)         — UUPS implementation
 * 6.  HeroNFTFactory         — deploys HeroNFT proxies; emits the primary hero collection
 * 7.  HeroNFT proxy          — deployed via factory (CREATE), stored as heroNFT
 * 8.  AMMMarketplace         — AETH/gAETH LP pool
 * 9.  CraftingEngine         — depends on AethToken, ItemRegistry, oracle, treasury
 * 10. MercenaryGuild         — NFT rental; pays fees in AETH
 * 11. GameParametersV1       — UUPS proxy for DAO-governed game params
 * 12. PvPArena               — VRF-powered battle arena
 * 13. AetherTimelock         — 2-day delay; needs governor address → deployed after governor
 *     AetherGovernor         — needs token + timelock (circular: governor needs timelock,
 *                              timelock needs governor address)
 *     Resolution: deploy Governor first with a temporary placeholder,
 *     then deploy Timelock with the real governor address.
 *     OZ Governor does NOT store the timelock at construction time beyond the
 *     GovernorTimelockControl hook — the timelock is passed in and used directly.
 *     AetherTimelock takes governor in constructor → so: Governor first, Timelock second.
 * 14. Role grants and ownership transfers — final wiring step
 *
 * Post-deploy verification
 * ─────────────────────────
 * Run Verify.s.sol to assert all parameters and ownership are correct.
 */
contract Deploy is Script {
    // ─── Deployed addresses (written during run, read by Verify.s.sol) ────────

    AethToken public aethToken;
    GuildTreasury public guildTreasury;
    ChainlinkPriceAdapter public priceAdapter;
    ItemRegistry public itemRegistry;
    HeroNFTFactory public heroNFTFactory;
    HeroNFT public heroNFT; // the primary proxy deployed via factory
    AMMMarketplace public ammMarketplace;
    CraftingEngine public craftingEngine;
    MercenaryGuild public mercenaryGuild;
    GameParametersV1 public gameParameters; // proxy
    PvPArena public pvpArena;
    AetherGovernor public governor;
    AetherTimelock public timelock;

    // ─── Protocol constants ───────────────────────────────────────────────────

    /// @dev CraftingEngine treasury fee: 5 % of AETH cost goes to GuildTreasury.
    uint256 public constant CRAFTING_TREASURY_FEE_BPS = 500;

    /// @dev MercenaryGuild protocol fee: 2.5 % of rental payments.
    uint256 public constant GUILD_PROTOCOL_FEE_BPS = 250;

    /// @dev PvPArena treasury fee: 10 % of prize pool goes to GuildTreasury.
    uint256 public constant ARENA_TREASURY_FEE_BPS = 1_000;

    /// @dev PvPArena entry fee: 10 AETH per battle.
    uint256 public constant ARENA_ENTRY_FEE = 10 ether;

    // ─── Main entry point ─────────────────────────────────────────────────────

    function run() external {
        // Read required env vars.
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        address chainlinkFeed = vm.envAddress("CHAINLINK_FEED");
        uint256 maxStaleness = vm.envUint("CHAINLINK_MAX_STALENESS");
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        bytes32 vrfKeyHash = vm.envBytes32("VRF_KEY_HASH");
        uint256 vrfSubId = vm.envUint("VRF_SUBSCRIPTION_ID");
        string memory heroBaseURI = vm.envString("HERO_NFT_BASE_URI");
        string memory itemURI = vm.envString("ITEM_REGISTRY_URI");

        console2.log("=== AetherForge Deploy ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployer);

        // ── 1. AethToken ──────────────────────────────────────────────────────
        aethToken = new AethToken(deployer);
        console2.log("AethToken:", address(aethToken));

        // ── 2. GuildTreasury (ERC-4626 vault backed by AETH) ──────────────────
        guildTreasury = new GuildTreasury(IERC20(address(aethToken)), deployer);
        console2.log("GuildTreasury:", address(guildTreasury));

        // ── 3. ChainlinkPriceAdapter ──────────────────────────────────────────
        priceAdapter = new ChainlinkPriceAdapter(chainlinkFeed, maxStaleness, deployer);
        console2.log("ChainlinkPriceAdapter:", address(priceAdapter));

        // ── 4. ItemRegistry (ERC-1155) ────────────────────────────────────────
        itemRegistry = new ItemRegistry(deployer, itemURI);
        console2.log("ItemRegistry:", address(itemRegistry));

        // ── 5-7. HeroNFTFactory + primary HeroNFT proxy ───────────────────────
        // Factory deploys the shared HeroNFT implementation internally (CREATE).
        heroNFTFactory = new HeroNFTFactory(deployer);
        console2.log("HeroNFTFactory:", address(heroNFTFactory));
        console2.log("HeroNFT implementation:", heroNFTFactory.implementation());

        // Deploy primary hero collection via factory using CREATE.
        // Deployer is both admin and upgrader initially; upgrader transferred to Timelock later.
        address heroNFTProxy = heroNFTFactory.deployCreate(deployer, deployer, heroBaseURI);
        heroNFT = HeroNFT(heroNFTProxy);
        console2.log("HeroNFT proxy:", address(heroNFT));

        // ── 8. AMMMarketplace (AETH / gAETH) ─────────────────────────────────
        // Pairs AETH governance token against gAETH (GuildTreasury shares).
        ammMarketplace = new AMMMarketplace(
            address(aethToken),
            address(guildTreasury),
            "AetherForge AETH-gAETH LP",
            "AF-LP"
        );
        console2.log("AMMMarketplace:", address(ammMarketplace));

        // ── 9. CraftingEngine ─────────────────────────────────────────────────
        craftingEngine = new CraftingEngine(
            address(aethToken),
            address(itemRegistry),
            address(priceAdapter),
            address(guildTreasury),
            CRAFTING_TREASURY_FEE_BPS,
            deployer
        );
        console2.log("CraftingEngine:", address(craftingEngine));

        // ── 10. MercenaryGuild ────────────────────────────────────────────────
        // Fee recipient = GuildTreasury (rental fees flow into the yield vault).
        mercenaryGuild = new MercenaryGuild(
            address(aethToken),
            deployer,
            address(guildTreasury),
            GUILD_PROTOCOL_FEE_BPS
        );
        console2.log("MercenaryGuild:", address(mercenaryGuild));

        // ── 11. GameParametersV1 (UUPS proxy) ─────────────────────────────────
        GameParametersV1 paramsImpl = new GameParametersV1();
        bytes memory paramsInit = abi.encodeCall(GameParametersV1.initialize, (deployer, deployer));
        ERC1967Proxy paramsProxy = new ERC1967Proxy(address(paramsImpl), paramsInit);
        gameParameters = GameParametersV1(address(paramsProxy));
        console2.log("GameParametersV1 impl:", address(paramsImpl));
        console2.log("GameParametersV1 proxy:", address(gameParameters));

        // ── 12. PvPArena ──────────────────────────────────────────────────────
        pvpArena = new PvPArena(
            vrfCoordinator,
            address(aethToken),
            address(heroNFT),
            address(guildTreasury),
            deployer, // admin (transferred to Timelock later)
            deployer, // pauser
            vrfKeyHash,
            vrfSubId,
            ARENA_ENTRY_FEE,
            ARENA_TREASURY_FEE_BPS
        );
        console2.log("PvPArena:", address(pvpArena));

        // ── 13. AetherGovernor + AetherTimelock ───────────────────────────────
        // Circular dependency: Governor needs a Timelock in its constructor,
        // AetherTimelock needs the Governor address.
        // Resolution: deploy Timelock with deployer as temp proposer, deploy
        // Governor pointing to it, then grant Governor PROPOSER/CANCELLER roles
        // and revoke deployer's temporary proposer role.
        // This avoids updateTimelock() which requires a full governance lifecycle.
        _deployGovernanceAtomic(deployer);
    }

    /**
     * @dev Deploys Governor + Timelock atomically without updateTimelock().
     *      Strategy:
     *        1. Deploy AetherTimelock with deployer as temporary PROPOSER.
     *        2. Deploy AetherGovernor pointing to that timelock.
     *        3. Grant Governor PROPOSER_ROLE + CANCELLER_ROLE on timelock.
     *        4. Revoke deployer's temporary PROPOSER_ROLE.
     *      This avoids updateTimelock() which internally calls .pop() on an
     *      empty proposals array and panics when called outside governance.
     */
    function _deployGovernanceAtomic(address deployer) internal {

        // Step 1: Deploy AetherTimelock with deployer as temp PROPOSER and
        //         temp DEFAULT_ADMIN (setupAdmin) so the script can grantRole.
        timelock = new AetherTimelock(deployer, deployer);
        console2.log("AetherTimelock:", address(timelock));

        // Step 2: Deploy Governor pointing to the real timelock.
        governor = new AetherGovernor(IVotes(address(aethToken)), timelock);
        console2.log("AetherGovernor:", address(governor));

        // Step 3: Grant Governor PROPOSER_ROLE and CANCELLER_ROLE.
        // Deployer has DEFAULT_ADMIN_ROLE here so grantRole succeeds.
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // Step 4: Revoke deployer's temp roles — timelock becomes self-administered.
        timelock.revokeRole(timelock.PROPOSER_ROLE(), deployer);
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        console2.log("Governance wired: Governor is sole proposer on AetherTimelock");

        // ── 14. Role grants and ownership wiring ─────────────────────────────

        // AethToken: grant MINTER_ROLE to GuildTreasury and CraftingEngine.
        //            grant BURNER_ROLE to CraftingEngine.
        aethToken.grantRole(aethToken.MINTER_ROLE(), address(guildTreasury));
        aethToken.grantRole(aethToken.MINTER_ROLE(), address(craftingEngine));
        aethToken.grantRole(aethToken.BURNER_ROLE(), address(craftingEngine));

        // ItemRegistry: grant MINTER_ROLE + BURNER_ROLE to CraftingEngine.
        itemRegistry.grantRole(itemRegistry.MINTER_ROLE(), address(craftingEngine));
        itemRegistry.grantRole(itemRegistry.BURNER_ROLE(), address(craftingEngine));

        // HeroNFT: grant MINTER_ROLE to PvPArena (optional: arena does not mint heroes,
        //          but may need it for future reward drops). Skip if not needed.
        // heroNFT.grantRole(heroNFT.MINTER_ROLE(), address(pvpArena));

        // Transfer DEFAULT_ADMIN_ROLE to Timelock on all contracts.
        // Deployer retains admin temporarily during setup; revoke at the end.
        _transferAdminToTimelock(deployer);

        // GameParameters: grant PARAM_MANAGER_ROLE to Timelock.
        gameParameters.grantRole(gameParameters.PARAM_MANAGER_ROLE(), address(timelock));
        // UPGRADER_ROLE is already held by deployer; transfer to Timelock then revoke.
        gameParameters.grantRole(gameParameters.UPGRADER_ROLE(), address(timelock));
        gameParameters.revokeRole(gameParameters.UPGRADER_ROLE(), deployer);
        gameParameters.revokeRole(gameParameters.DEFAULT_ADMIN_ROLE(), deployer);

        console2.log("=== Deployment complete ===");
        console2.log("All admin roles transferred to Timelock:", address(timelock));

        vm.stopBroadcast();
    }

    /**
     * @dev Transfer DEFAULT_ADMIN_ROLE from deployer to Timelock on all contracts
     *      that use AccessControl. Revoke deployer's admin last.
     */
    /**
     * @dev Grant ALL roles to Timelock first, then revoke deployer roles.
     *      This order is critical: revoking DEFAULT_ADMIN_ROLE before all
     *      grantRole calls are done causes AccessControlUnauthorizedAccount.
     */
    function _transferAdminToTimelock(address deployer) internal {
        address tl = address(timelock);

        // ── Step 1: grant all roles to Timelock (deployer still has DEFAULT_ADMIN) ──
        aethToken.grantRole(aethToken.DEFAULT_ADMIN_ROLE(), tl);
        guildTreasury.grantRole(guildTreasury.DEFAULT_ADMIN_ROLE(), tl);
        priceAdapter.grantRole(priceAdapter.DEFAULT_ADMIN_ROLE(), tl);
        itemRegistry.grantRole(itemRegistry.DEFAULT_ADMIN_ROLE(), tl);
        heroNFTFactory.grantRole(heroNFTFactory.DEFAULT_ADMIN_ROLE(), tl);
        heroNFT.grantRole(heroNFT.DEFAULT_ADMIN_ROLE(), tl);
        craftingEngine.grantRole(craftingEngine.DEFAULT_ADMIN_ROLE(), tl);
        mercenaryGuild.grantRole(mercenaryGuild.DEFAULT_ADMIN_ROLE(), tl);
        pvpArena.grantRole(pvpArena.DEFAULT_ADMIN_ROLE(), tl);
        pvpArena.grantRole(pvpArena.PAUSER_ROLE(), tl);

        // ── Step 2: revoke deployer after all grants are complete ─────────────
        aethToken.revokeRole(aethToken.DEFAULT_ADMIN_ROLE(), deployer);
        guildTreasury.revokeRole(guildTreasury.DEFAULT_ADMIN_ROLE(), deployer);
        priceAdapter.revokeRole(priceAdapter.DEFAULT_ADMIN_ROLE(), deployer);
        itemRegistry.revokeRole(itemRegistry.DEFAULT_ADMIN_ROLE(), deployer);
        heroNFTFactory.revokeRole(heroNFTFactory.DEFAULT_ADMIN_ROLE(), deployer);
        heroNFT.revokeRole(heroNFT.DEFAULT_ADMIN_ROLE(), deployer);
        craftingEngine.revokeRole(craftingEngine.DEFAULT_ADMIN_ROLE(), deployer);
        mercenaryGuild.revokeRole(mercenaryGuild.DEFAULT_ADMIN_ROLE(), deployer);
        pvpArena.revokeRole(pvpArena.PAUSER_ROLE(), deployer);   // revoke before DEFAULT_ADMIN
        pvpArena.revokeRole(pvpArena.DEFAULT_ADMIN_ROLE(), deployer);
    }
}
