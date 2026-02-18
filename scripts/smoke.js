require("dotenv").config();
const fs = require("fs");
const path = require("path");

async function main() {
  const depPath = path.join(__dirname, "..", "deployments.json");
  const deployments = JSON.parse(fs.readFileSync(depPath, "utf8"));

  const lsAddr = deployments.contracts.LiquidStaking;
  const undAddr = deployments.contracts.Underlying;
  const stAddr = deployments.contracts.StToken;

  const [owner, user] = await ethers.getSigners();
  const ls = await ethers.getContractAt("LiquidStaking", lsAddr);
  const und = await ethers.getContractAt("StakingManager", undAddr);
  const st = await ethers.getContractAt("StakingManager", stAddr);

  console.log("LiquidStaking:", lsAddr);

  const amt = ethers.utils.parseUnits("5", 18);
  await (await und.mint(user.address, amt)).wait();
  await (await und.connect(user).approve(lsAddr, amt)).wait();

  await (await ls.connect(user).deposit(amt)).wait();
  console.log("Deposited");

  await (await st.connect(user).approve(lsAddr, amt)).wait();
  await (await ls.connect(user).requestRedeem(amt)).wait();
  console.log("Redeem requested");

  await (await ls.connect(user).cancelRedeem()).wait();
  console.log("Redeem cancelled");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

