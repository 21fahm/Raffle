const { ethers } = require("hardhat");

async function enterRaffle() {
  const contract = await ethers.getContract("Raffle");
  const requiredAmount = await contract.getAmount();
  const fundContract = await contract.fundContract({
    value: requiredAmount + 1,
  });
  await fundContract.wait(1);
  console.log(fundContract.hash);
  console.log("Entered Raffle");
}

enterRaffle()
  .then(() => {
    process.exit(0);
  })
  .catch(() => {
    process.exit(1);
  });
