///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {LotteryFactory} from "./LotteryFactory.sol";
import {LotteryNFT} from "./LotteryNFT.sol";
 
contract Lottery is ERC20Capped {
/*///////////////////////////////////////////////
                STATE VARIABLES 
/*/////////////////////////////////////////////*/
    uint256 private lotteryId;
    uint256 private feePercentage; // in basis points
    uint256 private ticketPriceInWei;
    address private lotteryFactory;
    uint256 private numberOfOwners; // to keep track of limited number of owners

/*//////////////////////////////////////////////
                    ERRORS 
/*////////////////////////////////////////////*/
    error Lottery__NotOpen();
    error Lottery__NotPending();
    error Lottery__TicketsLimitReached();
    error Lottery__ZeroValue();
    error Lottery__CallFailed();
    error Lottery__OnlyWholeTickets(uint256 ticketPriceInWei);
    error Lottery__DirectTransfersDisabled();
    error Lottery__TooManyOwners();

/*//////////////////////////////////////////////
                    EVENTS 
/*////////////////////////////////////////////*/
    event Lottery__TicketsPurchased(address buyer, uint256 amount);
    event Lottery__TicketsTransfered(address sender, address buyer, uint256 amount);
    event Lottery__FeesWithdrawn(address recipient, uint256 amount);
    event Lottery__LotteryClosed(address winner, uint256 reward);

/*//////////////////////////////////////////////
                    MODIFIERS 
/*////////////////////////////////////////////*/
    modifier lotteryIsOpen() {
        if (address(this).balance < cap()) revert Lottery__TicketsLimitReached();
        _;
    }    

    modifier onlyFactory() {
        require(msg.sender == lotteryFactory, Lottery__NotPending());
        _;
    }

    modifier setPendingWinner() {
        _;
        if (totalSupply() == cap()) {
            LotteryFactory(lotteryFactory).setLotteryPendingWinner(true);
        }
    }

    modifier manageOwners(address sender, uint256 amount, address recipient) {
        /* if sender sends entire balance, number of owners is decremented */
        if (sender != address(0) && balanceOf(sender) == amount) {
            numberOfOwners--;
        }

        /* if recipienct has no balance prior to transfer, number of owners is incremented */
        if (balanceOf(recipient) == 0) {
            numberOfOwners++;
        }
        _;
    }

/*/////////////// CONSTRUCTOR ///////////////*/
    constructor (uint256 _lotteryId, uint256 _feePercentage, uint256 _ticketPriceInWei) 
        ERC20("Lottery Ticket", "LT") 
        ERC20Capped(5000)
    {
        lotteryId = _lotteryId;
        feePercentage = _feePercentage;
        ticketPriceInWei = _ticketPriceInWei;
        lotteryFactory = msg.sender;
    }
     

/*//////////////////////////////////////////////
                PUBLIC FUNCTIONS 
/*////////////////////////////////////////////*/
    function transferFrom(address, address, uint256) 
        public virtual override returns (bool) 
    {
        revert Lottery__DirectTransfersDisabled();
    }

    function transfer(address, uint256) 
        public virtual override returns (bool) 
    {
        revert Lottery__DirectTransfersDisabled();
    }

    receive() external payable {}
    
/*//////////////////////////////////////////////
                EXTERNAL FUNCTIONS 
/*////////////////////////////////////////////*/
    function purchaseTickets() 
        external payable 
        lotteryIsOpen 
        setPendingWinner 
        manageOwners(address(0), 0, msg.sender) 
    {
        uint256 tickets = msg.value;
        require(tickets > 0, Lottery__ZeroValue());
        require(tickets % ticketPriceInWei == 0, Lottery__OnlyWholeTickets(ticketPriceInWei));

        _mint(msg.sender, tickets);
        emit Lottery__TicketsPurchased(msg.sender, tickets);
    }

    function transferTickets(address recipient, uint256 amount) 
        external 
        manageOwners(msg.sender, amount, recipient) 
    {
        require(amount % ticketPriceInWei == 0, Lottery__OnlyWholeTickets(ticketPriceInWei));
        _transfer(msg.sender, recipient, amount);  // ← this calls _update(from=msg.sender, recipient, amount) internally
        emit Lottery__TicketsTransfered(msg.sender, recipient, amount);  
    }

    function endLottery(address lotteryWinner) 
        external 
        onlyFactory 
    {
        uint256 fee = address(this).balance * (10000 / feePercentage);

        (bool success, ) = lotteryWinner.call{value: address(this).balance - fee}("");
        require(success, Lottery__CallFailed());

        (bool feeSuccess, ) = lotteryFactory.call{value: fee}("");
        require(feeSuccess, Lottery__CallFailed());

        ///////////////////////
            /* NFT LOGIC */
        ///////////////////////

        LotteryFactory(lotteryFactory).setActiveLottery(address(0));
        LotteryFactory(lotteryFactory).setLotteryPendingWinner(false);
        emit Lottery__LotteryClosed(lotteryWinner, address(this).balance - fee);
    }

/*//////////////////////////////////////////////
                    VIEW FUNCTIONS 
/*////////////////////////////////////////////*/
    function getLotteryId() public view returns (uint256) {
        return lotteryId;
    }

    function getFeePercentage() public view returns (uint256) {
        return feePercentage;
    }

    function getMaxTickets() public view returns (uint256) {
        return cap();
    }

    function getLotteryFactory() public view returns (address) {
        return lotteryFactory;
    }

    function getTicketPriceInWei() public view returns (uint256) {
        return ticketPriceInWei;
    }

    function getNumberOfOwners() public view returns (uint256) {
        return numberOfOwners;
    }
}