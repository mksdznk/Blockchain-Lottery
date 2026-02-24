///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {LotteryFunctions} from "../contracts/LotteryFunctions.sol";
import {LotteryFactory} from "../contracts/LotteryFactory.sol";
import {Lottery} from "../contracts/Lottery.sol";
import {
    VRFCoordinatorV2Interface
} from "foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {
    VRFConsumerBaseV2Plus
} from "foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {
    ConfirmedOwner
} from "foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {
    IVRFCoordinatorV2Plus
} from "foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {
    VRFV2PlusClient
} from "foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";

// solhint-disable chainlink-solidity/prefix-immutable-variables-with-i
// solhint-disable gas-custom-errors
// solhint-disable avoid-low-level-calls

contract VRFCoordinatorV2PlusMock is ConfirmedOwner, IVRFCoordinatorV2Plus {
    uint96 public immutable BASE_FEE;
    uint96 public immutable GAS_PRICE_LINK;
    uint16 public immutable MAX_CONSUMERS = 100;

    error InvalidSubscription();
    error InsufficientBalance();
    error MustBeSubOwner(address owner);
    error TooManyConsumers();
    error InvalidConsumer();
    error InvalidRandomWords();
    error Reentrant();

    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 requestId,
        uint256 preSeed,
        uint256 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        address indexed sender
    );
    event RandomWordsFulfilled(uint256 indexed requestId, uint256 outputSeed, uint96 payment, bool success);
    event SubscriptionCreated(uint256 indexed subId, address owner);
    event SubscriptionFunded(uint256 indexed subId, uint256 oldBalance, uint256 newBalance);
    event SubscriptionFundedWithNative(uint256 indexed subId, uint256 oldNativeBalance, uint256 newNativeBalance);
    event SubscriptionCanceled(uint256 indexed subId, address to, uint256 amount);
    event ConsumerAdded(uint256 indexed subId, address consumer);
    event ConsumerRemoved(uint256 indexed subId, address consumer);
    event ConfigSet();

    struct Config {
        // Reentrancy protection.
        bool reentrancyLock;
    }
    Config private s_config;
    uint256 internal s_currentSubId;
    uint256 internal s_nextRequestId = 1;
    uint256 internal s_nextPreSeed = 100;

    struct Subscription {
        address owner;
        uint96 nativeBalance;
        uint96 balance;
    }
    mapping(uint256 => Subscription) internal s_subscriptions; /* subId */ /* subscription */
    mapping(uint256 => address[]) internal s_consumers; /* subId */ /* consumers */

    struct Request {
        uint256 subId;
        uint32 callbackGasLimit;
        uint32 numWords;
    }
    mapping(uint256 => Request) internal s_requests; /* requestId */ /* request */

    constructor(uint96 _baseFee, uint96 _gasPriceLink) ConfirmedOwner(msg.sender) {
        BASE_FEE = _baseFee;
        GAS_PRICE_LINK = _gasPriceLink;
        setConfig();
    }

    /**
     * @notice Sets the configuration of the vrfv2 mock coordinator
     */
    function setConfig() public onlyOwner {
        s_config = Config({reentrancyLock: false});
        emit ConfigSet();
    }

    function consumerIsAdded(uint256 _subId, address _consumer) public view returns (bool) {
        address[] memory consumers = s_consumers[_subId];
        for (uint256 i = 0; i < consumers.length; i++) {
            if (consumers[i] == _consumer) {
                return true;
            }
        }
        return false;
    }

    modifier onlyValidConsumer(uint256 _subId, address _consumer) {
        if (!consumerIsAdded(_subId, _consumer)) {
            revert InvalidConsumer();
        }
        _;
    }

    /**
     * @notice fulfillRandomWords fulfills the given request, sending the random words to the supplied
     * @notice consumer.
     *
     * @dev This mock uses a simplified formula for calculating payment amount and gas usage, and does
     * @dev not account for all edge cases handled in the real VRF coordinator. When making requests
     * @dev against the real coordinator a small amount of additional LINK is required.
     *
     * @param _requestId the request to fulfill
     * @param _consumer the VRF randomness consumer to send the result to
     */
    function fulfillRandomWords(uint256 _requestId, address _consumer) external nonReentrant {
        fulfillRandomWordsWithOverride(_requestId, _consumer, new uint256[](0));
    }

    /**
     * @notice fulfillRandomWordsWithOverride allows the user to pass in their own random words.
     *
     * @param _requestId the request to fulfill
     * @param _consumer the VRF randomness consumer to send the result to
     * @param _words user-provided random words
     */
    function fulfillRandomWordsWithOverride(uint256 _requestId, address _consumer, uint256[] memory _words) public {
        uint256 startGas = gasleft();
        if (s_requests[_requestId].subId == 0) {
            revert("nonexistent request");
        }
        Request memory req = s_requests[_requestId];

        if (_words.length == 0) {
            _words = new uint256[](req.numWords);
            for (uint256 i = 0; i < req.numWords; i++) {
                _words[i] = uint256(keccak256(abi.encode(_requestId, i)));
            }
        } else if (_words.length != req.numWords) {
            revert InvalidRandomWords();
        }

        VRFConsumerBaseV2Plus v;
        bytes memory callReq = abi.encodeWithSelector(v.rawFulfillRandomWords.selector, _requestId, _words);
        s_config.reentrancyLock = true;
        (bool success,) = _consumer.call{gas: req.callbackGasLimit}(callReq);
        s_config.reentrancyLock = false;

        uint96 payment = uint96(BASE_FEE + ((startGas - gasleft()) * GAS_PRICE_LINK));
        if (s_subscriptions[req.subId].balance < payment) {
            revert InsufficientBalance();
        }
        s_subscriptions[req.subId].balance -= payment;
        delete (s_requests[_requestId]);
        emit RandomWordsFulfilled(_requestId, _requestId, payment, success);
    }

    /**
     * @notice fundSubscription allows funding a subscription with an arbitrary amount for testing.
     *
     * @param _subId the subscription to fund
     * @param _amount the amount to fund
     */
    function fundSubscription(uint256 _subId, uint96 _amount) public {
        if (s_subscriptions[_subId].owner == address(0)) {
            revert InvalidSubscription();
        }
        uint96 oldBalance = s_subscriptions[_subId].balance;
        s_subscriptions[_subId].balance += _amount;
        emit SubscriptionFunded(_subId, oldBalance, oldBalance + _amount);
    }

    function fundSubscriptionWithNative(uint256 _subId) external payable override nonReentrant {
        if (s_subscriptions[_subId].owner == address(0)) {
            revert InvalidSubscription();
        }
        uint96 oldNativeBalance = s_subscriptions[_subId].nativeBalance;
        s_subscriptions[_subId].nativeBalance += uint96(msg.value);
        emit SubscriptionFundedWithNative(_subId, oldNativeBalance, oldNativeBalance + msg.value);
    }

    function requestRandomWords(VRFV2PlusClient.RandomWordsRequest calldata req)
        external
        override
        nonReentrant
        onlyValidConsumer(req.subId, msg.sender)
        returns (uint256)
    {
        if (s_subscriptions[req.subId].owner == address(0)) {
            revert InvalidSubscription();
        }

        uint256 requestId = s_nextRequestId++;
        uint256 preSeed = s_nextPreSeed++;

        s_requests[requestId] =
            Request({subId: req.subId, callbackGasLimit: req.callbackGasLimit, numWords: req.numWords});

        emit RandomWordsRequested(
            req.keyHash,
            requestId,
            preSeed,
            req.subId,
            req.requestConfirmations,
            req.callbackGasLimit,
            req.numWords,
            msg.sender
        );
        return requestId;
    }

    function createSubscription() external override returns (uint256) {
        s_currentSubId++;
        s_subscriptions[s_currentSubId] = Subscription({owner: msg.sender, balance: 0, nativeBalance: 0});
        emit SubscriptionCreated(s_currentSubId, msg.sender);
        return s_currentSubId;
    }

    function getSubscription(uint256 subId)
        external
        view
        override
        returns (uint96 balance, uint96 nativeBalance, uint64 reqCount, address owner, address[] memory consumers)
    {
        if (s_subscriptions[subId].owner == address(0)) {
            revert InvalidSubscription();
        }
        return (
            s_subscriptions[subId].balance,
            s_subscriptions[subId].nativeBalance,
            0,
            s_subscriptions[subId].owner,
            s_consumers[subId]
        );
    }

    function cancelSubscription(uint256 _subId, address _to) external override onlySubOwner(_subId) nonReentrant {
        emit SubscriptionCanceled(_subId, _to, s_subscriptions[_subId].balance);
        delete (s_subscriptions[_subId]);
    }

    modifier onlySubOwner(uint256 _subId) {
        address owner = s_subscriptions[_subId].owner;
        if (owner == address(0)) {
            revert InvalidSubscription();
        }
        if (msg.sender != owner) {
            revert MustBeSubOwner(owner);
        }
        _;
    }

    function getRequestConfig() external pure returns (uint16, uint32, bytes32[] memory) {
        return (3, 2000000, new bytes32[](0));
    }

    function addConsumer(uint256 subId, address consumer) external override onlySubOwner(subId) {
        if (s_consumers[subId].length == MAX_CONSUMERS) {
            revert TooManyConsumers();
        }

        if (consumerIsAdded(subId, consumer)) {
            return;
        }

        s_consumers[subId].push(consumer);
        emit ConsumerAdded(subId, consumer);
    }

    function removeConsumer(uint256 _subId, address _consumer)
        external
        override
        onlySubOwner(_subId)
        onlyValidConsumer(_subId, _consumer)
        nonReentrant
    {
        address[] storage consumers = s_consumers[_subId];
        for (uint256 i = 0; i < consumers.length; i++) {
            if (consumers[i] == _consumer) {
                address last = consumers[consumers.length - 1];
                consumers[i] = last;
                consumers.pop();
                break;
            }
        }

        emit ConsumerRemoved(_subId, _consumer);
    }

    function getConfig()
        external
        pure
        returns (
            uint16 minimumRequestConfirmations,
            uint32 maxGasLimit,
            uint32 stalenessSeconds,
            uint32 gasAfterPaymentCalculation
        )
    {
        return (4, 2_500_000, 2_700, 33285);
    }

    function getFeeConfig()
        external
        pure
        returns (
            uint32 fulfillmentFlatFeeLinkPPMTier1,
            uint32 fulfillmentFlatFeeLinkPPMTier2,
            uint32 fulfillmentFlatFeeLinkPPMTier3,
            uint32 fulfillmentFlatFeeLinkPPMTier4,
            uint32 fulfillmentFlatFeeLinkPPMTier5,
            uint24 reqsForTier2,
            uint24 reqsForTier3,
            uint24 reqsForTier4,
            uint24 reqsForTier5
        )
    {
        return (
            100000, // 0.1 LINK
            100000, // 0.1 LINK
            100000, // 0.1 LINK
            100000, // 0.1 LINK
            100000, // 0.1 LINK
            0,
            0,
            0,
            0
        );
    }

    modifier nonReentrant() {
        if (s_config.reentrancyLock) {
            revert Reentrant();
        }
        _;
    }

    function getFallbackWeiPerUnitLink() external pure returns (int256) {
        return 4000000000000000; // 0.004 Ether
    }

    function requestSubscriptionOwnerTransfer(
        uint256,
        /*_subId*/
        address /*_newOwner*/
    )
        external
        pure
        override
    {
        revert("not implemented");
    }

    function acceptSubscriptionOwnerTransfer(
        uint256 /*_subId*/
    )
        external
        pure
        override
    {
        revert("not implemented");
    }

    function pendingRequestExists(
        uint256 /*subId*/
    )
        public
        pure
        override
        returns (bool)
    {
        revert("not implemented");
    }

    function getActiveSubscriptionIds(
        uint256,
        /* startIndex */
        uint256 /* maxCount */
    )
        external
        pure
        override
        returns (uint256[] memory)
    {
        revert("not implemented");
    }
}

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
