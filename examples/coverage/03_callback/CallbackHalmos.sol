// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";
import "./CallbackTarget.sol";

contract Callback is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);

    CallbackTarget target;
    SymbolicActor[] actors;

    function setUp() public {
        startHoax(deployer, 1 << 80);
        target = new CallbackTarget();
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        halmosHelpersRegisterTargetAddress(address(target), "Callback");
        actors = halmosHelpersGetSymbolicActorArray(1);
        vm.stopPrank();
    }

    function check_Callback() external {
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_Callback");
        vm.stopPrank();

        assert(target.goal() != true);
    }
}