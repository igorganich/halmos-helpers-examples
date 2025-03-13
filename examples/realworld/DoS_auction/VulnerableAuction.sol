// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract NFTAuction {
    address public highestBidder;
    uint256 public highestBid;

    constructor() payable {}

    function bid() external payable {
        require(msg.value > highestBid, "Bid not high enough");

        if (highestBidder != address(0)) {
            (bool success, ) = highestBidder.call{value: highestBid}(""); 
            require(success, "Refund failed");
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}