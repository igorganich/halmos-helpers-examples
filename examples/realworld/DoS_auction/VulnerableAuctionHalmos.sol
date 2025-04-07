// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";

import {NFTAuction} from "./VulnerableAuction.sol";

contract VulnerableAuctionChallenge is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);
    SymbolicActor[] actors;
    NFTAuction auction;

    uint256 constant HANDLERS_BALANCE = 10 ether;

    function setUp() public {
        startHoax(deployer, 1 << 80);
        auction = new NFTAuction();
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        actors = halmosHelpersGetSymbolicActorArray(2);

        vm.deal(address(actors[0]), HANDLERS_BALANCE);
        vm.deal(address(actors[1]), HANDLERS_BALANCE);
        halmosHelpersRegisterTargetAddress(address(auction), "NFTAuction");
        vm.stopPrank();
    }

    function check_VulnerableAuction() public {
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_VulnerableAuction");
        vm.stopPrank();

        inv_AuctionNotBlocked();
    }

    /*
    ** An actor should be able to make a new bid if it has 
    ** enough ETH and transfers enough ETH to exceed the previous bid
    */
    function inv_AuctionNotBlocked() internal {
        vm.startPrank(address(actors[1]));
        uint256 nextbid = _svm.createUint256("nextbid");
        vm.assume(address(actors[1]).balance > auction.highestBid()); // Actor has enough balance
        vm.assume(nextbid > auction.highestBid()); // Actor passes enough ETH as a next bid
        vm.assume(nextbid < address(actors[1]).balance); // Actor's balance is enough to make a bid

        // use "call" to check the success of the transaction
        bytes memory biddata = abi.encodeWithSignature("bid()"); 
        (bool success, bytes memory retdata) = address(auction).call{value: nextbid}(biddata);
        assert(success == true);
        vm.stopPrank();
    }
}