// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

error Raffle__NOTENOUGHFUNDS();
error Raffle__CLOSED();
error Raffle__TRANSFERFAILED();
error RAFFLE_UPKEEPNOTNEEDED(
    uint256 balance,
    uint256 participants,
    uint256 state
);

/**
 * @title This is a decentralized lottery contract
 * @author testdev810308
 * @dev This is an untamparable contract that uses chainlink to achieve automation and randomness.
 */

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    //Type variables
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    //State variables
    uint256 private immutable i_entranceFee;
    address payable[] private s_participants;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callBackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    //Lottery variable
    address payable private s_recentWinner;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    event EventRaffle(address indexed funders);
    event RequestedRaffleWinner(uint256 indexed id);
    event WinnerPicked(address indexed winner);

    constructor(
        address vrfCoordinator,
        uint256 amount,
        bytes32 gasLane,
        uint32 callBackGasLimit,
        uint256 interval,
        uint64 subId
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_entranceFee = amount;
        i_gasLane = gasLane;
        i_subId = subId;
        i_callBackGasLimit = callBackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function fundContract() public payable {
        if (msg.value > i_entranceFee) {
            revert Raffle__NOTENOUGHFUNDS();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__CLOSED();
        }
        s_participants.push(payable(msg.sender));
        emit EventRaffle(msg.sender);
    }

    /**
     * @dev This function helps the chainlink nodes to keep
     * check if an update is needed if the upKeepNeeded is true.
     * The following should be true inorder  to return true:
     * 1.Our time interval has passed.
     * 2.Their is atleast 1 funder and the contract has some money.
     * 3.Our subscription is funded with link
     * 4.The lottery should be in an "open" state.
     */

    function checkUpkeep(
        bytes memory /*checkData*/
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/)
    {
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayes = (s_participants.length > 0);
        bool hasMoney = (address(this).balance > 0);
        upkeepNeeded = (isOpen && timePassed && hasPlayes && hasMoney);
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /*performData*/) external override {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert RAFFLE_UPKEEPNOTNEEDED(
                address(this).balance,
                s_participants.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //Max amount of fee you are willing to pay for a request
            i_subId, //SUB ID used by this contract for funding requests
            REQUEST_CONFIRMATIONS, // No of blocks the nodes wait before responding
            i_callBackGasLimit, // Control gas used by the fullfillRandomWords function
            NUM_WORDS // NO. pf random words required
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 randomWinnerIndex = randomWords[0] % s_participants.length;
        address payable lastWinner = s_participants[randomWinnerIndex];
        s_recentWinner = lastWinner;
        s_participants = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        (bool success, ) = lastWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TRANSFERFAILED();
        }
        emit WinnerPicked(lastWinner);
    }

    function getAmount() public view returns (uint256) {
        return i_entranceFee;
    }

    function getParticipants(uint256 index) public view returns (address) {
        return s_participants[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNoOfPlayers() public view returns (uint256) {
        return s_participants.length;
    }

    function getLatestTimestamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmation() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getVrfAddress() public view returns (VRFCoordinatorV2Interface) {
        return i_vrfCoordinator;
    }

    function getCallGasLimit() public view returns (uint32) {
        return i_callBackGasLimit;
    }

    function getGasLane() public view returns (bytes32) {
        return i_gasLane;
    }

    function getSubId() public view returns (uint64) {
        return i_subId;
    }
}
