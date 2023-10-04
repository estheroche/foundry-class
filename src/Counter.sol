// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Counter.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MyContract {
    using Counters for Counters.Counter;
    Counters.Counter public CounterTesttokenId;

    uint256 public listingPrice = 0.0025 ether;
    using ECDSA for bytes32;

    struct Order {
        address owner;
        address tokenAddress;
        uint256 tokenId;
        uint256 price;
        bytes signature;
        uint256 deadline;
        bool active;
    }

    mapping(uint256 => Order) public orders;

    IERC721Enumerable public erc721Contract;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor(address _erc721Contract) {
        erc721Contract = IERC721Enumerable(_erc721Contract);
        owner = msg.sender;
    }

    function createOrder(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        bytes calldata _signature
    ) public payable {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_price > 0, "Price must be greater than zero");
        require(_deadline > block.timestamp, "Invalid deadline");
        require(
            IERC721(_tokenAddress).ownerOf(_tokenId) == msg.sender,
            "You are not the owner of this NFT"
        );

        bool status = IERC721(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        CounterTesttokenId.increment();

        Order storage order = orders[CounterTesttokenId.current()];
        order.owner = msg.sender;
        order.tokenAddress = _tokenAddress;
        order.tokenId = _tokenId;
        order.price = _price;
        order.signature = _signature;
        order.deadline = _deadline;
        order.active = true;
    }

    function executeOrder(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        bytes calldata _signature
    ) external payable {
        bytes32 orderHash = keccak256(
            abi.encodePacked(
                _tokenAddress,
                _tokenId,
                _price,
                _deadline,
                _signature
            )
        );
        Order storage order = orders[uint256(orderHash)];
        require(order.owner != address(0), "Order not found");
        require(order.price == _price, "Incorrect price");
        require(block.timestamp <= order.deadline, "Order expired");

        // Verify the seller's signature
        bytes32 hashToVerify = keccak256(
            abi.encodePacked(
                order.tokenAddress,
                order.tokenId,
                order.price,
                order.owner
            )
        );
        address seller = hashToVerify.recover(order.signature);
        require(seller == order.owner, "Invalid seller signature");

        // For simplicity, we'll assume the order is valid and execute the trade
        erc721Contract.safeTransferFrom(order.owner, msg.sender, order.tokenId);

        if (msg.value > listingPrice) {
            uint256 remainingAmount = msg.value - listingPrice;
            (bool sent, ) = msg.sender.call{value: remainingAmount}("");
            require(sent, "Failed to send Ether");

            order.active = false;
        }
    }

    function setOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner");
        owner = _newOwner;
    }
}
