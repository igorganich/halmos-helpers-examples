// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";
import "./MultipleActorsAndContractsTarget1.sol";
import "./MultipleActorsAndContractsTarget2.sol";

contract MultipleActorsAndContracts is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);
    SymbolicActor[] actors;
    MultipleActorsAndContractsTarget1 target1;
    MultipleActorsAndContractsTarget2 target2;

    function setUp() public {
        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        actors = halmosHelpersGetSymbolicActorArray(2);
        vm.stopPrank();

        vm.startPrank(deployer);
        target1 = new MultipleActorsAndContractsTarget1(address(actors[0]));
        target2 = new MultipleActorsAndContractsTarget2(target1, address(actors[1]));
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersRegisterTargetAddress(address(target1), "MultipleActorsAndContractsTarget1");
        halmosHelpersRegisterTargetAddress(address(target2), "MultipleActorsAndContractsTarget2");
        vm.stopPrank();
    }

    function check_MultipleActorsAndContracts() external {
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_MultipleActorsAndContracts_1");
        vm.stopPrank();

        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_MultipleActorsAndContracts_2");
        vm.stopPrank();

        assert(target2.goal() != true);
    }
}