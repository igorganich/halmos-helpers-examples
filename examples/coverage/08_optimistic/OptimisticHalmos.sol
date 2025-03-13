// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/GlobalStorage.sol";
import "halmos-helpers-lib/SymbolicHandler.sol";
import "./OptimisticTarget.sol";

contract Optimistic is Test {
    address configurer = address(0xcafe0000);
    address actor = address(0xcafe0001);

    OptimisticTarget target;
    GlobalStorage glob;
    SymbolicHandler handler;

    function setUp() public {
        startHoax(configurer, 1 << 80);
        target = new OptimisticTarget();
        glob = new GlobalStorage(configurer);
        glob.add_addr_name_pair(address(target), "OptimisticTarget");
        handler = new SymbolicHandler(actor, glob, configurer);
        vm.stopPrank();
    }

    function check_Optimistic_disabled() external {
        vm.startPrank(actor);
        handler.execute_symbolically_all();
        handler.execute_symbolically_all();
        handler.execute_symbolically_all();
        handler.execute_symbolically_all();
        handler.execute_symbolically_all();
        assert(target.goal() != true);
        vm.stopPrank();
    }

    /*
    ** This check is ~5x faster!
    */
    function check_Optimistic_enabled() external {
        vm.startPrank(configurer);
        handler.set_is_optimistic(true);
        vm.stopPrank();

        vm.startPrank(actor);
        handler.execute_symbolically_all();
        handler.execute_symbolically_all();
        handler.execute_symbolically_all();
        handler.execute_symbolically_all();
        handler.execute_symbolically_all();
        assert(target.goal() != true);
        vm.stopPrank();
    }
}