// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {FractionalizedNFT} from "../src/Fractionized-NFT.sol";
import "../src/ERC721Mock.sol";
import "./Helpers.sol";

contract FractionalizedNFTTest is Helpers {
    FractionalizedNFT marketPlace;
    Treasure nft;

    function setup() public {
        nft = new Treasure();
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
}
