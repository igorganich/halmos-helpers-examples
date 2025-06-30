// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";
import "./AllowedFunctionTarget.sol";

contract AllowedFunction is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);

    AllowedFunctionTarget target;
    SymbolicActor[] actors;

    function setUp() public {
        startHoax(deployer, 1 << 80);
        target = new AllowedFunctionTarget();
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        halmosHelpersRegisterTargetAddress(address(target), "AllowedFunctionTarget");
        actors = halmosHelpersGetSymbolicActorArray(1);
        vm.stopPrank();
    }

    function check_AllowedFunction_disabled() external {
        vm.startPrank(address(actors[0]));
        executeSymbolicallyAllTargets("check_AllowedFunction_disabled_1");
        executeSymbolicallyAllTargets("check_AllowedFunction_disabled_2");
        executeSymbolicallyAllTargets("check_AllowedFunction_disabled_3");
        executeSymbolicallyAllTargets("check_AllowedFunction_disabled_4");
        executeSymbolicallyAllTargets("check_AllowedFunction_disabled_5");
        vm.stopPrank();
        assert(target.goal() != true);
    }

    /*
    ** This check is much faster!
    */
    function check_AllowedFunction_enabled() external {
        vm.startPrank(getConfigurer());
        halmosHelpersSetOnlyAllowedSelectors(true);
        halmosHelpersAllowFunctionSelector(target.goal_function.selector);
        vm.stopPrank();

        vm.startPrank(address(actors[0]));
        executeSymbolicallyAllTargets("check_AllowedFunction_enabled_1");
        executeSymbolicallyAllTargets("check_AllowedFunction_enabled_2");
        executeSymbolicallyAllTargets("check_AllowedFunction_enabled_3");
        executeSymbolicallyAllTargets("check_AllowedFunction_enabled_4");
        executeSymbolicallyAllTargets("check_AllowedFunction_enabled_5");
        vm.stopPrank();
        assert(target.goal() != true);
    }
}