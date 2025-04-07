// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

contract NoDuplicateCallsTarget {
    bool public goal;
    uint8 private counter;

    constructor() {
        counter = 0;
        goal = false;
    }

    function inc_counter1() external {
        if (counter == 0) {
            counter++;
        }
    }

    function inc_counter2() external {
        if (counter == 1) {
            counter++;
        }
    }

    function inc_counter3() external {
        if (counter == 2) {
            counter++;
        }
    }

    function inc_counter4() external {
        if (counter == 3) {
            counter++;
        }
    }

    function goal_function() external {
        if (counter == 4) {
            goal = true;
        }
    }
}