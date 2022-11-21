pragma solidity ^0.6.6;

import {Governable} from "../gov/Governable.sol";

contract Registry is Governable {


    event ContractMapUpdated(bytes32 indexed key, address indexed previousContract, address indexed newContract);

    bytes32 private constant STAKE_MANAGER = keccak256("w3fsStakeManager");
    bytes32 private constant DELEGATE_SHARE = keccak256("delegateShare");
    bytes32 private constant SYSTEM_REWARD_SHARE = keccak256("systemReward");
    bytes32 private constant STORAGE_MANAGER = keccak256("w3fsStorageManager");
    bytes32 private constant SLASH_MANAGER = keccak256("slashingManager");
    bytes32 private constant STAKE_INFO = keccak256("w3fsStakingInfo");

    mapping(bytes32 => address) public contractMap;

    constructor(address _governance) public Governable(_governance) {

    }


    function updateContractMap(bytes32 _key, address _address) external onlyGovernance {
        emit ContractMapUpdated(_key, contractMap[_key], _address);
        contractMap[_key] = _address;
    }

    function getW3fsStakingInfoAddress() public view returns (address) {
        return contractMap[STAKE_INFO];
    }

    function getW3fsStakeManagerAddress() public view returns (address) {
        return contractMap[STAKE_MANAGER];
    }

    function getDelegateShareAddress() public view returns (address) {
        return contractMap[DELEGATE_SHARE];
    }

    function getSystemRewardAddress() public view returns (address) {
        return contractMap[SYSTEM_REWARD_SHARE];
    }

    function getW3fsStorageManagerAddress() public view returns (address) {
        return contractMap[STORAGE_MANAGER];
    }

    function getW3fsSlashManagerAddress() public view returns (address) {
        return contractMap[SLASH_MANAGER];
    }

}
