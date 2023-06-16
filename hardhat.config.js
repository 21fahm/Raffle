require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("hardhat-deploy");
require("@nomiclabs/hardhat-ethers");

/** @type import('hardhat/config').HardhatUserConfig */

const url = process.env.RPC_URL;
const key = process.env.PRIV_KEY;
const etherscan = process.env.ETHERSCAN_API_KEY;
const marketCap = process.env.COINMARTKETCAP_API_KEY;

module.exports = {
  solidity: "0.8.18",
  networks: {
    sepolia: {
      url: url,
      accounts: [key],
      chainId: 11155111,
      blockConfirmations: 6,
    },
    hardhat: {
      chainId: 31337,
      blockConfirmations: 1,
    },
  },
  localhost: {
    url: "http://127.0.0.1:8545/",
    chainId: 31337,
    blockConfirmations: 1,
  },
  gasReporter: {
    enabled: false,
    currency: "KES",
    coinmarketcap: marketCap,
    outputFile: "gas_report.txt",
    noColors: true,
  },
  etherscan: {
    apiKey: etherscan,
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    player: {
      default: 1,
    },
  },
  mocha: {
    timeout: 300000,
  },
};
