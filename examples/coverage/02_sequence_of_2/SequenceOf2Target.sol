// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

contract SequenceOf2Target {
    bool public goal;
    bool private lock;

    constructor() {
        lock = true;
        goal = false;
    }

    function unlock_goal_function(uint256 unlocker) external {
        if (unlocker == 0x1337) {
            lock = false;
        }
    }

    function goal_function() external {
        if (lock == true) {
            revert();
        }
        goal = true;
    }
}