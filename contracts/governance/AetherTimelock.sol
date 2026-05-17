// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title AetherTimelock
 * @notice TimelockController for AetherForge Arena governance.
 *
 * Configuration (immutable after deploy)
 * ────────────────────────────────────────
 * minDelay  = 2 days  — any queued action must wait 2 days before execution.
 * PROPOSER  -> AetherGovernor (only the Governor can queue proposals).
 * CANCELLER -> AetherGovernor (Governor can cancel queued proposals).
 * EXECUTOR  -> address(0)  (anyone can trigger execution after the delay).
 * ADMIN     -> revoked from deployer in the constructor (no backdoor).
 *
 * The Timelock controls the treasury and any protocol parameters that require
 * governance approval. A 2-day delay gives token holders time to react before
 * a malicious or mistaken proposal takes effect.
 */
contract AetherTimelock is TimelockController {
    uint256 public constant MIN_DELAY = 2 days;

    /**
     * @param governor Address of the AetherGovernor contract.
     *                 Receives PROPOSER_ROLE and CANCELLER_ROLE.
     */
    constructor(address governor)
        TimelockController(
            MIN_DELAY,
            _toArray(governor), // proposers
            _toArray(address(0)), // executors — open (anyone can execute after delay)
            address(0) // admin — address(0) means no extra admin; deployer admin is auto-revoked
        )
    { }

    // Internal helpers

    function _toArray(address a) private pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }
}
