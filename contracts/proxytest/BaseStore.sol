pragma solidity ^0.6.6;

contract BaseStore {
    uint256 public value;
    string public text;
    uint256[] public values;

    function initializeNonPayable() public {
        value = 10;
    }

    function initializePayable() public payable {
        value = 100;
    }

    function initializeNonPayableWithValue(uint256 _value) public {
        value = _value;
    }

    function initializePayableWithValue(uint256 _value) public payable {
        value = _value;
    }

    function initialize(
        uint256 _value,
        string memory _text,
        uint256[] memory _values
    ) public {
        value = _value;
        text = _text;
        values = _values;
    }

    function get() public pure returns (bool) {
        return true;
    }

    function version() public pure virtual returns (string memory) {
        return "V1";
    }

    function reverts() public pure {
        require(false, "DummyImplementation reverted");
    }
}
