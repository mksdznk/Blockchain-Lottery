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
    bytes private s_lastFunctionsResponse;
    bytes private s_lastVRFResponse;
    bytes private s_lastFunctionsError;
    bytes private s_lastVRFError;
    bytes32 private s_keyHash;
    uint256 private lastFunctionsCallTime;
    uint256 private lastVRFCallTime;
    uint256 private s_vrfSubscriptionId;
    uint64 private immutable i_functionsSubscriptionId;
    address private lotteryFactory;
    uint32 private gasLimit = 300_000;
    address private router; //// ENTER YOUR ROUTER ADDRESS
    bytes32 private donID; //// ENTER YOUR DON ID
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
        "return Functions.encodeString(lotteryAddresses[winnerIndex]);} catch (error) {console.error('Error:', error);"
        "return Functions.encodeString(JSON.stringify({success: false,error: error.message}));}";

    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) private s_requests;

    /*///////////////////////////////////////////////
                        ERRORS
    //////////////////////////////////////////////*/
    error LotteryFunctions__UnexpectedRequestID(bytes32 requestId);
    error LotteryFunctions__UpkeepNotNeeded();
    error LotteryFunctions__InvalidSubscription();
    error LotteryFunctions__LotteryNotValid();

    /*///////////////////////////////////////////////
                        EVENTS
    //////////////////////////////////////////////*/
    event LotteryFunctions__Response(bytes32 indexed requestId, address winner, bytes response, bytes err);

    /*///////////////////////////////////////////////
                        CONSTRUCTOR
    ///////////////////////////////////////////////*/
    constructor(
        address _router,
        bytes32 _donID,
        uint64 _functionsSubscriptionId,
        uint256 _vrfSubscriptionId,
        address _vrfCoordinator,
        address _lotteryFactory
    )
        FunctionsClient(router)
        VRFConsumerBaseV2Plus(_vrfCoordinator) /* VRF vrfCoordinator address is address deployed to each network by Chainlink to handle and verify VRF https://docs.chain.link/vrf/v2-5/supported-networks */

    {
        router = _router;
        donID = _donID;
        i_functionsSubscriptionId = _functionsSubscriptionId;
        s_vrfSubscriptionId = _vrfSubscriptionId;
        lotteryFactory = _lotteryFactory;
    }

    /*///////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////*/

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = LotteryFactory(lotteryFactory).getActiveLottery() != address(0);

        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata) external override {
        // Verify upkeep condition
        if (LotteryFactory(lotteryFactory).getActiveLottery() == address(0)) {
            revert LotteryFunctions__LotteryNotValid();
        }

        // Validate subscription
        if (s_vrfSubscriptionId == 0) {
            revert LotteryFunctions__InvalidSubscription();
        }

        // Update timestamp to prevent immediate retriggering
        lastVRFCallTime = block.timestamp;

        /*
        * CALL RANDOM NUMBER
        */
        _getLotteryWinnerIndex();
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        s_requests[requestId].fulfilled = true;
        s_requests[requestId].randomWords = randomWords;

        string[] memory args = new string[](4);
        address payable lottery = LotteryFactory(lotteryFactory).getActiveLottery();
        args[0] = Strings.toHexString(lottery);
        args[1] = Strings.toString(Lottery(lottery).getTicketPriceInWei());
        args[2] = Strings.toString(block.chainid);
        args[3] = Strings.toString(randomWords[0]);

        _getWinner(i_functionsSubscriptionId, args);
    }

    function forceEndLottery() external onlyOwner {
        _getLotteryWinnerIndex();
    }

    /*///////////////////////////////////////////////
                    INTERNAL FUNCTIONS
    ///////////////////////////////////////////////*/

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (s_lastFunctionsRequestId != requestId) {
            revert LotteryFunctions__UnexpectedRequestID(requestId); // Check if request IDs match
        }
        // Update the contract's state variables with the response and any errors
        s_lastFunctionsResponse = response;
        s_lastFunctionsError = err;
        address lotteryWinner;

        if (err.length == 0) {
            lotteryWinner = abi.decode(response, (address));
            address payable lotteryAddress = LotteryFactory(lotteryFactory).getActiveLottery();
            LotteryFactory(lotteryFactory).endLottery(lotteryAddress, lotteryWinner);
        }

        // Emit an event to log the response
        emit LotteryFunctions__Response(requestId, lotteryWinner, s_lastFunctionsResponse, s_lastFunctionsError);
    }

    function _getWinner(uint64 subscriptionId, string[] memory args) internal returns (bytes32) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastFunctionsRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, gasLimit, donID);

        return s_lastFunctionsRequestId;
    }

    function _getLotteryWinnerIndex() internal returns (uint256) {
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_vrfSubscriptionId,
                requestConfirmations: 5, // 5 blocks needed to be confirmed before random number is generated
                callbackGasLimit: 100_000, // gas limit for execution of callback VRF function (fufillRandomWords)
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        s_lastVRFRequestId = requestId;
        s_requests[requestId] = RequestStatus({exists: true, fulfilled: false, randomWords: new uint256[](0)});

        return requestId;
    }

    /*///////////////////////////////////////////////
                    VIEW FUNCTIONS
    ///////////////////////////////////////////////*/

    function getLastVRFCallTime() external view returns (uint256) {
        return lastVRFCallTime;
    }

    function getLastFunctionsCallTime() external view returns (uint256) {
        return lastFunctionsCallTime;
    }

    function getFunctionsSubscriptionId() external view returns (uint256) {
        return i_functionsSubscriptionId;
    }

    function getVFRSubscriptionId() external view returns (uint256) {
        return s_vrfSubscriptionId;
    }
}
