///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Lottery} from "../contracts/Lottery.sol";
import {LotteryFactory} from "../contracts/LotteryFactory.sol";
import {LotteryNft} from "../contracts/LotteryNft.sol";

contract LotteryFactoryTest is Test {
    LotteryFactory factory;

    address owner;
    address oracle = makeAddr("oracle");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address winner = makeAddr("winner");

    uint256 constant FEE = 500;
    uint256 constant TICKET_PRICE = 0.01 ether;
    uint256 constant CAP = 100;
    uint256 constant MAX_OWNERS = 10;

    function setUp() public {
        owner = address(this);
        factory = new LotteryFactory();
        factory.setOracle(oracle);
    }

    receive() external payable {}

    /*//////////////////////////////////////////////
                  CONSTRUCTOR TESTS
    //////////////////////////////////////////////*/

    function test_constructor_deploysNft() public view {
        address nftAddr = factory.getLotteryNftAddress();
        assertTrue(nftAddr != address(0));

        LotteryNft nft = LotteryNft(nftAddr);
        assertEq(nft.name(), "Fifu Fifu");
    }

    function test_constructor_initialState() public view {
        assertEq(factory.getLotteryCount(), 0);
        assertEq(factory.getActiveLottery(), address(0));
    }

    /*//////////////////////////////////////////////
                CREATE LOTTERY TESTS
    //////////////////////////////////////////////*/

    function test_createLottery_createsLottery() public {
        address lotteryAddr = factory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);

        assertTrue(lotteryAddr != address(0));
        assertEq(factory.getLotteryCount(), 1);
        assertEq(factory.getActiveLottery(), lotteryAddr);
    }

    function test_createLottery_setsLotteryInfo() public {
        address lotteryAddr = factory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);

        LotteryFactory.LotteryInfo memory info = factory.getLotteryWithId(1);
        assertEq(info.id, 1);
        assertEq(info.lotteryAddress, lotteryAddr);
        assertEq(info.fee, FEE);
        assertEq(info.price, TICKET_PRICE);
        assertEq(info.winner, address(0));
        assertEq(info.winningAmount, 0);
    }

    function test_createLottery_emitsEvent() public {
        vm.expectEmit(false, false, false, false);
        emit LotteryFactory.LotteryFactory__LotteryCreated(address(0)); // address doesn't matter for check
        factory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);
    }

    function test_createLottery_revertsWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);
    }

    function test_createLottery_revertsWhenActiveLotteryExists() public {
        factory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);

        vm.expectRevert(LotteryFactory.LotteryFactory__ActiveLotteryExists.selector);
        factory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);
    }

    function test_createLottery_revertsWhenOracleNotSet() public {
        LotteryFactory newFactory = new LotteryFactory();

        vm.expectRevert(LotteryFactory.LotteryFactory__OracleNotSet.selector);
        newFactory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);
    }

    function test_createLottery_revertsWhenCapIsZero() public {
        vm.expectRevert(LotteryFactory.LotteryFactory__InvalidCap.selector);
        factory.createLottery(FEE, TICKET_PRICE, 0, MAX_OWNERS);
    }

    function test_createLottery_revertsWhenCapTooHigh() public {
        vm.expectRevert(LotteryFactory.LotteryFactory__InvalidCap.selector);
        factory.createLottery(FEE, TICKET_PRICE, 5001, MAX_OWNERS);
    }

    function test_createLottery_maxCap() public {
        address lotteryAddr = factory.createLottery(FEE, TICKET_PRICE, 5000, MAX_OWNERS);
        Lottery lottery = Lottery(payable(lotteryAddr));
        assertEq(lottery.getMaxTickets(), 5000);
    }

    /*//////////////////////////////////////////////
                  END LOTTERY TESTS
    //////////////////////////////////////////////*/

    function test_endLottery_revertsWhenNotOracle() public {
        address lotteryAddr = factory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);

        vm.prank(user1);
        vm.expectRevert(LotteryFactory.LotteryFactory__NotOracle.selector);
        factory.endLottery(payable(lotteryAddr), winner);
    }

    function test_endLottery_revertsWhenWrongLottery() public {
        factory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);

        vm.prank(oracle);
        vm.expectRevert(LotteryFactory.LotteryFactory__NotLottery.selector);
        factory.endLottery(payable(address(0x1234)), winner);
    }

    function test_endLottery_revertsWhenZeroAddressWinner() public {
        address lotteryAddr = factory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);

        vm.prank(oracle);
        vm.expectRevert(LotteryFactory.LotteryFactory__InvalidRecipient.selector);
        factory.endLottery(payable(lotteryAddr), address(0));
    }

    /*//////////////////////////////////////////////
                 WITHDRAW FEES TESTS
    //////////////////////////////////////////////*/

    function test_withdrawFees_revertsWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.withdrawFees(1 ether, user1);
    }

    function test_withdrawFees_revertsOnZeroAmount() public {
        vm.expectRevert(LotteryFactory.LotteryFactory__ZeroAmount.selector);
        factory.withdrawFees(0, user1);
    }

    function test_withdrawFees_revertsWhenInsufficientBalance() public {
        vm.expectRevert(LotteryFactory.LotteryFactory__InsuffifientAccumulatedFees.selector);
        factory.withdrawFees(1 ether, user1);
    }

    function test_withdrawFees_revertsWhenZeroRecipient() public {
        // Fund the factory first
        vm.deal(address(factory), 1 ether);

        vm.expectRevert(LotteryFactory.LotteryFactory__InvalidRecipient.selector);
        factory.withdrawFees(1 ether, address(0));
    }

    function test_withdrawFees_sendsETH() public {
        vm.deal(address(factory), 1 ether);

        uint256 balanceBefore = user1.balance;
        factory.withdrawFees(0.5 ether, user1);
        assertEq(user1.balance, balanceBefore + 0.5 ether);
    }

    function test_withdrawFees_emitsEvent() public {
        vm.deal(address(factory), 1 ether);

        vm.expectEmit(true, true, true, true);
        emit LotteryFactory.LotteryFactory__FeesWithdrawn(user1, 0.5 ether);
        factory.withdrawFees(0.5 ether, user1);
    }

    /*//////////////////////////////////////////////
                  SET ORACLE TESTS
    //////////////////////////////////////////////*/

    function test_setOracle_setsOracle() public {
        factory.setOracle(user1);
        assertEq(factory.getOracle(), user1);
    }

    function test_setOracle_revertsWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setOracle(user1);
    }

    /*//////////////////////////////////////////////
           SET ACTIVE LOTTERY / PENDING TESTS
    //////////////////////////////////////////////*/

    function test_setActiveLottery_revertsWhenNotLottery() public {
        vm.prank(user1);
        vm.expectRevert(LotteryFactory.LotteryFactory__NotLottery.selector);
        factory.setActiveLottery(address(0));
    }

    function test_setLotteryPending_revertsWhenNotLottery() public {
        vm.prank(user1);
        vm.expectRevert(LotteryFactory.LotteryFactory__NotLottery.selector);
        factory.setLotteryPending(false);
    }

    /*//////////////////////////////////////////////
                  VIEW FUNCTION TESTS
    //////////////////////////////////////////////*/

    function test_getOracle() public view {
        assertEq(factory.getOracle(), oracle);
    }

    function test_getLotteryCount_incrementsOnCreate() public {
        assertEq(factory.getLotteryCount(), 0);

        factory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);
        assertEq(factory.getLotteryCount(), 1);
    }
}
