// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";
import {SideEntranceLenderPool} from "./SideEntranceLenderPool.sol";

contract SideEntranceChallenge is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);
    address player = address(0xcafe0001);
    address recovery = address(0xcafe0002);
    SymbolicActor[] actors;

    uint256 constant ETHER_IN_POOL = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e18;

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
        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        halmosHelpersRegisterTargetAddress(address(pool), "SideEntranceLenderPool");
        actors = halmosHelpersGetSymbolicActorArray(1);
        halmosHelpersSetNoDuplicateCalls(true);
        vm.stopPrank();
    }

    function check_sideEntrance() public checkSolvedByPlayer {
        vm.stopPrank();
        vm.deal(address(actors[0]), PLAYER_INITIAL_ETH_BALANCE);
        vm.deal(address(player), 0); // Player's ETH is transferred to its handler.
        vm.startPrank(address(actors[0]));
        executeSymbolicallyAllTargets("check_sideEntrance_1");
        executeSymbolicallyAllTargets("check_sideEntrance_2");
        vm.stopPrank();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assert(address(pool).balance >= ETHER_IN_POOL);
    }
}
