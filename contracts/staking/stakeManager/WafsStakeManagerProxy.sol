pragma solidity ^0.6.6;

import {UpgradesAvailableProxy} from "../../common/proxy/UpgradesAvailableProxy.sol";

contract W3fsStakeManagerProxy is UpgradesAvailableProxy {
    constructor() public UpgradesAvailableProxy(){}
}
