// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";
import "./MultipleActorsTarget.sol";

contract MultipleActors is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);
    SymbolicActor[] actors;
    MultipleActorsTarget target;

    function setUp() public {
        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        actors = halmosHelpersGetSymbolicActorArray(2);
        vm.stopPrank();

        startHoax(deployer, 1 << 80);
        target = new MultipleActorsTarget(address(actors[0]), address(actors[1]));
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersRegisterTargetAddress(address(target), "MultipleActorsTarget");
        vm.stopPrank();
    }

    function check_MultipleActorsOneTarget() external {
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_MultipleActors_1");
        vm.stopPrank();

        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_MultipleActors_2");
        vm.stopPrank();

        assert(target.goal() != true);
    }
}