// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";
import "./BannedFunctionTarget.sol";

contract BannedFunction is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);

    BannedFunctionTarget target;
    SymbolicActor[] actors;

    function setUp() public {
        startHoax(deployer, 1 << 80);
        target = new BannedFunctionTarget();
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        halmosHelpersRegisterTargetAddress(address(target), "BannedFunctionTarget");
        actors = halmosHelpersGetSymbolicActorArray(1);
        vm.stopPrank();
    }

    function check_BannedFunction_disabled() external {
        vm.startPrank(address(actors[0]));
        executeSymbolicallyAllTargets("check_BannedFunction_disabled_1");
        executeSymbolicallyAllTargets("check_BannedFunction_disabled_2");
        executeSymbolicallyAllTargets("check_BannedFunction_disabled_3");
        executeSymbolicallyAllTargets("check_BannedFunction_disabled_4");
        executeSymbolicallyAllTargets("check_BannedFunction_disabled_5");
        vm.stopPrank();
        assert(target.goal() != true);
    }

    /*
    ** This check is much faster!
    */
    function check_BannedFunction_enabled() external {
        vm.startPrank(getConfigurer());
        halmosHelpersBanFunctionSelector(bytes4(keccak256("simulateAndRevert(address,bytes)")));
        vm.stopPrank();

        vm.startPrank(address(actors[0]));
        executeSymbolicallyAllTargets("check_BannedFunction_enabled_1");
        executeSymbolicallyAllTargets("check_BannedFunction_enabled_2");
        executeSymbolicallyAllTargets("check_BannedFunction_enabled_3");
        executeSymbolicallyAllTargets("check_BannedFunction_enabled_4");
        executeSymbolicallyAllTargets("check_BannedFunction_enabled_5");
        vm.stopPrank();
        assert(target.goal() != true);
    }
}