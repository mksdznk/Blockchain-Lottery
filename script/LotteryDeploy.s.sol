//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LotteryFactory} from "../contracts/LotteryFactory.sol";
import {Lottery} from "../contracts/Lottery.sol";
import {LotteryFunctions} from "../contracts/LotteryFunctions.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract LotteryDeploy is Script {
    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerKey);
        address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0; // enter router address for respective chain
        bytes32 donID = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000; // enter DON ID for respective chain
        uint64 functionsSubscriptionId = 6234; // enter subscription ID after creating a subscription
        uint256 vrfSubscriptionId = 22890821576172042770795576892011386820829453116532600925660041482855304707571; // enter subscription ID after creating a subscription
        address vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B; // enter router address for respective chain

        vm.startBroadcast(deployerKey);
        // DEPLOY LOTTERY FACTORY
        console.log("Account: ", deployerAddress);
        LotteryFactory lotteryFactory = new LotteryFactory();

        // DEPLOY LOTTERY FUNCTIONS
        LotteryFunctions lotteryFunctions = new LotteryFunctions(
            router, donID, functionsSubscriptionId, vrfSubscriptionId, vrfCoordinator, address(lotteryFactory)
        );

        console.log("LotteryFactory deployed to:", address(lotteryFactory));
        console.log("LotteryFunctions deployed to:", address(lotteryFunctions));
        console.log("LotteryNft deployed to:", lotteryFactory.getLotteryNftAddress());

        vm.stopBroadcast();
    }
}
