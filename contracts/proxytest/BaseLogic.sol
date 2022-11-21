pragma solidity ^0.6.6;

import {BaseStore} from "./BaseStore.sol";

contract BaseLogic {
    BaseStore internal _baseStore;

    function initialize(address _addr) external {
        _baseStore = BaseStore(_addr);
    }

    function setValueByData(uint256 _value) public {
        _baseStore.initializeNonPayableWithValue(_value);
    }

    function getValue() public returns (uint256) {
        return _baseStore.value();
    }
}
