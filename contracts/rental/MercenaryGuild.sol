// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title  MercenaryGuild
 * @notice NFT rental escrow for AetherForge Arena.
 *         Lenders deposit heroes (ERC-721) and items (ERC-1155) into escrow.
 *         Borrowers rent them for a fixed duration, paying in AETH.
 *         Game contracts query borrowerOf() to grant in-game usage rights.
 *
 * Rental flow
 * ───────────
 * 1. Lender calls list()           -> NFT transferred to this contract (escrow).
 * 2. Borrower calls rent()         -> fee paid in AETH; rental record created.
 * 3. Game contracts call borrowerOf(listingId) to check active renter.
 * 4a. Borrower calls returnEarly() -> NFT returned to lender; listing Available again.
 * 4b. Lender calls reclaimExpired() after endTime -> NFT returned; listing Available.
 * 5.  Lender calls claimFees()     -> accumulated AETH fees withdrawn (pull-over-push).
 *
 * Design patterns
 * ───────────────
 * Pull-over-push  - pendingFees[lender] accumulates; never pushed.
 * CEI             - checks -> effects -> interactions in every write function.
 * ReentrancyGuard - nonReentrant on all state-changing public functions.
 * AccessControl   - ADMIN_ROLE (Timelock post-deploy).
 * Escrow          - NFTs held by this contract for the rental duration.
 *
 * Roles
 * ─────
 * DEFAULT_ADMIN_ROLE - grant/revoke roles (transferred to Timelock post-deploy).
 * ADMIN_ROLE         - setProtocolFee, setFeeRecipient.
 */
