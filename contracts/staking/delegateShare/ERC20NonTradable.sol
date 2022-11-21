pragma solidity ^0.6.6;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20NonTradable is ERC20 {

    constructor() public ERC20("", ""){
    }

    function _approve(address owner, address spender, uint256 value) internal override {
        revert("disabled");
    }
}
