const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // UNDERLYING and ST_TOKEN can be provided, otherwise deploy helpers via StakingManager if possible
  let underlying = process.env.UNDERLYING || "";
  let stToken = process.env.ST_TOKEN || "";

  if (!underlying) {
    const T = await ethers.getContractFactory("StakingManager");
    const t = await T.deploy("Underlying", "UND", 18);
    await t.deployed();
    underlying = t.address;
    console.log("Underlying (StakingManager):", underlying);
  }

  if (!stToken) {
    const T = await ethers.getContractFactory("StakingManager");
    const t = await T.deploy("StakedToken", "stUND", 18);
    await t.deployed();
    stToken = t.address;
    console.log("StakedToken (StakingManager):", stToken);
  }

  const LS = await ethers.getContractFactory("LiquidStaking");
  const ls = await LS.deploy(underlying, stToken);
  await ls.deployed();

  console.log("LiquidStaking:", ls.address);

  const out = {
    network: hre.network.name,
    chainId: (await ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    contracts: {
      Underlying: underlying,
      StToken: stToken,
      LiquidStaking: ls.address
    }
  };

  const outPath = path.join(__dirname, "..", "deployments.json");
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log("Saved:", outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
