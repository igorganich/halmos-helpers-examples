// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.25;

import "halmos-helpers-lib/GlobalStorage.sol";
import "halmos-helpers-lib/SymbolicHandler.sol";
import "halmos-helpers-lib/SymbolicHandlerUtils.sol";
import {SideEntranceLenderPool} from "./SideEntranceLenderPool.sol";

contract SideEntranceChallenge is Test {
    address deployer = address(0xcafe0000);
    address player = address(0xcafe0001);
    address recovery = address(0xcafe0002);
    address configurer = address(0xcafe0003);
    SymbolicHandler handler;

    uint256 constant ETHER_IN_POOL = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e18;

    GlobalStorage glob;
    SideEntranceLenderPool pool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    function setUp() public {
        /* 
        ** Challenge setup part 
        */ 
        startHoax(deployer, 1 << 80);
        pool = new SideEntranceLenderPool();
        pool.deposit{value: ETHER_IN_POOL}();
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        vm.stopPrank();

        /* 
        ** halmos-helpers-lib setup part
        */
        vm.startPrank(configurer);
        glob = new GlobalStorage(configurer);
        glob.add_addr_name_pair(address(pool), "SideEntranceLenderPool");
        handler = new SymbolicHandler(player, glob, configurer);
        
        handler.set_is_optimistic(true);
        
        vm.stopPrank();
    }

    function check_sideEntrance() public checkSolvedByPlayer {
        vm.deal(address(handler), PLAYER_INITIAL_ETH_BALANCE);
        vm.deal(address(player), 0); // Player's ETH is transferred to its handler.
        handler.execute_symbolically_all();
        handler.execute_symbolically_all();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assert(address(pool).balance >= ETHER_IN_POOL);
    }
}
