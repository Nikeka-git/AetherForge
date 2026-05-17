// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

interface IAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function decimals() external view returns (uint8);
}

/**
 * @title ChainlinkPriceAdapter
 * @notice Thin adapter over a Chainlink AggregatorV3 price feed.
 *
 * Responsibilities
 * ────────────────
 * 1. Staleness check — revert if price is older than `maxStaleness` seconds.
 * 2. Sanity check    — revert if price <= 0 (feed malfunction / depegged).
 * 3. Single source of truth — all protocol contracts read price through here,
 *    so a feed swap requires only one contract upgrade instead of N.
 *
 * Oracle adapter / interface abstraction (Design Pattern §4.1)
 * ────────────────────────────────────────────────────────────
 * The adapter decouples the protocol from the concrete AggregatorV3Interface.
 * If Chainlink changes their interface or the project migrates to a different
 * oracle provider, only this adapter needs to change.
 *
 * Roles
 * ─────
 * DEFAULT_ADMIN_ROLE — can update the feed address and maxStaleness
 *                      (should be NVTimelock post-deploy)
 */
contract ChainlinkPriceAdapter is AccessControl {
    // State

    /// @notice The underlying Chainlink feed.
    IAggregatorV3 public feed;

    /// @notice Maximum age of a price update before it is considered stale (seconds).
    uint256 public maxStaleness;

    // Errors

    error ChainlinkPriceAdapter__StalePrice(uint256 updatedAt, uint256 maxStaleness);
    error ChainlinkPriceAdapter__InvalidPrice(int256 price);
    error ChainlinkPriceAdapter__ZeroAddress();
    error ChainlinkPriceAdapter__ZeroStaleness();

    // Events

    event FeedUpdated(address indexed oldFeed, address indexed newFeed);
    event MaxStalenessUpdated(uint256 oldStaleness, uint256 newStaleness);

    // Constructor

    /**
     * @param feed_         Address of the Chainlink AggregatorV3 price feed.
     * @param maxStaleness_ Maximum acceptable age of a price in seconds (e.g. 3600 = 1 hour).
     * @param admin         Receives DEFAULT_ADMIN_ROLE (should be Timelock).
     */
    constructor(address feed_, uint256 maxStaleness_, address admin) {
        if (feed_ == address(0)) revert ChainlinkPriceAdapter__ZeroAddress();
        if (maxStaleness_ == 0) revert ChainlinkPriceAdapter__ZeroStaleness();
        if (admin == address(0)) revert ChainlinkPriceAdapter__ZeroAddress();

        feed = IAggregatorV3(feed_);
        maxStaleness = maxStaleness_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // Price query

    /**
     * @notice Return the latest price from the Chainlink feed.
     * @dev    Reverts if:
     *         - The price is older than `maxStaleness` seconds (staleness check).
     *         - The price is zero or negative (sanity check).
     *
     * @return price    Latest price with feed's native decimals.
     * @return decimals Number of decimals in the returned price.
     */
    function latestPrice() external view returns (int256 price, uint8 decimals) {
        // slither-disable-next-line unused-return
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();

        if (block.timestamp - updatedAt > maxStaleness) {
            revert ChainlinkPriceAdapter__StalePrice(updatedAt, maxStaleness);
        }
        if (answer <= 0) {
            revert ChainlinkPriceAdapter__InvalidPrice(answer);
        }

        return (answer, feed.decimals());
    }

    /**
     * @notice Return the latest price, reverts on staleness or invalid value.
     * @return price Latest price as uint256 (safe cast after > 0 check above).
     */
    function latestPriceUint() external view returns (uint256 price) {
        // slither-disable-next-line unused-return
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();

        if (block.timestamp - updatedAt > maxStaleness) {
            revert ChainlinkPriceAdapter__StalePrice(updatedAt, maxStaleness);
        }
        if (answer <= 0) {
            revert ChainlinkPriceAdapter__InvalidPrice(answer);
        }

        return uint256(answer);
    }

    // Admin functions

    /**
     * @notice Update the Chainlink feed address (e.g. when migrating to a new feed).
     * @dev    Only callable by DEFAULT_ADMIN_ROLE (Timelock via governance proposal).
     */
    function setFeed(address newFeed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newFeed == address(0)) revert ChainlinkPriceAdapter__ZeroAddress();
        address old = address(feed);
        feed = IAggregatorV3(newFeed);
        emit FeedUpdated(old, newFeed);
    }

    /**
     * @notice Update the maximum staleness threshold.
     * @dev    Only callable by DEFAULT_ADMIN_ROLE (Timelock via governance proposal).
     */
    function setMaxStaleness(uint256 newMaxStaleness) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMaxStaleness == 0) revert ChainlinkPriceAdapter__ZeroStaleness();
        uint256 old = maxStaleness;
        maxStaleness = newMaxStaleness;
        emit MaxStalenessUpdated(old, newMaxStaleness);
    }
}
