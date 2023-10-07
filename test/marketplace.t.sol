// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {NFTMarket} from "../src/markeplace.sol";
import "../src/ERC721Mock.sol";
import "./Helpers.sol";

contract NFTMarketTest is Helpers {
    NFTMarket marketPlace;
    Treasure nft;

    uint256 currentListingId;

    address addrA;
    address addrB;

    uint256 privKeyA;
    uint256 privKeyB;

    NFTMarket.ListingData listing;

    function setUp() public {
        marketPlace = new NFTMarket();
        nft = new Treasure();

        (addrA, privKeyA) = mkaddr("ADDRA");
        (addrB, privKeyB) = mkaddr("ADDRB");

        listing = NFTMarket.ListingData({
            tokenAddress: address(nft),
            tokenId: 1,
            priceInWei: 1e18,
            signature: bytes(""),
            expiryTime: 0,
            listerAddress: address(addrA),
            isActive: false
        });

        // mint NFT
        nft.mint(addrA, 1);
    }

    function testNotOwnerListing() public {
        listing.listerAddress = addrB;
        switchSigner(addrB);

        vm.expectRevert(NFTMarket.NotOwner.selector);
        marketPlace.createCustomListing(listing);
    }

    function testNonApproved() public {
        switchSigner(addrA);
        vm.expectRevert(NFTMarket.NotApproved.selector);
        marketPlace.createCustomListing(listing);
    }

    function testMinPriceTooLow() public {
        switchSigner(addrA);
        nft.setApprovalForAll(address(marketPlace), true);
        listing.priceInWei = 0;
        vm.expectRevert(NFTMarket.MinPriceTooLow.selector);
        marketPlace.createCustomListing(listing);
    }

    function testMinDurationNotMet() public {
        switchSigner(addrA);
        listing.expiryTime = uint88(block.timestamp);
        nft.setApprovalForAll(address(marketPlace), true);
        vm.expectRevert(NFTMarket.MinDurationNotMet.selector);
        marketPlace.createCustomListing(listing);
    }

    function testInValidSignature() public {
        switchSigner(addrA);
        nft.setApprovalForAll(address(marketPlace), true);
        listing.expiryTime = uint88(block.timestamp + 120 minutes);
        listing.signature = constructSig(
            listing.tokenAddress,
            listing.tokenId,
            listing.priceInWei,
            listing.expiryTime,
            listing.listerAddress,
            privKeyB
        );
        vm.expectRevert(NFTMarket.InvalidSignature.selector);
        marketPlace.createCustomListing(listing);
    }

    // EDIT LISTING
    function testListingNotExistent() public {
        switchSigner(addrA);
        vm.expectRevert(NFTMarket.ListingNotExistent.selector);
        marketPlace.executeCustomListing(listing.tokenId);
    }

    function testListingNotActive() public {
        switchSigner(addrA);
        listing.expiryTime = uint88(block.timestamp + 120 minutes);
        listing.signature = constructSig(
            listing.tokenAddress,
            listing.tokenId,
            listing.priceInWei,
            listing.expiryTime,
            listing.listerAddress,
            privKeyA
        );
    }

    function testListerNotOwner() public {
        switchSigner(addrA);
        nft.setApprovalForAll(address(marketPlace), true);
        listing.expiryTime = uint88(block.timestamp + 120 minutes);
        listing.signature = constructSig(
            listing.tokenAddress,
            listing.tokenId,
            listing.priceInWei,
            listing.expiryTime,
            listing.listerAddress,
            privKeyA
        );
        uint256 lId = marketPlace.createCustomListing(listing);
        switchSigner(addrB);
        vm.expectRevert(NFTMarket.NotOwner.selector);
        marketPlace.editCustomListing(lId, 0, false);
    }

    function testEditListing() public {
        switchSigner(addrA);
        nft.setApprovalForAll(address(marketPlace), true);
        listing.expiryTime = uint88(block.timestamp + 120 minutes);
        listing.signature = constructSig(
            listing.tokenAddress,
            listing.tokenId,
            listing.priceInWei,
            listing.expiryTime,
            listing.listerAddress,
            privKeyA
        );
        uint256 lId = marketPlace.createCustomListing(listing);
        marketPlace.editCustomListing(lId, 0.01 ether, false);

        NFTMarket.ListingData memory t = marketPlace.getCustomListing(lId);
        assertEq(t.priceInWei, 0.01 ether);
        assertEq(t.isActive, false);
    }

    // EXECUTE LISTING
    function testExecuteNonValidListing() public {
        switchSigner(addrA);
        vm.expectRevert(NFTMarket.ListingNotExistent.selector);
        marketPlace.executeCustomListing(1);
    }

    function testExecuteExpiredListing() public {
        switchSigner(addrA);
        nft.setApprovalForAll(address(marketPlace), true);
    }

    function testExecuteListingNotActive() public {
        switchSigner(addrA);
        nft.setApprovalForAll(address(marketPlace), true);
        listing.expiryTime = uint88(block.timestamp + 120 minutes);
        listing.signature = constructSig(
            listing.tokenAddress,
            listing.tokenId,
            listing.priceInWei,
            listing.expiryTime,
            listing.listerAddress,
            privKeyA
        );
        uint256 lId = marketPlace.createCustomListing(listing);
        marketPlace.editCustomListing(lId, 0.01 ether, false);
        switchSigner(addrB);
        vm.expectRevert(NFTMarket.ListingNotActive.selector);
        marketPlace.executeCustomListing(lId);
    }

    function testExecutePriceNotMet() public {
        switchSigner(addrA);
        nft.setApprovalForAll(address(marketPlace), true);
        listing.expiryTime = uint88(block.timestamp + 150 minutes);
        listing.signature = constructSig(
            listing.tokenAddress,
            listing.tokenId,
            listing.priceInWei,
            listing.expiryTime,
            listing.listerAddress,
            privKeyA
        );
        uint256 lId = marketPlace.createCustomListing(listing);
        switchSigner(addrB);
        vm.expectRevert(
            abi.encodeWithSelector(
                NFTMarket.PriceNotMet.selector,
                listing.priceInWei - 0.7 ether
            )
        );
        marketPlace.executeCustomListing{value: 0.7 ether}(lId);
    }

    function testExecute() public {
        switchSigner(addrA);
        nft.setApprovalForAll(address(marketPlace), true);
        listing.expiryTime = uint88(block.timestamp + 120 minutes);
        listing.signature = constructSig(
            listing.tokenAddress,
            listing.tokenId,
            listing.priceInWei,
            listing.expiryTime,
            listing.listerAddress,
            privKeyA
        );
        uint256 lId = marketPlace.createCustomListing(listing);
        switchSigner(addrB);
        uint256 addrABalanceBefore = addrA.balance;

        marketPlace.executeCustomListing{value: listing.priceInWei}(lId);

        NFTMarket.ListingData memory t = marketPlace.getCustomListing(lId);
        assertEq(t.priceInWei, 1 ether);
        assertEq(t.isActive, false);
        assertEq(t.isActive, false);
        assertEq(ERC721(listing.tokenAddress).ownerOf(listing.tokenId), addrB);
    }
}
