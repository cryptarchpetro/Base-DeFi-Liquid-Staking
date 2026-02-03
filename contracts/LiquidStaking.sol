// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LiquidStakingV2 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    struct Staker {
        uint256 amountStaked;
        uint256 rewardDebt;
        uint256 lastRewardTime;
        bool isStaking;
        uint256[] stakingHistory;
        uint256 totalRewardsReceived;
        uint256 firstStakeTime;
        uint256 lastClaimTime;
        uint256 pendingRewards;
        uint256 stakingDuration;
        uint256 stakingStartBlock;
        uint256 lockupPeriod;
        uint256 performanceFee;
        uint256 withdrawalFee;
    }

    struct Pool {
        IERC20 token;
        uint256 totalStaked;
        uint256 rewardPerSecond;
        uint256 lastUpdateTime;
        uint256 accRewardPerShare;
        uint256 poolStartTime;
        uint256 poolEndTime;
        bool isActive;
        uint256 apr;
        uint256 minimumStake;
        uint256 maximumStake;
        uint256 lockupPeriod;
        uint256 performanceFee;
        uint256 withdrawalFee;
        uint256 stakingDuration;
        uint256 totalRewardsDistributed;
        uint256 stakingCap;
        uint256 currentStakers;
    }

    struct RewardTier {
        uint256 minStake;
        uint256 multiplier;
        string tierName;
        uint256 bonusApr;
    }

    struct UserStakeInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastUpdateTime;
        uint256[] stakingHistory;
        uint256 totalRewardsReceived;
        uint256 firstStakeTime;
        uint256 lastClaimTime;
        uint256 pendingRewards;
        uint256 stakingDuration;
        uint256 stakingStartBlock;
        uint256 lockupPeriod;
        uint256 performanceFee;
        uint256 withdrawalFee;
    }

    mapping(address => Staker) public stakers;
    mapping(address => Pool) public pools;
    mapping(address => RewardTier[]) public rewardTiers;
    
    IERC20 public rewardToken;
    IERC20 public stakingToken;
    uint256 public constant REWARD_PRECISION = 1e18;
    uint256 public constant MAX_LOCKUP_PERIOD = 365 days;
    uint256 public constant MAX_PERFORMANCE_FEE = 1000; // 10%
    uint256 public constant MAX_WITHDRAWAL_FEE = 1000; // 10%
    uint256 public constant MIN_STAKE_AMOUNT = 1;
    uint256 public constant MAX_STAKE_CAP = 1000000000000000000000000; // 1 million tokens
    
    // Events
    event Staked(
        address indexed user,
        address indexed pool,
        uint256 amount,
        uint256 sharesMinted,
        uint256 timestamp,
        uint256 stakingDuration
    );
    
    event Unstaked(
        address indexed user,
        address indexed pool,
        uint256 amount,
        uint256 sharesBurned,
        uint256 timestamp,
        uint256 feeAmount
    );
    
    event RewardClaimed(
        address indexed user,
        address indexed pool,
        uint256 rewardAmount,
        uint256 timestamp
    );
    
    event PoolCreated(
        address indexed pool,
        address indexed token,
        uint256 rewardPerSecond,
        uint256 startTime,
        uint256 endTime,
        uint256 apr,
        uint256 minimumStake,
        uint256 maximumStake,
        uint256 stakingDuration,
        uint256 stakingCap
    );
    
    event PoolUpdated(
        address indexed pool,
        uint256 rewardPerSecond,
        uint256 apr,
        uint256 minimumStake,
        uint256 maximumStake,
        uint256 stakingDuration,
        uint256 stakingCap
    );
    
    event RewardTierAdded(
        address indexed pool,
        uint256 minStake,
        uint256 multiplier,
        string tierName,
        uint256 bonusApr
    );
    
    event FeeUpdated(
        address indexed pool,
        uint256 performanceFee,
        uint256 withdrawalFee
    );
    
    event LockupPeriodUpdated(
        address indexed pool,
        uint256 newPeriod
    );
    
    event PoolActivated(address indexed pool);
    event PoolDeactivated(address indexed pool);
    
    event StakingCapUpdated(address indexed pool, uint256 newCap);
    event StakingDurationUpdated(address indexed pool, uint256 newDuration);
    event PoolClosed(address indexed pool);
    event PoolOpened(address indexed pool);

    constructor(
        address _rewardToken,
        address _stakingToken
    ) {
        rewardToken = IERC20(_rewardToken);
        stakingToken = IERC20(_stakingToken);
    }

    // Create pool
    function createPool(
        address token,
        uint256 rewardPerSecond,
        uint256 startTime,
        uint256 endTime,
        uint256 apr,
        uint256 minimumStake,
        uint256 maximumStake,
        uint256 stakingDuration,
        uint256 stakingCap
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(startTime > block.timestamp, "Invalid start time");
        require(endTime > startTime, "Invalid end time");
        require(apr <= 1000000, "APR too high"); // 10000% max APR
        require(minimumStake >= MIN_STAKE_AMOUNT, "Minimum stake too low");
        require(maximumStake >= minimumStake, "Invalid stake limits");
        require(stakingDuration > 0, "Invalid staking duration");
        require(stakingCap <= MAX_STAKE_CAP, "Staking cap too high");
        
        pools[token] = Pool({
            token: IERC20(token),
            totalStaked: 0,
            rewardPerSecond: rewardPerSecond,
            lastUpdateTime: startTime,
            accRewardPerShare: 0,
            poolStartTime: startTime,
            poolEndTime: endTime,
            isActive: true,
            apr: apr,
            minimumStake: minimumStake,
            maximumStake: maximumStake,
            lockupPeriod: 0,
            performanceFee: 0,
            withdrawalFee: 0,
            stakingDuration: stakingDuration,
            totalRewardsDistributed: 0,
            stakingCap: stakingCap,
            currentStakers: 0
        });
        
        emit PoolCreated(
            token,
            token,
            rewardPerSecond,
            startTime,
            endTime,
            apr,
            minimumStake,
            maximumStake,
            stakingDuration,
            stakingCap
        );
    }

    // Update pool
    function updatePool(
        address token,
        uint256 rewardPerSecond,
        uint256 apr,
        uint256 minimumStake,
        uint256 maximumStake,
        uint256 stakingDuration,
        uint256 stakingCap
    ) external onlyOwner {
        Pool storage pool = pools[token];
        require(pool.token != address(0), "Pool does not exist");
        require(apr <= 1000000, "APR too high");
        require(minimumStake >= MIN_STAKE_AMOUNT, "Minimum stake too low");
        require(maximumStake >= minimumStake, "Invalid stake limits");
        require(stakingDuration > 0, "Invalid staking duration");
        require(stakingCap <= MAX_STAKE_CAP, "Staking cap too high");
        
        pool.rewardPerSecond = rewardPerSecond;
        pool.apr = apr;
        pool.minimumStake = minimumStake;
        pool.maximumStake = maximumStake;
        pool.stakingDuration = stakingDuration;
        pool.stakingCap = stakingCap;
        
        emit PoolUpdated(token, rewardPerSecond, apr, minimumStake, maximumStake, stakingDuration, stakingCap);
    }

    // Add reward tier
    function addRewardTier(
        address pool,
        uint256 minStake,
        uint256 multiplier,
        string memory tierName,
        uint256 bonusApr
    ) external onlyOwner {
        require(pools[pool].token != address(0), "Pool does not exist");
        require(multiplier >= 1e18, "Multiplier too low");
        require(bonusApr <= 1000000, "Bonus APR too high");
        
        rewardTiers[pool].push(RewardTier({
            minStake: minStake,
            multiplier: multiplier,
            tierName: tierName,
            bonusApr: bonusApr
        }));
        
        emit RewardTierAdded(pool, minStake, multiplier, tierName, bonusApr);
    }

    // Set fees
    function setFees(
        address pool,
        uint256 performanceFee,
        uint256 withdrawalFee
    ) external onlyOwner {
        require(pools[pool].token != address(0), "Pool does not exist");
        require(performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        require(withdrawalFee <= MAX_WITHDRAWAL_FEE, "Withdrawal fee too high");
        
        pools[pool].performanceFee = performanceFee;
        pools[pool].withdrawalFee = withdrawalFee;
        
        emit FeeUpdated(pool, performanceFee, withdrawalFee);
    }

    // Set lockup period
    function setLockupPeriod(
        address pool,
        uint256 lockupPeriod
    ) external onlyOwner {
        require(pools[pool].token != address(0), "Pool does not exist");
        require(lockupPeriod <= MAX_LOCKUP_PERIOD, "Lockup period too long");
        
        pools[pool].lockupPeriod = lockupPeriod;
        emit LockupPeriodUpdated(pool, lockupPeriod);
    }

    // Set staking cap
    function setStakingCap(
        address pool,
        uint256 stakingCap
    ) external onlyOwner {
        require(pools[pool].token != address(0), "Pool does not exist");
        require(stakingCap <= MAX_STAKE_CAP, "Staking cap too high");
        
        pools[pool].stakingCap = stakingCap;
        emit StakingCapUpdated(pool, stakingCap);
    }

    // Set staking duration
    function setStakingDuration(
        address pool,
        uint256 stakingDuration
    ) external onlyOwner {
        require(pools[pool].token != address(0), "Pool does not exist");
        require(stakingDuration > 0, "Invalid staking duration");
        
        pools[pool].stakingDuration = stakingDuration;
        emit StakingDurationUpdated(pool, stakingDuration);
    }

    // Stake
    function stake(
        address pool,
        uint256 amount,
        uint256 stakingDuration
    ) external nonReentrant {
        Pool storage poolInfo = pools[pool];
        require(poolInfo.token != address(0), "Pool does not exist");
        require(poolInfo.isActive, "Pool not active");
        require(block.timestamp >= poolInfo.poolStartTime, "Pool not started");
        require(block.timestamp <= poolInfo.poolEndTime, "Pool ended");
        require(amount >= poolInfo.minimumStake, "Amount below minimum");
        require(amount <= poolInfo.maximumStake, "Amount above maximum");
        require(amount <= poolInfo.stakingCap - poolInfo.totalStaked, "Pool cap exceeded");
        require(poolInfo.token.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(stakingDuration >= poolInfo.stakingDuration, "Staking duration too short");
        
        updatePool(pool);
        Staker storage staker = stakers[msg.sender];
        
        if (staker.amountStaked > 0) {
            uint256 pending = calculatePendingReward(msg.sender, pool);
            if (pending > 0) {
                staker.pendingRewards = staker.pendingRewards.add(pending);
            }
        }
        
        staker.amountStaked = staker.amountStaked.add(amount);
        staker.lastRewardTime = block.timestamp;
        staker.isStaking = true;
        staker.stakingDuration = stakingDuration;
        staker.stakingStartBlock = block.number;
        
        if (staker.firstStakeTime == 0) {
            staker.firstStakeTime = block.timestamp;
        }
        
        poolInfo.totalStaked = poolInfo.totalStaked.add(amount);
        poolInfo.currentStakers = poolInfo.currentStakers.add(1);
        poolInfo.token.transferFrom(msg.sender, address(this), amount);
        
        // Add to history
        staker.stakingHistory.push(amount);
        
        emit Staked(msg.sender, pool, amount, amount, block.timestamp, stakingDuration);
    }

    // Unstake
    function unstake(
        address pool,
        uint256 amount
    ) external nonReentrant {
        Pool storage poolInfo = pools[pool];
        require(poolInfo.token != address(0), "Pool does not exist");
        require(poolInfo.isActive, "Pool not active");
        require(stakers[msg.sender].amountStaked >= amount, "Insufficient stake");
        
        updatePool(pool);
        Staker storage staker = stakers[msg.sender];
        
        uint256 pending = calculatePendingReward(msg.sender, pool);
        if (pending > 0) {
            staker.pendingRewards = staker.pendingRewards.add(pending);
        }
        
        // Check lockup period
        uint256 feeAmount = 0;
        if (block.timestamp < staker.firstStakeTime.add(poolInfo.lockupPeriod)) {
            feeAmount = amount.mul(poolInfo.withdrawalFee).div(10000);
        }
        
        uint256 amountAfterFee = amount.sub(feeAmount);
        
        staker.amountStaked = staker.amountStaked.sub(amountAfterFee);
        poolInfo.totalStaked = poolInfo.totalStaked.sub(amountAfterFee);
        poolInfo.currentStakers = poolInfo.currentStakers > 0 ? poolInfo.currentStakers.sub(1) : 0;
        
        // Apply fee
        if (feeAmount > 0) {
            poolInfo.token.transfer(owner(), feeAmount);
        }
        
        poolInfo.token.transfer(msg.sender, amountAfterFee);
        staker.lastUpdateTime = block.timestamp;
        
        emit Unstaked(msg.sender, pool, amountAfterFee, amountAfterFee, block.timestamp, feeAmount);
    }

    // Claim reward
    function claimReward(
        address pool
    ) external nonReentrant {
        Pool storage poolInfo = pools[pool];
        require(poolInfo.token != address(0), "Pool does not exist");
        require(poolInfo.isActive, "Pool not active");
        
        updatePool(pool);
        Staker storage staker = stakers[msg.sender];
        
        uint256 pending = calculatePendingReward(msg.sender, pool);
        require(pending > 0, "No rewards to claim");
        
        // Apply performance fee
        uint256 performanceFeeAmount = pending.mul(poolInfo.performanceFee).div(10000);
        uint256 amountAfterFee = pending.sub(performanceFeeAmount);
        
        if (performanceFeeAmount > 0) {
            rewardToken.transfer(owner(), performanceFeeAmount);
        }
        
        // Transfer rewards
        rewardToken.transfer(msg.sender, amountAfterFee);
        
        // Update stats
        staker.rewardDebt = staker.rewardDebt.add(amountAfterFee);
        staker.totalRewardsReceived = staker.totalRewardsReceived.add(amountAfterFee);
        staker.lastClaimTime = block.timestamp;
        staker.pendingRewards = staker.pendingRewards.sub(amountAfterFee);
        poolInfo.totalRewardsDistributed = poolInfo.totalRewardsDistributed.add(amountAfterFee);
        
        emit RewardClaimed(msg.sender, pool, amountAfterFee, block.timestamp);
    }

    // Update pool
    function updatePool(address pool) internal {
        Pool storage poolInfo = pools[pool];
        if (block.timestamp <= poolInfo.lastUpdateTime) return;
        
        uint256 timePassed = block.timestamp.sub(poolInfo.lastUpdateTime);
        uint256 rewards = timePassed.mul(poolInfo.rewardPerSecond);
        
        if (poolInfo.totalStaked > 0) {
            poolInfo.accRewardPerShare = poolInfo.accRewardPerShare.add(
                rewards.mul(REWARD_PRECISION).div(poolInfo.totalStaked)
            );
        }
        
        poolInfo.lastUpdateTime = block.timestamp;
    }

    // Calculate pending reward
    function calculatePendingReward(address user, address pool) public view returns (uint256) {
        Pool storage poolInfo = pools[pool];
        Staker storage staker = stakers[user];
        
        uint256 rewardPerToken = poolInfo.accRewardPerShare;
        uint256 userReward = staker.rewardDebt;
        
        if (staker.amountStaked > 0) {
            uint256 userEarned = staker.amountStaked.mul(rewardPerToken.sub(userReward)).div(REWARD_PRECISION);
            return userEarned;
        }
        return 0;
    }

    // Get pool info
    function getPoolInfo(address pool) external view returns (Pool memory) {
        return pools[pool];
    }

    // Get user info
    function getUserInfo(address user) external view returns (Staker memory) {
        return stakers[user];
    }

    // Get reward info
    function getUserRewardInfo(address user, address pool) external view returns (
        uint256 pendingRewards,
        uint256 totalRewardsReceived,
        uint256 estimatedAPR
    ) {
        Staker storage staker = stakers[user];
        Pool storage poolInfo = pools[pool];
        
        uint256 pending = calculatePendingReward(user, pool);
        uint256 totalRewards = staker.totalRewardsReceived;
        uint256 apr = poolInfo.apr;
        
        return (pending, totalRewards, apr);
    }

    // Get reward tiers
    function getRewardTiers(address pool) external view returns (RewardTier[] memory) {
        return rewardTiers[pool];
    }

    // Get pool stats
    function getPoolStats(address pool) external view returns (
        uint256 totalStaked,
        uint256 totalRewards,
        uint256 apr,
        uint256 activeUsers,
        uint256 stakingCap,
        uint256 currentStakers
    ) {
        Pool storage poolInfo = pools[pool];
        
        return (
            poolInfo.totalStaked,
            poolInfo.totalRewardsDistributed,
            poolInfo.apr,
            poolInfo.currentStakers,
            poolInfo.stakingCap,
            poolInfo.currentStakers
        );
    }

    // Activate pool
    function activatePool(address pool) external onlyOwner {
        Pool storage poolInfo = pools[pool];
        require(poolInfo.token != address(0), "Pool does not exist");
        poolInfo.isActive = true;
        emit PoolActivated(pool);
    }

    // Deactivate pool
    function deactivatePool(address pool) external onlyOwner {
        Pool storage poolInfo = pools[pool];
        require(poolInfo.token != address(0), "Pool does not exist");
        poolInfo.isActive = false;
        emit PoolDeactivated(pool);
    }

    // Close pool
    function closePool(address pool) external onlyOwner {
        Pool storage poolInfo = pools[pool];
        require(poolInfo.token != address(0), "Pool does not exist");
        poolInfo.isActive = false;
        emit PoolClosed(pool);
    }

    // Open pool
    function openPool(address pool) external onlyOwner {
        Pool storage poolInfo = pools[pool];
        require(poolInfo.token != address(0), "Pool does not exist");
        poolInfo.isActive = true;
        emit PoolOpened(pool);
    }

    // Get user staking history
    function getUserStakingHistory(address user) external view returns (uint256[] memory) {
        return stakers[user].stakingHistory;
    }

    // Get total stakers
    function getTotalStakers() external view returns (uint256) {
        // Implementation in future
        return 0;
    }

    // Check if can claim reward
    function canClaimReward(address user, address pool) external view returns (bool) {
        Pool storage poolInfo = pools[pool];
        Staker storage staker = stakers[user];
        if (poolInfo.token == address(0) || !poolInfo.isActive) return false;
        if (staker.amountStaked == 0) return false;
        return true;
    }

    // Get effective reward rate
    function getEffectiveRewardRate(address pool) external view returns (uint256) {
        Pool storage poolInfo = pools[pool];
        return poolInfo.rewardPerSecond;
    }

    // Get staking info
    function getStakingInfo(address user, address pool) external view returns (
        uint256 amountStaked,
        uint256 pendingRewards,
        uint256 totalRewardsReceived,
        uint256 firstStakeTime,
        uint256 lastClaimTime,
        uint256 stakingDuration,
        uint256 lockupPeriod
    ) {
        Staker storage staker = stakers[user];
        Pool storage poolInfo = pools[pool];
        
        return (
            staker.amountStaked,
            staker.pendingRewards,
            staker.totalRewardsReceived,
            staker.firstStakeTime,
            staker.lastClaimTime,
            poolInfo.stakingDuration,
            poolInfo.lockupPeriod
        );
    }

    // Get pool rewards
    function getPoolRewards(address pool) external view returns (uint256) {
        Pool storage poolInfo = pools[pool];
        return poolInfo.totalRewardsDistributed;
    }

    // Get user staking details
    function getUserStakingDetails(address user, address pool) external view returns (
        uint256 amountStaked,
        uint256 pendingRewards,
        uint256 totalRewardsReceived,
        uint256 stakingDuration,
        uint256 lockupPeriod,
        uint256 stakingStartBlock
    ) {
        Staker storage staker = stakers[user];
        Pool storage poolInfo = pools[pool];
        
        return (
            staker.amountStaked,
            staker.pendingRewards,
            staker.totalRewardsReceived,
            poolInfo.stakingDuration,
            poolInfo.lockupPeriod,
            staker.stakingStartBlock
        );
    }

    // Get user pool info
    function getUserPoolInfo(address user, address pool) external view returns (
        uint256 amountStaked,
        uint256 pendingRewards,
        uint256 totalRewardsReceived,
        uint256 stakingDuration,
        uint256 lockupPeriod,
        uint256 performanceFee,
        uint256 withdrawalFee
    ) {
        Staker storage staker = stakers[user];
        Pool storage poolInfo = pools[pool];
        
        return (
            staker.amountStaked,
            staker.pendingRewards,
            staker.totalRewardsReceived,
            poolInfo.stakingDuration,
            poolInfo.lockupPeriod,
            poolInfo.performanceFee,
            poolInfo.withdrawalFee
        );
    }

    // Get pool configuration
    function getPoolConfiguration(address pool) external view returns (
        uint256 rewardPerSecond,
        uint256 apr,
        uint256 minimumStake,
        uint256 maximumStake,
        uint256 stakingDuration,
        uint256 stakingCap,
        uint256 lockupPeriod,
        uint256 performanceFee,
        uint256 withdrawalFee
    ) {
        Pool storage poolInfo = pools[pool];
        
        return (
            poolInfo.rewardPerSecond,
            poolInfo.apr,
            poolInfo.minimumStake,
            poolInfo.maximumStake,
            poolInfo.stakingDuration,
            poolInfo.stakingCap,
            poolInfo.lockupPeriod,
            poolInfo.performanceFee,
            poolInfo.withdrawalFee
        );
    }

    // Get staking status
    function getStakingStatus(address user, address pool) external view returns (
        bool isStaking,
        uint256 amountStaked,
        uint256 pendingRewards,
        uint256 totalRewardsReceived,
        uint256 stakingDuration,
        uint256 lockupPeriod
    ) {
        Staker storage staker = stakers[user];
        Pool storage poolInfo = pools[pool];
        
        return (
            staker.isStaking,
            staker.amountStaked,
            staker.pendingRewards,
            staker.totalRewardsReceived,
            poolInfo.stakingDuration,
            poolInfo.lockupPeriod
        );
    }
   
function enableAutoReinvest(
    address pool,
    bool enabled,
    uint256 frequency,
    uint256 minAmount,
    uint256 rewardThreshold
) external {
   
}

function autoReinvestRewards(
    address pool
) external {
   
}

function getAutoReinvestInfo(address pool) external view returns (
    bool enabled,
    uint256 frequency,
    uint256 minAmount,
    uint256 rewardThreshold
) {
    
}
// Добавить структуры:
struct AutoReinvestConfig {
    address user;
    address pool;
    bool enabled;
    uint256 frequency;
    uint256 minReinvestAmount;
    uint256 rewardThreshold;
    bool compoundRewards;
    uint256 lastReinvestTime;
    uint256 totalReinvested;
    uint256 totalCompounds;
    uint256 lastRewardAmount;
}

struct ReinvestHistory {
    address user;
    address pool;
    uint256 amount;
    uint256 rewards;
    uint256 timestamp;
    string action;
}

// Добавить маппинги:
mapping(address => mapping(address => AutoReinvestConfig)) public autoReinvestConfigs;
mapping(address => ReinvestHistory[]) public reinvestHistory;

// Добавить события:
event AutoReinvestEnabled(
    address indexed user,
    address indexed pool,
    bool enabled,
    uint256 frequency,
    uint256 minAmount
);

event AutoReinvestExecuted(
    address indexed user,
    address indexed pool,
    uint256 amount,
    uint256 rewards,
    uint256 timestamp
);

event ReinvestSettingsUpdated(
    address indexed user,
    address indexed pool,
    uint256 frequency,
    uint256 minAmount,
    bool compound
);

// Добавить функции:
function enableAutoReinvest(
    address pool,
    uint256 frequency,
    uint256 minAmount,
    uint256 rewardThreshold,
    bool compound
) external {
    require(pool != address(0), "Invalid pool");
    require(frequency >= 3600, "Frequency too short (minimum 1 hour)");
    require(minAmount > 0, "Minimum amount must be greater than 0");
    
    AutoReinvestConfig storage config = autoReinvestConfigs[msg.sender][pool];
    
    config.user = msg.sender;
    config.pool = pool;
    config.enabled = true;
    config.frequency = frequency;
    config.minReinvestAmount = minAmount;
    config.rewardThreshold = rewardThreshold;
    config.compoundRewards = compound;
    config.lastReinvestTime = block.timestamp;
    config.totalReinvested = 0;
    config.totalCompounds = 0;
    config.lastRewardAmount = 0;
    
    emit AutoReinvestEnabled(msg.sender, pool, true, frequency, minAmount);
}

function disableAutoReinvest(address pool) external {
    require(pool != address(0), "Invalid pool");
    
    AutoReinvestConfig storage config = autoReinvestConfigs[msg.sender][pool];
    config.enabled = false;
    
    emit AutoReinvestEnabled(msg.sender, pool, false, 0, 0);
}

function updateReinvestSettings(
    address pool,
    uint256 frequency,
    uint256 minAmount,
    uint256 rewardThreshold,
    bool compound
) external {
    require(pool != address(0), "Invalid pool");
    require(frequency >= 3600, "Frequency too short (minimum 1 hour)");
    require(minAmount > 0, "Minimum amount must be greater than 0");
    
    AutoReinvestConfig storage config = autoReinvestConfigs[msg.sender][pool];
    config.frequency = frequency;
    config.minReinvestAmount = minAmount;
    config.rewardThreshold = rewardThreshold;
    config.compoundRewards = compound;
    
    emit ReinvestSettingsUpdated(msg.sender, pool, frequency, minAmount, compound);
}

function autoReinvestRewards(address pool) external {
    require(pool != address(0), "Invalid pool");
    AutoReinvestConfig storage config = autoReinvestConfigs[msg.sender][pool];
    
    require(config.enabled, "Auto reinvest not enabled");
    require(block.timestamp >= config.lastReinvestTime + config.frequency, "Too early for reinvestment");
    
    // Calculate pending rewards
    uint256 pendingRewards = calculatePendingReward(msg.sender, pool);
    
    // Check conditions
    if (pendingRewards >= config.minReinvestAmount && 
        (pendingRewards >= config.rewardThreshold || config.rewardThreshold == 0)) {
        
        // Execute reinvestment
        uint256 amountToReinvest = pendingRewards;
        
        // If compound is enabled, reinvest all rewards
        if (config.compoundRewards) {
            // In real implementation, this would transfer rewards and re-stake
            
            config.lastReinvestTime = block.timestamp;
            config.totalReinvested += amountToReinvest;
            config.totalCompounds++;
            config.lastRewardAmount = pendingRewards;
            
            // Add to history
            ReinvestHistory memory history = ReinvestHistory({
                user: msg.sender,
                pool: pool,
                amount: amountToReinvest,
                rewards: pendingRewards,
                timestamp: block.timestamp,
                action: "compounded"
            });
            
            reinvestHistory[msg.sender].push(history);
            
            emit AutoReinvestExecuted(msg.sender, pool, amountToReinvest, pendingRewards, block.timestamp);
        }
    }
}

function getAutoReinvestConfig(address user, address pool) external view returns (AutoReinvestConfig memory) {
    return autoReinvestConfigs[user][pool];
}

function getReinvestHistory(address user) external view returns (ReinvestHistory[] memory) {
    return reinvestHistory[user];
}

function getAvailableReinvestment(address user, address pool) external view returns (uint256) {
    AutoReinvestConfig storage config = autoReinvestConfigs[user][pool];
    
    if (!config.enabled) return 0;
    
    uint256 pendingRewards = calculatePendingReward(user, pool);
    
    if (pendingRewards >= config.minReinvestAmount && 
        (pendingRewards >= config.rewardThreshold || config.rewardThreshold == 0)) {
        return pendingRewards;
    }
    
    return 0;
}

function getTotalReinvested(address user, address pool) external view returns (uint256) {
    return autoReinvestConfigs[user][pool].totalReinvested;
}

function getReinvestStats(address user) external view returns (
    uint256 totalReinvested,
    uint256 totalCompounds,
    uint256 lastReinvestTime,
    uint256 lastRewardAmount
) {
    AutoReinvestConfig storage config = autoReinvestConfigs[user][address(0)]; // Simplified
    return (
        config.totalReinvested,
        config.totalCompounds,
        config.lastReinvestTime,
        config.lastRewardAmount
    );
}
}
