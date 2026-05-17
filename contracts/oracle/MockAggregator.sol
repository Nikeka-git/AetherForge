// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MockAggregator
 * @notice Minimal mock of Chainlink AggregatorV3Interface for use in Foundry tests.
 *         Allows tests to set price, decimals, and round data without a live feed.
 *
 * @dev    This contract is intentionally kept in contracts/oracle/ (not test/) so
 *         it can be imported by fork tests and deployment scripts on testnets.
 *         It must NEVER be deployed to mainnet.
 */
contract MockAggregator {
    // State

    int256 private _answer;
    uint8 private _decimals;
    uint256 private _updatedAt;
    uint80 private _roundId;
    string private _description;

    // Errors

    error MockAggregator__StalePrice();

    // Constructor

    /**
     * @param initialAnswer  Initial price (e.g. 2000_00000000 for $2000 with 8 decimals).
     * @param decimals_      Number of decimals (8 for USD feeds, 18 for ETH feeds).
     * @param description_   Human-readable feed name (e.g. "ETH / USD").
     */
    constructor(int256 initialAnswer, uint8 decimals_, string memory description_) {
        _answer = initialAnswer;
        _decimals = decimals_;
        _description = description_;
        _updatedAt = block.timestamp;
        _roundId = 1;
    }

    // Chainlink AggregatorV3Interface

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function version() external pure returns (uint256) {
        return 4;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _roundId);
    }

    function getRoundData(uint80 roundId_)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (roundId_, _answer, _updatedAt, _updatedAt, roundId_);
    }

    // Test helpers

    /**
     * @notice Update the price and mark it as fresh (updatedAt = block.timestamp).
     */
    function setAnswer(int256 newAnswer) external {
        _answer = newAnswer;
        _updatedAt = block.timestamp;
        _roundId++;
    }

    /**
     * @notice Simulate a stale price by setting updatedAt to a past timestamp.
     * @param staleSince Timestamp in the past (e.g. block.timestamp - 2 hours).
     */
    function setStale(uint256 staleSince) external {
        _updatedAt = staleSince;
    }

    /**
     * @notice Simulate an invalid (zero or negative) price.
     */
    function setInvalidAnswer(int256 badAnswer) external {
        _answer = badAnswer;
        _updatedAt = block.timestamp;
        _roundId++;
    }
}
