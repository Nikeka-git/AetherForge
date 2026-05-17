// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ChainlinkPriceAdapter } from "../../contracts/oracle/ChainlinkPriceAdapter.sol";
import { MockAggregator } from "../../contracts/oracle/MockAggregator.sol";

/**
 * @title ChainlinkPriceAdapterTest
 * @notice 10 unit tests for ChainlinkPriceAdapter.
 *         Run with: forge test --match-contract ChainlinkPriceAdapterTest -vv
 */
contract ChainlinkPriceAdapterTest is Test {
    // Constants

    uint256 constant MAX_STALENESS = 3600; // 1 hour
    int256 constant ETH_PRICE = 200_000_000_000; // $2000 with 8 decimals
    uint8 constant DECIMALS = 8;

    // Actors

    address admin = makeAddr("admin");
    address alice = makeAddr("alice");

    // System under test

    MockAggregator mock;
    ChainlinkPriceAdapter adapter;

    function setUp() public {
        // Warp to a realistic timestamp so block.timestamp - N hours doesn't underflow
        vm.warp(1_700_000_000);

        mock = new MockAggregator(ETH_PRICE, DECIMALS, "ETH / USD");
        adapter = new ChainlinkPriceAdapter(address(mock), MAX_STALENESS, admin);
    }

    // Test 1: latestPrice returns correct price and decimals

    function test_LatestPriceReturnsCorrectValue() public view {
        (int256 price, uint8 decimals) = adapter.latestPrice();
        assertEq(price, ETH_PRICE, "price wrong");
        assertEq(decimals, DECIMALS, "decimals wrong");
    }

    // Test 2: latestPriceUint returns uint256 price

    function test_LatestPriceUintReturnsUint() public view {
        uint256 price = adapter.latestPriceUint();
        assertEq(price, uint256(ETH_PRICE), "uint price wrong");
    }

    // Test 3: Stale price reverts

    function test_StalePriceReverts() public {
        // Make the price stale by setting updatedAt to 2 hours ago
        mock.setStale(block.timestamp - 2 hours);

        vm.expectRevert(
            abi.encodeWithSelector(
                ChainlinkPriceAdapter.ChainlinkPriceAdapter__StalePrice.selector,
                block.timestamp - 2 hours,
                MAX_STALENESS
            )
        );
        adapter.latestPrice();
    }

    // Test 4: Price exactly at staleness boundary does not revert

    function test_PriceAtStalenessThresholdDoesNotRevert() public {
        // updatedAt = block.timestamp - maxStaleness → age == maxStaleness → NOT stale
        mock.setStale(block.timestamp - MAX_STALENESS);
        (int256 price,) = adapter.latestPrice();
        assertEq(price, ETH_PRICE, "price at boundary should be valid");
    }

    // Test 5: Zero price reverts

    function test_ZeroPriceReverts() public {
        mock.setInvalidAnswer(0);

        vm.expectRevert(
            abi.encodeWithSelector(ChainlinkPriceAdapter.ChainlinkPriceAdapter__InvalidPrice.selector, int256(0))
        );
        adapter.latestPrice();
    }

    // Test 6: Negative price reverts

    function test_NegativePriceReverts() public {
        mock.setInvalidAnswer(-1);

        vm.expectRevert(
            abi.encodeWithSelector(ChainlinkPriceAdapter.ChainlinkPriceAdapter__InvalidPrice.selector, int256(-1))
        );
        adapter.latestPrice();
    }

    // Test 7: Admin can update feed

    function test_AdminCanUpdateFeed() public {
        MockAggregator newMock = new MockAggregator(300_000_000_000, DECIMALS, "ETH / USD v2");

        vm.prank(admin);
        adapter.setFeed(address(newMock));

        assertEq(address(adapter.feed()), address(newMock), "feed not updated");

        (int256 price,) = adapter.latestPrice();
        assertEq(price, 300_000_000_000, "new feed price wrong");
    }

    // Test 8: Non-admin cannot update feed

    function test_NonAdminCannotUpdateFeed() public {
        MockAggregator newMock = new MockAggregator(300_000_000_000, DECIMALS, "ETH / USD v2");

        vm.expectRevert();
        vm.prank(alice);
        adapter.setFeed(address(newMock));
    }

    // Test 9: Admin can update maxStaleness

    function test_AdminCanUpdateMaxStaleness() public {
        uint256 newStaleness = 7200; // 2 hours

        vm.prank(admin);
        adapter.setMaxStaleness(newStaleness);

        assertEq(adapter.maxStaleness(), newStaleness, "maxStaleness not updated");

        // Price that was stale at 1h should now be valid at 2h threshold
        mock.setStale(block.timestamp - 5400); // 1.5 hours ago
        (int256 price,) = adapter.latestPrice();
        assertEq(price, ETH_PRICE, "price should be valid with new staleness");
    }

    // Test 10: Price update reflected immediately

    function test_PriceUpdateReflectedImmediately() public {
        int256 newPrice = 180_000_000_000; // $1800
        mock.setAnswer(newPrice);

        (int256 price,) = adapter.latestPrice();
        assertEq(price, newPrice, "updated price not reflected");
    }
}
