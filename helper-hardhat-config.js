const { ethers } = require("hardhat");

const networkConfig = {
  11155111: {
    name: "sepolia",
    vrfCoordinatorV2: "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
    etherAmount: ethers.utils.parseEther("0.01"),
    gasLane:
      "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c",
    callbackGasLimit: "500000",
    //add subId here
    interval: "30",
  },
  1: {
    name: "Ethereum",
    vrfCoordinatorV2: "0x271682DEB8C4E0901D1a1550aD2e64D568E69909",
  },
  80001: {
    name: "Mumbai",
    vrfCoordinatorV2: "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed",
  },
  137: {
    name: "Polygon",
    vrfCoordinatorV2: "0xAE975071Be8F8eE67addBC1A82488F1C24858067",
  },
  31337: {
    name: "hardhat",
    etherAmount: ethers.utils.parseEther("0.01"),
    gasLane:
      "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c",
    callbackGasLimit: "500000",
    interval: "30",
    subscriptionId: "0",
  },
};
const mockOnThisNetworks = ["hardhat", "localhost"];

module.exports = {
  networkConfig,
  mockOnThisNetworks,
};
