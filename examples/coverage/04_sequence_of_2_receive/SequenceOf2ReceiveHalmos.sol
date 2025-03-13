// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/GlobalStorage.sol";
import "halmos-helpers-lib/SymbolicHandler.sol";
import "./SequenceOf2ReceiveTarget.sol";

contract SequenceOf2Receive is Test {
    address configurer = address(0xcafe0000);
    address actor = address(0xcafe0001);

    SequenceOf2ReceiveTarget target;
    GlobalStorage glob;
    SymbolicHandler handler;

    function setUp() public {
        startHoax(configurer, 1 << 80);
        target = new SequenceOf2ReceiveTarget();
        vm.deal(address(target), 10e18); // Give some ETH to target
        glob = new GlobalStorage(configurer);
        glob.add_addr_name_pair(address(target), "SequenceOf2ReceiveTarget");
        handler = new SymbolicHandler(actor, glob, configurer);
        vm.deal(address(handler), 10e18); // Give some ETH to handler
        handler.set_symbolic_receive_txs_number(2);
        vm.stopPrank();
    }

    function check_SequenceOf2Receive() external {
        vm.startPrank(actor);
        handler.execute_symbolically_all();

        assert(target.goal() != true);
        vm.stopPrank();
    }
}