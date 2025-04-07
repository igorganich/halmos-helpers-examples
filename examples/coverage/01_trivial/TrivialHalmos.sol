// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";
import "./TrivialTarget.sol";

contract Trivial is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);

    TrivialTarget target;
    SymbolicActor[] actors;

    function setUp() public {
        startHoax(deployer, 1 << 80);
        target = new TrivialTarget();
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        halmosHelpersRegisterTargetAddress(address(target), "TrivialTarget");
        actors = halmosHelpersGetSymbolicActorArray(1);

        vm.stopPrank();
    }

    function check_TrivialAll() external {
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_TrivialAll");
        vm.stopPrank();

        assert(target.goal() != true);
    }

    function check_TrivialTarget() external {
        vm.startPrank(address(actors[0]));
        executeSymbolicallyTarget(address(target));
        vm.stopPrank();

        assert(target.goal() != true);
    }

    function check_TrivialTargetData() external {
        vm.startPrank(address(actors[0]));
        target.trivial_function();
        vm.stopPrank();

        assert(target.goal() != true);
    }
}