// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { HeroNFT } from "./HeroNFT.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title HeroNFTFactory
 * @notice Deploys HeroNFT proxy instances using both CREATE and CREATE2.
 *
 * Why two deploy methods?
 * ───────────────────────
 * CREATE  (deployCreate)  - address depends on factory address + nonce.
 *                           Use when you don't need to predict the address beforehand.
 * CREATE2 (deployCreate2) - address depends on factory address + salt + initcode hash.
 *                           Use when the frontend or another contract needs to know
 *                           the hero collection address before it's deployed
 *                           (e.g. whitelisting in the AMM or CraftingEngine).
 *
 * Design
 * ──────
 * The factory deploys ERC1967Proxy instances pointing to a shared HeroNFT implementation.
 * Each proxy is a fully independent hero collection (separate owner, minters, token IDs).
 * The implementation is deployed once; proxies are cheap to spin up.
 */
contract HeroNFTFactory is AccessControl {
    // Roles

    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    // State

    /// @notice The shared HeroNFT implementation contract (immutable after construction).
    address public immutable implementation;

    /// @notice All proxy addresses deployed by this factory (both CREATE and CREATE2).
    address[] public deployedHeroes;

    // Errors

    error HeroNFTFactory__ZeroAddress();
    error HeroNFTFactory__SaltAlreadyUsed(bytes32 salt);
    error HeroNFTFactory__DeployFailed();

    // Events

    event HeroCollectionDeployed(address indexed proxy, address indexed admin, bool isCreate2, bytes32 salt);

    // Constructor

    /**
     * @param admin Receives DEFAULT_ADMIN_ROLE and DEPLOYER_ROLE.
     */
    constructor(address admin) {
        if (admin == address(0)) revert HeroNFTFactory__ZeroAddress();

        // Deploy the shared implementation using CREATE (normal new).
        // The implementation's initializers are disabled in its constructor.
        implementation = address(new HeroNFT());

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEPLOYER_ROLE, admin);
    }

    // CREATE deployment

    /**
     * @notice Deploy a new HeroNFT proxy using CREATE (address = keccak(factory, nonce)).
     * @param proxyAdmin  Admin of the new hero collection (gets DEFAULT_ADMIN_ROLE).
     * @param upgrader    Gets UPGRADER_ROLE on the new proxy.
     * @param baseURI     Token metadata base URI.
     * @return proxy      Address of the newly deployed ERC1967Proxy.
     */
    function deployCreate(address proxyAdmin, address upgrader, string calldata baseURI, address aethToken)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address proxy)
    {
        if (proxyAdmin == address(0) || upgrader == address(0) || aethToken == address(0)) {
            revert HeroNFTFactory__ZeroAddress();
        }

        bytes memory initData = abi.encodeCall(HeroNFT.initialize, (proxyAdmin, upgrader, baseURI, aethToken));

        // CREATE — Solidity 'new' keyword, address determined by factory nonce
        proxy = address(new ERC1967Proxy(implementation, initData));

        deployedHeroes.push(proxy);
        emit HeroCollectionDeployed(proxy, proxyAdmin, false, bytes32(0));
    }

    // CREATE2 deployment

    /**
     * @notice Deploy a new HeroNFT proxy using CREATE2 (deterministic address).
     * @dev    The proxy address can be computed off-chain with predictCreate2Address()
     *         before deployment, enabling whitelisting in other contracts.
     * @param salt        Unique salt chosen by the caller.
     * @param proxyAdmin  Admin of the new hero collection.
     * @param upgrader    Gets UPGRADER_ROLE on the new proxy.
     * @param baseURI     Token metadata base URI.
     * @return proxy      Address of the newly deployed ERC1967Proxy.
     */
    function deployCreate2(
        bytes32 salt,
        address proxyAdmin,
        address upgrader,
        string calldata baseURI,
        address aethToken
    ) external onlyRole(DEPLOYER_ROLE) returns (address proxy) {
        if (proxyAdmin == address(0) || upgrader == address(0) || aethToken == address(0)) {
            revert HeroNFTFactory__ZeroAddress();
        }

        bytes memory initData = abi.encodeCall(HeroNFT.initialize, (proxyAdmin, upgrader, baseURI, aethToken));

        // CREATE2 - Solidity 'new' with 'salt' option; address is deterministic
        proxy = address(new ERC1967Proxy{ salt: salt }(implementation, initData));

        deployedHeroes.push(proxy);
        emit HeroCollectionDeployed(proxy, proxyAdmin, true, salt);
    }

    // View helpers

    /**
     * @notice Predict the CREATE2 proxy address for a given salt without deploying.
     * @dev    Uses the same initcode hash that deployCreate2 would produce.
     */
    function predictCreate2Address(
        bytes32 salt,
        address proxyAdmin,
        address upgrader,
        string calldata baseURI,
        address aethToken
    ) external view returns (address predicted) {
        bytes memory initData = abi.encodeCall(HeroNFT.initialize, (proxyAdmin, upgrader, baseURI, aethToken));
        bytes memory creationCode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, initData));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(creationCode)));
        predicted = address(uint160(uint256(hash)));
    }

    /**
     * @notice Total number of hero collections deployed by this factory.
     */
    function totalDeployed() external view returns (uint256) {
        return deployedHeroes.length;
    }
}
