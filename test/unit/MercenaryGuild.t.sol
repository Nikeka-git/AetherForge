// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import { MercenaryGuild } from "../../contracts/rental/MercenaryGuild.sol";

/**
 * @dev OZ v5 calls onERC721Received / onERC1155Received on ALL token recipients.
 *      TokenReceiver implements both hooks so it can safely receive NFTs in tests.
 */
contract TokenReceiver is ERC721Holder, ERC1155Holder { }

// Mock helpers

/// @dev Simple ERC-20 used as the AETH payment token in tests.
contract MockAETH is ERC20 {
    constructor() ERC20("Aether", "AETH") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Minimal ERC-721 with open mint. Simulates HeroNFT in unit tests.
contract MockHeroNFT is ERC721 {
    uint256 private _nextId;

    constructor() ERC721("MockHero", "MHERO") { }

    function mint(address to) external returns (uint256 id) {
        id = ++_nextId;
        _mint(to, id);
    }
}

/// @dev Minimal ERC-1155 with open mint. Simulates ItemRegistry in unit tests.
contract MockItemRegistry is ERC1155 {
    constructor() ERC1155("https://mock-items/{id}.json") { }

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }
}

// Tests

/**
 * @title  MercenaryGuildTest
 * @notice Unit tests for MercenaryGuild.sol — NFT rental escrow.
 *
 * Run:
 *   forge test --match-contract MercenaryGuildTest -vv
 *
 * Coverage target: every public/external function + all custom revert paths.
 *
 * Test inventory (22 tests)
 * ─────────────────────────
 *  Constructor
 *   1.  test_Constructor_SetsStateCorrectly
 *   2.  test_Constructor_RevertsOnZeroPaymentToken
 *   3.  test_Constructor_RevertsOnZeroAdmin
 *   4.  test_Constructor_RevertsOnZeroFeeRecipient
 *   5.  test_Constructor_RevertsOnFeeTooHigh
 *  list
 *   6.  test_List_ERC721_TransfersNFTAndCreatesListing
 *   7.  test_List_ERC1155_TransfersItemsAndCreatesListing
 *   8.  test_List_RevertsOnZeroPrice
 *   9.  test_List_RevertsOnInvalidDuration
 *  rent
 *  10.  test_Rent_DeductsFeeAndMarketsListing
 *  11.  test_Rent_ProtocolFeeForwardedToRecipient
 *  12.  test_Rent_RevertsIfListingNotFound
 *  13.  test_Rent_RevertsIfAlreadyRented
 *  14.  test_Rent_RevertsIfDurationOutOfRange
 *  returnEarly
 *  15.  test_ReturnEarly_ReturnsNFTToLenderAndRelistsListing
 *  16.  test_ReturnEarly_RevertsIfNotBorrower
 *  reclaimExpired
 *  17.  test_ReclaimExpired_SucceedsAfterEndTime
 *  18.  test_ReclaimExpired_RevertsIfNotExpired
 *  19.  test_ReclaimExpired_RevertsIfNotLender
 *  cancelListing
 *  20.  test_CancelListing_ReturnsNFTAndCancelsState
 *  21.  test_CancelListing_RevertsIfRented
 *  claimFees
 *  22.  test_ClaimFees_PullsAccumulatedFeesAndResetsBalance
 */
