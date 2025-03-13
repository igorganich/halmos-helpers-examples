// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/GlobalStorage.sol";
import "halmos-helpers-lib/SymbolicHandler.sol";
import "./MultipleActorsTarget.sol";
import "halmos-helpers-lib/SymbolicHandlerUtils.sol";

contract MultipleActors is Test {
    address configurer = address(0xcafe0000);
    address[] actors = [address(0xcafe0001), address(0xcafe0002)];
    SymbolicHandler[] handlers;
    MultipleActorsTarget target;
    GlobalStorage glob;
    SymbolicHandlerUtils utils;

    function setUp() public {
        startHoax(configurer, 1 << 80);
        utils = new SymbolicHandlerUtils();
        glob = new GlobalStorage(configurer);
        handlers = new SymbolicHandler[](2);
        handlers[0] = new SymbolicHandler(actors[0], glob, configurer);
        handlers[1] = new SymbolicHandler(actors[1], glob, configurer);
        target = new MultipleActorsTarget(address(handlers[0]), address(handlers[1]));
        glob.add_addr_name_pair(address(target), "MultipleActorsTarget");
        vm.stopPrank();
    }

    function check_MultipleActors() external {
        bytes memory action = abi.encodeWithSignature("execute_symbolically_all()");
        utils.execute_actor_handler_pair(actors, handlers, action);
        utils.execute_actor_handler_pair(actors, handlers, action);

        assert(target.goal() != true);
    }
}