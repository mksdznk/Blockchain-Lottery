///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LotteryNft is ERC721, Ownable {
    /*///////////// STATE VARIABLES /////////////*/
    uint256 private constant MAX_ID = 5;
    uint256 private counter = 0;

    /*////////////////// ERRORS //////////////////*/
    error LotteryNft__MaxSupplyReached();

    /*/////////////// CONSTRUCTOR ///////////////*/
    constructor() ERC721("Fifu Fifu", "FIFU2") Ownable(msg.sender) {}

    /*//////////// EXTERNAL FUNCTIONS ////////////*/
    function mint(address to) external onlyOwner {
        require(counter < MAX_ID, LotteryNft__MaxSupplyReached());

        _safeMint(to, counter);
        counter += 1;
    }

    /*//////////// INTERNAL FUNCTIONS ////////////*/
    function _baseURI() internal view override returns (string memory) {
        return "ipfs://bafybeieiqrnwhc5xbuc6caemc5uvtqi2s56fe3i7o4kamxdbac2sd74s3i/";
    }
}
