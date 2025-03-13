// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

contract TrivialTarget {
    bool public goal;

    constructor() {
        goal = false;
    }

    function trivial_function() external {
        goal = true;
    }
}