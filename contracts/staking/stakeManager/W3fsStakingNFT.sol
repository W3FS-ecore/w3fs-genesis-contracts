pragma solidity ^0.6.6;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract W3fsStakingNFT is ERC721, Ownable {

    constructor(string memory name, string memory symbol) public ERC721(name, symbol){

    }

    function mint(address to, uint256 tokenId) public onlyOwner {
        require(balanceOf(to) == 0, "StorageMiners MUST NOT own multiple stake position");
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }

    function _transferFrom(address from, address to, uint256 tokenId) internal {
        require(balanceOf(to) == 0, "StorageMiners MUST NOT own multiple stake position");
        transferFrom(from, to, tokenId);
    }

}
