// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/GlobalStorage.sol";
import "halmos-helpers-lib/SymbolicHandler.sol";
import "./CallbackTarget.sol";

contract Callback is Test {
    address configurer = address(0xcafe0000);
    address actor = address(0xcafe0001);

    CallbackTarget target;
    GlobalStorage glob;
    SymbolicHandler handler;

    function setUp() public {
        startHoax(configurer, 1 << 80);
        target = new CallbackTarget();
        glob = new GlobalStorage(configurer);
        glob.add_addr_name_pair(address(target), "Callback");
        handler = new SymbolicHandler(actor, glob, configurer);
        vm.stopPrank();
    }

    function check_Callback() external {
        vm.startPrank(actor);
        handler.execute_symbolically_all();

        assert(target.goal() != true);
        vm.stopPrank();
    }
}