// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import "solmate/tokens/ERC721.sol";
import "openzeppelin/token/ERC721/ERC721.sol";
import {SignUtils} from "./SignUtils.sol";

contract NFTMarket {
    struct ListingData {
        address tokenAddress;
        uint256 tokenId;
        uint256 priceInWei;
        bytes signature;
        uint88 expiryTime;
        address listerAddress;
        bool isActive;
    }

    mapping(uint256 => ListingData) public customListings;
    address public customAdmin;
    uint256 public customListingId;

    /* ERRORS */
    error NotOwner();
    error NotApproved();
    error MinPriceTooLow();
    error DeadlineTooSoon();
    error MinDurationNotMet();
    error InvalidSignature();
    error ListingNotExistent();
    error ListingNotActive();
    error PriceNotMet(int256 difference);
    error ListingExpired();
    error PriceMismatch(uint256 originalPrice);

    /* EVENTS */
    event CustomListingCreated(uint256 indexed listingId, ListingData);
    event CustomListingExecuted(uint256 indexed listingId, ListingData);
    event CustomListingEdited(uint256 indexed listingId, ListingData);

    constructor() {
        customAdmin = msg.sender;
    }

    function createCustomListing(
        ListingData calldata listing
    ) public returns (uint256 listingId) {
        if (ERC721(listing.tokenAddress).ownerOf(listing.tokenId) != msg.sender)
            revert NotOwner();
        if (
            !ERC721(listing.tokenAddress).isApprovedForAll(
                msg.sender,
                address(this)
            )
        ) revert NotApproved();
        if (listing.priceInWei < 0.01 ether) revert MinPriceTooLow();
        if (listing.expiryTime < block.timestamp) revert DeadlineTooSoon();
        if (listing.expiryTime - block.timestamp < 60 minutes)
            revert MinDurationNotMet();

        // Assert signature
        if (
            !SignUtils.isValid(
                SignUtils.constructMessageHash(
                    listing.tokenAddress,
                    listing.tokenId,
                    listing.priceInWei,
                    listing.expiryTime,
                    listing.listerAddress
                ),
                listing.signature,
                msg.sender
            )
        ) revert InvalidSignature();

        // append to Storage
        ListingData storage customListing = customListings[customListingId];
        customListing.tokenAddress = listing.tokenAddress;
        customListing.tokenId = listing.tokenId;
        customListing.priceInWei = listing.priceInWei;
        customListing.signature = listing.signature;
        customListing.expiryTime = uint88(listing.expiryTime);
        customListing.listerAddress = msg.sender;
        customListing.isActive = true;

        // Emit event
        emit CustomListingCreated(customListingId, listing);
        listingId = customListingId;
        customListingId++;
        return listingId;
    }

    function executeCustomListing(uint256 listingId) public payable {
        if (listingId >= customListingId) revert ListingNotExistent();
        ListingData storage customListing = customListings[listingId];
        if (customListing.expiryTime < block.timestamp) revert ListingExpired();
        if (!customListing.isActive) revert ListingNotActive();
        if (customListing.priceInWei != msg.value)
            revert PriceNotMet(
                int256(customListing.priceInWei) - int256(msg.value)
            );

        // Update state
        customListing.isActive = false;

        // transfer
        ERC721(customListing.tokenAddress).transferFrom(
            customListing.listerAddress,
            msg.sender,
            customListing.tokenId
        );

        // transfer eth
        payable(customListing.listerAddress).transfer(customListing.priceInWei);

        // Update storage
        emit CustomListingExecuted(listingId, customListing);
    }

    function editCustomListing(
        uint256 listingId,
        uint256 newPrice,
        bool isActive
    ) public {
        if (listingId >= customListingId) revert ListingNotExistent();
        ListingData storage customListing = customListings[listingId];
        if (customListing.listerAddress != msg.sender) revert NotOwner();
        customListing.priceInWei = newPrice;
        customListing.isActive = isActive;
        emit CustomListingEdited(listingId, customListing);
    }

    // add getter for listing
    function getCustomListing(
        uint256 listingId
    ) public view returns (ListingData memory) {
        return customListings[listingId];
    }
}
