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
    //////////////////////////////////////////////*/
    uint256 private lotteryCount;
    address private oracle;
    address payable private activeLottery;
    bool private lotteryPending;

    mapping(address => bool) private isLottery;
    mapping(uint256 => address) private lotteries;

    /*//////////////////////////////////////////////
                        ERRORS
    //////////////////////////////////////////////*/
    error LotteryFactory__ZeroAmount();
    error LotteryFactory__InsuffifientAccumulatedFees();
    error LotteryFactory__InvalidRecipient();
    error LotteryFactory__CallFailed();
    error LotteryFactory__ActiveLotteryExists();
    error LotteryFactory__NotLottery();
    error LotteryFactory__NotOracle();
    error LotteryFactory__OracleNotSet();
    error LotteryFactory__InvalidCap();

    /*//////////////////////////////////////////////
                        EVENTS
    //////////////////////////////////////////////*/
    event LotteryFactory__LotteryCreated(address lottery);
    event LotteryFactory__FeesWithdrawn(address recipient, uint256 amount);

    /*//////////////////////////////////////////////
                      MODIFIERS
    //////////////////////////////////////////////*/
    modifier onlyLottery() {
        require(isLottery[msg.sender], LotteryFactory__NotLottery());
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, LotteryFactory__NotOracle());
        _;
    }

    /*/////////////// CONSTRUCTOR ///////////////*/
    constructor() {}

    /*//////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    //////////////////////////////////////////////*/
    function createLottery(uint256 fee, uint256 ticketPriceInWei, uint256 cap) external onlyOwner returns (address lottery) {
        require(!lotteryPending, LotteryFactory__ActiveLotteryExists());
        require(oracle != address(0), LotteryFactory__OracleNotSet());
        require(cap > 0 && cap <= 5000, LotteryFactory__InvalidCap());

        lottery = address(new Lottery{salt: bytes32(lotteryCount)}(fee, ticketPriceInWei, cap));
        emit LotteryFactory__LotteryCreated(lottery);
        lotteries[lotteryCount] = lottery;
        isLottery[lottery] = true;
        lotteryCount++;
        lotteryPending = true;
        activeLottery = payable(lottery);
    }

    function endLottery(address payable lottery, address lotteryWinner) external onlyOracle {
        require(lottery == activeLottery, LotteryFactory__NotLottery());
        require(lotteryWinner != address(0), LotteryFactory__InvalidRecipient());

        Lottery(lottery).endLottery(lotteryWinner);

        activeLottery = payable(address(0));
    }

    function withdrawFees(uint256 amount, address recipient) external onlyOwner {
        require(amount > 0, LotteryFactory__ZeroAmount());
        require(amount <= address(this).balance, LotteryFactory__InsuffifientAccumulatedFees());
        require(recipient != address(0), LotteryFactory__InvalidRecipient());

        (bool success,) = recipient.call{value: amount}("");
        require(success, LotteryFactory__CallFailed());
        emit LotteryFactory__FeesWithdrawn(recipient, amount);
    }

    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function setActiveLottery(address lottery) external onlyLottery {
        activeLottery = payable(lottery);
    }

    function setLotteryPending(bool _lotteryPending) external onlyLottery {
        lotteryPending = _lotteryPending;
    }

    /*//////////////////////////////////////////////
                    VIEW FUNCTIONS
    //////////////////////////////////////////////*/

    function getActiveLottery() public view returns (address payable) {
        return activeLottery;
    }

    function getLotteryCount() public view returns (uint256) {
        return lotteryCount;
    }

    function getLotteryWithId(uint256 id) public view returns (address) {
        return lotteries[id];
    }
}
