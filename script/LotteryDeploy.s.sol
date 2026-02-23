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
        uint64 functionsSubscriptionId = 6277; // enter subscription ID after creating a subscription
        uint256 vrfSubscriptionId = 43880759362028424185460512860079674532526562359479720028203006214749272697836; // enter subscription ID after creating a subscription
        address vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B; // enter router address for respective chain
        bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae; // enter keyHash for VRF

        vm.startBroadcast(deployerKey);
            // DEPLOY LOTTERY FACTORY
            console.log("Account: ", deployerAddress);
            LotteryFactory lotteryFactory = new LotteryFactory();

            // DEPLOY LOTTERY FUNCTIONS
            LotteryFunctions lotteryFunctions = new LotteryFunctions(
                router, donID, functionsSubscriptionId, vrfSubscriptionId, vrfCoordinator, address(lotteryFactory), keyHash
            );

            lotteryFactory.setOracle(address(lotteryFunctions));

            address payable lottery = payable(lotteryFactory.createLottery(1000, 1e13, 75, 10));
            Lottery(lottery).purchaseTickets{value: 1e13 * 65}(); // bought 65 tickets
            Lottery(lottery).transferTickets(0x86a74cCA6e7a16bA5C68bEE001B2F6C5b4023593, 15);
            Lottery(lottery).transferTickets(0xAc82F54C2d27C3AEF6637f75d5ABF78b417Ea37f, 15);
            Lottery(lottery).transferTickets(0x3B0E2eFA9F8a75f8A986B0ca2E43DDE77eE0a5AC, 15);


            console.log("LotteryFactory deployed to:", address(lotteryFactory));
            console.log("LotteryFunctions deployed to:", address(lotteryFunctions));
            console.log("LotteryNft deployed to:", lotteryFactory.getLotteryNftAddress());

        vm.stopBroadcast();
    }
}
