// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";

import "./HandleAbstractCallTarget_handle.sol";

contract HandleAbstractCall is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);

    SymbolicActor[] actors;
    HandleAbstractCallTarget_handle target;

    function setUp() public {
        startHoax(deployer, 1 << 80);
        target = new HandleAbstractCallTarget_handle();
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        halmosHelpersSetNoDuplicateCalls(true);
        halmosHelpersRegisterTargetAddress(address(target), "HandleAbstractCallTarget_handle");
        actors = halmosHelpersGetSymbolicActorArray(1);
        vm.stopPrank();
    }

    function check_HandleAbstractCall_handle() external {
        vm.startPrank(address(actors[0]));
        executeSymbolicallyAllTargets("check_HandleAbstractCall_handle");
        vm.stopPrank();
        assert(target.goal() != true);
    }
}