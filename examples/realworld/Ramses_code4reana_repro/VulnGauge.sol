// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./VulnPool.sol";
import "./TestERC20.sol";

contract VulnGauge {
    address public owner;
    address public rewardAdmin; // account authorized to call notifyRewardAmount
    VulnPool public pool;

    // period => token => remaining budget
    mapping(uint256 => mapping(address => uint256)) public periodReward;
    // per-user per-period snapshot of cumulative (when cached)
    mapping(address => mapping(uint256 => uint256)) public userSnapshot;
    // cached (locked) earned amount
    mapping(address => mapping(uint256 => uint256)) public cachedEarned;
    // user liquidity (simplified)
    mapping(address => uint256) public userLiquidity;

    event RewardNotified(address indexed token, uint256 amount, uint256 period);
    event Cached(address indexed user, uint256 period, uint256 amount);
    event Claimed(address indexed user, uint256 period, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "VulnGauge: not owner");
        _;
    }

    modifier onlyRewardAdmin() {
        require(msg.sender == rewardAdmin, "VulnGauge: not reward admin");
        _;
    }

    constructor(address _pool) {
        owner = msg.sender;
        rewardAdmin = msg.sender; // default: deployer is rewardAdmin; can be changed
        pool = VulnPool(_pool);
    }

    // owner can change rewardAdmin (or set multisig)
    function setRewardAdmin(address a) external onlyOwner {
        rewardAdmin = a;
    }

    // owner helper: in production reward tokens should be deposited first,
    // but we keep logic minimal: owner / rewardAdmin must call notifyRewardAmount.
    // Only rewardAdmin may call this to avoid arbitrary actors seeding budgets.
    function notifyRewardAmount(address token, uint256 amount, uint256 period) external onlyRewardAdmin {
        periodReward[period][token] += amount;
        emit RewardNotified(token, amount, period);
    }

    // Anyone can cache (lock) their earned value for a period.
    // This saves the computed earned into cachedEarned and records snapshot.
    function cachePeriodEarned(uint256 period, address user, address token) external {
        uint256 val = periodEarned(period, user, token);
        cachedEarned[user][period] = val;
        userSnapshot[user][period] = pool.secondsPerLiquidityCumulativeX128_view();
        emit Cached(user, period, val);
    }

    // public view: compute user earned for a period, returns cached value if present
    function periodEarned(uint256 period, address user, address token) public view returns (uint256) {
        uint256 locked = cachedEarned[user][period];
        if (locked != 0) return locked;

        uint256 uLiq = userLiquidity[user];
        uint256 totalLiq = pool.liquidity();
        if (uLiq == 0 || totalLiq == 0) return 0;

        uint256 snapshot = userSnapshot[user][period];
        uint256 current = pool.secondsPerLiquidityCumulativeX128_view();
        if (current <= snapshot) return 0;
        uint256 delta = current - snapshot;

        uint256 totalReward = periodReward[period][token];
        if (totalReward == 0) return 0;

        // earned = (delta * uLiq * totalReward) / (2^128 * totalLiq)
        // rearranged: ((delta * uLiq) * totalReward) >> 128  then divided by totalLiq
        uint256 num = delta * uLiq;
        uint256 earned = (num * totalReward) / ( (uint256(1) << 128) * totalLiq );
        return earned;
    }

    // public claim method: msg.sender claims for `period`. Transfers from gauge's token balance.
    function getPeriodReward(uint256 period, address token, address to) external {
        uint256 amt = periodEarned(period, msg.sender, token);
        if (amt == 0) return;
        uint256 avail = periodReward[period][token];
        if (amt > avail) amt = avail;
        periodReward[period][token] = avail - amt;
        cachedEarned[msg.sender][period] = amt;
        require(SimpleERC20(token).transfer(to, amt), "txfail");
        emit Claimed(msg.sender, period, amt);
    }

    // helper for test: set user liquidity (in real system derived from pool positions)
    function setUserLiquidity(address user, uint256 liq) external onlyOwner {
        userLiquidity[user] = liq;
    }
}