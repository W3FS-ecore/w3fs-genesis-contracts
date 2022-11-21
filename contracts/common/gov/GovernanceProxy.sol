pragma solidity ^0.6.6;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UpgradeableProxy} from "@openzeppelin/contracts/proxy/UpgradeableProxy.sol";

contract GovernanceProxy is Ownable, UpgradeableProxy {
    // when js , if _data is empty  you can set "Buffer.from('')"
    constructor(address _logic, bytes memory _data) public UpgradeableProxy(_logic, _data) {}
}
