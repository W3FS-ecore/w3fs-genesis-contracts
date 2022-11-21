pragma solidity ^0.6.6;

import {Lockable} from "./Lockable.sol";
import {OwnableExpand} from "./OwnableExpand.sol";

contract OwnableLockable is Lockable, OwnableExpand {
    function lock() public override onlyOwner {
        super.lock();
    }

    function unlock() public override onlyOwner {
        super.unlock();
    }
}
