// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpersTargetsExecutor.sol";

contract HandleAbstractCallTarget_handle is HalmosHelpersTargetsExecutor {
    bool public goal;

    constructor() {
        goal = false;
    }

    function entry(address target, bytes calldata data) external {
        //target.call(data);
        executeSymbolicallyTarget(target);
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