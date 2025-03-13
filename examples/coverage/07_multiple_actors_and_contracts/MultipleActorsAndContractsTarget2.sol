// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "./MultipleActorsAndContractsTarget1.sol";

contract MultipleActorsAndContractsTarget2 {
    bool public goal;
    address immutable private goaler;
    MultipleActorsAndContractsTarget1 target1;

    constructor(MultipleActorsAndContractsTarget1 _target1, address _goaler) {
        target1 = _target1;
        goaler = _goaler;
        goal = false;
    }

    function goal_function() external {
        if (target1.lock() == false && msg.sender == goaler) {
            goal = true;
        }
    }
}