const { network, ethers } = require("hardhat");
const { mockOnThisNetworks } = require("../helper-hardhat-config");

const BASE_FEE = ethers.utils.parseEther("0.25");
const GAS_PRICE_LINK = 1e9;

module.exports = async ({ deployments, getNamedAccounts }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const args = [BASE_FEE, GAS_PRICE_LINK];

  if (mockOnThisNetworks.includes(network.name)) {
    log("Local network detected. Deploying Mock contract...");
    await deploy("VRFCoordinatorV2Mock", {
      args: args,
      from: deployer,
      log: true,
    });
    log("MOCKS DEPLOYED!!!");
    log("\n---------------------------------------------------------------");
  }
};

module.exports.tags = ["all", "mock"];
