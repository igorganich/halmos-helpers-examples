// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

contract HandleAbstractCallTarget_original {
    bool public goal;

    constructor() {
        goal = false;
    }

    function entry(address target, bytes calldata data) external {
        target.call(data);
    }

    function goal_function(address target, bytes calldata data) external {
        if (msg.sender != address(this)) {
            revert();
        }
        if (bytes4(data) != bytes4(0x13371337)) {
            revert();
        }
        goal = true;
    }
}