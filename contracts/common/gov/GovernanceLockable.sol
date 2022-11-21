pragma solidity ^0.6.6;

import {Governable} from "./Governable.sol";
import {Lockable} from "../utils/Lockable.sol";

contract GovernanceLockable is Lockable, Governable {

    constructor(address governance) public Governable(governance) {

    }

    function lock() public override onlyGovernance {
        super.lock();
    }

    function unlock() public override onlyGovernance {
        super.unlock();
    }

}
