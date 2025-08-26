# base-defi-liquid-staking/contracts/LiquidStaking.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LiquidStaking is Ownable, ReentrancyGuard {
    struct StakingPool {
        IERC20 underlyingToken;
        IERC20 stakingToken;
        uint256 totalStaked;
        uint256 totalSupply;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 accRewardPerShare;
        uint256 poolStartTime;
        uint256 poolEndTime;
        bool isActive;
    }
    
    struct Staker {
        uint256 stakedAmount;
        uint256 rewardDebt;
        uint256 lastUpdateTime;
        uint256[] stakingHistory;
    }
    
    struct RewardDistribution {
        address distributor;
        uint256 distributionAmount;
        uint256 distributionTime;
        bool claimed;
    }
    
    mapping(address => StakingPool) public stakingPools;
    mapping(address => Staker) public stakers;
    mapping(address => mapping(address => RewardDistribution)) public rewardDistributions;
    
    IERC20 public rewardToken;
    uint256 public constant REWARD_PRECISION = 1e18;
    uint256 public performanceFee;
    uint256 public withdrawalFee;
    
    event Staked(
        address indexed user,
        address indexed pool,
        uint256 amount,
        uint256 sharesMinted
    );
    
    event Unstaked(
        address indexed user,
        address indexed pool,
        uint256 amount,
        uint256 sharesBurned
    );
    
    event RewardDistributed(
        address indexed pool,
        address indexed distributor,
        uint256 amount,
        uint256 timestamp
    );
    
    event RewardClaimed(
        address indexed user,
        address indexed pool,
        uint256 rewardAmount
    );
    
    constructor(
        address _rewardToken,
        uint256 _performanceFee,
        uint256 _withdrawalFee
    ) {
        rewardToken = IERC20(_rewardToken);
        performanceFee = _performanceFee;
        withdrawalFee = _withdrawalFee;
    }
    
    function createStakingPool(
        address underlyingToken,
        address stakingToken,
        uint256 rewardRate,
        uint256 startTime,
        uint256 endTime
    ) external onlyOwner {
        require(underlyingToken != stakingToken, "Same tokens");
        require(startTime > block.timestamp, "Invalid start time");
        require(endTime > startTime, "Invalid end time");
        
        stakingPools[underlyingToken] = StakingPool({
            underlyingToken: IERC20(underlyingToken),
            stakingToken: IERC20(stakingToken),
            totalStaked: 0,
            totalSupply: 0,
            rewardRate: rewardRate,
            lastUpdateTime: startTime,
            accRewardPerShare: 0,
            poolStartTime: startTime,
            poolEndTime: endTime,
            isActive: true
        });
    }
    
    function stake(
        address poolAddress,
        uint256 amount
    ) external nonReentrant {
        StakingPool storage pool = stakingPools[poolAddress];
        require(pool.isActive, "Pool inactive");
        require(block.timestamp >= pool.poolStartTime, "Pool not started");
        require(block.timestamp <= pool.poolEndTime, "Pool ended");
        require(amount > 0, "Amount must be greater than 0");
        require(pool.underlyingToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Update pool rewards
        updatePool(poolAddress);
        
        // Transfer underlying tokens
        pool.underlyingToken.transferFrom(msg.sender, address(this), amount);
        
        // Calculate shares
        uint256 shares = amount;
        if (pool.totalSupply > 0) {
            shares = (amount * pool.totalSupply) / pool.totalStaked;
        }
        
        // Update staker
        stakers[msg.sender].stakedAmount += amount;
        stakers[msg.sender].lastUpdateTime = block.timestamp;
        
        // Update pool
        pool.totalStaked += amount;
        pool.totalSupply += shares;
        
        // Mint staking tokens to user
        pool.stakingToken.mint(msg.sender, shares);
        
        emit Staked(msg.sender, poolAddress, amount, shares);
    }
    
    function unstake(
        address poolAddress,
        uint256 shares
    ) external nonReentrant {
        StakingPool storage pool = stakingPools[poolAddress];
        require(pool.isActive, "Pool inactive");
        require(stakers[msg.sender].stakedAmount >= shares, "Insufficient stake");
        
        // Update pool rewards
        updatePool(poolAddress);
        
        // Calculate amount to unstake
        uint256 amount = (shares * pool.totalStaked) / pool.totalSupply;
        
        // Apply withdrawal fee
        uint256 fee = (amount * withdrawalFee) / 10000;
        uint256 amountAfterFee = amount - fee;
        
        // Burn staking tokens
        pool.stakingToken.burn(msg.sender, shares);
        
        // Transfer tokens to user
        pool.underlyingToken.transfer(msg.sender, amountAfterFee);
        
        // Transfer fee to owner
        if (fee > 0) {
            pool.underlyingToken.transfer(owner(), fee);
        }
        
        // Update staker
        stakers[msg.sender].stakedAmount -= amount;
        stakers[msg.sender].lastUpdateTime = block.timestamp;
        
        // Update pool
        pool.totalStaked -= amount;
        pool.totalSupply -= shares;
        
        emit Unstaked(msg.sender, poolAddress, amount, shares);
    }
    
    function claimRewards(
        address poolAddress
    ) external nonReentrant {
        StakingPool storage pool = stakingPools[poolAddress];
        require(pool.isActive, "Pool inactive");
        
        updatePool(poolAddress);
        uint256 reward = calculatePendingReward(msg.sender, poolAddress);
        require(reward > 0, "No rewards to claim");
        
        // Transfer rewards
        rewardToken.transfer(msg.sender, reward);
        
        // Update reward debt
        stakers[msg.sender].rewardDebt += reward;
        
        emit RewardClaimed(msg.sender, poolAddress, reward);
    }
    
    function distributeReward(
        address poolAddress,
        address distributor,
        uint256 amount
    ) external {
        StakingPool storage pool = stakingPools[poolAddress];
        require(pool.isActive, "Pool inactive");
        require(distributor != address(0), "Invalid distributor");
        require(amount > 0, "Amount must be greater than 0");
        require(rewardToken.balanceOf(msg.sender) >= amount, "Insufficient rewards");
        
        // Transfer rewards to contract
        rewardToken.transferFrom(msg.sender, address(this), amount);
        
        // Store distribution info
        rewardDistributions[poolAddress][distributor] = RewardDistribution({
            distributor: distributor,
            distributionAmount: amount,
            distributionTime: block.timestamp,
            claimed: false
        });
        
        emit RewardDistributed(poolAddress, distributor, amount, block.timestamp);
    }
    
    function updatePool(address poolAddress) internal {
        StakingPool storage pool = stakingPools[poolAddress];
        if (block.timestamp <= pool.lastUpdateTime) return;
        
        uint256 timePassed = block.timestamp - pool.lastUpdateTime;
        uint256 rewards = timePassed * pool.rewardRate;
        
        if (pool.totalStaked > 0) {
            pool.accRewardPerShare += (rewards * REWARD_PRECISION) / pool.totalStaked;
        }
        
        pool.lastUpdateTime = block.timestamp;
    }
    
    function calculatePendingReward(address user, address poolAddress) internal view returns (uint256) {
        StakingPool storage pool = stakingPools[poolAddress];
        Staker storage staker = stakers[user];
        
        uint256 pending = (staker.stakedAmount * pool.accRewardPerShare) / REWARD_PRECISION;
        return pending - staker.rewardDebt;
    }
    
    function getStakingInfo(address poolAddress) external view returns (StakingPool memory) {
        return stakingPools[poolAddress];
    }
    
    function getUserStake(address user, address poolAddress) external view returns (uint256) {
        return stakers[user].stakedAmount;
    }
}
