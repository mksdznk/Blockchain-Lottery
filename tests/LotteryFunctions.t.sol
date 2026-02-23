///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {LotteryFunctions} from "../contracts/LotteryFunctions.sol";
import {LotteryFactory} from "../contracts/LotteryFactory.sol";
import {Lottery} from "../contracts/Lottery.sol";
import {
    VRFCoordinatorV2PlusMock
} from "foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2PlusMock.sol";

// /// @notice Mock VRF Coordinator for testing
// contract MockVRFCoordinator {
//     uint256 private requestCounter;

//     function requestRandomWords(bytes32, uint256, uint16, uint32, uint32, bytes memory)
//         external
//         returns (uint256)
//     {
//         requestCounter++;
//         return requestCounter;
//     }

//     // Overloaded version matching VRFV2PlusClient pattern
//     function requestRandomWords(
//         bytes32, uint256, uint16, uint32, uint32
//     ) external returns (uint256) {
//         requestCounter++;
//         return requestCounter;
//     }
// }

/// @notice Mock Functions Router for testing
contract MockFunctionsRouter {
    bytes32 private constant MOCK_REQUEST_ID = bytes32(uint256(1));

    function sendRequest(uint64, bytes memory, uint16, uint32, bytes32) external pure returns (bytes32) {
        return MOCK_REQUEST_ID;
    }
}

contract LotteryFunctionsTest is Test {
    LotteryFunctions lotteryFunctions;
    LotteryFactory factory;
    VRFCoordinatorV2PlusMock vrfCoordinator;
    MockFunctionsRouter functionsRouter;

    address owner;
    address oracle = makeAddr("oracle");
    address buyer1 = makeAddr("buyer1");

    uint64 constant FUNCTIONS_SUB_ID = 1;
    uint256 vrfSubId;
    bytes32 keyHash;

    function setUp() public {
        owner = address(this);
        factory = new LotteryFactory();

        vrfCoordinator = new VRFCoordinatorV2PlusMock(0.1e18, 1e9);
        functionsRouter = new MockFunctionsRouter();
        keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

        vrfSubId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(vrfSubId, 0.1e18);

        lotteryFunctions = new LotteryFunctions(
            address(functionsRouter),
            bytes32(uint256(1)), // donID
            FUNCTIONS_SUB_ID,
            vrfSubId,
            address(vrfCoordinator),
            address(factory),
            keyHash
        );
        vrfCoordinator.addConsumer(vrfSubId, address(lotteryFunctions));
        factory.setOracle(address(lotteryFunctions));
    }

    /*//////////////////////////////////////////////
                  CONSTRUCTOR TESTS
    //////////////////////////////////////////////*/

    function test_constructor_setsSubscriptionIds() public view {
        assertEq(lotteryFunctions.getFunctionsSubscriptionId(), FUNCTIONS_SUB_ID);
        assertEq(lotteryFunctions.getVFRSubscriptionId(), vrfSubId);
    }

    /*//////////////////////////////////////////////
                 CHECK UPKEEP TESTS
    //////////////////////////////////////////////*/

    function test_checkUpkeep_returnsFalseWhenNoActiveLottery() public {
        (bool upkeepNeeded,) = lotteryFunctions.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function test_checkUpkeep_returnsTrueWhenActiveLottery() public {
        address lotteryAddr = factory.createLottery(500, 0.01 ether, 100, 10);
        Lottery(payable(lotteryAddr)).purchaseTickets{value: 0.01 ether * 100}();

        (bool upkeepNeeded,) = lotteryFunctions.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    /*//////////////////////////////////////////////
                PERFORM UPKEEP TESTS
    //////////////////////////////////////////////*/

    function test_performUpkeep_revertsWhenNoActiveLottery() public {
        vm.expectRevert();
        lotteryFunctions.performUpkeep("");
    }

    /*//////////////////////////////////////////////
                  VIEW FUNCTION TESTS
    //////////////////////////////////////////////*/

    // function test_getLastVRFCallTime_initiallyZero() public view {
    //     assertEq(lotteryFunctions.getLastVRFCallTime(), 0);
    // }

    // function test_getLastFunctionsCallTime_initiallyZero() public view {
    //     assertEq(lotteryFunctions.getLastFunctionsCallTime(), 0);
    // }

    /*//////////////////////////////////////////////
                  FORCE END TEST
    //////////////////////////////////////////////*/
    function test_forceEndLottery() public {
        factory.createLottery(500, 0.01 ether, 100, 10);
        Lottery lottery = Lottery(factory.getActiveLottery());
        lotteryFunctions.forceEndLottery();
    }

    /*//////////////////////////////////////////////
                SET LOTTERY PENDING TEST
    //////////////////////////////////////////////*/
    function test_setLotteryPending_revertsWhenNotLottery() public {
        vm.prank(buyer1);
        vm.expectRevert(LotteryFunctions.LotteryFunctions__LotteryNotValid.selector);
        lotteryFunctions.setLotteryPending(false);
    }
}
