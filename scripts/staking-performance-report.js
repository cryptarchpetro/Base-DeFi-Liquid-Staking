// base-defi-liquid-staking/scripts/performance-report.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function generateStakingPerformanceReport() {
  console.log("Generating performance report for Base DeFi Liquid Staking...");
  
  const stakingAddress = "0x...";
  const staking = await ethers.getContractAt("LiquidStakingV3", stakingAddress);
  
  // Получение информации о производительности
  const performanceReport = {
    timestamp: new Date().toISOString(),
    stakingAddress: stakingAddress,
    performanceMetrics: {},
    userMetrics: {},
    poolMetrics: {},
    recommendations: []
  };
  
  // Получение показателей производительности
  const performanceMetrics = await staking.getPerformanceMetrics();
  performanceReport.performanceMetrics = {
    totalStaked: performanceMetrics.totalStaked.toString(),
    totalRewards: performanceMetrics.totalRewards.toString(),
    avgAPR: performanceMetrics.avgAPR.toString(),
    totalUsers: performanceMetrics.totalUsers.toString(),
    totalPools: performanceMetrics.totalPools.toString()
  };
  
  // Получение пользовательской статистики
  const userMetrics = await staking.getUserMetrics();
  performanceReport.userMetrics = {
    avgStaked: userMetrics.avgStaked.toString(),
    avgRewards: userMetrics.avgRewards.toString(),
    activeUsers: userMetrics.activeUsers.toString(),
    totalStakedByUsers: userMetrics.totalStakedByUsers.toString()
  };
  
  // Получение статистики по пулам
  const poolMetrics = await staking.getPoolMetrics();
  performanceReport.poolMetrics = {
    avgPoolAPR: poolMetrics.avgPoolAPR.toString(),
    totalPoolStaked: poolMetrics.totalPoolStaked.toString(),
    activePools: poolMetrics.activePools.toString(),
    avgPoolSize: poolMetrics.avgPoolSize.toString()
  };
  
  // Анализ производительности
  const apr = parseFloat(performanceMetrics.avgAPR);
  const userCount = parseInt(performanceMetrics.totalUsers);
  
  if (apr < 500) { // 5%
    performanceReport.recommendations.push("Consider improving APR to attract more users");
  }
  
  if (userCount < 100) {
    performanceReport.recommendations.push("Need to increase user adoption");
  }
  
  // Сравнение с предыдущими данными
  const previousData = await getPreviousPerformanceData();
  if (previousData) {
    const aprChange = apr - parseFloat(previousData.performanceMetrics.avgAPR);
    if (aprChange < 0) {
      performanceReport.recommendations.push("APR decreased compared to previous period");
    }
  }
  
  // Сохранение отчета
  fs.writeFileSync(`./reports/performance-report-${Date.now()}.json`, JSON.stringify(performanceReport, null, 2));
  
  console.log("Performance report generated successfully!");
  console.log("Recommendations:", performanceReport.recommendations.length);
}

async function getPreviousPerformanceData() {
  // Возвращает предыдущие данные (в реальной реализации будет читать из файла или базы данных)
  return null;
}

generateStakingPerformanceReport()
  .catch(error => {
    console.error("Performance report error:", error);
    process.exit(1);
  });
