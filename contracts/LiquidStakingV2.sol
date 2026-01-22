// base-defi-liquid-staking/contracts/LiquidStakingV3.sol

struct AutoReinvestSettings {
    bool enabled;
    uint256 minReinvestAmount;
    uint256 frequency; // Частота реинвестирования в секундах
    uint256 lastReinvestTime;
    uint256 rewardThreshold;
    bool compoundRewards;
}

struct UserPortfolio {
    uint256 totalStaked;
    uint256 totalRewards;
    uint256 lastClaimTime;
    uint256[] stakingHistory;
    mapping(address => uint256) stakedByPool;
    mapping(address => uint256) rewardsByPool;
}

mapping(address => AutoReinvestSettings) public autoReinvestSettings;
mapping(address => UserPortfolio) public userPortfolios;

event AutoReinvestEnabled(
    address indexed user,
    address indexed pool,
    bool enabled,
    uint256 frequency
);

event PortfolioUpdated(
    address indexed user,
    address indexed pool,
    uint256 totalStaked,
    uint256 totalRewards
);

event AutoReinvestExecuted(
    address indexed user,
    address indexed pool,
    uint256 amount,
    uint256 rewards,
    uint256 timestamp
);

// Включение автоматического реинвестирования
function enableAutoReinvest(
    address pool,
    uint256 frequency,
    uint256 minAmount,
    uint256 rewardThreshold,
    bool compound
) external {
    require(pool != address(0), "Invalid pool");
    require(frequency >= 3600, "Frequency too short (minimum 1 hour)");
    
    autoReinvestSettings[pool] = AutoReinvestSettings({
        enabled: true,
        minReinvestAmount: minAmount,
        frequency: frequency,
        lastReinvestTime: block.timestamp,
        rewardThreshold: rewardThreshold,
        compoundRewards: compound
    });
    
    emit AutoReinvestEnabled(msg.sender, pool, true, frequency);
}

// Отключение автоматического реинвестирования
function disableAutoReinvest(address pool) external {
    require(pool != address(0), "Invalid pool");
    autoReinvestSettings[pool].enabled = false;
    emit AutoReinvestEnabled(msg.sender, pool, false, 0);
}


function autoReinvest(address pool) external {
    require(autoReinvestSettings[pool].enabled, "Auto reinvest not enabled");
    require(block.timestamp >= autoReinvestSettings[pool].lastReinvestTime + autoReinvestSettings[pool].frequency, "Too early for reinvestment");
    
    uint256 pendingRewards = calculatePendingReward(msg.sender, pool);
    
    // Проверка минимальной суммы
    if (pendingRewards >= autoReinvestSettings[pool].minReinvestAmount) {
        // Проверка порога наград
        if (pendingRewards >= autoReinvestSettings[pool].rewardThreshold || 
            autoReinvestSettings[pool].rewardThreshold == 0) {
            
            // Реинвестируем награды
            uint256 amountToReinvest = pendingRewards;
            
            // Если Compound Rewards включен, реинвестируем все награды
            if (autoReinvestSettings[pool].compoundRewards) {
                // Обновляем статистику
                updatePortfolio(msg.sender, pool, amountToReinvest, pendingRewards);
                
                // Переводим награды обратно в стейкинг
                rewardToken.transferFrom(msg.sender, address(this), amountToReinvest);
                stake(pool, amountToReinvest);
                
                // Обновляем время последнего реинвестирования
                autoReinvestSettings[pool].lastReinvestTime = block.timestamp;
                
                emit AutoReinvestExecuted(msg.sender, pool, amountToReinvest, pendingRewards, block.timestamp);
            }
        }
    }
}

// Обновление портфеля пользователя
function updatePortfolio(
    address user,
    address pool,
    uint256 amount,
    uint256 rewards
) internal {
    UserPortfolio storage portfolio = userPortfolios[user];
    
    portfolio.totalStaked = portfolio.totalStaked.add(amount);
    portfolio.totalRewards = portfolio.totalRewards.add(rewards);
    portfolio.lastClaimTime = block.timestamp;
    
    portfolio.stakedByPool[pool] = portfolio.stakedByPool[pool].add(amount);
    portfolio.rewardsByPool[pool] = portfolio.rewardsByPool[pool].add(rewards);
    
    emit PortfolioUpdated(user, pool, portfolio.totalStaked, portfolio.totalRewards);
}

// Получение информации о настройках автоматического реинвестирования
function getAutoReinvestSettings(address pool) external view returns (AutoReinvestSettings memory) {
    return autoReinvestSettings[pool];
}

// Получение портфеля пользователя
function getUserPortfolio(address user) external view returns (UserPortfolio memory) {
    return userPortfolios[user];
}

// Получение статистики по пулу
function getPoolPortfolio(address pool) external view returns (
    uint256 totalStaked,
    uint256 totalRewards,
    uint256 userCount
) {
    // Реализация в будущем
    return (0, 0, 0);
}

// Получение информации о времени следующего реинвестирования
function getNextReinvestTime(address pool) external view returns (uint256) {
    if (!autoReinvestSettings[pool].enabled) {
        return 0;
    }
    return autoReinvestSettings[pool].lastReinvestTime + autoReinvestSettings[pool].frequency;
}

// Получение информации о доступных наградах для автоматического реинвестирования
function getAvailableAutoReinvestRewards(address user, address pool) external view returns (uint256) {
    uint256 pendingRewards = calculatePendingReward(user, pool);
    AutoReinvestSettings storage settings = autoReinvestSettings[pool];
    
    if (settings.enabled && pendingRewards >= settings.minReinvestAmount) {
        return pendingRewards;
    }
    return 0;
}
