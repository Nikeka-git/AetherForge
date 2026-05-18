// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/* solhint-disable no-console */

import { Script, console2 } from "forge-std/Script.sol";
import { AethToken } from "../contracts/token/AethToken.sol";
import { AetherGovernor } from "../contracts/governance/AetherGovernor.sol";
import { AetherTimelock } from "../contracts/governance/AetherTimelock.sol";
import { HeroNFT } from "../contracts/nft/HeroNFT.sol";

/**
 * @title Verify
 * @author AetherForge Team
 * @notice Post-deployment verification script.
 *         Checks that every privileged role is held by the Timelock (not the deployer),
 *         Governor parameters match the spec, and no admin backdoor remains.
 *
 * @dev Run with:
 *      forge script script/Verify.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
 */
contract Verify is Script {
    // ── Custom errors ─────────────────────────────────────────────────────────

    error VerificationFailed(uint256 failCount);

    // ── Deployed addresses (Arbitrum Sepolia) — EIP-55 checksummed ────────────

    address internal constant AETH_TOKEN = 0x7aA8834926C783F69c5Cad7FCD008A140176c34d;
    address internal constant GUILD_TREASURY = 0x117aBC28A926df44746d36e56a04a4332Aa25c3B;
    address internal constant HERO_NFT = 0x2C40DF51d53CB9Ff32f031D0840d2B8D8C0b7252;
    address internal constant AETHER_GOVERNOR = 0x8A7eF55437AeEBD6e2B9Dde1BFbc143E90d50E80;
    address internal constant AETHER_TIMELOCK = 0x3E31dc90CF05410F062788a9CD9128172f529a18;

    // ── Known roles ───────────────────────────────────────────────────────────

    bytes32 internal constant DEFAULT_ADMIN = 0x00;
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 internal constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 internal constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 internal constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    // ── Expected governance parameters (from spec §3.1) ───────────────────────

    uint256 internal constant EXPECTED_VOTING_DELAY = 7200; // 1 day  (~12 s/block)
    uint256 internal constant EXPECTED_VOTING_PERIOD = 50_400; // 1 week
    uint256 internal constant EXPECTED_QUORUM_BPS = 4; // 4 %
    uint256 internal constant EXPECTED_TIMELOCK_DELAY = 2 days;

    uint256 internal failCount;

    // ─────────────────────────────────────────────────────────────────────────
    // Entry point
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Run all post-deployment checks. Reverts if any check fails.
    function run() external {
        console2.log("=================================================");
        console2.log(unicode" AetherForge -- Post-Deployment Verification");
        console2.log("=================================================");
        console2.log("");

        _checkTimelockDelay();
        _checkGovernorParams();
        _checkAethTokenRoles();
        _checkHeroNFTRoles();
        _checkTimelockGovernorLink();
        _checkNoDeployerAdmin();

        console2.log("");
        if (failCount == 0) {
            console2.log("[PASS] All checks passed.");
        } else {
            console2.log("[FAIL] check(s) failed: %d", failCount);
            revert VerificationFailed(failCount);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Individual checks
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Verify Timelock minimum delay equals 2 days.
    function _checkTimelockDelay() internal {
        AetherTimelock tl = AetherTimelock(payable(AETHER_TIMELOCK));
        uint256 delay = tl.getMinDelay();
        _assert(
            delay == EXPECTED_TIMELOCK_DELAY,
            string(abi.encodePacked("Timelock delay: expected ", _uint(EXPECTED_TIMELOCK_DELAY), " got ", _uint(delay)))
        );
        console2.log("[OK] Timelock min delay = %d seconds (2 days)", delay);
    }

    /// @notice Verify Governor votingDelay, votingPeriod, and quorum match the spec.
    function _checkGovernorParams() internal {
        AetherGovernor gov = AetherGovernor(payable(AETHER_GOVERNOR));

        uint256 vDelay = gov.votingDelay();
        _assert(
            vDelay == EXPECTED_VOTING_DELAY,
            string(abi.encodePacked("votingDelay: expected ", _uint(EXPECTED_VOTING_DELAY), " got ", _uint(vDelay)))
        );
        console2.log("[OK] Governor.votingDelay  = %d blocks", vDelay);

        uint256 vPeriod = gov.votingPeriod();
        _assert(
            vPeriod == EXPECTED_VOTING_PERIOD,
            string(abi.encodePacked("votingPeriod: expected ", _uint(EXPECTED_VOTING_PERIOD), " got ", _uint(vPeriod)))
        );
        console2.log("[OK] Governor.votingPeriod = %d blocks", vPeriod);

        uint256 qFrac = gov.quorumNumerator();
        _assert(
            qFrac == EXPECTED_QUORUM_BPS,
            string(abi.encodePacked("quorum: expected ", _uint(EXPECTED_QUORUM_BPS), "% got ", _uint(qFrac), "%"))
        );
        console2.log("[OK] Governor.quorum       = %d%%", qFrac);
    }

    /// @notice Verify AethToken role assignments.
    function _checkAethTokenRoles() internal {
        AethToken token = AethToken(AETH_TOKEN);

        _assert(token.hasRole(DEFAULT_ADMIN, AETHER_TIMELOCK), "AethToken: Timelock does not hold DEFAULT_ADMIN_ROLE");
        console2.log("[OK] AethToken DEFAULT_ADMIN_ROLE -> Timelock");

        // Deployer must NOT hold DEFAULT_ADMIN anymore.
        // AethToken uses plain AccessControl (no enumerable) so we cannot count
        // members — instead we verify the deployer key is absent by checking the
        // msg.sender of this script (the operator running verification).
        address operator = msg.sender;
        _assert(!token.hasRole(DEFAULT_ADMIN, operator), "AethToken: script operator still holds DEFAULT_ADMIN_ROLE");
        console2.log("[OK] AethToken DEFAULT_ADMIN_ROLE not held by operator");

        _assert(token.hasRole(MINTER_ROLE, GUILD_TREASURY), "AethToken: GuildTreasury does not hold MINTER_ROLE");
        console2.log("[OK] AethToken MINTER_ROLE -> GuildTreasury");
    }

    /// @notice Verify HeroNFT role assignments.
    function _checkHeroNFTRoles() internal {
        HeroNFT hero = HeroNFT(HERO_NFT);

        _assert(hero.hasRole(DEFAULT_ADMIN, AETHER_TIMELOCK), "HeroNFT: Timelock does not hold DEFAULT_ADMIN_ROLE");
        console2.log("[OK] HeroNFT DEFAULT_ADMIN_ROLE -> Timelock");

        _assert(hero.hasRole(UPGRADER_ROLE, AETHER_TIMELOCK), "HeroNFT: Timelock does not hold UPGRADER_ROLE");
        console2.log("[OK] HeroNFT UPGRADER_ROLE -> Timelock");
    }

    /// @notice Verify Governor holds PROPOSER/CANCELLER and EXECUTOR is open.
    function _checkTimelockGovernorLink() internal {
        AetherTimelock tl = AetherTimelock(payable(AETHER_TIMELOCK));

        _assert(tl.hasRole(PROPOSER_ROLE, AETHER_GOVERNOR), "Timelock: Governor does not hold PROPOSER_ROLE");
        console2.log("[OK] Timelock PROPOSER_ROLE -> Governor");

        _assert(tl.hasRole(CANCELLER_ROLE, AETHER_GOVERNOR), "Timelock: Governor does not hold CANCELLER_ROLE");
        console2.log("[OK] Timelock CANCELLER_ROLE -> Governor");

        _assert(tl.hasRole(EXECUTOR_ROLE, address(0)), "Timelock: EXECUTOR_ROLE is not open (address(0) not granted)");
        console2.log("[OK] Timelock EXECUTOR_ROLE -> open (address(0))");
    }

    /// @notice Verify deployer (operator) no longer holds DEFAULT_ADMIN on the Timelock itself.
    function _checkNoDeployerAdmin() internal {
        AetherTimelock tl = AetherTimelock(payable(AETHER_TIMELOCK));
        address operator = msg.sender;

        _assert(!tl.hasRole(DEFAULT_ADMIN, operator), "Timelock: operator still holds DEFAULT_ADMIN_ROLE");
        console2.log("[OK] Timelock DEFAULT_ADMIN_ROLE not held by operator");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Log a failure and increment the counter; pass silently.
     * @param condition The invariant to assert.
     * @param message   Human-readable description logged on failure.
     */
    function _assert(bool condition, string memory message) internal {
        if (!condition) {
            console2.log("[FAIL] %s", message);
            ++failCount;
        }
    }

    /**
     * @notice Convert a uint256 to its decimal string representation.
     * @param v The value to convert.
     * @return  Decimal string.
     */
    function _uint(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 tmp = v;
        uint256 digits;
        while (tmp != 0) {
            ++digits;
            tmp /= 10;
        }
        bytes memory buf = new bytes(digits);
        while (v != 0) {
            --digits;
            buf[digits] = bytes1(uint8(48 + (v % 10)));
            v /= 10;
        }
        return string(buf);
    }
}