contract MercenaryGuild is AccessControl, ReentrancyGuard, IERC721Receiver, IERC1155Receiver {
    using SafeERC20 for IERC20;

    // Constants

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @dev Protocol fee ceiling: 10 % (1000 bps).
    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant SECONDS_PER_DAY = 86_400;

    // Types

    enum AssetType {
        ERC721,
        ERC1155
    }

    enum ListingState {
        Available,
        Rented,
        Cancelled
    }

    struct Listing {
        address lender;
        address nftContract;
        uint256 tokenId;
        uint256 amount; // always 1 for ERC-721; ≥1 for ERC-1155
        AssetType assetType;
        uint256 pricePerDay; // AETH (18 dec) per day
        uint256 minDuration; // seconds
        uint256 maxDuration; // seconds
        ListingState state;
    }

    struct Rental {
        uint256 listingId;
        address borrower;
        uint256 startTime;
        uint256 endTime;
        uint256 totalFee; // gross AETH paid (before protocol fee deduction)
    }

    // State

    /// @notice Token used for rental payments (AETH).
    IERC20 public immutable paymentToken;

    /// @notice Protocol fee in basis points (e.g. 200 = 2 %). Max 1 000 bps.
    uint256 public protocolFeeBps;

    /// @notice Receives the protocol slice of every rental fee.
    address public feeRecipient;

    uint256 private _nextListingId;
    uint256 private _nextRentalId;

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Rental) public rentals;

    /// @dev listingId → current active rentalId (0 = none).
    mapping(uint256 => uint256) public activeRental;

    /// @dev Accumulated net AETH fees per lender (pull-over-push pattern).
    mapping(address => uint256) public pendingFees;

    // Errors

    error Guild__ZeroAddress();
    error Guild__ZeroAmount();
    error Guild__ZeroPrice();
    error Guild__InvalidDuration(uint256 min, uint256 max);
    error Guild__ListingNotFound(uint256 listingId);
    error Guild__NotAvailable(uint256 listingId, ListingState state);
    error Guild__DurationOutOfRange(uint256 duration, uint256 min, uint256 max);
    error Guild__NotBorrower(address caller, uint256 rentalId);
    error Guild__NotLender(address caller, uint256 listingId);
    error Guild__RentalNotExpired(uint256 rentalId, uint256 endTime);
    error Guild__RentalAlreadyEnded(uint256 rentalId);
    error Guild__NothingToClaim();
    error Guild__FeeTooHigh(uint256 feeBps, uint256 maxBps);
    error Guild__NotOwner(uint256 listingId);

    // Events

    event Listed(
        uint256 indexed listingId,
        address indexed lender,
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        AssetType assetType,
        uint256 pricePerDay,
        uint256 minDuration,
        uint256 maxDuration
    );
    event Rented(
        uint256 indexed rentalId,
        uint256 indexed listingId,
        address indexed borrower,
        uint256 startTime,
        uint256 endTime,
        uint256 totalFee
    );
    event Returned(uint256 indexed rentalId, uint256 indexed listingId, address returnedTo);
    event ListingCancelled(uint256 indexed listingId, address indexed lender);
    event FeesClaimed(address indexed lender, uint256 amount);
    event ProtocolFeeUpdated(uint256 newFeeBps);
    event FeeRecipientUpdated(address newRecipient);

    // Constructor

    /**
     * @param paymentToken_  AETH token address.
     * @param admin          Receives DEFAULT_ADMIN_ROLE and ADMIN_ROLE.
     * @param feeRecipient_  Address that receives the protocol slice of rental fees.
     * @param initialFeeBps  Protocol fee in bps (e.g. 200 = 2 %). Must be <= MAX_FEE_BPS.
     */
    constructor(address paymentToken_, address admin, address feeRecipient_, uint256 initialFeeBps) {
        if (paymentToken_ == address(0)) revert Guild__ZeroAddress();
        if (admin == address(0)) revert Guild__ZeroAddress();
        if (feeRecipient_ == address(0)) revert Guild__ZeroAddress();
        if (initialFeeBps > MAX_FEE_BPS) revert Guild__FeeTooHigh(initialFeeBps, MAX_FEE_BPS);

        paymentToken = IERC20(paymentToken_);
        feeRecipient = feeRecipient_;
        protocolFeeBps = initialFeeBps;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    // Lender: create listing

    /**
     * @notice Deposit an NFT into escrow and create a rental listing.
     * @dev    For ERC-721 `amount` must be 1. The NFT is transferred here immediately.
     *
     * @param nftContract  Address of HeroNFT (ERC-721) or ItemRegistry (ERC-1155).
     * @param tokenId      Token ID to list.
     * @param amount       Number of tokens (must be 1 for ERC-721, >=1 for ERC-1155).
     * @param assetType    AssetType.ERC721 or AssetType.ERC1155.
     * @param pricePerDay  Price in AETH per day (18 decimals).
     * @param minDuration  Minimum rental duration in seconds.
     * @param maxDuration  Maximum rental duration in seconds (≥ minDuration).
     * @return listingId   ID of the new listing.
     */
    function list(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        AssetType assetType,
        uint256 pricePerDay,
        uint256 minDuration,
        uint256 maxDuration
    ) external nonReentrant returns (uint256 listingId) {
        // Checks
        if (nftContract == address(0)) revert Guild__ZeroAddress();
        if (pricePerDay == 0) revert Guild__ZeroPrice();
        if (amount == 0) revert Guild__ZeroAmount();
        if (minDuration == 0 || maxDuration == 0 || minDuration > maxDuration) {
            revert Guild__InvalidDuration(minDuration, maxDuration);
        }

        listingId = ++_nextListingId;

        // Effects - write state before external calls (CEI)
        listings[listingId] = Listing({
            lender: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            amount: amount,
            assetType: assetType,
            pricePerDay: pricePerDay,
            minDuration: minDuration,
            maxDuration: maxDuration,
            state: ListingState.Available
        });

        emit Listed(
            listingId, msg.sender, nftContract, tokenId, amount, assetType, pricePerDay, minDuration, maxDuration
        );

        // Interactions - pull NFT into escrow
        if (assetType == AssetType.ERC721) {
            IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        } else {
            IERC1155(nftContract).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        }
    }

    // Borrower: rent

    /**
     * @notice Rent a listed NFT for 'duration' seconds.
     * @dev    Total fee = pricePerDay * duration / SECONDS_PER_DAY.
     *         Protocol fee is forwarded to feeRecipient immediately.
     *         Lender net fee is credited to pendingFees (pull-over-push).
     *
     * @param listingId  ID of the listing to rent.
     * @param duration   Rental duration in seconds; must be in [minDuration, maxDuration].
     * @return rentalId  ID of the new rental.
     */
    function rent(uint256 listingId, uint256 duration) external nonReentrant returns (uint256 rentalId) {
        // Checks
        Listing storage listing = listings[listingId];
        if (listing.lender == address(0)) revert Guild__ListingNotFound(listingId);
        if (listing.state != ListingState.Available) revert Guild__NotAvailable(listingId, listing.state);
        if (duration < listing.minDuration || duration > listing.maxDuration) {
            revert Guild__DurationOutOfRange(duration, listing.minDuration, listing.maxDuration);
        }

        uint256 totalFee = (listing.pricePerDay * duration) / SECONDS_PER_DAY;
        uint256 protocolFee = (totalFee * protocolFeeBps) / BPS_DENOMINATOR;
        uint256 lenderFee = totalFee - protocolFee;

        rentalId = ++_nextRentalId;
        uint256 endTime = block.timestamp + duration;

        // Effects - update state before external calls (CEI)
        listing.state = ListingState.Rented;
        activeRental[listingId] = rentalId;

        rentals[rentalId] = Rental({
            listingId: listingId, borrower: msg.sender, startTime: block.timestamp, endTime: endTime, totalFee: totalFee
        });

        pendingFees[listing.lender] += lenderFee;

        emit Rented(rentalId, listingId, msg.sender, block.timestamp, endTime, totalFee);

        // Interactions - pull payment, forward protocol cut
        paymentToken.safeTransferFrom(msg.sender, address(this), totalFee);
        if (protocolFee > 0) {
            paymentToken.safeTransfer(feeRecipient, protocolFee);
        }
    }

    // Borrower: return early

    /**
     * @notice Return a rented NFT before the rental period expires.
     * @dev    No refund is issued; fee was already credited to the lender.
     *         Only the active borrower may call this.
     *         The listing returns to Available state, ready for re-rental.
     *
     * @param rentalId  ID of the rental to close.
     */
    function returnEarly(uint256 rentalId) external nonReentrant {
        Rental storage rental = rentals[rentalId];
        Listing storage listing = listings[rental.listingId];

        // Checks
        if (rental.borrower != msg.sender) revert Guild__NotBorrower(msg.sender, rentalId);
        if (listing.state != ListingState.Rented) revert Guild__RentalAlreadyEnded(rentalId);

        address lender = listing.lender;

        // Effects
        listing.state = ListingState.Available;
        activeRental[rental.listingId] = 0;
        rental.borrower = address(0); // sentinel: rental closed

        emit Returned(rentalId, rental.listingId, lender);

        // Interactions - return NFT to lender
        _returnNFT(listing);
    }

    // Lender: reclaim after expiry

    /**
     * @notice Reclaim an escrowed NFT whose rental period has elapsed.
     * @dev    Only the original lender may call this.
     *         The listing returns to Available state after reclaim.
     *
     * @param rentalId  ID of the expired rental.
     */
    function reclaimExpired(uint256 rentalId) external nonReentrant {
        Rental storage rental = rentals[rentalId];
        Listing storage listing = listings[rental.listingId];

        // Checks
        if (listing.lender != msg.sender) revert Guild__NotLender(msg.sender, rental.listingId);
        if (listing.state != ListingState.Rented) revert Guild__RentalAlreadyEnded(rentalId);
        if (block.timestamp < rental.endTime) revert Guild__RentalNotExpired(rentalId, rental.endTime);

        // Effects
        listing.state = ListingState.Available;
        activeRental[rental.listingId] = 0;
        rental.borrower = address(0);

        emit Returned(rentalId, rental.listingId, msg.sender);

        // Interactions
        _returnNFT(listing);
    }

    // Lender: cancel available listing

    /**
     * @notice Cancel an Available listing and retrieve the escrowed NFT.
     * @dev    Cannot cancel a Rented listing; wait for rental to expire first.
     *
     * @param listingId  ID of the listing to cancel.
     */
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];

        // Checks
        if (listing.lender != msg.sender) revert Guild__NotOwner(listingId);
        if (listing.state != ListingState.Available) revert Guild__NotAvailable(listingId, listing.state);

        // Effects
        listing.state = ListingState.Cancelled;

        emit ListingCancelled(listingId, msg.sender);

        // Interactions
        _returnNFT(listing);
    }

    // Lender: withdraw fees

    /**
     * @notice Withdraw accumulated net rental fees (pull-over-push).
     * @dev    Zeroes the balance before the transfer to prevent reentrancy.
     */
    function claimFees() external nonReentrant {
        uint256 amount = pendingFees[msg.sender];
        if (amount == 0) revert Guild__NothingToClaim();

        // Effects
        pendingFees[msg.sender] = 0;

        emit FeesClaimed(msg.sender, amount);

        // Interactions
        paymentToken.safeTransfer(msg.sender, amount);
    }

    // Admin

    /**
     * @notice Update the protocol fee. Applies to future rentals only.
     * @param newFeeBps New fee in basis points (max MAX_FEE_BPS).
     */
    function setProtocolFee(uint256 newFeeBps) external onlyRole(ADMIN_ROLE) {
        if (newFeeBps > MAX_FEE_BPS) revert Guild__FeeTooHigh(newFeeBps, MAX_FEE_BPS);
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(newFeeBps);
    }

    /**
     * @notice Update the address that receives the protocol fee slice.
     * @param newRecipient Non-zero address for fee collection.
     */
    function setFeeRecipient(address newRecipient) external onlyRole(ADMIN_ROLE) {
        if (newRecipient == address(0)) revert Guild__ZeroAddress();
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(newRecipient);
    }

    // View helpers

    /**
     * @notice Return the current active borrower of a listing.
     * @dev    Returns address(0) if not rented or if the rental has expired
     *         but reclaimExpired() has not yet been called (stale state check).
     */
    function borrowerOf(uint256 listingId) external view returns (address) {
        uint256 rentalId = activeRental[listingId];
        if (rentalId == 0) return address(0);
        Rental storage rental = rentals[rentalId];
        if (block.timestamp > rental.endTime) return address(0);
        return rental.borrower;
    }

    /**
     * @notice Return true if the listing is Rented and the rental has not expired.
     */
    function isActivelyRented(uint256 listingId) external view returns (bool) {
        uint256 rentalId = activeRental[listingId];
        if (rentalId == 0) return false;
        if (listings[listingId].state != ListingState.Rented) return false;
        return block.timestamp <= rentals[rentalId].endTime;
    }

    /**
     * @notice Quote the fee breakdown for renting a listing for 'duration' seconds.
     * @return totalFee     Gross AETH the borrower must pay.
     * @return lenderFee    Net AETH credited to the lender.
     * @return protocolFee_ AETH forwarded to feeRecipient.
     */
    function quoteFee(uint256 listingId, uint256 duration)
        external
        view
        returns (uint256 totalFee, uint256 lenderFee, uint256 protocolFee_)
    {
        Listing storage listing = listings[listingId];
        if (listing.lender == address(0)) revert Guild__ListingNotFound(listingId);
        totalFee = (listing.pricePerDay * duration) / SECONDS_PER_DAY;
        protocolFee_ = (totalFee * protocolFeeBps) / BPS_DENOMINATOR;
        lenderFee = totalFee - protocolFee_;
    }

    // ERC-721 / ERC-1155 receiver hooks

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    // IERC165

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId
            || super.supportsInterface(interfaceId);
    }

    // Internal

    /**
     * @dev Return the escrowed NFT to the lender. Called after state changes.
     */
    function _returnNFT(Listing storage listing) internal {
        if (listing.assetType == AssetType.ERC721) {
            IERC721(listing.nftContract).safeTransferFrom(address(this), listing.lender, listing.tokenId);
        } else {
            IERC1155(listing.nftContract)
                .safeTransferFrom(address(this), listing.lender, listing.tokenId, listing.amount, "");
        }
    }
}
