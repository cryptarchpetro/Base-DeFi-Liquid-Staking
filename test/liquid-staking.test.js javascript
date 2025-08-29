// base-defi-liquid-staking/test/liquid-staking.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Base DeFi Liquid Staking", function () {
  let staking;
  let rewardToken;
  let stakingToken;
  let owner;
  let addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    
    // Деплой токенов
    const RewardToken = await ethers.getContractFactory("ERC20Token");
    rewardToken = await RewardToken.deploy("Reward Token", "REWARD");
    await rewardToken.deployed();
    
    const StakingToken = await ethers.getContractFactory("ERC20Token");
    stakingToken = await StakingToken.deploy("Staking Token", "STAKE");
    await stakingToken.deployed();
    
    // Деплой Liquid Staking
    const LiquidStaking = await ethers.getContractFactory("LiquidStakingV3");
    staking = await LiquidStaking.deploy(
      rewardToken.address,
      stakingToken.address,
      ethers.utils.parseEther("100"), // 100 tokens per second
      ethers.utils.parseEther("1000"), // 1000 minimum stake
      ethers.utils.parseEther("100000") // 100000 maximum stake
    );
    await staking.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await staking.owner()).to.equal(owner.address);
    });

    it("Should initialize with correct parameters", async function () {
      expect(await staking.rewardToken()).to.equal(rewardToken.address);
      expect(await staking.stakingToken()).to.equal(stakingToken.address);
      expect(await staking.rewardPerSecond()).to.equal(ethers.utils.parseEther("100"));
    });
  });

  describe("Pool Management", function () {
    it("Should create a staking pool", async function () {
      await expect(staking.createStakingPool(
        stakingToken.address,
        ethers.utils.parseEther("100"),
        Math.floor(Date.now() / 1000),
        Math.floor(Date.now() / 1000) + 3600,
        10000 // 100% APR
      )).to.emit(staking, "PoolCreated");
    });
  });

  describe("Staking Operations", function () {
    beforeEach(async function () {
      await staking.createStakingPool(
        stakingToken.address,
        ethers.utils.parseEther("100"),
        Math.floor(Date.now() / 1000),
        Math.floor(Date.now() / 1000) + 3600,
        10000 // 100% APR
      );
    });

    it("Should stake tokens", async function () {
      await stakingToken.mint(addr1.address, ethers.utils.parseEther("1000"));
      await stakingToken.connect(addr1).approve(staking.address, ethers.utils.parseEther("1000"));
      
      await expect(staking.connect(addr1).stake(stakingToken.address, ethers.utils.parseEther("100")))
        .to.emit(staking, "Staked");
    });
  });
});
