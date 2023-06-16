const { network, ethers } = require("hardhat");
const { verify } = require("../utils/verify");
const {
  mockOnThisNetworks,
  networkConfig,
} = require("../helper-hardhat-config");

const FUND_SUBSCRIPTION_ID = ethers.utils.parseEther("1");

module.exports = async ({ deployments, getNamedAccounts }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;
  let vrfCoordinatorV2Address, subscriptionId, contract;
  const entryAmount = networkConfig[chainId]["etherAmount"];
  const gasLane = networkConfig[chainId]["gasLane"];
  const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"];
  const interval = networkConfig[chainId]["interval"];

  if (mockOnThisNetworks.includes(network.name)) {
    contract = await ethers.getContract("VRFCoordinatorV2Mock");
    vrfCoordinatorV2Address = contract.address;

    const createsubId = await contract.createSubscription();
    const transactionReceipt = await createsubId.wait(1);
    subscriptionId = transactionReceipt.events[0].args.subId;

    //fund the subID
    await contract.fundSubscription(subscriptionId, FUND_SUBSCRIPTION_ID);
  } else {
    vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"];
    subscriptionId = networkConfig[chainId]["subscriptionId"];
  }

  const args = [
    vrfCoordinatorV2Address,
    entryAmount,
    gasLane,
    callbackGasLimit,
    interval,
    subscriptionId,
  ];
  const raffle = await deploy("Raffle", {
    from: deployer,
    args: args,
    log: true,
    waitBlockConfirmation: network.config.blockConfirmations || 1,
  });

  log(`Deployed raffle contract at ${raffle.address} this is awesome! 😄`);
  log("\n--------------------------");

  if (mockOnThisNetworks.includes(network.name)) {
    await contract.addConsumer(subscriptionId, raffle.address);
    log("Consumer is added");
  }

  if (
    !mockOnThisNetworks.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    await verify(raffle.address, args);
    log("\n------------------------");
  } else {
    log("No deployment needed. LocalNetwork detected.");
  }
};
module.exports.tags = ["all", "raffle"];
