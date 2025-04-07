// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";

import "./HandleAbstractCallTarget_original.sol";

contract HandleAbstractCall is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);

    SymbolicActor[] actors;
    HandleAbstractCallTarget_original target;

    function setUp() public {
        startHoax(deployer, 1 << 80);
        target = new HandleAbstractCallTarget_original();
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        halmosHelpersRegisterTargetAddress(address(target), "HandleAbstractCallTarget_original");
        actors = halmosHelpersGetSymbolicActorArray(1);
        vm.stopPrank();
    }

    function check_HandleAbstractCall_original() external {
        vm.startPrank(address(actors[0]));
        executeSymbolicallyAllTargets("check_HandleAbstractCall_original");
        vm.stopPrank();
        assert(target.goal() != true);
    }
}