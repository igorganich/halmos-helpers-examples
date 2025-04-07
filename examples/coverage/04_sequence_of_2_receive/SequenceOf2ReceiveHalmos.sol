// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";
import "./SequenceOf2ReceiveTarget.sol";

contract SequenceOf2Receive is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);

    SequenceOf2ReceiveTarget target;
    SymbolicActor[] actors;

    function setUp() public {
        startHoax(deployer, 1 << 80);
        target = new SequenceOf2ReceiveTarget();
        vm.deal(address(target), 10e18); // Give some ETH to target
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        halmosHelpersRegisterTargetAddress(address(target), "SequenceOf2ReceiveTarget");
        actors = halmosHelpersGetSymbolicActorArray(1);
        vm.deal(address(actors[0]), 10e18); // Give some ETH to actor
        actors[0].setSymbolicReceiveTxsNumber(2);
        vm.stopPrank();
    }

    function check_SequenceOf2Receive() external {
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_SequenceOf2Receive");
        vm.stopPrank();

        assert(target.goal() != true);        
    }
}