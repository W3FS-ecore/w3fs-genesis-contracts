pragma solidity ^0.6.6;

import {UpgradeableProxy} from "@openzeppelin/contracts/proxy/UpgradeableProxy.sol";
import {Registry} from "../../common/misc/Registry.sol";

contract DelegateShareProxy is UpgradeableProxy {

    bytes32 constant OWNER_SLOT = keccak256("w3fs.network.proxy.owner");

    constructor(address _logic, bytes memory _data) public UpgradeableProxy(_logic, _data) {
        setOwner(msg.sender);
    }

    function _implementation() internal view override returns (address impl) {
        return Registry(super._implementation()).getDelegateShareAddress();
    }

    function setOwner(address newOwner) private {
        bytes32 position = OWNER_SLOT;
        assembly {
            sstore(position, newOwner)
        }
    }

    modifier onlyProxyOwner() {
        require(loadOwner() == msg.sender, "NOT_OWNER");
        _;
    }

    function owner() external view returns (address) {
        return loadOwner();
    }

    function loadOwner() internal view returns (address) {
        address _owner;
        bytes32 position = OWNER_SLOT;
        assembly {
            _owner := sload(position)
        }
        return _owner;
    }

    function transferOwnership(address newOwner) public onlyProxyOwner {
        require(newOwner != address(0), "ZERO_ADDRESS");
        setOwner(newOwner);
    }



}
