// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

contract MultipleContractsTarget1 {
    bool public lock;

    constructor() {
        lock = true;
    }

    function unlock() external {
        lock = false;
    }
}