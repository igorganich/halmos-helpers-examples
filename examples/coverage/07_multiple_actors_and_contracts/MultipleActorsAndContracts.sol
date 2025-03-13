// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/GlobalStorage.sol";
import "halmos-helpers-lib/SymbolicHandler.sol";
import "./MultipleActorsAndContractsTarget1.sol";
import "./MultipleActorsAndContractsTarget2.sol";
import "halmos-helpers-lib/SymbolicHandlerUtils.sol";

contract MultipleActorsAndContracts is Test {
    address configurer = address(0xcafe0000);
    address[] actors = [address(0xcafe0001), address(0xcafe0002)];
    SymbolicHandler[] handlers;
    MultipleActorsAndContractsTarget1 target1;
    MultipleActorsAndContractsTarget2 target2;
    GlobalStorage glob;
    SymbolicHandlerUtils utils;

    function setUp() public {
        startHoax(configurer, 1 << 80);
        utils = new SymbolicHandlerUtils();
        glob = new GlobalStorage(configurer);
        handlers = new SymbolicHandler[](2);
        handlers[0] = new SymbolicHandler(actors[0], glob, configurer);
        handlers[1] = new SymbolicHandler(actors[1], glob, configurer);
        target1 = new MultipleActorsAndContractsTarget1(address(handlers[0]));
        target2 = new MultipleActorsAndContractsTarget2(target1, address(handlers[1]));
        glob.add_addr_name_pair(address(target1), "MultipleActorsAndContractsTarget1");
        glob.add_addr_name_pair(address(target2), "MultipleActorsAndContractsTarget2");
        vm.stopPrank();
    }

    function check_MultipleActorsAndContracts() external {
        bytes memory action = abi.encodeWithSignature("execute_symbolically_all()");
        utils.execute_actor_handler_pair(actors, handlers, action);
        utils.execute_actor_handler_pair(actors, handlers, action);

        assert(target2.goal() != true);
    }
}