const { getNamedAccounts, deployments, network, ethers } = require("hardhat");
const {
  mockOnThisNetworks,
  networkConfig,
} = require("../../helper-hardhat-config");
const { assert, expect } = require("chai");

!mockOnThisNetworks.includes(network.name)
  ? describe.skip
  : describe("Raffle", () => {
      let contract, vrfCoordinatorV2Mock, raffleEnteredFee, deployer, interval;
      beforeEach(async () => {
        deployer = (await getNamedAccounts()).deployer;
        await deployments.fixture(["all"]);

        contract = await ethers.getContract("Raffle", deployer);
        vrfCoordinatorV2Mock = await ethers.getContract(
          "VRFCoordinatorV2Mock",
          deployer
        );
        raffleEnteredFee = await contract.getAmount();
        interval = await contract.getInterval();
      });

      describe("constructor", () => {
        const chainId = network.config.chainId;
        it("initializes the raffle correctly", async () => {
          const raffleState = await contract.getRaffleState();
          assert.equal(raffleState.toString(), "0");
        });
        it("address are the same for deployed contract", async () => {
          const contract2 = await contract.getVrfAddress();
          assert.equal(contract2, vrfCoordinatorV2Mock.address);
        });

        it("initializes the interval correctly", async () => {
          assert.equal(interval.toString(), networkConfig[chainId]["interval"]);
        });
        it("initializes the gasLimit correctly", async () => {
          const callGassLimit = await contract.getCallGasLimit();
          assert.equal(
            callGassLimit,
            networkConfig[chainId]["callbackGasLimit"]
          );
        });
        it("initializes the subID correctly", async () => {
          const subId = await contract.getSubId();
          assert.equal(
            subId.toString(),
            parseInt(networkConfig[chainId]["subscriptionId"]) + 1
          );
        });
        it("initializes the gasLane correctly", async () => {
          const gasLane = await contract.getGasLane();
          assert.equal(gasLane.toString(), networkConfig[chainId]["gasLane"]);
        });
      });

      describe("fundContract", () => {
        it("revert it to fail if not enough sent", async () => {
          expect(async () => {
            await contract.fundContract();
          }).to.be.revertedWith("Raffle__NOTENOUGHFUNDS");
        });
        it("records players when they enter", async () => {
          await contract.fundContract({ value: raffleEnteredFee });
          const partcipant = await contract.getParticipants(0);
          assert.equal(partcipant, deployer);
        });
        it("emits an event on enter", async () => {
          expect(
            await contract.fundContract({ value: raffleEnteredFee })
          ).to.emit(contract, "EventRaffle");
        });
        it("Does not allow entry when calculating", async () => {
          await contract.fundContract({ value: raffleEnteredFee });
          await network.provider.send("evm_increaseTime", [
            parseInt(interval.toString()) + 1,
          ]);
          await network.provider.send("evm_mine", []);
          await contract.performUpkeep([]);
          expect(async () => {
            await contract.fundContract({ value: raffleEnteredFee });
          }).to.revertedWith("Raffle__CLOSED");
        });
      });

      describe("checkUpkeep", () => {
        it("returns false if people have not sent any ETH", async () => {
          await network.provider.send("evm_increaseTime", [
            parseInt(interval.toString()) + 1,
          ]);
          await network.provider.send("evm_mine", []);
          const { upkeepNeeded } = await contract.checkUpkeep([]);
          assert(!upkeepNeeded);
        });
        it("should return false if raffle isn't open", async () => {
          await contract.fundContract({ value: raffleEnteredFee });
          await network.provider.send("evm_increaseTime", [
            parseInt(interval.toString()) + 1,
          ]);
          await network.provider.send("evm_mine", []);
          await contract.performUpkeep("0x");
          const raffleState = await contract.getRaffleState();
          const { upkeepNeeded } = await contract.checkUpkeep("0x");
          assert.equal(upkeepNeeded, false);
          assert.equal(raffleState.toString(), "1");
        });
        it("should return false if enough time hasn't passed", async () => {
          await contract.fundContract({ value: raffleEnteredFee });
          await network.provider.send("evm_increaseTime", [
            parseInt(interval.toString()) - 2, // Why minus 2?
          ]);
          await network.provider.send("evm_mine", []);
          const { upkeepNeeded } = await contract.checkUpkeep("0x");
          assert.equal(upkeepNeeded, false);
        });
        it("returns true for everything", async () => {
          await contract.fundContract({ value: raffleEnteredFee });
          await network.provider.send("evm_increaseTime", [
            parseInt(interval.toString()) + 1,
          ]);
          await network.provider.send("evm_mine", []);
          const { upkeepNeeded } = await contract.checkUpkeep("0x");
          assert(upkeepNeeded);
        });
      });

      describe("performUpkeep", () => {
        it("Can only run if checkUpkeep is true", async () => {
          await contract.fundContract({ value: raffleEnteredFee });
          await network.provider.send("evm_increaseTime", [
            parseInt(interval.toString()) + 1,
          ]);
          await network.provider.send("evm_mine", []);
          const tx = await contract.performUpkeep([]);
          assert(tx);
        });
        it("reverts when checkUpkeep is false", async () => {
          expect(async () => {
            await contract.performUpkeep("0x");
          }).to.be.revertedWith("RAFFLE_UPKEEPNOTNEEDED");
        });
        it("should return that state is calculating", async () => {
          await contract.fundContract({ value: raffleEnteredFee });
          await network.provider.send("evm_increaseTime", [
            parseInt(interval.toString()) + 1,
          ]);
          await network.provider.request({ method: "evm_mine", params: [] });
          const tx = await contract.performUpkeep("0x");
          const txReceipt = await tx.wait(1);
          const raffleState = await contract.getRaffleState();
          const requestId = await txReceipt.events[1].args.id;
          assert.equal(raffleState.toString(), "1");
          assert(requestId.toString() > "0");
        });
      });

      describe("fulfillRandomWords", () => {
        beforeEach(async () => {
          await contract.fundContract({ value: raffleEnteredFee });
          await network.provider.send("evm_increaseTime", [
            parseInt(interval.toString()) + 1,
          ]);
          await network.provider.send("evm_mine", []);
        });
        it("should only be called after performUpkeep", async () => {
          expect(async () => {
            await vrfCoordinatorV2Mock.fulfillRandomWords(0, contract.address);
          }).to.be.revertedWith("nonexistent request");
          expect(async () => {
            await vrfCoordinatorV2Mock.fulfillRandomWords(1, contract.address);
          }).to.be.revertedWith("nonexistent request");
        });
        it("select winner,reset players and send eth", async () => {
          const addParticipants = 3;
          const startingPointForParticipants = 1;
          const accounts = await ethers.getSigners();

          for (
            let i = 1;
            i < startingPointForParticipants + addParticipants;
            i++
          ) {
            const connectAccounts = contract.connect(accounts[i]);
            await connectAccounts.fundContract({ value: raffleEnteredFee });
          }
          const startingTimeStamp = await contract.getLatestTimestamp();
          await new Promise(async (resolve, reject) => {
            contract.once("WinnerPicked", async () => {
              console.log("Found the event...");
              try {
                const lastTimeStamp = await contract.getLatestTimestamp();
                const raffleState = await contract.getRaffleState();
                const winnerAccountBalance = await accounts[1].getBalance();
                const partcipants = await contract.getNoOfPlayers();
                assert.equal(partcipants.toString(), "0");
                assert(lastTimeStamp > startingTimeStamp);
                assert.equal(raffleState.toString(), "0");
                assert.equal(
                  winnerAccountBalance.toString(),
                  winnerStartingBalance
                    .add(
                      raffleEnteredFee
                        .mul(addParticipants)
                        .add(raffleEnteredFee)
                    )
                    .toString()
                );
                resolve();
              } catch (e) {
                console.log(e);
                reject(e);
              }
            });
            const tx = await contract.performUpkeep("0x");
            const txReceipt = await tx.wait(1);
            const winnerStartingBalance = await accounts[1].getBalance();
            await vrfCoordinatorV2Mock.fulfillRandomWords(
              txReceipt.events[1].args.id,
              contract.address
            );
          });
        });
      });
    });
