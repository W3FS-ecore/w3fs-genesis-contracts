pragma solidity ^0.6.6;

import {ERCProxy} from "./ERCProxy.sol";
import {DelegateProxyForwarder} from "./DelegateProxyForwarder.sol";

abstract contract DelegateProxy is ERCProxy, DelegateProxyForwarder {
    function proxyType() external override pure returns (uint256 proxyTypeId) {
        proxyTypeId = 2;
    }

    function implementation() external override  virtual view returns (address);
}