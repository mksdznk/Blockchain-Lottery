## Blockchain Lottery

**This is a project I made as my Capstone project for the web3 bootcamp I attended at Metana.**

The project is a lottery which runs on the ETH blockchain using smart contracts. The smart contracts are included in the **contracts** directory which is in the root directory, and the FE of the app is included within the directory **front-end**, also within the root directory.

Project setup: (execute commands in terminal from root)

1. ### Create env variables 
copy ```.env.sample``` and create ```.env``` and populate with respective keys

2. ### Install Foundry dependencies
```forge install```

3. ### Build contracts
```forge build```

4. ### Run tests
```forge test```

5. ### (optional) Deploy contract to have your own instance to keep track of
```forge script script/LotteryDeploy.s.sol --rpc-url <RPC_URL> --broadcast --verify```
 - Additonally fix contract configs in ```front-end/src/contracts/``` and change addresses to newly deployed ones

6. ### FE setup
```cd front-end``` <br>
```yarn install # or npm install``` <br>
```yarn dev # starts on localhost:3000```

Current deployment: [https://blockchain-lottery-alpha.vercel.app/](https://blockchain-lottery-alpha.vercel.app/)

Contract addresses of deployed instance: (sepolia)
 - LotteryFactory: [0x9843931D93d5131EDE9DceAC0407500070A0e097](https://sepolia.etherscan.io/address/0x9843931D93d5131EDE9DceAC0407500070A0e097)
 - LotteryFunctions: [0x0b29fA841d0411B13578Ec4639cb09E92186ce13](https://sepolia.etherscan.io/address/0x0b29fA841d0411B13578Ec4639cb09E92186ce13)
 - LotteryNft: [0x57BBFDb7e9e400e93A5b79F622e2e18034C7f454](https://sepolia.etherscan.io/address/0x57BBFDb7e9e400e93A5b79F622e2e18034C7f454)