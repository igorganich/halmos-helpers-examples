// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

contract MultipleActorsAndContractsTarget1 {
    bool public lock;
    address immutable private unlocker;

    constructor(address _unlocker) {
        unlocker = _unlocker;
        lock = true;
    }

    function unlock() external {
        if (msg.sender == unlocker) {
            lock = false;
        }
    }
}