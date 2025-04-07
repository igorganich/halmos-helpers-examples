// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;
import "halmos-helpers-lib/HalmosHelpers.sol";
import "./SequenceOf2Target.sol";

contract SequenceOf2 is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);

    SequenceOf2Target target;
    SymbolicActor[] actors;

    function setUp() public {
        startHoax(deployer, 1 << 80);
        target = new SequenceOf2Target();
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        halmosHelpersRegisterTargetAddress(address(target), "SequenceOf2Target");
        actors = halmosHelpersGetSymbolicActorArray(1);
        vm.stopPrank();
    }

    function check_SequenceOf2Unlock() external {
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_SequenceOf2Unlock_1");        
        vm.stopPrank();

        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_SequenceOf2Unlock_2");
        vm.stopPrank();

        assert(target.goal() != true);
    }
}