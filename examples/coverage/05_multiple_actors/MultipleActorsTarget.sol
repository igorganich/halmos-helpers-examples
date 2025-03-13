// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "forge-std/Test.sol";

contract MultipleActorsTarget {
    bool public goal;
    bool private lock;
    address private unlocker;
    address private goaler;

    constructor(address _unlocker, address _goaler) {
        unlocker = _unlocker;
        goaler = _goaler;
        lock = true;
    }

    function unlock() external {
        if (msg.sender != unlocker) {
            revert();
        }
        lock = false;
    }

    function goal_function() external {
        if (msg.sender == goaler && lock == false) {
            goal = true;
        }
    }
}