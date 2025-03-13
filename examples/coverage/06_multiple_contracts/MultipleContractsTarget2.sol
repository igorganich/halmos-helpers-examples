// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "./MultipleContractsTarget1.sol";

contract MultipleContractsTarget2 {
    bool public goal;
    MultipleContractsTarget1 target1;

    constructor(MultipleContractsTarget1 _target1) {
        target1 = _target1;
        goal = false;
    }

    function goal_function() external {
        if (target1.lock() == false) {
            goal = true;
        }
    }
}