contract MercenaryGuildTest is Test {
    // Role constants

    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Actors

    address internal admin = makeAddr("admin");
    address internal feeRecipient = makeAddr("feeRecipient");
    // OZ v5: token transfers call onReceived on ALL recipients.
    // alice and bob must implement ERC721Receiver + ERC1155Receiver.
    TokenReceiver internal aliceReceiver;
    TokenReceiver internal bobReceiver;
    address internal alice; // = address(aliceReceiver), set in setUp
    address internal bob; // = address(bobReceiver),   set in setUp
    address internal eve = makeAddr("eve"); // attacker (never receives tokens directly)

    // Contracts

    MockAETH internal aeth;
    MockHeroNFT internal heroNFT;
    MockItemRegistry internal itemRegistry;
    MercenaryGuild internal guild;

    // Shared parameters

    uint256 constant PROTOCOL_FEE_BPS = 200; // 2 %
    uint256 constant PRICE_PER_DAY = 100 * 1e18; // 100 AETH / day
    uint256 constant MIN_DURATION = 1 days;
    uint256 constant MAX_DURATION = 7 days;
    uint256 constant RENTAL_DURATION = 3 days; // 3 days -> fee = 300 AETH
    uint256 constant TOTAL_FEE = (PRICE_PER_DAY * RENTAL_DURATION) / 1 days; // 300e18

    // Setup

    function setUp() public {
        // Deploy receiver contracts so OZ v5 token transfer hooks pass
        aliceReceiver = new TokenReceiver();
        bobReceiver = new TokenReceiver();
        alice = address(aliceReceiver);
        bob = address(bobReceiver);

        aeth = new MockAETH();
        heroNFT = new MockHeroNFT();
        itemRegistry = new MockItemRegistry();

        guild = new MercenaryGuild(address(aeth), admin, feeRecipient, PROTOCOL_FEE_BPS);

        // Fund bob with enough AETH to cover rental fees in all tests
        aeth.mint(bob, 10_000 * 1e18);
        vm.prank(bob);
        aeth.approve(address(guild), type(uint256).max);

        // Mint a hero NFT to alice
        vm.prank(alice);
        heroNFT.mint(alice); // tokenId = 1
    }

    // Internal helpers

    /// @dev List alice's hero (tokenId 1) and return the listing ID.
    function _listHero() internal returns (uint256 listingId) {
        vm.startPrank(alice);
        heroNFT.approve(address(guild), 1);
        listingId = guild.list(
            address(heroNFT), 1, 1, MercenaryGuild.AssetType.ERC721, PRICE_PER_DAY, MIN_DURATION, MAX_DURATION
        );
        vm.stopPrank();
    }

    /// @dev List alice's hero and immediately rent it from bob. Returns (listingId, rentalId).
    function _listAndRent() internal returns (uint256 listingId, uint256 rentalId) {
        listingId = _listHero();
        vm.prank(bob);
        rentalId = guild.rent(listingId, RENTAL_DURATION);
    }

    // 1. Constructor

    function test_Constructor_SetsStateCorrectly() public view {
        assertEq(address(guild.paymentToken()), address(aeth), "paymentToken wrong");
        assertEq(guild.feeRecipient(), feeRecipient, "feeRecipient wrong");
        assertEq(guild.protocolFeeBps(), PROTOCOL_FEE_BPS, "protocolFeeBps wrong");
        assertTrue(guild.hasRole(guild.DEFAULT_ADMIN_ROLE(), admin), "admin role missing");
        assertTrue(guild.hasRole(ADMIN_ROLE, admin), "ADMIN_ROLE missing");
    }

    function test_Constructor_RevertsOnZeroPaymentToken() public {
        vm.expectRevert(MercenaryGuild.Guild__ZeroAddress.selector);
        new MercenaryGuild(address(0), admin, feeRecipient, PROTOCOL_FEE_BPS);
    }

    function test_Constructor_RevertsOnZeroAdmin() public {
        vm.expectRevert(MercenaryGuild.Guild__ZeroAddress.selector);
        new MercenaryGuild(address(aeth), address(0), feeRecipient, PROTOCOL_FEE_BPS);
    }

    function test_Constructor_RevertsOnZeroFeeRecipient() public {
        vm.expectRevert(MercenaryGuild.Guild__ZeroAddress.selector);
        new MercenaryGuild(address(aeth), admin, address(0), PROTOCOL_FEE_BPS);
    }

    function test_Constructor_RevertsOnFeeTooHigh() public {
        uint256 badFee = guild.MAX_FEE_BPS() + 1;
        vm.expectRevert(abi.encodeWithSelector(MercenaryGuild.Guild__FeeTooHigh.selector, badFee, guild.MAX_FEE_BPS()));
        new MercenaryGuild(address(aeth), admin, feeRecipient, badFee);
    }

    // 6. list - ERC-721

    function test_List_ERC721_TransfersNFTAndCreatesListing() public {
        vm.startPrank(alice);
        heroNFT.approve(address(guild), 1);
        uint256 listingId = guild.list(
            address(heroNFT), 1, 1, MercenaryGuild.AssetType.ERC721, PRICE_PER_DAY, MIN_DURATION, MAX_DURATION
        );
        vm.stopPrank();

        assertEq(listingId, 1, "first listing should have id 1");
        // NFT must now be held by the guild (escrow)
        assertEq(heroNFT.ownerOf(1), address(guild), "guild should hold the NFT");

        (
            address lender,
            address nftContract,
            uint256 tokenId,
            uint256 amount,
            MercenaryGuild.AssetType assetType,,,,
            MercenaryGuild.ListingState state
        ) = guild.listings(listingId);

        assertEq(lender, alice, "lender wrong");
        assertEq(nftContract, address(heroNFT), "nftContract wrong");
        assertEq(tokenId, 1, "tokenId wrong");
        assertEq(amount, 1, "amount wrong");
        assertEq(uint8(assetType), uint8(MercenaryGuild.AssetType.ERC721), "assetType wrong");
        assertEq(uint8(state), uint8(MercenaryGuild.ListingState.Available), "state should be Available");
    }

    // 7. list - ERC-1155

    function test_List_ERC1155_TransfersItemsAndCreatesListing() public {
        uint256 itemId = 1; // iron ore
        uint256 itemAmount = 50;

        itemRegistry.mint(alice, itemId, itemAmount);

        vm.startPrank(alice);
        itemRegistry.setApprovalForAll(address(guild), true);
        uint256 listingId = guild.list(
            address(itemRegistry),
            itemId,
            itemAmount,
            MercenaryGuild.AssetType.ERC1155,
            PRICE_PER_DAY,
            MIN_DURATION,
            MAX_DURATION
        );
        vm.stopPrank();

        assertEq(listingId, 1, "listing id wrong");
        assertEq(itemRegistry.balanceOf(address(guild), itemId), itemAmount, "guild should hold the items");
        assertEq(itemRegistry.balanceOf(alice, itemId), 0, "alice should have no items left");
    }

    // 8–9. list - reverts

    function test_List_RevertsOnZeroPrice() public {
        vm.startPrank(alice);
        heroNFT.approve(address(guild), 1);
        vm.expectRevert(MercenaryGuild.Guild__ZeroPrice.selector);
        guild.list(address(heroNFT), 1, 1, MercenaryGuild.AssetType.ERC721, 0, MIN_DURATION, MAX_DURATION);
        vm.stopPrank();
    }

    function test_List_RevertsOnInvalidDuration() public {
        vm.startPrank(alice);
        heroNFT.approve(address(guild), 1);
        // minDuration > maxDuration is invalid
        vm.expectRevert(abi.encodeWithSelector(MercenaryGuild.Guild__InvalidDuration.selector, 7 days, 1 days));
        guild.list(address(heroNFT), 1, 1, MercenaryGuild.AssetType.ERC721, PRICE_PER_DAY, 7 days, 1 days);
        vm.stopPrank();
    }

    // 10. rent - happy path

    function test_Rent_DeductsFeeAndMarketsListing() public {
        uint256 listingId = _listHero();

        uint256 bobBalBefore = aeth.balanceOf(bob);

        vm.prank(bob);
        uint256 rentalId = guild.rent(listingId, RENTAL_DURATION);

        // Rental record
        (, address borrower, uint256 startTime, uint256 endTime, uint256 totalFee) = guild.rentals(rentalId);
        assertEq(rentalId, 1, "first rental should have id 1");
        assertEq(borrower, bob, "borrower wrong");
        assertEq(endTime, startTime + RENTAL_DURATION, "endTime wrong");
        assertEq(totalFee, TOTAL_FEE, "totalFee wrong");

        // Listing state flipped to Rented
        (,,,,,,,, MercenaryGuild.ListingState state) = guild.listings(listingId);
        assertEq(uint8(state), uint8(MercenaryGuild.ListingState.Rented), "listing should be Rented");

        // Bob paid TOTAL_FEE
        assertEq(aeth.balanceOf(bob), bobBalBefore - TOTAL_FEE, "bob was not charged correctly");

        // borrowerOf view
        assertEq(guild.borrowerOf(listingId), bob, "borrowerOf should return bob");
        assertTrue(guild.isActivelyRented(listingId), "isActivelyRented should be true");
    }

    // 11. rent - protocol fee forwarding

    function test_Rent_ProtocolFeeForwardedToRecipient() public {
        uint256 listingId = _listHero();

        uint256 recipientBalBefore = aeth.balanceOf(feeRecipient);
        uint256 alicePendingBefore = guild.pendingFees(alice);

        vm.prank(bob);
        guild.rent(listingId, RENTAL_DURATION);

        uint256 protocolFee = (TOTAL_FEE * PROTOCOL_FEE_BPS) / 10_000;
        uint256 lenderFee = TOTAL_FEE - protocolFee;

        // Protocol fee forwarded immediately
        assertEq(aeth.balanceOf(feeRecipient), recipientBalBefore + protocolFee, "protocol fee not forwarded");
        // Lender fee accrued in pendingFees (pull-over-push)
        assertEq(guild.pendingFees(alice), alicePendingBefore + lenderFee, "lender pending fee wrong");
    }

    // 12-14. rent - reverts

    function test_Rent_RevertsIfListingNotFound() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MercenaryGuild.Guild__ListingNotFound.selector, 999));
        guild.rent(999, RENTAL_DURATION);
    }

    function test_Rent_RevertsIfAlreadyRented() public {
        (uint256 listingId,) = _listAndRent();

        // Second borrower tries to rent the same listing
        aeth.mint(eve, 10_000 * 1e18);
        vm.prank(eve);
        aeth.approve(address(guild), type(uint256).max);

        vm.prank(eve);
        vm.expectRevert(
            abi.encodeWithSelector(
                MercenaryGuild.Guild__NotAvailable.selector, listingId, MercenaryGuild.ListingState.Rented
            )
        );
        guild.rent(listingId, RENTAL_DURATION);
    }

    function test_Rent_RevertsIfDurationOutOfRange() public {
        uint256 listingId = _listHero();

        uint256 tooShort = MIN_DURATION - 1;

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                MercenaryGuild.Guild__DurationOutOfRange.selector, tooShort, MIN_DURATION, MAX_DURATION
            )
        );
        guild.rent(listingId, tooShort);
    }

    // 15. returnEarly

    function test_ReturnEarly_ReturnsNFTToLenderAndRelistsListing() public {
        (uint256 listingId, uint256 rentalId) = _listAndRent();

        vm.prank(bob);
        guild.returnEarly(rentalId);

        // NFT back with alice (lender)
        assertEq(heroNFT.ownerOf(1), alice, "NFT should be returned to lender");

        // Listing is Available again
        (,,,,,,,, MercenaryGuild.ListingState state) = guild.listings(listingId);
        assertEq(uint8(state), uint8(MercenaryGuild.ListingState.Available), "listing should be Available after return");

        // activeRental cleared
        assertEq(guild.activeRental(listingId), 0, "activeRental should be cleared");
        // borrowerOf returns zero
        assertEq(guild.borrowerOf(listingId), address(0), "borrowerOf should be zero after return");
    }

    // 16. returnEarly - revert if not borrower

    function test_ReturnEarly_RevertsIfNotBorrower() public {
        (, uint256 rentalId) = _listAndRent();

        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(MercenaryGuild.Guild__NotBorrower.selector, eve, rentalId));
        guild.returnEarly(rentalId);
    }

    // 17. reclaimExpired - success

    function test_ReclaimExpired_SucceedsAfterEndTime() public {
        (uint256 listingId, uint256 rentalId) = _listAndRent();

        // Advance past rental end
        (,,, uint256 endTime,) = guild.rentals(rentalId);
        vm.warp(endTime + 1);

        vm.prank(alice);
        guild.reclaimExpired(rentalId);

        assertEq(heroNFT.ownerOf(1), alice, "NFT should be back with lender");
        (,,,,,,,, MercenaryGuild.ListingState state) = guild.listings(listingId);
        assertEq(uint8(state), uint8(MercenaryGuild.ListingState.Available), "listing should be Available");
    }

    // 18. reclaimExpired - revert if not yet expired

    function test_ReclaimExpired_RevertsIfNotExpired() public {
        (, uint256 rentalId) = _listAndRent();

        // Still within rental period
        (,,, uint256 endTime,) = guild.rentals(rentalId);
        vm.expectRevert(abi.encodeWithSelector(MercenaryGuild.Guild__RentalNotExpired.selector, rentalId, endTime));
        vm.prank(alice);
        guild.reclaimExpired(rentalId);
    }

    // 19. reclaimExpired - revert if wrong caller

    function test_ReclaimExpired_RevertsIfNotLender() public {
        (uint256 listingId, uint256 rentalId) = _listAndRent();

        (,,, uint256 endTime,) = guild.rentals(rentalId);
        vm.warp(endTime + 1);

        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(MercenaryGuild.Guild__NotLender.selector, eve, listingId));
        guild.reclaimExpired(rentalId);
    }

    // 20. cancelListing

    function test_CancelListing_ReturnsNFTAndCancelsState() public {
        uint256 listingId = _listHero();

        vm.prank(alice);
        guild.cancelListing(listingId);

        assertEq(heroNFT.ownerOf(1), alice, "NFT should be returned on cancel");
        (,,,,,,,, MercenaryGuild.ListingState state) = guild.listings(listingId);
        assertEq(uint8(state), uint8(MercenaryGuild.ListingState.Cancelled), "listing should be Cancelled");
    }

    // 21. cancelListing - revert if rented

    function test_CancelListing_RevertsIfRented() public {
        (uint256 listingId,) = _listAndRent();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                MercenaryGuild.Guild__NotAvailable.selector, listingId, MercenaryGuild.ListingState.Rented
            )
        );
        guild.cancelListing(listingId);
    }

    // 22. claimFees

    function test_ClaimFees_PullsAccumulatedFeesAndResetsBalance() public {
        _listAndRent(); // alice earns lender fee

        uint256 pendingBefore = guild.pendingFees(alice);
        assertGt(pendingBefore, 0, "alice should have pending fees after rental");

        uint256 aliceBalBefore = aeth.balanceOf(alice);

        vm.prank(alice);
        guild.claimFees();

        assertEq(aeth.balanceOf(alice), aliceBalBefore + pendingBefore, "alice did not receive fees");
        assertEq(guild.pendingFees(alice), 0, "pendingFees should be zeroed after claim");

        // Second claim reverts (nothing left)
        vm.prank(alice);
        vm.expectRevert(MercenaryGuild.Guild__NothingToClaim.selector);
        guild.claimFees();
    }
}
