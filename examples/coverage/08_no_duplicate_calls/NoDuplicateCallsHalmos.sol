// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";
import "./NoDuplicateCallsTarget.sol";

contract NoDuplicateCalls is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);

    NoDuplicateCallsTarget target;
    SymbolicActor[] actors;

    function setUp() public {
        startHoax(deployer, 1 << 80);
        target = new NoDuplicateCallsTarget();
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        actors = halmosHelpersGetSymbolicActorArray(1);
        halmosHelpersRegisterTargetAddress(address(target), "NoDuplicateCallsTarget");
        vm.stopPrank();
    }

    function check_NoDuplicateCalls_disabled() external {
        vm.startPrank(address(actors[0]));
        executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_1");
        executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_2");
        executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_3");
        executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_4");
        executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_5");
        vm.stopPrank();
        assert(target.goal() != true);
    }

    /*
    ** This check is ~5x faster!
    */
    function check_NoDuplicateCalls_enabled() external {
        vm.startPrank(getConfigurer());
        halmosHelpersSetNoDuplicateCalls(true);
        vm.stopPrank();

        vm.startPrank(address(actors[0]));
        executeSymbolicallyAllTargets("check_NoDuplicateCalls_enabled_1");
        executeSymbolicallyAllTargets("check_NoDuplicateCalls_enabled_2");
        executeSymbolicallyAllTargets("check_NoDuplicateCalls_enabled_3");
        executeSymbolicallyAllTargets("check_NoDuplicateCalls_enabled_4");
        executeSymbolicallyAllTargets("check_NoDuplicateCalls_enabled_5");
        vm.stopPrank();
        assert(target.goal() != true);
    }
}