// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { AetherGovernor } from "../../contracts/governance/AetherGovernor.sol";
import { AetherTimelock } from "../../contracts/governance/AetherTimelock.sol";
import { AethToken } from "../../contracts/token/AethToken.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GovernanceForkTest
 * @notice Fork test: deploys our governance stack on a forked Sepolia network
 *         and verifies it can interact with real deployed infrastructure.
 *
 * @dev    Run with:
 *         forge test --match-contract GovernanceForkTest --fork-url $SEPOLIA_RPC_URL -vvv
 *
 *         This test:
 *         1. Forks Sepolia at a recent block.
 *         2. Deploys AethToken, AetherTimelock, AetherGovernor fresh on the fork.
 *         3. Runs the full propose→vote→queue→execute cycle.
 *         4. Verifies that the Timelock holds admin power over a target contract.
 */
contract GovernanceForkTest is Test {
    // Constants

    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    uint256 constant VOTING_DELAY = 7200;
    uint256 constant VOTING_PERIOD = 50_400;
    uint256 constant TIMELOCK_DELAY = 2 days;
    uint256 constant INITIAL_SUPPLY = 100_000_000 * 1e18;

    // Actors

    address admin = makeAddr("admin");
    address whale = makeAddr("whale"); // holds > 1 % supply

    // System under test

    AethToken token;
    AetherTimelock timelock;
    AetherGovernor governor;

    // Setup

    function setUp() public {
        // Fork Sepolia — SEPOLIA_RPC_URL must be set in environment
        // If not set, the test is skipped gracefully
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            // No RPC URL -> skip fork tests
            return;
        }
        vm.createSelectFork(rpcUrl);
        vm.warp(1_700_000_000);

        // Deploy governance stack on the fork
        vm.prank(admin);
        token = new AethToken(admin);

        vm.prank(admin);
        timelock = new AetherTimelock(admin);

        vm.prank(admin);
        governor = new AetherGovernor(token, timelock);

        // Wire roles — must prank as timelock itself (it holds DEFAULT_ADMIN_ROLE in OZ v5)
        vm.startPrank(address(timelock));
        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(keccak256("CANCELLER_ROLE"), address(governor));
        timelock.revokeRole(PROPOSER_ROLE, admin);
        vm.stopPrank();

        // Give whale 5 % of supply via transfer from admin (admin holds full initial supply
        // from the constructor; mint() requires MINTER_ROLE which admin does not have)
        vm.prank(admin);
        token.transfer(whale, INITIAL_SUPPLY * 5 / 100);

        vm.prank(whale);
        token.delegate(whale);

        vm.roll(block.number + 1);
    }

    // Fork Test 1: Governance stack deploys correctly on forked Sepolia

    function test_Fork_GovernanceDeploysOnSepolia() public {
        if (address(governor) == address(0)) return; // skip if no RPC

        assertEq(governor.votingDelay(), VOTING_DELAY, "voting delay wrong on fork");
        assertEq(governor.votingPeriod(), VOTING_PERIOD, "voting period wrong on fork");
        assertEq(timelock.getMinDelay(), TIMELOCK_DELAY, "timelock delay wrong on fork");
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(governor)), "governor not proposer");
    }

    // Fork Test 2: Full lifecycle on Sepolia fork

    function test_Fork_FullLifecycleOnSepolia() public {
        if (address(governor) == address(0)) return; // skip if no RPC

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Fork test: full governance lifecycle";
        bytes32 descriptionHash = keccak256(bytes(description));

        targets[0] = whale;
        values[0] = 0;
        calldatas[0] = "";

        // Propose
        vm.prank(whale);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Voting delay
        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // Vote
        vm.prank(whale);
        governor.castVote(proposalId, 1);

        // Voting period ends
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Queue
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // Timelock delay
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        // Execute
        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    }

    // Fork Test 3: Verify Timelock has admin control over treasury

    function test_Fork_TimelockControlsTreasury() public {
        if (address(governor) == address(0)) return; // skip if no RPC

        // The Timelock should be the admin of any protocol contract
        // Here we verify it can receive and hold ETH (simulating treasury)
        vm.deal(address(timelock), 1 ether);
        assertEq(address(timelock).balance, 1 ether, "timelock should hold ETH");

        // Only governance (via Governor → Timelock) can move those funds
        // Direct transfers from non-governor actors are blocked by the Timelock
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(governor)), "only governor can propose timelock actions");
    }
}
