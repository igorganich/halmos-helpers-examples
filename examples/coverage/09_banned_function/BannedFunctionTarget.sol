// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "forge-std/Test.sol";

contract BannedFunctionTarget {
    bool public goal;
    uint8 private counter;

    constructor() {
        counter = 0;
        goal = false;
    }

    /* 
    ** This function is guaranteed to have no effect on any target
    ** It is taken from https://docs.safe.global/reference-smart-account/transactions/simulateAndRevert
    */
    function simulateAndRevert(address targetContract, bytes memory calldataPayload) external {
        assembly {
            let success := delegatecall(gas(), targetContract, add(calldataPayload, 0x20), mload(calldataPayload), 0, 0)

            mstore(0x00, success)
            mstore(0x20, returndatasize())
            returndatacopy(0x40, 0, returndatasize())
            revert(0, add(returndatasize(), 0x40))
        }
    }

    function goal_function() external {
        counter++;
        if (counter == 5) {
            goal = true;
        }
    }
}