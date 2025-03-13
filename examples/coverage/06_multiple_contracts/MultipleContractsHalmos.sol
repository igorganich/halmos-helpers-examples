// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/GlobalStorage.sol";
import "halmos-helpers-lib/SymbolicHandler.sol";
import "./MultipleContractsTarget1.sol";
import "./MultipleContractsTarget2.sol";

contract MultipleContracts is Test {
    address configurer = address(0xcafe0000);
    address actor = address(0xcafe0001);
    SymbolicHandler handler;
    MultipleContractsTarget1 target1;
    MultipleContractsTarget2 target2;
    GlobalStorage glob;

    function setUp() public {
        startHoax(configurer, 1 << 80);
        glob = new GlobalStorage(configurer);
        handler = new SymbolicHandler(actor, glob, configurer);
        target1 = new MultipleContractsTarget1();
        target2 = new MultipleContractsTarget2(target1);
        glob.add_addr_name_pair(address(target1), "MultipleContractsTarget1");
        glob.add_addr_name_pair(address(target2), "MultipleContractsTarget2");
        vm.stopPrank();
    }

    function check_MultipleContracts() external {
        vm.startPrank(actor);
        handler.execute_symbolically_all();
        handler.execute_symbolically_all();
        vm.stopPrank();
        assert(target2.goal() != true);
    }
}