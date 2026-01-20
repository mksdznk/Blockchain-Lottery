///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/********* IMPORTS *********/  
import {Lottery} from "./Lottery.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract LotteryFactory is Ownable2Step {
    /*///////////// STATE VARIABLES /////////////*/
    uint256 private lotteryCount;

    /*////////////////// ERRORS //////////////////*/
    error LotteryFactory__ZeroAmount();
    error LotteryFactory__InsuffifientAccumulatedFees();
    error LotteryFactory__InvalidRecipient();
    error LotteryFactory__CallFailed();


    /*////////////////// EVENTS //////////////////*/
    event LotteryFactory__LotteryCreated(address lottery);
    event LotteryFactory__FeesWithdrawn(address recipient, uint256 amount);

    /*//////////////// MODIFIERS ////////////////*/

    /*/////////////// CONSTRUCTOR ///////////////*/
    constructor () Ownable(msg.sender) {}

    /*///////////// PUBLIC FUNCTIONS /////////////*/

    /*//////////// EXTERNAL FUNCTIONS ////////////*/
    function createLottery() external returns (address lottery) {
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

    /*//////////// PRIVATE FUNCTIONS ////////////*/
    
    /*//////////// INTERNAL FUNCTIONS ////////////*/

    /*////////////// VIEW FUNCTIONS //////////////*/
    function getLotteryCount() public view returns (uint256) {
        return lotteryCount;
    }
}