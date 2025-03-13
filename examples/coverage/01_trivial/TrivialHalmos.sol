// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/GlobalStorage.sol";
import "halmos-helpers-lib/SymbolicHandler.sol";
import "./TrivialTarget.sol";

contract Trivial is Test {
    address configurer = address(0xcafe0000);
    address actor = address(0xcafe0001);

    TrivialTarget target;
    GlobalStorage glob;
    SymbolicHandler handler;

    function setUp() public {
        startHoax(configurer, 1 << 80);
        target = new TrivialTarget();
        glob = new GlobalStorage(configurer);
        glob.add_addr_name_pair(address(target), "TrivialTarget");
        handler = new SymbolicHandler(actor, glob, configurer);
        vm.stopPrank();
    }

    function check_TrivialAll() external {
        vm.startPrank(actor);
        handler.execute_symbolically_all();

        assert(target.goal() != true);
        vm.stopPrank();
    }

    function check_TrivialTarget() external {
        vm.startPrank(actor);
        handler.execute_symbolically_target(address(target));

        assert(target.goal() != true);
        vm.stopPrank();
    }

    function check_TrivialTargetData() external {
        vm.startPrank(actor);
        bytes memory data = abi.encodeWithSignature("trivial_function()");
        handler.execute_symbolically_target_data(address(target), data);

        assert(target.goal() != true);
        vm.stopPrank();
    }
}