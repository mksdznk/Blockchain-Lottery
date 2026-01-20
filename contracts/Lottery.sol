///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
 
contract Lottery is ERC20Capped {
    /*////////////// STATE VARIABLES /////////////*/
    address private lotteryFactory;
    uint256 private lotteryId;
    uint256 private maxTickets;
    uint256 private maxTicketsPerPerson;
    uint256 private fee;
    Status private status;

    mapping(address => uint256) private tickets;

    enum Status { 
        Open,
        Pending,
        Closed
    }

    /*////////////////// ERRORS //////////////////*/
    error Lottery__NotOpen();
    error Lottery_TicketsLimitReached();

    /*////////////////// EVENTS //////////////////*/
    event Lottery__TicketsPurchased(address buyer, uint256 amount);
    event Lottery__LotteryClosed(address winner, uint256 reward);

    /*//////////////// MODIFIERS ////////////////*/
    modifier lotteryIsOpen() {
        if (status != Status.Open) revert Lottery__NotOpen();
        _;
    }    

    /*/////////////// CONSTRUCTOR ///////////////*/
    constructor (uint256 _lotteryId, uint256 _cap, uint256 _fee) ERC20("Lottery Ticket", "LT") ERC20Capped(_cap) {
        lotteryFactory = msg.sender;
        lotteryId = _lotteryId;
        fee = _fee;
    }
     
    /*//////////// EXTERNAL FUNCTIONS ////////////*/
    function purchaseTickets() external returns (uint256 amount) {
        //IMPLEMENT
    }

    function closeLottery() external {
        //IMPLEMENT
    }

    /*//////////// PRIVATE FUNCTIONS /////////////*/
    
    /*//////////// INTERNAL FUNCTIONS ////////////*/

    /*////////////// VIEW FUNCTIONS //////////////*/
    function getLotteryId() public view returns (uint256) {
        return lotteryId;
    }

    function getFee() public view returns (uint256) {
        return fee;
    }

    function getStatus() public view returns (Status) {
        return status;
    }

    function getMaxTickets() public view returns (uint256) {
        return maxTickets;
    }

    function getMaxTicketsPerPerson() public view returns (uint256) {
        return maxTicketsPerPerson;
    }

    function get
}