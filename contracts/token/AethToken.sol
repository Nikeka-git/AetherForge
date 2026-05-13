// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title AethToken
 * @notice Governance token for AetherForge Arena.
 *         ERC-20 with voting snapshots (ERC20Votes), gasless approvals (ERC20Permit),
 *         and role-gated minting / burning (AccessControl).
 *
 * Roles
 * ─────
 * DEFAULT_ADMIN_ROLE  - can grant / revoke all roles (held by deployer, then transferred to Timelock)
 * MINTER_ROLE         - CraftingEngine, GuildTreasury: can mint new tokens
 * BURNER_ROLE         - CraftingEngine: can burn tokens from an account
 */
contract AethToken is ERC20, ERC20Permit, ERC20Votes, AccessControl {
    // Roles

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Errors

    error AethToken__ZeroAddress();
    error AethToken__ZeroAmount();

    // Constructor

    /**
     * @param admin Address that receives DEFAULT_ADMIN_ROLE and the initial supply.
     *              After deployment, this should be transferred to the Timelock.
     */
    constructor(address admin) ERC20("Aether", "AETH") ERC20Permit("Aether") {
        if (admin == address(0)) revert AethToken__ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        // Mint the entire initial supply to the admin / deployer.
        // Distribution (staking rewards, DAO treasury, team vesting, etc.)
        // is handled off-chain via governance or separate vesting contracts.
        uint256 initialSupply = 100_000_000 * 1e18;
        _mint(admin, initialSupply);
    }

    // Privileged actions

    /**
     * @notice Mint 'amount' tokens to 'to'.
     * @dev    Called by CraftingEngine (rewards) and GuildTreasury (yield).
     *         Intentionally reverts on zero-amount to catch integration bugs early.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert AethToken__ZeroAddress();
        if (amount == 0) revert AethToken__ZeroAmount();
        _mint(to, amount);
    }

    /**
     * @notice Burn 'amount' tokens from 'from'.
     * @dev    Called by CraftingEngine when players spend AETH in crafting recipes.
     *         The caller must have BURNER_ROLE; no allowance from 'from' is needed
     *         because the CraftingEngine only burns tokens that 'from' has already
     *         approved to the engine (checked by the engine before calling here).
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        if (from == address(0)) revert AethToken__ZeroAddress();
        if (amount == 0) revert AethToken__ZeroAmount();
        _burn(from, amount);
    }

    // OZ v5 overrides required by diamond inheritance

    /**
     * @dev ERC20Votes hooks into _update to track voting checkpoints.
     *      Both ERC20 and ERC20Votes define _update - we must tell Solidity
     *      which linearization to use.
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    /**
     * @dev Both ERC20Permit and Nonces define nonces(). The compiler requires
     *      an explicit override that picks one (super routes through C3).
     */
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
