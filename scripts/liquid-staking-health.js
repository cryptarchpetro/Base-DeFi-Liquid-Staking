// base-defi-liquid-staking/scripts/health.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function healthCheckLiquidStaking() {
  console.log("Performing health check for Base DeFi Liquid Staking...");
  
  const stakingAddress = "0x...";
  const staking = await ethers.getContractAt("LiquidStakingV3", stakingAddress);
  
  // Проверка здоровья стейкинга
  const healthReport = {
    timestamp: new Date().toISOString(),
    stakingAddress: stakingAddress,
    stakingSummary: {},
    userHealth: {},
    financialHealth: {},
    performanceMetrics: {},
    riskAssessment: {},
    findings: [],
    recommendations: []
  };
  
  try {
    // Сводка стейкинга
    const stakingSummary = await staking.getStakingSummary();
    healthReport.stakingSummary = {
      totalStaked: stakingSummary.totalStaked.toString(),
      totalUsers: stakingSummary.totalUsers.toString(),
      totalRewards: stakingSummary.totalRewards.toString(),
      avgAPR: stakingSummary.avgAPR.toString(),
      totalStakingValue: stakingSummary.totalStakingValue.toString(),
      stakingStatus: stakingSummary.stakingStatus
    };
    
    // Здоровье пользователей
    const userHealth = await staking.getUserHealth();
    healthReport.userHealth = {
      avgStake: userHealth.avgStake.toString(),
      avgAPR: userHealth.avgAPR.toString(),
      userRetention: userHealth.userRetention.toString(),
      avgStakingPeriod: userHealth.avgStakingPeriod.toString(),
      totalActiveUsers: userHealth.totalActiveUsers.toString()
    };
    
    // Финансовое здоровье
    const financialHealth = await staking.getFinancialHealth();
    healthReport.financialHealth = {
      totalRewardsDistributed: financialHealth.totalRewardsDistributed.toString(),
      avgRewardPerUser: financialHealth.avgRewardPerUser.toString(),
      rewardDistributionRate: financialHealth.rewardDistributionRate.toString(),
      liquidityUtilization: financialHealth.liquidityUtilization.toString(),
      fundingStability: financialHealth.fundingStability.toString()
    };
    
    // Показатели производительности
    const performanceMetrics = await staking.getPerformanceMetrics();
    healthReport.performanceMetrics = {
      efficiencyScore: performanceMetrics.efficiencyScore.toString(),
      processingTime: performanceMetrics.processingTime.toString(),
      throughput: performanceMetrics.throughput.toString(),
      uptime: performanceMetrics.uptime.toString(),
      errorRate: performanceMetrics.errorRate.toString()
    };
    
    // Оценка рисков
    const riskAssessment = await staking.getRiskAssessment();
    healthReport.riskAssessment = {
      marketRisk: riskAssessment.marketRisk.toString(),
      technicalRisk: riskAssessment.technicalRisk.toString(),
      operationalRisk: riskAssessment.operationalRisk.toString(),
      regulatoryRisk: riskAssessment.regulatoryRisk.toString(),
      totalRiskScore: riskAssessment.totalRiskScore.toString()
    };
    
    // Найденные проблемы
    if (parseFloat(healthReport.stakingSummary.totalStaked) < 1000000) {
      healthReport.findings.push("Low total staked amount detected");
    }
    
    if (parseFloat(healthReport.userHealth.userRetention) < 70) {
      healthReport.findings.push("Low user retention rate detected");
    }
    
    if (parseFloat(healthReport.performanceMetrics.errorRate) > 2) {
      healthReport.findings.push("High error rate in staking operations");
    }
    
    // Рекомендации
    if (parseFloat(healthReport.stakingSummary.totalStaked) < 5000000) {
      healthReport.recommendations.push("Implement user acquisition strategies");
    }
    
    if (parseFloat(healthReport.userHealth.userRetention) < 80) {
      healthReport.recommendations.push("Develop user retention programs");
    }
    
    if (parseFloat(healthReport.performanceMetrics.errorRate) > 1) {
      healthReport.recommendations.push("Optimize staking operations for better performance");
    }
    
    // Сохранение отчета
    const healthFileName = `liquid-staking-health-${Date.now()}.json`;
    fs.writeFileSync(`./health/${healthFileName}`, JSON.stringify(healthReport, null, 2));
    console.log(`Health report created: ${healthFileName}`);
    
    console.log("Liquid staking health check completed successfully!");
    console.log("Findings:", healthReport.findings.length);
    console.log("Recommendations:", healthReport.recommendations);
    
  } catch (error) {
    console.error("Health check error:", error);
    throw error;
  }
}

healthCheckLiquidStaking()
  .catch(error => {
    console.error("Health check failed:", error);
    process.exit(1);
  });
