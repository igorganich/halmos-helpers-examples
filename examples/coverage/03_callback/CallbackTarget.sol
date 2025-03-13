// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

interface CallbackReceiver {
    function callback() external payable returns (uint256);
}

contract CallbackTarget {
    bool public goal;
    bool private lock;

    constructor() {
        lock = true;
        goal = false;
    }

    function unlock_goal_function() external {
        lock = false;
        if (CallbackReceiver(msg.sender).callback() != 0x1337) {
            revert();
        }
        lock = true;
    }

    function goal_function() external {
        if (lock == true) {
            revert();
        }
        goal = true;
    }
}