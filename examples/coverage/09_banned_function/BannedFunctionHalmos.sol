// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/GlobalStorage.sol";
import "halmos-helpers-lib/SymbolicHandler.sol";
import "./BannedFunctionTarget.sol";

contract BannedFunction is Test {
    address configurer = address(0xcafe0000);
    address actor = address(0xcafe0001);

    BannedFunctionTarget target;
    GlobalStorage glob;
    SymbolicHandler handler;

    function setUp() public {
        startHoax(configurer, 1 << 80);
        target = new BannedFunctionTarget();
        glob = new GlobalStorage(configurer);
        glob.add_addr_name_pair(address(target), "BannedFunctionTarget");
        handler = new SymbolicHandler(actor, glob, configurer);
        vm.stopPrank();
    }

    function check_BannedFunction_disabled() external {
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
    ** This check is much faster!
    */
    function check_BannedFunction_enabled() external {
        vm.startPrank(configurer);
        glob.add_banned_function_selector(bytes4(keccak256("simulateAndRevert(address,bytes)")));
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