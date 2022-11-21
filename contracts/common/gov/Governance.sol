pragma solidity ^0.6.6;

import {IGovernance} from "./IGovernance.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Governance is IGovernance, Ownable {

    function update(address target, bytes calldata data) external override onlyOwner {
        (bool success, ) = target.call(data); /* bytes memory returnData */
        require(success, "Update failed");
    }


}
