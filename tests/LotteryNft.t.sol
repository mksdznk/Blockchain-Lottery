///SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {LotteryNft} from "../contracts/LotteryNft.sol";

contract LotteryNftTest is Test {
    LotteryNft nft;
    address owner;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        owner = address(this);
        nft = new LotteryNft();
    }

    /*//////////////////////////////////////////////
                  CONSTRUCTOR TESTS
    //////////////////////////////////////////////*/

    function test_constructor_setsNameAndSymbol() public view {
        assertEq(nft.name(), "Fifu Fifu");
        assertEq(nft.symbol(), "FIFU2");
    }

    function test_constructor_setsOwner() public view {
        assertEq(nft.owner(), owner);
    }

    /*//////////////////////////////////////////////
                    MINT TESTS
    //////////////////////////////////////////////*/

    function test_mint_mintsToRecipient() public {
        nft.mint(user1);
        assertEq(nft.ownerOf(0), user1);
        assertEq(nft.balanceOf(user1), 1);
    }

    function test_mint_incrementsCounter() public {
        nft.mint(user1);
        nft.mint(user2);
        assertEq(nft.ownerOf(0), user1);
        assertEq(nft.ownerOf(1), user2);
    }

    function test_mint_allFiveNfts() public {
        for (uint256 i = 0; i < 5; i++) {
            nft.mint(user1);
        }
        assertEq(nft.balanceOf(user1), 5);
    }

    function test_mint_revertsAfterMaxSupply() public {
        for (uint256 i = 0; i < 5; i++) {
            nft.mint(user1);
        }
        vm.expectRevert(LotteryNft.LotteryNft__MaxSupplyReached.selector);
        nft.mint(user2);
    }

    function test_mint_revertsWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.mint(user1);
    }

    /*//////////////////////////////////////////////
                  TOKEN URI TESTS
    //////////////////////////////////////////////*/

    function test_tokenURI_returnsCorrectURI() public {
        nft.mint(user1);
        string memory expectedBase = "ipfs://bafybeifatqoahypgwbg2oyv5gj7nwd6b7weqc7b3wqtpajscg5l7inpium/";
        assertEq(nft.tokenURI(0), string(abi.encodePacked(expectedBase, "0")));
    }

    function test_tokenURI_revertsForNonExistentToken() public {
        vm.expectRevert();
        nft.tokenURI(99);
    }
}
