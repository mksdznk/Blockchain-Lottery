///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Lottery} from "./Lottery.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {LotteryNft} from "./LotteryNft.sol";

contract LotteryFactory is Ownable2Step {
    /*//////////////////////////////////////////////
                    STATE VARIABLES
    //////////////////////////////////////////////*/
    uint256 private lotteryCount;
    address private oracle;
    address payable private activeLottery;
    bool private lotteryPending;
    LotteryNft private lotteryNft;
    uint256 private constant MAX_NFT_ID = 5;

    mapping(address => bool) private isLottery;
    mapping(uint256 => LotteryInfo) private lotteries;

    struct LotteryInfo {
        uint256 id;
        address lotteryAddress;
        uint256 fee;
        uint256 price;
        address winner;
        uint256 winningAmount;
    }

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
    event LotteryFactory__LotteryClosed(address winner, uint256 reward);
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
    constructor() {
        lotteryNft = new LotteryNft();
    }

    /*//////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    //////////////////////////////////////////////*/
    function createLottery(uint256 fee, uint256 ticketPriceInWei, uint256 cap, uint256 maxOwners)
        external
        onlyOwner
        returns (address lottery)
    {
        require(activeLottery == address(0), LotteryFactory__ActiveLotteryExists());
        require(oracle != address(0), LotteryFactory__OracleNotSet());
        require(cap > 0 && cap <= 5000, LotteryFactory__InvalidCap());

        lottery = address(new Lottery{salt: bytes32(lotteryCount)}(fee, ticketPriceInWei, cap, maxOwners));
        emit LotteryFactory__LotteryCreated(lottery);
        isLottery[lottery] = true;
        lotteryCount++;
        LotteryInfo memory info = LotteryInfo(lotteryCount, lottery, fee, ticketPriceInWei, address(0), 0);
        lotteries[lotteryCount] = info;
        activeLottery = payable(lottery);
    }

    function endLottery(address payable lottery, address lotteryWinner) external onlyOracle {
        require(lottery == activeLottery, LotteryFactory__NotLottery());
        require(lotteryWinner != address(0), LotteryFactory__InvalidRecipient());

        uint256 reward = Lottery(lottery).endLottery(lotteryWinner);
        if (lotteryCount <= MAX_NFT_ID) {
            lotteryNft.mint(lotteryWinner);
        }

        LotteryInfo memory info = lotteries[lotteryCount];
        info.winner = lotteryWinner;
        info.winningAmount = reward;
        lotteries[lotteryCount] = info;
        lotteryPending = false;
        activeLottery = payable(address(0));
        emit LotteryFactory__LotteryClosed(lotteryWinner, reward);
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

    function getLotteryPending() public view returns (bool) {
        return lotteryPending;
    }

    function getLotteryCount() public view returns (uint256) {
        return lotteryCount;
    }

    function getLotteryWithId(uint256 id) public view returns (LotteryInfo memory) {
        return lotteries[id];
    }

    function getOracle() public view returns (address) {
        return oracle;
    }

    function getLotteryNftAddress() public view returns (address) {
        return address(lotteryNft);
    }
}
