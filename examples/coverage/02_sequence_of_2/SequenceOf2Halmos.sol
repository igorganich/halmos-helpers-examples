// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/GlobalStorage.sol";
import "halmos-helpers-lib/SymbolicHandler.sol";
import "./SequenceOf2Target.sol";

contract SequenceOf2 is Test {
    address configurer = address(0xcafe0000);
    address actor = address(0xcafe0001);

    SequenceOf2Target target;
    GlobalStorage glob;
    SymbolicHandler handler;

    function setUp() public {
        startHoax(configurer, 1 << 80);
        target = new SequenceOf2Target();
        glob = new GlobalStorage(configurer);
        glob.add_addr_name_pair(address(target), "SequenceOf2Target");
        handler = new SymbolicHandler(actor, glob, configurer);
        handler.set_symbolic_txs_number(2);
        vm.stopPrank();
    }

    function check_SequenceOf2() external {
        vm.startPrank(actor);
        handler.execute_symbolically_all();

        assert(target.goal() != true);
        vm.stopPrank();
    }
}