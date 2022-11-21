pragma solidity ^0.6.6;

contract Lockable {
    bool public locked;

    modifier onlyWhenUnlocked() {
        require(!locked, "locked");
        _;
    }

    function lock() public virtual {
        locked = true;
    }

    function unlock() public virtual {
        locked = false;
    }
}
