///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/********* IMPORTS *********/  
import {Lottery} from "./Lottery.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

contract LotteryFactory is Ownable2Step {

/*//////////////////////////////////////////////
                STATE VARIABLES 
/*////////////////////////////////////////////*/
    uint256 private lotteryCount;
    address private activeLottery;
    bool private lotteryPendingWinner;

/*//////////////////////////////////////////////
                    ERRORS 
/*////////////////////////////////////////////*/
    error LotteryFactory__ZeroAmount();
    error LotteryFactory__InsuffifientAccumulatedFees();
    error LotteryFactory__InvalidRecipient();
    error LotteryFactory__CallFailed();
    error LotteryFactory__ActiveLotteryExists();
    error LotteryFactory__NotLottery();

/*//////////////////////////////////////////////
                    EVENTS 
/*////////////////////////////////////////////*/
    event LotteryFactory__LotteryCreated(address lottery);
    event LotteryFactory__FeesWithdrawn(address recipient, uint256 amount);

/*//////////////////////////////////////////////
                  MODIFIERS 
/*////////////////////////////////////////////*/
    modifier onlyLottery() {
        // require(address(msg.sender).data == lotterydata, LotteryFactory__NotLottery());
        _;
    }

    modifier onlyOracle() {
        // require(address(msg.sender).data == oracledata, LotteryFactory__NotOracle());
        _;
    }

/*/////////////// CONSTRUCTOR ///////////////*/
    constructor () {}

/*//////////////////////////////////////////////
                EXTERNAL FUNCTIONS
/*////////////////////////////////////////////*/
    function createLottery(uint256 cap, uint256 fee) external onlyOwner returns (address lottery) {
        //IMPLEMENT
        require(!lotteryPendingWinner, LotteryFactory__ActiveLotteryExists());
        
        lottery = address(new Lottery{salt: bytes32(lotteryCount)}(lotteryCount, cap, fee));
        emit LotteryFactory__LotteryCreated(lottery);
        lotteryCount++;
        activeLottery = lottery;
    }

    function endLottery(address lottery, address lotteryWinner) external onlyOwner {
        require(lottery == activeLottery, LotteryFactory__NotLottery());
        require(lotteryWinner != address(0), LotteryFactory__InvalidRecipient());

        ///////// Implement lottery ending
        Lottery(lottery).endLottery(lotteryWinner);
        /////////

        activeLottery = address(0);
        //IMPLEMENT
    }

    function withdrawFees(uint256 amount, address recipient) external onlyOwner {
        require(amount > 0, LotteryFactory__ZeroAmount());
        require(amount <= address(this).balance, LotteryFactory__InsuffifientAccumulatedFees());
        require(recipient != address(0), LotteryFactory__InvalidRecipient());

        (bool success, ) = recipient.call{value: amount}("");
        require(success, LotteryFactory__CallFailed());
        emit LotteryFactory__FeesWithdrawn(recipient, amount);
    }

    function setActiveLottery(address lottery) external onlyLottery {
        activeLottery = lottery;
    }

    function setLotteryPendingWinner(bool pending) external onlyLottery {
        lotteryPendingWinner = pending;
    }

/*//////////////////////////////////////////////
                VIEW FUNCTIONS 
/*////////////////////////////////////////////*/
    function getLotteryCount() public view returns (uint256) {
        return lotteryCount;
    }

    function getActiveLottery() public view returns (address) {
        return activeLottery;
    }

    function getLotteryPendingWinner() public view returns (bool) {
        return lotteryPendingWinner;
    }
}