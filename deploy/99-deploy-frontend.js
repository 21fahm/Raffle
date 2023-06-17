require("dotenv").config();
const fs = require("fs");
const { network, ethers } = require("hardhat");

const FRONTEND_CONTRACTADDRESS =
  "../raffle-frontend/constants/contractAddress.json";
const FRONTEND_ABI = "../raffle-frontend/constants/abi.json";

module.exports = async () => {
  if (process.env.UPDATE_FRONTEND) {
    console.log("Updating frontend...");
    await updatingContractAddress();
    await updateABI();
  }
};

async function updateABI() {
  const raffle = await ethers.getContract("Raffle");
  fs.writeFileSync(
    FRONTEND_ABI,
    raffle.interface.format(ethers.utils.FormatTypes.json)
  );
}

async function updatingContractAddress() {
  const raffle = await ethers.getContract("Raffle");
  const contractAddress = JSON.parse(
    fs.readFileSync(FRONTEND_CONTRACTADDRESS, "utf8")
  );
  const chainId = network.config.chainId.toString();
  if (chainId in contractAddress) {
    if (!contractAddress[chainId].includes(raffle.address)) {
      contractAddress[chainId].push(raffle.address);
    }
  }
  {
    contractAddress[chainId] = [raffle.address];
  }
  fs.writeFileSync(FRONTEND_CONTRACTADDRESS, JSON.stringify(contractAddress));
}

module.exports.tags = ["all", "frontend"];
