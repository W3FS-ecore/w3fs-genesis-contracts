pragma solidity ^0.6.6;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {W3fsStakingNFT} from "./W3fsStakingNFT.sol";
import {W3fsStakingInfo} from "../W3fsStakingInfo.sol";
import {DelegateShareFactory} from "../delegateShare/DelegateShareFactory.sol";
import {IW3fsStorageManager} from "../../storage/IW3fsStorageManager.sol";

abstract contract W3fsStakeManagerStorage {
    using SafeMath for uint256;

    enum Status {Inactive, Active, Locked, Unstaked}

    struct StorageMiner {
        uint256 amount;  // stake amount
        uint256 reward;  // stake reward
        uint256 activationEpoch;            // 矿工开始质押的周期数
        uint256 deactivationEpoch;          // 矿工退出的周期数
        uint256 jailTime;
        address signer;
        address contractAddress;
        Status status;
        uint256 commissionRate;
        uint256 lastCommissionUpdate;
        uint256 delegatorsReward;
        uint256 delegatedAmount;
    }

    struct StorageMinerMin {
        address signer;
        uint256 amount;
    }

    struct IbcMinerSetPackage {
        uint8  packageType;
        StorageMinerMin[] storageMinerMinSet;
    }


    // all stake info
    struct State {
        uint256 amount;             // all amount number
        uint256 stakerCount;        // all staker count
    }

    struct StateChange {
        int256 amount;
        int256 stakerCount;
    }

    uint256 constant REWARD_PRECISION = 10 ** 25;
    uint256 internal constant INCORRECT_VALIDATOR_ID = 2 ** 256 - 1;
    uint256 internal constant INITIALIZED_AMOUNT = 1;
    uint256 internal SPAN_DURATION;
    uint256 internal storageMinerThreshold;
    uint256 internal totalStaked;
    uint256 internal NFTCounter;
    uint256 internal minDeposit;    //最小质押量
    uint256 internal MINER_REWARD;
    uint256 public COMMISSION_UPDATE_DELAY;  // 修改委托比率的延迟
    uint256 public UNSTAKE_CLAIM_DELAY;
    bool internal delegationEnabled;
    IERC20 public token;
    address public registry;
    DelegateShareFactory public delegateShareFactory;
    W3fsStakingNFT public NFTContract;
    W3fsStakingInfo public logger;
    IW3fsStorageManager public storageManager;
    address[] public signers;
    mapping(uint256 => StorageMiner) public storageMiners;
    mapping(address => uint256) public signerToStorageMiner;
    mapping(address => uint256) public signerToFee;
    mapping(address => uint256) public userFeeExit;




}
