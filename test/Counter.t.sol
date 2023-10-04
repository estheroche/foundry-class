// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Counter} from "../src/MyCounter.sol";
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MyContractTest {
    MyContract public myContract;
    uint256 public tokenId = 1;

    function beforeEach() public {
        myContract = new MyContract(msg.sender);
    }

    function testCreateOrder() public {
        // Create an order
        myContract.createOrder(
            address(this),
            tokenId,
            10 ether,
            block.timestamp + 3600,
            "signature"
        );

        // Check that the order was created successfully
        MyContract.Order memory order = myContract.orders(
            myContract.CounterTesttokenId()
        );
        Assert.equal(order.owner, msg.sender, "Owner should be the sender");
        Assert.equal(
            order.tokenAddress,
            address(this),
            "Token address should match"
        );
        Assert.equal(order.tokenId, tokenId, "Token ID should match");
        Assert.equal(order.price, 10 ether, "Price should match");
        Assert.equal(order.active, true, "Order should be active");
    }

    function testExecuteOrder() public {
        // Create an order
        myContract.createOrder(
            address(this),
            tokenId,
            10 ether,
            block.timestamp + 3600,
            "signature"
        );

        // Execute the order
        myContract.executeOrder(
            address(this),
            tokenId,
            10 ether,
            block.timestamp + 3600,
            "signature"
        );

        // Check that the order was executed successfully
        MyContract.Order memory order = myContract.orders(
            myContract.CounterTesttokenId()
        );
        Assert.equal(
            order.active,
            false,
            "Order should be inactive after execution"
        );
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(
                recoveredAddress != address(0) && recoveredAddress == owner,
                "INVALID_SIGNER"
            );

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }
}
