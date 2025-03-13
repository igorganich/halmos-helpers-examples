// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

contract SequenceOf2ReceiveTarget {
    bool public goal;
    bool private lock1;
    bool private lock2;

    constructor() {
        lock1 = true;
        lock2 = true;
        goal = false;
    }

    receive() external payable {
        if (lock1 == false && address(this).balance == 15e18) {
            lock2 = false;
        }
    }

    function unlock1() external payable {
        lock1 = false;
        payable(msg.sender).transfer(msg.value);
        lock1 = true;
    }

    function goal_function() external {
        if (lock1 == false && lock2 == false) {
            goal = true;
        }
    }
}