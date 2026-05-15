// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title GuildTreasury
 * @notice ERC-4626 tokenized yield vault for AetherForge Arena.
 *
 * Overview
 * ────────
 * Players deposit AETH (the governance token) and receive gAETH (vault shares).
 * The vault accrues yield via two sources:
 *   1. Direct yield injections by the YIELD_MANAGER_ROLE (e.g. from arena fees).
 *   2. Passive: share price rises as totalAssets grows relative to totalSupply.
 *
 * ERC-4626 invariants enforced
 * ────────────────────────────
 * • convertToShares / convertToAssets are monotone and round correctly
 *   (shares round DOWN on deposit/mint, assets round DOWN on withdraw/redeem).
 * • No share inflation attack: a _decimalsOffset() of 3 means virtual shares
 *   start at 1000:1, making donation attacks ~1000× more expensive.
 *
 * Roles
 * ─────
 * DEFAULT_ADMIN_ROLE  — grant / revoke roles (transferred to NVTimelock)
 * YIELD_MANAGER_ROLE  — can call injectYield() to add rewards to the vault
 */
contract GuildTreasury is ERC4626, AccessControl {
    using Math for uint256;

    // ─── Roles ────────────────────────────────────────────────────────────────

    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");

    // ─── Errors ───────────────────────────────────────────────────────────────

    error GuildTreasury__ZeroAddress();
    error GuildTreasury__ZeroAmount();
    error GuildTreasury__InsufficientShares();

    // ─── Events ───────────────────────────────────────────────────────────────

    event YieldInjected(address indexed from, uint256 amount);

    // ─── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param asset_  The underlying token (AethToken / AETH).
     * @param admin   Receives DEFAULT_ADMIN_ROLE (transferred to Timelock post-deploy).
     */
    constructor(IERC20 asset_, address admin) ERC4626(asset_) ERC20("Guild Treasury Share", "gAETH") {
        if (admin == address(0)) revert GuildTreasury__ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // ─── Yield injection ──────────────────────────────────────────────────────

    /**
     * @notice Inject `amount` AETH as yield into the vault without minting shares.
     * @dev    This increases totalAssets(), which raises the share price for all
     *         existing depositors. Called by the ArenaEngine when distributing
     *         match-entry fees to the treasury.
     *
     *         CEI: checks → effects (state change is inside OZ safeTransferFrom)
     *         → interaction (the transfer itself is the only external call).
     */
    function injectYield(uint256 amount) external onlyRole(YIELD_MANAGER_ROLE) {
        if (amount == 0) revert GuildTreasury__ZeroAmount();
        SafeERC20.safeTransferFrom(IERC20(asset()), msg.sender, address(this), amount);
        emit YieldInjected(msg.sender, amount);
    }

    // ─── ERC-4626 inflation-attack mitigation ─────────────────────────────────

    /**
     * @dev Offset of 3 decimals means the virtual share count starts at 1000.
     *      An attacker trying to inflate the share price via a donation would need
     *      to donate 1000× the first depositor's amount to profit — effectively
     *      making the attack economically unviable for any realistic deposit size.
     *
     *      See OZ ERC-4626 docs: https://docs.openzeppelin.com/contracts/5.x/erc4626
     */
    function _decimalsOffset() internal pure override returns (uint8) {
        return 3;
    }

    // ─── OZ overrides ─────────────────────────────────────────────────────────

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
