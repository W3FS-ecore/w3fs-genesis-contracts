pragma solidity ^0.6.6;

import {GovernanceLockable} from "../../common/gov/GovernanceLockable.sol";
import {Registry} from "../../common/misc/Registry.sol";
import {IW3fsStakeManager} from "../stakeManager/IW3fsStakeManager.sol";
import {IGovernance} from "../../common/gov/IGovernance.sol";
import {System} from "../../System.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {OwnableExpand} from "../../common/utils/OwnableExpand.sol";
import {IDelegateShare} from "../delegateShare/IDelegateShare.sol";

// solc --bin-runtime @openzeppelin/=node_modules/@openzeppelin/ /=/ contracts/staking/reward/SystemReward.sol
// abigen --abi=SystemReward.abi --pkg=systemReward -out=SystemReward.go
// miner reward records
contract SystemReward is GovernanceLockable, System, OwnableExpand {

    using SafeMath for uint256;

    event receiveNotMiner(address addr);
    event increaseReward(address indexed addr, uint256 indexed reward);

    bool public alreadyInit;
    bool internal reentrantlocked;

    Registry public registry;
    IW3fsStakeManager public w3fsStakeManager;

    mapping(address => uint256) internal minerRewards;


    modifier onlyNotInit() {
        require(!alreadyInit, "the contract already init");
        _;
    }

    modifier noReentrancy(){
        require(!reentrantlocked, "No re-entrancy");
        reentrantlocked = true;
        _;
        reentrantlocked = false;
    }

    modifier onlyCoinbase(address receiver) {
        require(receiver == block.coinbase, "the message sender must be the block producer");
        _;
    }

    constructor() public payable GovernanceLockable(address(0x0)) {
    }

    receive() external payable {
    }



    function initialize(address _governance, address _registry) public onlyNotInit {
        alreadyInit = true;
        governance = IGovernance(_governance);
        registry = Registry(_registry);
        w3fsStakeManager = IW3fsStakeManager(registry.getW3fsStakeManagerAddress());
        _transferOwnership(msg.sender);
    }


    // 用于矿工提取奖励
    function claimRewardsMiner(uint256 _amount) public noReentrancy onlyWhenUnlocked {
        uint256 reward = w3fsStakeManager.updateRewardsMiner(msg.sender, _amount);
        require(reward > 0, "reward error!");
        (bool success,) = payable(address(uint160(msg.sender))).call{value : reward}("");
        require(success, "Failed to claim w3fs");
    }


    // 委托者提取奖励
    function withdrawDelegateRewards(uint256 minerId) public noReentrancy onlyWhenUnlocked {
        ( , , ,address _contract, , ) = w3fsStakeManager.getMinerBaseInfo(minerId);
        require(_contract != address(0x0), "contract is empty");
        uint256 reward = IDelegateShare(_contract).withdrawRewards(msg.sender);
        require(reward > 0 , "reward is empty");
        (bool success,) = payable(address(uint160(msg.sender))).call{value : reward}("");
        require(success, "Failed to claim w3fs");
    }


}
