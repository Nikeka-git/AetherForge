// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/*─────────────────────────────────────────────────────────────────────────────
 * SECURITY CASE STUDY 2 - Access Control
 *
 * Context
 * ───────
 * AetherForge Arena's item registry allows privileged accounts to mint
 * in-game items.  In the vulnerable version the mint function has no
 * access guard at all - any address can mint arbitrary items for free,
 * breaking the entire in-game economy.
 *
 * A second misconfiguration: the admin role can be claimed by anyone
 * because the constructor forgets to assign it, leaving the contract
 * permanently unmanaged - or worse, capturable by the first caller.
 *
 * Files
 * ─────
 *   AccessVuln   - the VULNERABLE version (missing role guards)
 *   AccessFixed  - the FIXED version using OpenZeppelin AccessControl
 *
 * How to run the proof-of-concept exploit test:
 *   forge test --match-contract SecurityAccessControlTest -vvv
 *─────────────────────────────────────────────────────────────────────────────*/

// VULNERABLE

/**
 * @title AccessVuln
 * @notice INTENTIONALLY VULNERABLE - for security case-study purposes only.
 *
 * Vulnerability 1 (SWC-105): Unprotected mint function.
 *   mint() has no access control - any EOA or contract can mint unlimited
 *   items to any address, completely breaking game-economy scarcity.
 *
 * Vulnerability 2 (SWC-106): Unprotected admin takeover.
 *   claimAdmin() lets the first caller permanently seize admin rights.
 *   The constructor never assigns admin, leaving the role unclaimed.
 *
 * @dev DO NOT USE IN PRODUCTION.
 */
contract AccessVuln {
    address public admin;

    mapping(address => mapping(uint256 => uint256)) public itemBalances;

    event ItemMinted(address indexed to, uint256 itemId, uint256 amount);
    event AdminChanged(address indexed newAdmin);

    /// @notice Constructor intentionally does NOT set admin - anyone can claim it.
    constructor() { }

    /// @notice VULNERABLE: no access control - any address can call this.
    function mint(address to, uint256 itemId, uint256 amount) external {
        itemBalances[to][itemId] += amount;
        emit ItemMinted(to, itemId, amount);
    }

    /// @notice VULNERABLE: first caller becomes admin permanently.
    function claimAdmin() external {
        require(admin == address(0), "admin already set");
        admin = msg.sender;
        emit AdminChanged(msg.sender);
    }

    /// @notice VULNERABLE: no check that caller is current admin.
    function setAdmin(address newAdmin) external {
        admin = newAdmin;
        emit AdminChanged(newAdmin);
    }
}

// FIXED

/**
 * @title AccessFixed
 * @notice Fixed version of AccessVuln.
 *
 * Fixes applied
 * ─────────────
 * 1. OpenZeppelin AccessControl: role-based permission system with
 *    cryptographically distinct role identifiers.
 * 2. Constructor assigns DEFAULT_ADMIN_ROLE to the deployer immediately -
 *    no unclaimed admin window.
 * 3. mint() is guarded by onlyRole(MINTER_ROLE) - only explicitly granted
 *    addresses can mint items.
 * 4. Role management (grant/revoke) is restricted to DEFAULT_ADMIN_ROLE
 *    holders by OpenZeppelin's AccessControl internals.
 * 5. No claimAdmin() function exists - role assignment is solely through
 *    grantRole(), which itself requires DEFAULT_ADMIN_ROLE.
 *
 * Both findings are documented in the audit report (Finding S-02).
 */
contract AccessFixed is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(address => mapping(uint256 => uint256)) public itemBalances;

    event ItemMinted(address indexed to, uint256 itemId, uint256 amount);

    /// @notice Constructor assigns DEFAULT_ADMIN_ROLE to 'admin' immediately.
    /// @param admin Address that will manage roles (should be a multisig or Timelock).
    constructor(address admin) {
        require(admin != address(0), "admin cannot be zero address");
        // Admin is set at construction - no unclaimed-admin window.
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Mint items to 'to'. Restricted to MINTER_ROLE holders.
    /// @param to     Recipient address.
    /// @param itemId Item identifier.
    /// @param amount Number of items to mint.
    function mint(address to, uint256 itemId, uint256 amount)
        external
        onlyRole(MINTER_ROLE) // access guard

    {
        require(to != address(0), "mint to zero address");
        require(amount > 0, "amount must be > 0");
        itemBalances[to][itemId] += amount;
        emit ItemMinted(to, itemId, amount);
    }
}
