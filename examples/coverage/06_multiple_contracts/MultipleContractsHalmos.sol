// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";
import "./MultipleContractsTarget1.sol";
import "./MultipleContractsTarget2.sol";

contract MultipleContracts is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);
    SymbolicActor[] actors;
    MultipleContractsTarget1 target1;
    MultipleContractsTarget2 target2;
    GlobalStorage glob;

    function setUp() public {
        startHoax(deployer, 1 << 80);
        target1 = new MultipleContractsTarget1();
        target2 = new MultipleContractsTarget2(target1);
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        actors = halmosHelpersGetSymbolicActorArray(1);
        halmosHelpersRegisterTargetAddress(address(target1), "MultipleContractsTarget1");
        halmosHelpersRegisterTargetAddress(address(target2), "MultipleContractsTarget2");
        vm.stopPrank();
    }

    function check_MultipleContracts() external {
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_MultipleContracts_1");
        vm.stopPrank();

        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_MultipleContracts_2");
        vm.stopPrank();

        assert(target2.goal() != true);
    }
}