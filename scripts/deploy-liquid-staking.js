
const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Base DeFi Liquid Staking...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());


  const RewardToken = await ethers.getContractFactory("ERC20Token");
  const rewardToken = await RewardToken.deploy("Reward Token", "REWARD");
  await rewardToken.deployed();
  
  const StakingToken = await ethers.getContractFactory("ERC20Token");
  const stakingToken = await StakingToken.deploy("Staking Token", "STAKE");
  await stakingToken.deployed();


  const LiquidStaking = await ethers.getContractFactory("LiquidStakingV3");
  const staking = await LiquidStaking.deploy(
    rewardToken.address,
    stakingToken.address,
    ethers.utils.parseEther("100"), // 100 tokens per second
    ethers.utils.parseEther("1000"), // 1000 minimum stake
    ethers.utils.parseEther("100000") // 100000 maximum stake
  );

  await staking.deployed();

  console.log("Base DeFi Liquid Staking deployed to:", staking.address);
  console.log("Reward Token deployed to:", rewardToken.address);
  console.log("Staking Token deployed to:", stakingToken.address);
  
  // Сохраняем адреса
  const fs = require("fs");
  const data = {
    staking: staking.address,
    rewardToken: rewardToken.address,
    stakingToken: stakingToken.address,
    owner: deployer.address
  };
  
  fs.writeFileSync("./config/deployment.json", JSON.stringify(data, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
