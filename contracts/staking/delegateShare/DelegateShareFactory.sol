pragma solidity ^0.6.6;

import {DelegateShareProxy} from "./DelegateShareProxy.sol";
import {DelegateShare} from "./DelegateShare.sol";

contract DelegateShareFactory {

    function create(uint256 minerId, address loggerAddress, address registry, address storageManager) public returns (address) {
        DelegateShareProxy proxy = new DelegateShareProxy(registry, "");
        //哪个合约调用这个create方法， 对应的msg.sender就是谁
        proxy.transferOwnership(msg.sender);
        address proxyAddr = address(proxy);
        (bool success, bytes memory data) = proxyAddr.call{gas:gasleft()}(
            abi.encodeWithSelector(
                DelegateShare(proxyAddr).initialize.selector,
                minerId,
                loggerAddress,
                msg.sender,
                registry,
                storageManager
            )
        );
        require(success, string(data));
        return proxyAddr;
    }
}
