///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LotteryNFT is ERC721, Ownable {
    /*///////////// STATE VARIABLES /////////////*/
    uint256 private constant MAX_SUPPLY = 6;
    uint256 private counter = 0;
    

    /*////////////////// ERRORS //////////////////*/
    error LotteryNFT__MaxSupplyReached();

    /*/////////////// CONSTRUCTOR ///////////////*/
    constructor() ERC721("Fifu Fifu", "FIFU2") {}

    /*//////////// EXTERNAL FUNCTIONS ////////////*/
    function mint(address to) external onlyOwner {
        require(counter < MAX_SUPPLY, LotteryNFT__MaxSupplyReached());

        _safeMint(to, counter);
        counter += 1;
    }
    /*//////////// INTERNAL FUNCTIONS ////////////*/
    function _baseURI() internal view override returns (string memory) {
        return "ipfs://bafybeifatqoahypgwbg2oyv5gj7nwd6b7weqc7b3wqtpajscg5l7inpium/";
    }
}
