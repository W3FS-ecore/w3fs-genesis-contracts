pragma solidity ^0.6.6;

interface IGovernance {
    function update(address target, bytes calldata data) external;
}
