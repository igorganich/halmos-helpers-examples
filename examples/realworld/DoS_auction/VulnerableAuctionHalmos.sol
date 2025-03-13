// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.25;

import "halmos-helpers-lib/GlobalStorage.sol";
import "halmos-helpers-lib/SymbolicHandler.sol";
import "halmos-helpers-lib/SymbolicHandlerUtils.sol";

import {NFTAuction} from "./VulnerableAuction.sol";

contract VulnerableAuctionChallenge is Test, SymTest {
    address configurer = address(0xcafe0000);
    address[] actors = [address(0xcafe0001), address(0xcafe0002)];
    SymbolicHandler[] handlers;
    GlobalStorage glob;
    SymbolicHandlerUtils utils;
    NFTAuction auction;

    uint256 constant HANDLERS_BALANCE = 10 ether;

    function setUp() public {
        startHoax(configurer, 1 << 80);
        auction = new NFTAuction();

        utils = new SymbolicHandlerUtils();
        glob = new GlobalStorage(configurer);
        handlers = new SymbolicHandler[](2);
        handlers[0] = new SymbolicHandler(actors[0], glob, configurer);
        handlers[1] = new SymbolicHandler(actors[1], glob, configurer);

        handlers[0].set_is_optimistic(true);
        handlers[1].set_is_optimistic(true);

        vm.deal(address(handlers[0]), HANDLERS_BALANCE);
        vm.deal(address(handlers[1]), HANDLERS_BALANCE);

        glob.add_addr_name_pair(address(auction), "NFTAuction");
        vm.stopPrank();
    }

    function check_VulnerableAuction() public {
        bytes memory action = abi.encodeWithSignature("execute_symbolically_all()");
        utils.execute_actor_handler_pair(actors, handlers, action);

        inv_AuctionNotBlocked();
    }

    /*
    ** An actor should be able to make a new bid if he has 
    ** enough ETH and transfers enough ETH to exceed the previous bid
    */
    function inv_AuctionNotBlocked() internal {
        vm.startPrank(address(handlers[1]));
        uint256 nextbid = svm.createUint256("nextbid");
        vm.assume(address(handlers[1]).balance > auction.highestBid()); // Handler has enough balance
        vm.assume(nextbid > auction.highestBid()); // Handler passes enough ETH as a next bid

        // use "call" to check the success of the transaction
        bytes memory biddata = abi.encodeWithSignature("bid()"); 
        (bool success, bytes memory retdata) = address(auction).call{value: nextbid}(biddata);
        assert(success == true);
        vm.stopPrank();
    }
}