// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";
import { GovernorSettings } from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import { GovernorCountingSimple } from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import { GovernorVotes } from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import { GovernorTimelockControl } from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title AetherGovernor
 * @notice On-chain governance for AetherForge Arena.
 *         Full OpenZeppelin Governor stack with TimelockController integration.
 *
 * Parameters
 * ──────────────────────────
 * votingDelay    = 1 day   (~7 200 blocks at 12s/block)
 * votingPeriod   = 1 week  (~50 400 blocks at 12s/block)
 * quorumFraction = 4 %     of total supply at proposal snapshot
 * proposalThreshold = 1 %  of total supply (holder must have ≥ 1 % to propose)
 *
 * Governance lifecycle
 * ────────────────────
 * 1. propose()  — any holder with ≥ 1 % of supply creates a proposal.
 * 2. (1 day delay) — voting delay before voting begins.
 * 3. castVote() — 1 week voting window.
 * 4. queue()    — if quorum reached and For > Against, proposal is queued in Timelock.
 * 5. (2 day delay) — Timelock enforces minimum delay.
 * 6. execute()  — anyone can execute after the Timelock delay expires.
 *
 * The Timelock controls the treasury and all privileged protocol functions.
 * No action can bypass the Timelock — the Governor has no direct power.
 */
contract AetherGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    // Constants

    /// @notice 1 day voting delay in blocks (12 s/block -> 7200 blocks).
    uint48 public constant VOTING_DELAY_BLOCKS = 7200;

    /// @notice 1 week voting period in blocks (12 s/block -> 50400 blocks).
    uint32 public constant VOTING_PERIOD_BLOCKS = 50_400;

    /// @notice Quorum: 4 % of total supply at proposal snapshot.
    uint256 public constant QUORUM_FRACTION = 4;

    // Constructor

    /**
     * @param token_    AethToken (ERC20Votes) — the governance token.
     * @param timelock_ AetherTimelock — controls execution of passed proposals.
     */
    constructor(IVotes token_, TimelockController timelock_)
        Governor("AetherForge Governor")
        GovernorSettings(
            VOTING_DELAY_BLOCKS, // 1 day
            VOTING_PERIOD_BLOCKS, // 1 week
            0 // proposalThreshold set via _proposalThreshold() override below
        )
        GovernorVotes(token_)
        GovernorVotesQuorumFraction(QUORUM_FRACTION)
        GovernorTimelockControl(timelock_)
    { }

    // Proposal threshold: 1 % of total supply

    /**
     * @notice A proposer must hold at least 1 % of the total token supply
     *         (measured at the block before the proposal is created).
     * @dev    Overrides GovernorSettings.proposalThreshold() to make the threshold
     *         dynamic (1 % of current total supply) instead of a fixed token amount.
     */
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return token().getPastTotalSupply(clock() - 1) / 100; // 1 %
    }

    // Required OZ overrides

    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
