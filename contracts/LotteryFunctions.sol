///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {FunctionsClient} from "@chainlink/contracts/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/v0.8/interfaces/AutomationCompatibleInterface.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";
import {LotteryFactory} from "./LotteryFactory.sol";
import {Lottery} from "./Lottery.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract LotteryFunctions is FunctionsClient, AutomationCompatibleInterface, VRFConsumerBaseV2Plus {
    using FunctionsRequest for FunctionsRequest.Request;

    /*///////////////////////////////////////////////
                    STATE VARIABLES
    ///////////////////////////////////////////////*/
    bytes32 private s_lastFunctionsRequestId;
    uint256 private s_lastVRFRequestId;
    bytes32 private s_keyHash;
    address payable private lotteryFactory;
    uint32 private functionsGasLimit = 300_000;
    uint32 private vrfCallbackGasLimit = 150_000;
    uint256 private s_pendingRandomWord;
    address private s_pendingWinner;
    bool private s_vrfRequestPending;
    bool private s_vrfFulfilled;
    bool private s_winnerRequestFulfilled;
    bool private s_lotteryPending;
    address private router; //// ENTER YOUR ROUTER ADDRESS
    bytes32 private donID; //// ENTER YOUR DON ID
    uint256 private s_vrfSubscriptionId;
    uint64 private immutable i_functionsSubscriptionId;
    string private source = "try {const lotteryAddress = args[0];"
        "const ticketPriceInWei = args[1];let chain;if (args[2] == 1) {chain = 'eth';}else if (args[2] == 11155111) {"
        "chain = 'sepolia';}const randomNumber = args[3];let response = await Functions.makeHttpRequest({"
        "method: 'GET',url: `https://deep-index.moralis.io/api/v2.2/erc20/${lotteryAddress}/owners`,"
        "params: {chain: chain,limit: '100',order: 'DESC'},headers: {accept: 'application/json',"
        "'X-API-Key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJub25jZSI6IjM3NWJhN2U0LWI5OGItNDMyMS04ZDZlLWU2ZjFlZjBlOGJkOSIsIm9yZ0lkIjoiNDk0MTg2IiwidXNlcklkIjoiNTA4NTM1IiwidHlwZUlkIjoiYjEzNGI4YmMtMjA3MS00ODk4LWE3OTItZDU0MjlmNGE2ZDdjIiwidHlwZSI6IlBST0pFQ1QiLCJpYXQiOjE3NjkxNzkzNzEsImV4cCI6NDkyNDkzOTM3MX0.IFUfq-1G7tyUOFFfsM4lsWEQJzY9qiZHtP_1KSuv5Hk'}});"
        "let lotteryEntries = response.data.result;let lotteryAddresses = [];let entriesForAddress = 0;let cursor = response.data.cursor;"
        "for (let i = 0; i < lotteryEntries.length; i++) {entriesForAddress = lotteryEntries[i].balance;"
        "for (let j = 0; j < entriesForAddress; j++) {lotteryAddresses.push(lotteryEntries[i].owner_address);}}"
        "while (cursor != null) {response = await Functions.makeHttpRequest({"
        "method: 'GET',url: `https://deep-index.moralis.io/api/v2.2/erc20/${lotteryAddress}/owners`,"
        "params: {chain: chain,limit: '100',order: 'DESC',cursor: cursor,},headers: {accept: 'application/json',"
        "'X-API-Key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJub25jZSI6IjM3NWJhN2U0LWI5OGItNDMyMS04ZDZlLWU2ZjFlZjBlOGJkOSIsIm9yZ0lkIjoiNDk0MTg2IiwidXNlcklkIjoiNTA4NTM1IiwidHlwZUlkIjoiYjEzNGI4YmMtMjA3MS00ODk4LWE3OTItZDU0MjlmNGE2ZDdjIiwidHlwZSI6IlBST0pFQ1QiLCJpYXQiOjE3NjkxNzkzNzEsImV4cCI6NDkyNDkzOTM3MX0.IFUfq-1G7tyUOFFfsM4lsWEQJzY9qiZHtP_1KSuv5Hk'"
        "}});lotteryEntries = response.data.result;entriesForAddress = 0;"
        "cursor = response.data.cursor;for (let i = 0; i < lotteryEntries.length; i++) {"
        "entriesForAddress = lotteryEntries[i].balance;for (let j = 0; j < entriesForAddress; j++) {"
        "lotteryAddresses.push(lotteryEntries[i].owner_address);}}}if (response.error) {"
        "throw new Error(`API error: ${response.error}`);}const winnerIndex = randomNumber % lotteryAddresses.length;"
        "return Functions.encodeString(lotteryAddresses[winnerIndex]);} catch (error) {"
        "throw Error(error.message);}";

    struct VrfRequestStatus {
        bool fulfilled;
        bool exists;
    }

    struct FunctionsRequestStatus {
        bool fulfilled;
        bool exists;
    }

    mapping(uint256 => VrfRequestStatus) private s_vrfRequests;
    mapping(bytes32 => FunctionsRequestStatus) private s_functionsRequests;
    mapping(address => bool) private s_isLottery;

    /*///////////////////////////////////////////////
                        ERRORS
    //////////////////////////////////////////////*/
    error LotteryFunctions__UnexpectedRequestID(bytes32 functionsRequestId, uint256 vrfRequestId);
    error LotteryFunctions__UpkeepNotNeeded();
    error LotteryFunctions__InvalidSubscription();
    error LotteryFunctions__LotteryNotValid();
    error LotteryFunctions__NotFactory();

    /*///////////////////////////////////////////////
                        EVENTS
    //////////////////////////////////////////////*/
    event LotteryFunctions__Response(bytes32 indexed requestId, string winner);
    event LotteryFunctions__UpkeepFulfilled(uint256 requestTime);
    event LotteryFunctions__VRFCalled(uint256 requestTime);
    event LotteryFunctions__FunctionsRequested(string[] args);

    /*///////////////////////////////////////////////
                        MODIFIERS
    //////////////////////////////////////////////*/
    modifier onlyLottery() {
        require(s_isLottery[msg.sender], LotteryFunctions__LotteryNotValid());
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == lotteryFactory, LotteryFunctions__NotFactory());
        _;
    }

    /*///////////////////////////////////////////////
                        CONSTRUCTOR
    ///////////////////////////////////////////////*/
    constructor(
        address _router,
        bytes32 _donID,
        uint64 _functionsSubscriptionId,
        uint256 _vrfSubscriptionId,
        address _vrfCoordinator,
        address _lotteryFactory,
        bytes32 _keyHash
    )
        FunctionsClient(_router)
        VRFConsumerBaseV2Plus(_vrfCoordinator) /* VRF vrfCoordinator address is address deployed to each network by Chainlink to handle and verify VRF https://docs.chain.link/vrf/v2-5/supported-networks */
    {
        router = _router;
        donID = _donID;
        i_functionsSubscriptionId = _functionsSubscriptionId;
        s_vrfSubscriptionId = _vrfSubscriptionId;
        lotteryFactory = payable(_lotteryFactory);
        s_keyHash = _keyHash;
    }

    /*///////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////*/

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = (s_vrfFulfilled || s_lotteryPending || s_winnerRequestFulfilled) && !s_vrfRequestPending;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata) external override {
        require((s_vrfFulfilled || s_lotteryPending || s_winnerRequestFulfilled) && !s_vrfRequestPending,  LotteryFunctions__UpkeepNotNeeded());
        if (s_vrfFulfilled && !s_vrfRequestPending) {
            // Phase 2: VRF is done, now trigger Chainlink Functions
            s_lotteryPending = false;
            address payable lottery = LotteryFactory(lotteryFactory).getActiveLottery();
            string[] memory args = new string[](4);
            args[0] = Strings.toHexString(lottery);
            args[1] = Strings.toString(Lottery(lottery).getTicketPriceInWei());
            args[2] = Strings.toString(block.chainid);
            args[3] = Strings.toString(s_pendingRandomWord);

            emit LotteryFunctions__FunctionsRequested(args);

            _getWinner(i_functionsSubscriptionId, args);
        } else if (s_winnerRequestFulfilled) {
            // Phase 3: Lottery is ended and winner has been paid
            _endLottery();
        }
        else {
            // Phase 1: Lottery pending, request VRF random number
            if (LotteryFactory(lotteryFactory).getActiveLottery() == address(0)) {
                revert LotteryFunctions__LotteryNotValid();
            }

            if (s_vrfSubscriptionId == 0) {
                revert LotteryFunctions__InvalidSubscription();
            }

            s_vrfRequestPending = true;
            _getLotteryWinnerIndex();
        }

        emit LotteryFunctions__UpkeepFulfilled(block.timestamp);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(s_vrfRequests[requestId].exists && !s_vrfRequests[requestId].fulfilled, LotteryFunctions__UnexpectedRequestID(bytes32(0), requestId));

        s_vrfRequests[requestId].fulfilled = true;
        s_pendingRandomWord = randomWords[0];
        s_vrfRequestPending = false;
        s_vrfFulfilled = true;
        emit LotteryFunctions__VRFCalled(block.timestamp);
    }

    function forceEndLottery() external onlyOwner {
        if (s_vrfFulfilled && !s_vrfRequestPending) {
            // Phase 2: VRF is done, now trigger Chainlink Functions
            s_lotteryPending = false;
            address payable lottery = LotteryFactory(lotteryFactory).getActiveLottery();
            string[] memory args = new string[](4);
            args[0] = Strings.toHexString(lottery);
            args[1] = Strings.toString(Lottery(lottery).getTicketPriceInWei());
            args[2] = Strings.toString(block.chainid);
            args[3] = Strings.toString(s_pendingRandomWord);

            emit LotteryFunctions__FunctionsRequested(args);

            _getWinner(i_functionsSubscriptionId, args);
        } else if (s_winnerRequestFulfilled) {
            // Phase 3: Lottery is ended and winner has been paid
            _endLottery();
        }
        else {
            // Phase 1: Lottery pending, request VRF random number
            if (LotteryFactory(lotteryFactory).getActiveLottery() == address(0)) {
                revert LotteryFunctions__LotteryNotValid();
            }

            if (s_vrfSubscriptionId == 0) {
                revert LotteryFunctions__InvalidSubscription();
            }

            s_vrfRequestPending = true;
            _getLotteryWinnerIndex();
        }
    }

    function setIsLottery(address _lottery) external onlyFactory {
        s_isLottery[_lottery] = true;
    }

    function setLotteryPending(bool _lotteryPending) external onlyLottery {
        s_lotteryPending = _lotteryPending;
    }

    /*///////////////////////////////////////////////
                    INTERNAL FUNCTIONS
    ///////////////////////////////////////////////*/

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        require(s_functionsRequests[requestId].exists && !s_functionsRequests[requestId].fulfilled, LotteryFunctions__UnexpectedRequestID(requestId, 0));

        string memory lotteryWinnerString;

        if (err.length == 0) {
            lotteryWinnerString = string(response);
            s_pendingWinner = Strings.parseAddress(lotteryWinnerString);
            s_winnerRequestFulfilled = true;
            s_functionsRequests[requestId].fulfilled = true;
        }

        // Emit an event to log the response
        emit LotteryFunctions__Response(requestId, lotteryWinnerString);
    }

    function _getWinner(uint64 subscriptionId, string[] memory args) internal {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastFunctionsRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, functionsGasLimit, donID);
        s_functionsRequests[s_lastFunctionsRequestId] = FunctionsRequestStatus({exists: true, fulfilled: false});
        s_vrfFulfilled = false;
    }

    function _getLotteryWinnerIndex() internal returns (uint256) {
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_vrfSubscriptionId,
                requestConfirmations: 5, // 5 blocks needed to be confirmed before random number is generated
                callbackGasLimit: vrfCallbackGasLimit, // gas limit for execution of callback VRF function (fufillRandomWords)
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        s_lastVRFRequestId = requestId;
        s_vrfRequests[requestId] = VrfRequestStatus({exists: true, fulfilled: false});

        return requestId;
    }

    function _endLottery() internal {
        address payable lotteryAddress = LotteryFactory(lotteryFactory).getActiveLottery();
        LotteryFactory(lotteryFactory).endLottery(lotteryAddress, s_pendingWinner);
        s_winnerRequestFulfilled = false;
    }

    /*///////////////////////////////////////////////
                    VIEW FUNCTIONS
    ///////////////////////////////////////////////*/

    function getLotteryPending() public view returns (bool) {
        return s_lotteryPending;
    }

    function getLastVRFRequestId() external view returns (uint256) {
        return s_lastVRFRequestId;
    }

    function getLastFunctionsRequestId() external view returns (bytes32) {
        return s_lastFunctionsRequestId;
    }

    function getVRFRequest(uint256 id) external view returns (VrfRequestStatus memory) {
        return s_vrfRequests[id];
    }

    function getFunctionsRequest(bytes32 id) external view returns (FunctionsRequestStatus memory) {
        return s_functionsRequests[id];
    }

    function getFunctionsSubscriptionId() external view returns (uint256) {
        return i_functionsSubscriptionId;
    }

    function getVFRSubscriptionId() external view returns (uint256) {
        return s_vrfSubscriptionId;
    }

    function getPendingWinner() external view returns (address) {
        return s_pendingWinner;
    }

    function getPendingRandomWord() external view returns (uint256) {
        return s_pendingRandomWord;
    }
}
