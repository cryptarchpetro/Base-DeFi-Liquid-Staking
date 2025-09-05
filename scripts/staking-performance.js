// base-defi-liquid-staking/scripts/performance.js
const { ethers } = require("hardhat");

async function analyzeStakingPerformance() {
  console.log("Analyzing Base DeFi Liquid Staking Performance...");
  
  const stakingAddress = "0x...";
  const staking = await ethers.getContractAt("LiquidStakingV3", stakingAddress);
  
  // Получение производительности
  const performanceStats = await staking.getPerformanceStats();
  console.log("Performance Stats:", {
    totalStaked: performanceStats.totalStaked.toString(),
    totalRewards: performanceStats.totalRewards.toString(),
    totalUsers: performanceStats.totalUsers.toString(),
    avgAPR: performanceStats.avgAPR.toString(),
    totalStakingValue: performanceStats.totalStakingValue.toString()
  });
  
  // Получение статистики по пулу
  const poolPerformance = await staking.getPoolPerformance();
  console.log("Pool Performance:", {
    totalPools: poolPerformance.totalPools.toString(),
    activePools: poolPerformance.activePools.toString(),
    avgPoolAPR: poolPerformance.avgPoolAPR.toString(),
    totalPoolStaked: poolPerformance.totalPoolStaked.toString()
  });
  
  // Получение информации о пользователях
  const userPerformance = await staking.getUserPerformance();
  console.log("User Performance:", {
    totalActiveUsers: userPerformance.totalActiveUsers.toString(),
    avgStaked: userPerformance.avgStaked.toString(),
    avgRewards: userPerformance.avgRewards.toString()
  });
  
  // Получение статистики по наградам
  const rewardPerformance = await staking.getRewardPerformance();
  console.log("Reward Performance:", {
    totalRewardsDistributed: rewardPerformance.totalRewardsDistributed.toString(),
    avgRewardPerUser: rewardPerformance.avgRewardPerUser.toString(),
    rewardDistributionRate: rewardPerformance.rewardDistributionRate.toString()
  });
  
  // Генерация отчета о производительности
  const fs = require("fs");
  const performanceReport = {
    timestamp: new Date().toISOString(),
    stakingAddress: stakingAddress,
    performance: {
      performanceStats: performanceStats,
      poolPerformance: poolPerformance,
      userPerformance: userPerformance,
      rewardPerformance: rewardPerformance
    }
  };
  
  fs.writeFileSync("./reports/staking-performance.json", JSON.stringify(performanceReport, null, 2));
  
  console.log("Staking performance analysis completed successfully!");
}

analyzeStakingPerformance()
  .catch(error => {
    console.error("Performance analysis error:", error);
    process.exit(1);
  });
