const { ethers, network } = require("hardhat");

async function mockChainLink() {
  const raffle = await ethers.getContractAt("Raffle");
  const checkData = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(""));
  const { upKeepNeeded } = await raffle.callStatic.checkUpKeep(checkData);
  if (upKeepNeeded) {
    const performUpKeep = await raffle.performUpkeep(checkData);
    const txReceipt = await performUpKeep.wait(1);
    const requestId = txReceipt.events[1].args.id;

    if (network.config.chainId == 31337) {
      await randomWords(requestId, raffle);
    } else {
      console.log("Non-localNetwork detected🫡");
    }
  }
}

async function randomWords(requestId, raffle) {
  const mockContract = await ethers.getContractAt("VRFCoordinatorV2Mock");
  await mockContract.fulfillRandomWords(requestId, raffle.address);
  const recentWinner = await raffle.getRecentWinner();
  console.log(recentWinner);
}

mockChainLink()
  .then(() => process.exit(0))
  .catch((e) => console.log(e));
