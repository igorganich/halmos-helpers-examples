// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract VulnPool {
    address public owner;
    uint256 public secondsPerLiquidityCumulativeX128;
    uint256 public liquidity;
    uint32  public lastObservationTimestamp;

    event Advance(uint32 periodEnd, uint32 delta, uint256 incr);

    modifier onlyOwner() {
        require(msg.sender == owner, "VulnPool: not owner");
        _;
    }

    constructor() { owner = msg.sender; }

    function setLiquidity(uint256 l) external onlyOwner {
        liquidity = l;
    }

    // Owner-only keeper/cron style function to progress periods.
    // Computes period end based on current block.timestamp and updates cumulative.
    function advancePeriod() external onlyOwner {
        // compute current period index
        uint256 periodIndex = block.timestamp / 1 weeks;
        // periodEnd = periodIndex * 1 weeks - 1
        uint32 periodEnd = uint32(periodIndex * 1 weeks - 1);

        uint32 delta = (periodEnd > lastObservationTimestamp) ? uint32(periodEnd - lastObservationTimestamp) : 0;
        uint256 incr = 0;
        if (liquidity > 0 && delta > 0) {
            // Q128 increment: (delta << 128) / liquidity
            incr = (uint256(delta) << 128) / liquidity;
            secondsPerLiquidityCumulativeX128 += incr;
        }
        lastObservationTimestamp = periodEnd;
        emit Advance(periodEnd, delta, incr);
    }

    // Direct getter used by gauge
    function secondsPerLiquidityCumulativeX128_view() external view returns (uint256) {
        return secondsPerLiquidityCumulativeX128;
    }
}