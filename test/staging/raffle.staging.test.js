const { getNamedAccounts, deployments, network, ethers } = require("hardhat");
const {
  mockOnThisNetworks,
  networkConfig,
} = require("../../helper-hardhat-config");
const { assert, expect } = require("chai");

mockOnThisNetworks.includes(network.name)
  ? describe.skip
  : describe("Raffle", () => {
      let contract, raffleEnteredFee, deployer;
      beforeEach(async () => {
        deployer = (await getNamedAccounts()).deployer;
        contract = await ethers.getContract("Raffle", deployer);
        raffleEnteredFee = await contract.getAmount();
      });
      describe("fulfillRandomWords", () => {
        it("should kick of keeper and VRF from chainlink and fund winner", async () => {
          let accounts = await ethers.getSigners();
          let signer = accounts[0];
          let startingTimeStamp = await contract.getLatestTimestamp();
          await new Promise(async (resolve, reject) => {
            contract.once("WinnerPicked", async () => {
              console.log("Event has been kicked off!!!");
              try {
                const lastWinner = await contract.getRecentWinner();
                const endingTimeStamp = await contract.getLatestTimestamp();
                const raffleState = await contract.getRaffleState();
                const endingWinnerBalance = await signer.getBalance();

                assert.equal(lastWinner.toString(), signer.address);
                assert(endingTimeStamp > startingTimeStamp);
                assert.equal(raffleState.toString(), "0");
                assert.equal(
                  endingWinnerBalance.toString(),
                  startingWalletBalance.add(raffleEnteredFee).toString()
                );
                resolve();
              } catch (error) {
                console.log(error);
                reject(error);
              }
            });
            await contract.fundContract({ value: raffleEnteredFee });
            const startingWalletBalance = await signer.getBalance();
          });
        });
      });
    });
