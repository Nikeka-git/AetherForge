// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/*─────────────────────────────────────────────────────────────────────────────
 * SECURITY CASE STUDY 1 - Reentrancy
 *
 * Context
 * ───────
 * AetherForge Arena collects entry fees and PvP rewards in AETH.
 * Before the fix, a reward-withdrawal function updated the caller's
 * balance AFTER the external ETH transfer - the classic "withdraw then
 * update" ordering mistake.  An attacker could re-enter withdraw() on
 * every callback and drain the contract.
 *
 * Files
 * ─────
 *   ReentrancyVuln   - the VULNERABLE version (do NOT deploy to mainnet)
 *   ReentrancyFixed  - the FIXED version using Checks-Effects-Interactions
 *                      and OpenZeppelin ReentrancyGuard
 *
 * How to run the proof-of-concept exploit test:
 *   forge test --match-contract SecurityReentrancyTest -vvv
 *─────────────────────────────────────────────────────────────────────────────*/

// VULNERABLE

/**
 * @title ReentrancyVuln
 * @notice INTENTIONALLY VULNERABLE - for security case-study purposes only.
 *
 * Vulnerability: SWC-107 Reentrancy
 * Location    : withdraw() - state update happens AFTER the external call.
 * Impact      : An attacker contract can re-enter withdraw() on every
 *               receive() callback and drain the entire contract balance.
 *
 * @dev DO NOT USE IN PRODUCTION.
 */
contract ReentrancyVuln {
    mapping(address => uint256) public balances;

    /// @notice Deposit ETH into the reward pool.
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /// @notice Withdraw accumulated ETH rewards.
    /// @dev    VULNERABLE: external call before state update.
    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "nothing to withdraw");

        //    WRONG ORDER: transfer first, update state second.
        //    An attacker's receive() can call withdraw() again before
        //    balances[msg.sender] is set to 0.
        (bool ok,) = msg.sender.call{ value: amount }("");
        require(ok, "transfer failed");

        balances[msg.sender] = 0; // too late - state updated after external call
    }

    /// @notice Total ETH held by the contract.
    function totalFunds() external view returns (uint256) {
        return address(this).balance;
    }
}

// FIXED


/**
 * @title ReentrancyFixed
 * @notice Fixed version of ReentrancyVuln.
 *
 * Fixes applied
 * ─────────────
 * 1. Checks-Effects-Interactions pattern: state is zeroed BEFORE the transfer.
 * 2. OpenZeppelin ReentrancyGuard: nonReentrant modifier as a defence-in-depth
 *    layer - even if a future refactor accidentally reorders the lines,
 *    the mutex will prevent exploitation.
 *
 * Both mitigations are documented in the audit report (Finding S-01).
 */
contract ReentrancyFixed is ReentrancyGuard {
    mapping(address => uint256) public balances;

    /// @notice Deposit ETH into the reward pool.
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /// @notice Withdraw accumulated ETH rewards - reentrancy-safe.
    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "nothing to withdraw");

        // CORRECT ORDER: Checks-Effects-Interactions
        // 1. Check  - require above
        // 2. Effect - zero the balance before any external call
        balances[msg.sender] = 0;

        // 3. Interaction - external call last
        (bool ok,) = msg.sender.call{ value: amount }("");
        require(ok, "transfer failed");
    }

    /// @notice Total ETH held by the contract.
    function totalFunds() external view returns (uint256) {
        return address(this).balance;
    }
}
