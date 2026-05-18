// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { AetherGovernor } from "../../contracts/governance/AetherGovernor.sol";
import { AetherTimelock } from "../../contracts/governance/AetherTimelock.sol";
import { AethToken } from "../../contracts/token/AethToken.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";

/**
 * @title GovernanceTest
 * @notice 8 unit tests for AetherGovernor + AetherTimelock.
 *         Demonstrates the full propose→vote→queue→execute lifecycle.
 *         Run with: forge test --match-contract GovernanceTest -vv
 */
contract GovernanceTest is Test {
    // Constants

    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    uint256 constant INITIAL_SUPPLY = 100_000_000 * 1e18;
    // Testnet values matching AetherGovernor (VOTING_DELAY_BLOCKS=10, VOTING_PERIOD_BLOCKS=100)
    // and AetherTimelock (MIN_DELAY=60 seconds).
    uint256 constant VOTING_DELAY = 10; // blocks (testnet: ~2.5 s on Arbitrum Sepolia)
    uint256 constant VOTING_PERIOD = 100; // blocks (testnet: ~25 s)
    uint256 constant TIMELOCK_DELAY = 60; // seconds (testnet value)

    // Actors

    address admin = makeAddr("admin");
    address proposer = makeAddr("proposer"); // holds > 1% to propose
    address voter1 = makeAddr("voter1");
    address voter2 = makeAddr("voter2");
    address alice = makeAddr("alice");

    // System under test

    AethToken token;
    AetherTimelock timelock;
    AetherGovernor governor;

    // Setup

    function setUp() public {
        vm.warp(1_700_000_000);

        // 1. Deploy token
        vm.prank(admin);
        token = new AethToken(admin);

        // 2. Deploy governor (temp: pass address(0) for timelock)
        //    We need the governor address before deploying timelock
        //    So: deploy timelock with a placeholder, then deploy governor

        // Deploy timelock with admin as temporary proposer
        vm.prank(admin);
        timelock = new AetherTimelock(admin, admin); // admin as temp proposer

        // Deploy governor
        vm.prank(admin);
        governor = new AetherGovernor(token, timelock);

        // 3. Wire up: grant governor PROPOSER + CANCELLER, revoke admin
        // Wire up: grant governor PROPOSER + CANCELLER, revoke admin
        vm.startPrank(address(timelock)); // <- timelock сам себе admin
        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(keccak256("CANCELLER_ROLE"), address(governor));
        timelock.revokeRole(PROPOSER_ROLE, admin);
        vm.stopPrank();

        // 4. Distribute tokens and self-delegate
        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, admin);
        // proposer gets 2% of supply (> 1% threshold)
        token.mint(proposer, INITIAL_SUPPLY * 2 / 100);
        // voters get 30% each
        token.mint(voter1, INITIAL_SUPPLY * 30 / 100);
        token.mint(voter2, INITIAL_SUPPLY * 30 / 100);
        vm.stopPrank();

        // Self-delegate to activate voting power
        vm.prank(proposer);
        token.delegate(proposer);
        vm.prank(voter1);
        token.delegate(voter1);
        vm.prank(voter2);
        token.delegate(voter2);

        // Mine one block so checkpoints are recorded
        vm.roll(block.number + 1);
    }

    // Helper: create a simple proposal to send ETH from timelock

    function _createProposal() internal returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = alice;
        values[0] = 0;
        calldatas[0] = "";

        vm.prank(proposer);
        proposalId = governor.propose(targets, values, calldatas, "Send ETH to alice");
    }

    // Test 1: Governor parameters are correct

    function test_GovernorParameters() public view {
        assertEq(governor.votingDelay(), VOTING_DELAY, "voting delay wrong");
        assertEq(governor.votingPeriod(), VOTING_PERIOD, "voting period wrong");
        assertEq(governor.quorumNumerator(), 4, "quorum fraction wrong");
        assertEq(address(governor.timelock()), address(timelock), "timelock wrong");
    }

    // Test 2: Timelock delay is 2 days

    function test_TimelockDelay() public view {
        assertEq(timelock.getMinDelay(), TIMELOCK_DELAY, "timelock delay wrong");
    }

    // Test 3: Proposal is created and enters Pending state

    function test_ProposalCreated() public {
        uint256 proposalId = _createProposal();
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending), "should be Pending");
    }

    // Test 4: Holder below threshold cannot propose

    function test_BelowThresholdCannotPropose() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = alice;

        // alice has no tokens → cannot propose
        vm.expectRevert();
        vm.prank(alice);
        governor.propose(targets, values, calldatas, "Alice tries to propose");
    }

    // Test 5: Voting becomes Active after delay

    function test_ProposalBecomesActiveAfterDelay() public {
        uint256 proposalId = _createProposal();

        // Roll past voting delay
        vm.roll(block.number + VOTING_DELAY + 1);

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active), "should be Active");
    }

    // Test 6: Votes are cast correctly

    function test_VotesAreCastCorrectly() public {
        uint256 proposalId = _createProposal();
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voter1);
        governor.castVote(proposalId, 1); // 1 = For

        vm.prank(voter2);
        governor.castVote(proposalId, 0); // 0 = Against

        (uint256 against, uint256 forVotes,) = governor.proposalVotes(proposalId);
        assertEq(forVotes, token.balanceOf(voter1), "for votes wrong");
        assertEq(against, token.balanceOf(voter2), "against votes wrong");
    }

    // Test 7: Proposal succeeds when quorum + majority reached

    function test_ProposalSucceeds() public {
        uint256 proposalId = _createProposal();
        vm.roll(block.number + VOTING_DELAY + 1);

        // voter1 (30%) votes For - exceeds 4% quorum and majority
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        // Roll past voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded), "should be Succeeded");
    }

    // Test 8: Full propose→vote→queue→execute lifecycle

    function test_FullGovernanceLifecycle() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Governance lifecycle test";
        bytes32 descriptionHash = keccak256(bytes(description));

        targets[0] = alice;
        values[0] = 0;
        calldatas[0] = "";

        // 1. Propose
        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // 2. Wait for voting delay
        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // 3. Vote (voter1 has 30% > 4% quorum)
        vm.prank(voter1);
        governor.castVote(proposalId, 1); // For

        // 4. Wait for voting period to end
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // 5. Queue in Timelock
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // 6. Wait for Timelock delay
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        // 7. Execute
        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    }

    // Test 9: proposalNeedsQueuing returns true for a succeeded proposal

    function test_ProposalNeedsQueuing() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = alice;

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "queuing check");

        assertTrue(governor.proposalNeedsQueuing(proposalId), "Governor with Timelock must always need queuing");
    }

    // Test 10: cancel a pending proposal via the governor

    function test_CancelProposal_WhilePending() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "proposal to cancel";
        bytes32 descriptionHash = keccak256(bytes(description));
        targets[0] = alice;

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // Proposer cancels their own proposal before voting starts
        vm.prank(proposer);
        governor.cancel(targets, values, calldatas, descriptionHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }
}
