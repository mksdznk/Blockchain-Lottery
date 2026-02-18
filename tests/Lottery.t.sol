///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Lottery} from "../contracts/Lottery.sol";
import {LotteryFactory} from "../contracts/LotteryFactory.sol";

contract LotteryTest is Test {
    LotteryFactory factory;
    Lottery lottery;

    address owner;
    address oracle = makeAddr("oracle");
    address buyer1 = makeAddr("buyer1");
    address buyer2 = makeAddr("buyer2");
    address buyer3 = makeAddr("buyer3");

    uint256 constant FEE = 500; // basis points
    uint256 constant TICKET_PRICE = 0.01 ether;
    uint256 constant CAP = 100; // max tickets
    uint256 constant MAX_OWNERS = 10;

    function setUp() public {
        owner = address(this);
        factory = new LotteryFactory();
        factory.setOracle(oracle);

        address lotteryAddr = factory.createLottery(FEE, TICKET_PRICE, CAP, MAX_OWNERS);
        lottery = Lottery(payable(lotteryAddr));

        // Fund test buyers
        vm.deal(buyer1, 10 ether);
        vm.deal(buyer2, 10 ether);
        vm.deal(buyer3, 10 ether);
    }

    /*//////////////////////////////////////////////
                  CONSTRUCTOR TESTS
    //////////////////////////////////////////////*/

    function test_constructor_setsParams() public view {
        assertEq(lottery.getFeePercentage(), FEE);
        assertEq(lottery.getTicketPriceInWei(), TICKET_PRICE);
        assertEq(lottery.getMaxTickets(), CAP);
        assertEq(lottery.getLotteryFactory(), address(factory));
        assertEq(lottery.getMaxOwners(), MAX_OWNERS);
    }

    function test_constructor_nameAndSymbol() public view {
        assertEq(lottery.name(), "Lottery Ticket");
        assertEq(lottery.symbol(), "LT");
    }

    function test_decimals_returnsZero() public view {
        assertEq(lottery.decimals(), 0);
    }

    /*//////////////////////////////////////////////
              PURCHASE TICKETS TESTS
    //////////////////////////////////////////////*/

    function test_purchaseTickets_mintsCorrectAmount() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: 0.05 ether}();

        assertEq(lottery.balanceOf(buyer1), 5);
        assertEq(lottery.totalSupply(), 5);
    }

    function test_purchaseTickets_singleTicket() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: TICKET_PRICE}();

        assertEq(lottery.balanceOf(buyer1), 1);
    }

    function test_purchaseTickets_multipleTickets() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: 0.1 ether}();

        assertEq(lottery.balanceOf(buyer1), 10);
    }

    function test_purchaseTickets_multipleBuyers() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: 0.03 ether}();

        vm.prank(buyer2);
        lottery.purchaseTickets{value: 0.05 ether}();

        assertEq(lottery.balanceOf(buyer1), 3);
        assertEq(lottery.balanceOf(buyer2), 5);
        assertEq(lottery.getNumberOfOwners(), 2);
    }

    function test_purchaseTickets_tracksOwnerCount() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: TICKET_PRICE}();
        assertEq(lottery.getNumberOfOwners(), 1);

        vm.prank(buyer2);
        lottery.purchaseTickets{value: TICKET_PRICE}();
        assertEq(lottery.getNumberOfOwners(), 2);
    }

    function test_purchaseTickets_emitsEvent() public {
        vm.prank(buyer1);
        vm.expectEmit(true, true, true, true);
        emit Lottery.Lottery__TicketsPurchased(buyer1, 5);
        lottery.purchaseTickets{value: 0.05 ether}();
    }

    function test_purchaseTickets_revertsOnZeroValue() public {
        vm.prank(buyer1);
        vm.expectRevert(Lottery.Lottery__ZeroValue.selector);
        lottery.purchaseTickets{value: 0}();
    }

    function test_purchaseTickets_revertsOnNonWholeTickets() public {
        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__OnlyWholeTickets.selector, TICKET_PRICE));
        lottery.purchaseTickets{value: 0.015 ether}();
    }

    function test_purchaseTickets_revertsWhenCapExceeded() public {
        // Buy all 100 tickets
        vm.prank(buyer1);
        lottery.purchaseTickets{value: 1 ether}(); // 100 tickets

        // Try to buy one more
        vm.prank(buyer2);
        vm.expectRevert(); // ERC20Capped cap exceeded
        lottery.purchaseTickets{value: TICKET_PRICE}();
    }

    function test_purchaseTickets_revertsWhenTooManyOwners() public {
        // Use a separate factory to avoid ActiveLotteryExists error
        LotteryFactory factory2 = new LotteryFactory();
        factory2.setOracle(oracle);
        address smallLotteryAddr = factory2.createLottery(FEE, TICKET_PRICE, CAP, 2);
        Lottery smallLottery = Lottery(payable(smallLotteryAddr));

        vm.prank(buyer1);
        smallLottery.purchaseTickets{value: TICKET_PRICE}();

        vm.prank(buyer2);
        smallLottery.purchaseTickets{value: TICKET_PRICE}();

        // Third buyer should fail
        vm.prank(buyer3);
        vm.expectRevert(Lottery.Lottery__TooManyOwners.selector);
        smallLottery.purchaseTickets{value: TICKET_PRICE}();
    }

    /*//////////////////////////////////////////////
              TRANSFER TICKETS TESTS
    //////////////////////////////////////////////*/

    function test_transferTickets_transfersCorrectly() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: 0.05 ether}();

        vm.prank(buyer1);
        lottery.transferTickets(buyer2, 2);

        assertEq(lottery.balanceOf(buyer1), 3);
        assertEq(lottery.balanceOf(buyer2), 2);
    }

    function test_transferTickets_updatesOwnerCount_newRecipient() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: 0.05 ether}();
        assertEq(lottery.getNumberOfOwners(), 1);

        vm.prank(buyer1);
        lottery.transferTickets(buyer2, 2);
        assertEq(lottery.getNumberOfOwners(), 2);
    }

    function test_transferTickets_decrementsOwnerWhenFullTransfer() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: 0.05 ether}();

        vm.prank(buyer1);
        lottery.transferTickets(buyer2, 5); // Transfer all tickets

        assertEq(lottery.getNumberOfOwners(), 1); // buyer1 removed, buyer2 added
        assertEq(lottery.balanceOf(buyer1), 0);
        assertEq(lottery.balanceOf(buyer2), 5);
    }

    function test_transferTickets_emitsEvent() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: 0.05 ether}();

        vm.prank(buyer1);
        vm.expectEmit(true, true, true, true);
        emit Lottery.Lottery__TicketsTransfered(buyer1, buyer2, 2);
        lottery.transferTickets(buyer2, 2);
    }

    function test_transferTickets_revertsWhenTooManyOwners() public {
        // Use a separate factory to avoid ActiveLotteryExists error
        LotteryFactory factory2 = new LotteryFactory();
        factory2.setOracle(oracle);
        address tinyLotteryAddr = factory2.createLottery(FEE, TICKET_PRICE, CAP, 1);
        Lottery tinyLottery = Lottery(payable(tinyLotteryAddr));

        vm.prank(buyer1);
        tinyLottery.purchaseTickets{value: 0.05 ether}();

        // Partial transfer to new owner should fail (would make 2 owners)
        vm.prank(buyer1);
        vm.expectRevert(Lottery.Lottery__TooManyOwners.selector);
        tinyLottery.transferTickets(buyer2, 1);
    }

    /*//////////////////////////////////////////////
           DIRECT TRANSFERS DISABLED TESTS
    //////////////////////////////////////////////*/

    function test_transfer_reverts() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: 0.05 ether}();

        vm.prank(buyer1);
        vm.expectRevert(Lottery.Lottery__DirectTransfersDisabled.selector);
        lottery.transfer(buyer2, 1);
    }

    function test_transferFrom_reverts() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: 0.05 ether}();

        vm.prank(buyer1);
        vm.expectRevert(Lottery.Lottery__DirectTransfersDisabled.selector);
        lottery.transferFrom(buyer1, buyer2, 1);
    }

    /*//////////////////////////////////////////////
                END LOTTERY TESTS
    //////////////////////////////////////////////*/

    function test_endLottery_revertsWhenNotFactory() public {
        vm.prank(buyer1);
        lottery.purchaseTickets{value: 0.05 ether}();

        vm.prank(buyer1);
        vm.expectRevert(Lottery.Lottery__NotPending.selector);
        lottery.endLottery(buyer1);
    }

    /*//////////////////////////////////////////////
                  VIEW FUNCTION TESTS
    //////////////////////////////////////////////*/

    function test_getTicketsLeft() public {
        assertEq(lottery.getTicketsLeft(), CAP);

        vm.prank(buyer1);
        lottery.purchaseTickets{value: 0.05 ether}();

        assertEq(lottery.getTicketsLeft(), CAP - 5);
    }

    function test_receiveEther() public {
        // The contract should accept ETH via receive()
        (bool success,) = address(lottery).call{value: 1 ether}("");
        assertTrue(success);
    }
}
