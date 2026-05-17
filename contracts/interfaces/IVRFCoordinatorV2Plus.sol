// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IVRFCoordinatorV2Plus
 * @notice Minimal Chainlink VRF v2.5 coordinator interface used by PvPArena.
 *         Defined here (instead of inline in PvPArena) so tests can import it
 *         to implement MockVRFCoordinator without circular references.
 *
 * @dev    Full interface: @chainlink/contracts/src/v0.8/vrf/interfaces/IVRFCoordinatorV2Plus.sol
 *         We only declare what PvPArena actually calls.
 */
interface IVRFCoordinatorV2Plus {
    struct RandomWordsRequest {
        bytes32 keyHash;
        uint256 subId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 numWords;
        bytes extraArgs;
    }

    function requestRandomWords(RandomWordsRequest calldata req) external returns (uint256 requestId);
}
