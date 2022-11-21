pragma solidity ^0.6.6;

contract System {
    address public constant SYSTEM_ADDRESS = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;

    modifier onlySystem() {
        require(msg.sender == SYSTEM_ADDRESS, "Not System Addess!");
        _;
    }
}