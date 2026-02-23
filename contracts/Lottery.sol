///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {LotteryFactory} from "./LotteryFactory.sol";
import {LotteryFunctions} from "./LotteryFunctions.sol";

contract Lottery is ERC20Capped {
    /*///////////////////////////////////////////////
                    STATE VARIABLES
    ///////////////////////////////////////////////*/
    uint256 private feePercentage; // in basis points
    uint256 private ticketPriceInWei;
    address private lotteryFactory;
    uint256 private maxOwners;
    uint256 private numberOfOwners; // to keep track of limited number of owners
    address private lotteryWinner;
    address private lotteryFunctions;
    bool private lotteryClosed;

    /*//////////////////////////////////////////////
                        ERRORS
    //////////////////////////////////////////////*/
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
    //////////////////////////////////////////////*/
    event Lottery__TicketsPurchased(address buyer, uint256 amount);
    event Lottery__TicketsTransfered(address sender, address buyer, uint256 amount);
    event Lottery__FeesWithdrawn(address recipient, uint256 amount);
    event Lottery__LotteryClosed(address winner, uint256 reward);

    /*//////////////////////////////////////////////
                        MODIFIERS
    //////////////////////////////////////////////*/
    modifier lotteryIsOpen() {
        if (lotteryClosed) revert Lottery__NotOpen();
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == lotteryFactory, Lottery__NotPending());
        _;
    }

    modifier manageOwners(address sender, uint256 amount, address recipient) {
        /* if sender sends entire balance, number of owners is decremented */
        if (sender != address(0) && balanceOf(sender) == amount) {
            numberOfOwners--;
        }

        /* if recipienct has no balance prior to transfer, number of owners is incremented */
        if (balanceOf(recipient) == 0) {
            require(numberOfOwners < maxOwners, Lottery__TooManyOwners());
            numberOfOwners++;
        }
        _;
    }

    modifier setPendingLottery() {
        _;
        if (totalSupply() == cap() || numberOfOwners == maxOwners) {
            LotteryFunctions(lotteryFunctions).setLotteryPending(true);
        }
    }

    /*/////////////// CONSTRUCTOR ///////////////*/
    constructor(uint256 _feePercentage, uint256 _ticketPriceInWei, uint256 _cap, uint256 _maxOwners, address _lotteryFunctions)
        ERC20("Lottery Ticket", "LT")
        ERC20Capped(_cap)
    {
        feePercentage = _feePercentage;
        ticketPriceInWei = _ticketPriceInWei;
        lotteryFactory = msg.sender;
        maxOwners = _maxOwners;
        lotteryFunctions = _lotteryFunctions;
    }

    /*//////////////////////////////////////////////
                    PUBLIC FUNCTIONS
    //////////////////////////////////////////////*/
    function transferFrom(address, address, uint256) public virtual override returns (bool) {
        revert Lottery__DirectTransfersDisabled();
    }

    function transfer(address, uint256) public virtual override returns (bool) {
        revert Lottery__DirectTransfersDisabled();
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    /*//////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    //////////////////////////////////////////////*/
    receive() external payable {}

    function purchaseTickets()
        external
        payable
        lotteryIsOpen
        manageOwners(address(0), 0, msg.sender)
        setPendingLottery
    {
        require(msg.value > 0, Lottery__ZeroValue());
        require(msg.value % ticketPriceInWei == 0, Lottery__OnlyWholeTickets(ticketPriceInWei));
        uint256 tickets = msg.value / ticketPriceInWei;

        _mint(msg.sender, tickets);
        emit Lottery__TicketsPurchased(msg.sender, tickets);
    }

    function transferTickets(address recipient, uint256 amount)
        external
        manageOwners(msg.sender, amount, recipient)
        setPendingLottery
    {
        _transfer(msg.sender, recipient, amount);
        emit Lottery__TicketsTransfered(msg.sender, recipient, amount);
    }

    function endLottery(address _lotteryWinner) external onlyFactory returns (uint256 reward) {
        uint256 fee = address(this).balance * feePercentage / 10000;

        reward = address(this).balance - fee;

        (bool success,) = _lotteryWinner.call{value: reward}("");
        require(success, Lottery__CallFailed());

        (bool feeSuccess,) = lotteryFactory.call{value: fee}("");
        require(feeSuccess, Lottery__CallFailed());

        lotteryWinner = _lotteryWinner;
        lotteryClosed = true;
        emit Lottery__LotteryClosed(_lotteryWinner, reward);
    }

    /*//////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////*/

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

    function getMaxOwners() public view returns (uint256) {
        return maxOwners;
    }

    function getTicketsLeft() public view returns (uint256) {
        return (cap() - totalSupply());
    }
}
