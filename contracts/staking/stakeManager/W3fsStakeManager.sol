pragma solidity ^0.6.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {MerkleProof} from "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import {Merkle} from "../../common/utils/Merkle.sol";
import {GovernanceLockable} from "../../common/gov/GovernanceLockable.sol";
import {IGovernance} from "../../common/gov/IGovernance.sol";
import {OwnableExpand} from "../../common/utils/OwnableExpand.sol";
import {W3fsStakeManagerStorage} from "./W3fsStakeManagerStorage.sol";
import {IW3fsStakeManager} from "./IW3fsStakeManager.sol";
import {W3fsStakingNFT} from "./W3fsStakingNFT.sol";
import {W3fsStakingInfo} from "../W3fsStakingInfo.sol";
import {Registry} from "../../common/misc/Registry.sol";
import {DelegateShareFactory} from "../delegateShare/DelegateShareFactory.sol";
import {IDelegateShare} from "../delegateShare/IDelegateShare.sol";
import {IW3fsStorageManager} from "../../storage/IW3fsStorageManager.sol";
import {System} from "../../System.sol";
import {RLPDecode} from "../../common/utils/RLPDecode.sol";
import {BorValidatorSet} from "../../BorValidatorSet.sol";

// truffle run contract-size
// solc --bin-runtime @openzeppelin/=node_modules/@openzeppelin/ solidity-rlp/=node_modules/solidity-rlp/ /=/ contracts/staking/stakeManager/W3fsStakeManager.sol
contract W3fsStakeManager is W3fsStakeManagerStorage, IW3fsStakeManager, GovernanceLockable, OwnableExpand, System {

    using SafeMath for uint256;
    using RLPDecode for *;
    using Merkle for bytes32;

    bytes public constant INIT_MINERSET_BYTES = hex"f84580f842e094b4551bab04854a09b93492bb61b1b011a82cc27a8a043c33c1937564800000e094cd372b7d1e5c9892d5d545e4b02521ac096f94568a021e19e0c9bab2400000";
    bool private inited = false;

    event ReceiverRewardEvent(address indexed miner);


    constructor() public payable GovernanceLockable(address(0x0)) {

    }

    receive() external payable {

    }

    modifier onlyStaker(uint256 minerId) {
        require(NFTContract.ownerOf(minerId) == msg.sender);
        _;
    }

    modifier onlySystemReward(){
        require(Registry(registry).getSystemRewardAddress() == msg.sender);
        _;
    }

    modifier onlyDelegation(uint256 minerId) {
        require(storageMiners[minerId].contractAddress == msg.sender, "Invalid contract address");
        _;
    }

    modifier onlySlashManager() {
        require(Registry(registry).getW3fsSlashManagerAddress() == msg.sender);
        _;
    }

    modifier initializer() {
        require(!inited, "already inited");
        inited = true;
        _;
    }


    function _init() private {
        (IbcMinerSetPackage memory minerSetPackage,) = decodeMinerSetSynPackage(INIT_MINERSET_BYTES);
        for (uint i; i < minerSetPackage.storageMinerMinSet.length; i++) {
            // 初始化质押
            uint256 amount = minerSetPackage.storageMinerMinSet[i].amount;
            address signer = minerSetPackage.storageMinerMinSet[i].signer;
            totalStaked = totalStaked.add(amount);
            uint256 minerId = NFTCounter;
            storageMiners[minerId] = StorageMiner({
                reward : INITIALIZED_AMOUNT,
                amount : amount,
                activationEpoch : 0,
                deactivationEpoch : 0,
                jailTime : 0,
                signer : signer,
                contractAddress : delegateShareFactory.create(minerId, address(logger), registry, address(storageManager)),
                status : Status.Active,
                commissionRate : 5,
                lastCommissionUpdate : 0,
                delegatorsReward : INITIALIZED_AMOUNT,
                delegatedAmount : 0
                });
            NFTContract.mint(signer, minerId);
            signerToStorageMiner[signer] = minerId;
            NFTCounter = minerId.add(1);
            _insertSigner(signer);
        }
    }

    function initialize(
        address _owner,
        address _registry,
        address _token,
        address _NFTContract,
        address _governance,
        address _stakingLogger,
        address _delegateShareFactory,
        address _storageManager
    ) external initializer {
        storageMinerThreshold = 7;
        NFTCounter = 1;
        delegationEnabled = true;
        minDeposit = (10 ** 18);
        MINER_REWARD = 5 * (10 ** 18);
        COMMISSION_UPDATE_DELAY = 120;
        UNSTAKE_CLAIM_DELAY = 5;
        SPAN_DURATION = 64;
        _transferOwnership(_owner);
        governance = IGovernance(_governance);
        token = IERC20(_token);
        delegateShareFactory = DelegateShareFactory(_delegateShareFactory);
        registry = _registry;
        NFTContract = W3fsStakingNFT(_NFTContract);
        logger = W3fsStakingInfo(_stakingLogger);
        storageManager = IW3fsStorageManager(_storageManager);
        _init();
    }


    function stakeFor(
        address user,
        uint256 amount,
        uint256 fee,
        uint256 storagePromise,
        bool acceptDelegation,
        bytes calldata signerPubkey
    ) external onlyWhenUnlocked payable virtual override {
        require(signers.length < storageMinerThreshold, "no more slots");
        require(amount >= minDeposit, "not enough deposit");
        require(msg.value == amount, "Insufficient amount");
        require(amount > fee && fee > 0 , "fee is bigger than amount");
        require(storagePromise >= 2 , "storagePromise is wrong");
        uint256 realAmount = amount.sub(fee);
        _transferAndTopUp(user, fee);
        require(storageManager.checkCanStakeMore(user, 0, realAmount) , "no enough stake eligibility");
        _stakeFor(user, realAmount, storagePromise, acceptDelegation, signerPubkey);
    }

    function _transferAndTopUp(address user, uint256 fee) private {
        signerToFee[user] = signerToFee[user].add(fee);
        logger.logTopUpFee(user, fee);
    }

    function topupFee(address user, uint256 fee) payable external override {
        require(msg.value == fee , "fee is wrong");
        _transferAndTopUp(user, fee);
    }

    function claimFee(uint256 accumFeeAmount, uint256 index, bytes memory proof) public {
        BorValidatorSet borValidatorSet = BorValidatorSet(0x0000000000000000000000000000000000001000);
        bytes32 accountRootHash = borValidatorSet.getAccountRootHash();
        require(
            keccak256(abi.encode(msg.sender, accumFeeAmount)).checkMembership(index, accountRootHash, proof),
            "Wrong acc proof"
        );

        uint256 withdrawAmount = accumFeeAmount.sub(userFeeExit[msg.sender]);
        require(signerToFee[msg.sender] >= withdrawAmount, "no enough fee");
        userFeeExit[msg.sender] = accumFeeAmount;
        signerToFee[msg.sender] = signerToFee[msg.sender].sub(withdrawAmount);
        (bool success,) = payable(address(uint160(msg.sender))).call{value : withdrawAmount}("");
        require(success, "Failed to claim w3fs");
    }

    function _stakeFor(
        address user,
        uint256 amount,
        uint256 storagePromise,
        bool acceptDelegation,
        bytes memory signerPubkey
    ) internal returns (uint256) {
        address signer = _getAndAssertSigner(signerPubkey);
        uint256 minerId = NFTCounter;
        W3fsStakingInfo _logger = logger;
        uint256 _currentEpoch = getCurrentEpoch(uint256(block.number)).add(1);
        totalStaked = totalStaked.add(amount);
        storageMiners[minerId] = StorageMiner({
            reward : INITIALIZED_AMOUNT,
            amount : amount,
            activationEpoch : _currentEpoch,
            deactivationEpoch : 0,
            jailTime : 0,
            signer : signer,
            contractAddress : acceptDelegation ? delegateShareFactory.create(minerId, address(_logger), registry, address(storageManager)) : address(0x0),
            status : Status.Active,
            // 委托比例 默认初始时5%
            commissionRate : 5,
            lastCommissionUpdate : 0,
            delegatorsReward : INITIALIZED_AMOUNT,
            delegatedAmount : 0
        });
        // set map user => minerId
        NFTContract.mint(user, minerId);
        signerToStorageMiner[signer] = minerId;
        // update storagepromise
        storageManager.updateStoragePromise(user, storagePromise);
        // send staked event
        _logger.logStaked(signer, signerPubkey, minerId, _currentEpoch, amount, totalStaked);
        NFTCounter = minerId.add(1);
        _insertSigner(signer);
        return minerId;
    }


    // 提取奖励 只能 systemReward调用
    function updateRewardsMiner(address minerAddr, uint256 amount) external override onlySystemReward returns (uint256) {
        uint256 minerId = signerToStorageMiner[minerAddr];
        require(minerId > 0 , "no miner");
        if(amount > 0) {
            require(amount > 0 && storageMiners[minerId].reward.sub(INITIALIZED_AMOUNT) > amount, "the amount is too big !");
            storageMiners[minerId].reward = storageMiners[minerId].reward.sub(amount);
            return amount;
        } else if (amount == 0) {
            // update all
            require(storageMiners[minerId].reward > INITIALIZED_AMOUNT , "the amount is too big");
            uint256 reward = storageMiners[minerId].reward.sub(INITIALIZED_AMOUNT);
            storageMiners[minerId].reward = INITIALIZED_AMOUNT;
            return reward;
        }
        return 0;
    }

    function slash(address minerAddr, uint256 slashAmount, bool doJail) external override onlySlashManager {
        uint256 minerId = signerToStorageMiner[minerAddr];
        address delegateContract = storageMiners[minerId].contractAddress;
        if(delegateContract != address(0x0)) {
            uint256 delSlashedAmount = IDelegateShare(delegateContract).slash(storageMiners[minerId].amount, storageMiners[minerId].delegatedAmount, slashAmount);
            slashAmount = slashAmount.sub(delSlashedAmount);
        }
        if(doJail) {
            _jail(minerId);
        }
        if(storageMiners[minerId].amount > slashAmount) {
            storageMiners[minerId].amount = storageMiners[minerId].amount.sub(slashAmount);
        } else {
            storageMiners[minerId].amount = 0;
            uint256 currentEpoch = getCurrentEpoch(block.number);
            _unstake(minerId, currentEpoch.add(1));
        }
    }


    // 计算奖励 , 系统调用触发
    function receiverReward(address miner) external onlySystem {
        bool isMiner = _isActiveMiner(miner);
        if (isMiner) {
            uint256 minerId = signerToStorageMiner[miner];
            StorageMiner storage storageMiner = storageMiners[minerId];
            if (storageMiner.contractAddress != address(0x0)) {
                // 如果支持委托，则通过委托去计算奖励
                uint256 commissionRate = storageMiner.commissionRate;
                uint256 delegatedAmount = storageMiner.delegatedAmount;
                uint256 stakeAmount = storageMiner.amount;
                (uint256 minerReward, uint256 delegatorsReward) = _increaseReward(commissionRate, stakeAmount, delegatedAmount);
                storageMiner.reward = storageMiner.reward.add(minerReward);
                storageMiner.delegatorsReward = storageMiner.delegatorsReward.add(delegatorsReward);
            } else {
                //无委托奖励都给矿工
                storageMiner.reward = storageMiner.reward.add(MINER_REWARD);
            }
            emit ReceiverRewardEvent(miner);
        }
    }

    // TODO 用于计算出块奖励,后续根据经济模型去计算 返回（矿工奖励，委托者奖励）
    function _increaseReward(uint256 commissionRate, uint256 stakeAmount, uint256 delegatedAmount) public view returns (uint256, uint256) {
        // 矿工总质押 (自身 + 委托)
        uint256 combinedStakePower = stakeAmount.add(delegatedAmount);
        // 根据当前自身质押和委托质押比例计算矿工奖励，矿工并再次基础上根据commissionRate收取质押手续费
        uint256 validatorRewardVar = stakeAmount.mul(MINER_REWARD).div(combinedStakePower);
        if (commissionRate > 0) {
            validatorRewardVar = validatorRewardVar.add(MINER_REWARD.sub(validatorRewardVar).mul(commissionRate).div(100));
        }
        uint256 delegatorsRewardVar = MINER_REWARD.sub(validatorRewardVar);
        return (validatorRewardVar, delegatorsRewardVar);
    }


    // 增加额度质押
    function restake(uint256 minerId, uint256 amount) public payable onlyWhenUnlocked onlyStaker(minerId) {
        // 必须是活跃验证者
        require(storageMiners[minerId].deactivationEpoch == 0, "No restaking");
        require(msg.value != 0 && msg.value == amount, "msg.value is wrong");
        // 判断是否还有质押额度
        require(storageManager.checkCanStakeMore(storageMiners[minerId].signer, storageMiners[minerId].amount, amount) , "no enough stake eligibility");
        uint256 newTotalStaked = totalStaked.add(amount);
        totalStaked = newTotalStaked;
        uint256 newAmount = storageMiners[minerId].amount.add(amount);
        storageMiners[minerId].amount = newAmount;
        // 记录事件
        logger.logStakeUpdate(minerId);
        logger.logRestaked(minerId, storageMiners[minerId].amount, newTotalStaked);
    }


    //
    /**
        停止质押
         1. 设置deactivationEpoch(unstake时的周期)，下一轮就不是活跃矿工，就不会获得奖励
         2. 锁定委托合约，防止用户进行委托
         3. 删除signers数组对应的值
    */
    function unstake(uint256 minerId) external override onlyStaker(minerId) {
        Status status = storageMiners[minerId].status;
        require(
            storageMiners[minerId].deactivationEpoch == 0 && (status == Status.Active || status == Status.Locked)
        );
        uint256 currentEpoch = getCurrentEpoch(block.number);
        _unstake(minerId, currentEpoch.add(1));
    }

    function _unstake(uint256 minerId, uint256 exitEpoch) internal {
        address delegationContract = storageMiners[minerId].contractAddress;
        //require(epoch >= 1, "too early to execute unstake");
        storageMiners[minerId].deactivationEpoch = exitEpoch;
        // 锁委托合约
        if (delegationContract != address(0)) {
            // TODO 需要注意下，lockExpand要用权限控制，后面测试下
            IDelegateShare(delegationContract).lockExpand();
        }
        // 删除数组里对应的值和更新全局信息
        _removeSigner(storageMiners[minerId].signer);
    }


    // 停止质押后的质押币延迟提取
    function unstakeClaim(uint256 minerId) public onlyStaker(minerId) onlyWhenUnlocked {
        uint256 deactivationEpoch = storageMiners[minerId].deactivationEpoch;
        uint256 _amount = storageMiners[minerId].amount;
        uint256 _currentEpoch = getCurrentEpoch(block.number);
        require(
            deactivationEpoch > 0 &&
            storageMiners[minerId].status != Status.Unstaked &&
            deactivationEpoch.add(UNSTAKE_CLAIM_DELAY) <= _currentEpoch,
            "miner status is Unstaked or deactivationEpoch is too low");
        // 必须保证矿工的奖励已经被提取
        require(storageMiners[minerId].reward.sub(INITIALIZED_AMOUNT) == 0, "There are rewards not extracted");
        NFTContract.burn(minerId);
        storageMiners[minerId].amount = 0;
        storageMiners[minerId].jailTime = 0;
        storageMiners[minerId].status = Status.Unstaked;
        storageMiners[minerId].signer = address(0);
        signerToStorageMiner[storageMiners[minerId].signer] = INCORRECT_VALIDATOR_ID;
        // 提取质押币
        if (_amount > 0) {
            (bool success,) = payable(address(uint160(msg.sender))).call{value : _amount}("");
            require(success, "Failed to claim w3fs");
        }
    }

    // 矿工解除监禁状态
    function unjail(uint256 minerId) public onlyStaker(minerId){
        require(storageMiners[minerId].status == Status.Locked, "Not jailed");
        require(storageMiners[minerId].deactivationEpoch == 0, "Already unstaking");
        uint256 _currentEpoch = getCurrentEpoch(block.number);
        // 解除监禁需要在下一个周期
        require(storageMiners[minerId].jailTime <= _currentEpoch, "Incomplete jail period");
        uint256 amount = storageMiners[minerId].amount;
        // 如果被惩罚的质押量已经小于最低值，则没办法再解除
        require(amount >= minDeposit);
        // 如果有委托，解锁委托合约
        address delegationContract = storageMiners[minerId].contractAddress;
        if (delegationContract != address(0x0)) {
            IDelegateShare(delegationContract).unlockExpand();
        }
        storageMiners[minerId].status = Status.Active;
        address signer = storageMiners[minerId].signer;
        logger.logUnjailed(minerId, signer); //记录日志
    }

    function _jail(uint256 minerId) private {
        address delegationContract = storageMiners[minerId].contractAddress;
        if (delegationContract != address(0x0)) {
            IDelegateShare(delegationContract).lockExpand();
        }
        uint256 _epoch = getCurrentEpoch(block.number);
        storageMiners[minerId].jailTime = _epoch.add(1);
        storageMiners[minerId].status = Status.Locked;
        logger.logJailed(minerId, _epoch, storageMiners[minerId].signer);
    }



    function _removeSigner(address signerToDelete) internal {
        // 记录数组原来的长度
        uint256 totalSigners = signers.length;
        // swapSigner 记录删掉的值
        address swapSigner = signers[totalSigners - 1];
        // 删掉最后一个元素
        signers.pop();
        for (uint256 i = totalSigners - 1; i > 0; --i) {
            if (swapSigner == signerToDelete) {
                break;
            }
            (swapSigner, signers[i - 1]) = (signers[i - 1], swapSigner);
        }
    }


    // ======================================== 委托相关 ====================================================
    function updateMinerState(uint256 minerId, int256 amount) public override onlyDelegation(minerId) {
        if (amount > 0) {
            // 是否允许委托
            require(delegationEnabled, "Delegation is disabled");
        }
        if (amount >= 0) {
            storageMiners[minerId].delegatedAmount = storageMiners[minerId].delegatedAmount.add(uint256(amount));
        } else {
            decreaseMinerDelegatedAmount(minerId, uint256(amount * - 1));
        }
    }

    // Reduce the number of mining commissions
    function decreaseMinerDelegatedAmount(uint256 minerId, uint256 amount) public override onlyDelegation(minerId) {
        storageMiners[minerId].delegatedAmount = storageMiners[minerId].delegatedAmount.sub(amount);
    }


    //
    function withdrawDelegatorsReward(uint256 minerId) public override onlyDelegation(minerId) returns (uint256) {
        uint256 totalReward = storageMiners[minerId].delegatorsReward.sub(INITIALIZED_AMOUNT);
        storageMiners[minerId].delegatorsReward = INITIALIZED_AMOUNT;
        return totalReward;
    }

    // ======================================== delegator ====================================================


    function getSorageMinerId(address user) public view returns (uint256) {
        return NFTContract.tokenOfOwnerByIndex(user, 0);
    }


    function _getAndAssertSigner(bytes memory pub) private view returns (address) {
        require(pub.length == 64, "not pub");
        address signer = address(uint160(uint256(keccak256(pub))));
        // check signer exits
        require(signer != address(0) && signerToStorageMiner[signer] == 0, "Invalid signer");
        return signer;
    }

    function transferFunds(uint256 minerId, uint256 amount, address delegator) external override returns(bool) {
        require(storageMiners[minerId].contractAddress == msg.sender , "not allowed");
        (bool success,) = payable(address(uint160(delegator))).call{value : amount}("");
        require(success, "Failed to stake w3fs");
        return success;
    }


    function _insertSigner(address newSigner) internal {
        signers.push(newSigner);

        uint lastIndex = signers.length - 1;
        uint i = lastIndex;
        for (; i > 0; --i) {
            address signer = signers[i - 1];
            if (signer < newSigner) {
                break;
            }
            signers[i] = signer;
        }
        if (i != lastIndex) {
            signers[i] = newSigner;
        }
    }


    // ======================= update param ===========================
    function updateStorageMinerThreshold(uint256 newValue) public onlyGovernance {
        require(newValue != 0);
        logger.logThresholdChange(newValue, storageMinerThreshold);
        storageMinerThreshold = newValue;
    }

    function updateSpanDuration(uint256 newSpanDuration) public onlyGovernance {
        require(newSpanDuration >= 64 && newSpanDuration % 64 == 0, "spanDuration too low");
        SPAN_DURATION = newSpanDuration;
        // TODO event
    }

    function updateMinerReward(uint256 newReward) public onlyGovernance {
        require(newReward != 0);
        MINER_REWARD = newReward;
        // TODO event
    }

    function updateDelay(uint256 new_unstake_claim_delay, uint256 new_commission_update_delay) public onlyGovernance {
        require(new_unstake_claim_delay > 0 && new_commission_update_delay > 0, "delay too low");
        COMMISSION_UPDATE_DELAY = new_commission_update_delay;
        UNSTAKE_CLAIM_DELAY = new_unstake_claim_delay;
        // TODO event
    }

    // 管理员移除长期不活跃节点
    function forceUnstake(uint256 minerId) external onlyGovernance {
        uint256 currentEpoch = getCurrentEpoch(block.number);
        _unstake(minerId, currentEpoch.add(1));
    }


    // ======================= update param end ===========================


    function updateCommissionRate(uint256 minerId, uint256 newCommissionRate) external onlyStaker(minerId) {
        uint256 _epoch = getCurrentEpoch(block.number);
        uint256 _lastCommissionUpdate = storageMiners[minerId].lastCommissionUpdate;
        //最后一次修改的轮次
        // 修改比例
        require(_lastCommissionUpdate == 0 || (_lastCommissionUpdate.add(COMMISSION_UPDATE_DELAY) <= _epoch), "Cooldown");
        require(newCommissionRate <= 100, "Incorrect value");
        storageMiners[minerId].commissionRate = newCommissionRate;
        storageMiners[minerId].lastCommissionUpdate = _epoch;
    }


    // ======================================= 初始化相关 ==========================================
    function decodeMinerSetSynPackage(bytes memory msgBytes) internal pure returns (IbcMinerSetPackage memory, bool){
        IbcMinerSetPackage memory minerSetPkg;
        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                minerSetPkg.packageType = uint8(iter.next().toUint());
            } else if (idx == 1) {
                RLPDecode.RLPItem[] memory items = iter.next().toList();
                minerSetPkg.storageMinerMinSet = new StorageMinerMin[](items.length);
                for (uint j; j < items.length; j++) {
                    (StorageMinerMin memory val, bool ok) = decodeMiner(items[j]);
                    if (!ok) {
                        return (minerSetPkg, false);
                    }
                    minerSetPkg.storageMinerMinSet[j] = val;
                }
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (minerSetPkg, success);
    }


    function decodeMiner(RLPDecode.RLPItem memory itemMiner) internal pure returns (StorageMinerMin memory, bool) {
        StorageMinerMin memory minerMin;
        RLPDecode.Iterator memory iter = itemMiner.iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                minerMin.signer = iter.next().toAddress();
            } else if (idx == 1) {
                minerMin.amount = uint256(iter.next().toUint());
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (minerMin, success);
    }


    // ======================================= 初始化相关END ==========================================
    function getCurrentEpoch(uint256 number) public override view returns (uint256) {
        return number.div(SPAN_DURATION);
    }

    function getBorMiners() external override view returns (address[] memory, uint256[] memory) {
        // 当还没有任何一个质押时，通过系统默认矿工进行出块，保证链正常运行。
        if (inited) {
            uint256 minerLength = 0;
            for (uint i = 1; i <= NFTCounter - 1; i++) {
                StorageMiner memory miner = storageMiners[i];
                if (_isActiveMiner(miner.signer)) {
                    minerLength ++;
                }
            }
            address[] memory addrs = new address[](minerLength);
            uint256[] memory powers = new uint256[](minerLength);
            minerLength = 0;
            for (uint i = 1; i <= NFTCounter - 1; i++) {
                StorageMiner memory miner = storageMiners[i];
                if (_isActiveMiner(miner.signer)) {
                    addrs[minerLength] = miner.signer;
                    powers[minerLength] = miner.amount + miner.delegatedAmount;
                    minerLength++;
                }
            }
            return (addrs, powers);
        } else {
            // 系统初始矿工
            return getInitialValidators();
        }
    }


    function getInitialValidators() public override view returns (address[] memory, uint256[] memory) {
        (IbcMinerSetPackage memory minerSetPackage,) = decodeMinerSetSynPackage(INIT_MINERSET_BYTES);
        uint length = minerSetPackage.storageMinerMinSet.length;
        address[] memory addrs = new address[](length);
        uint256[] memory powers = new uint256[](length);
        for (uint i; i < length; i++) {
            addrs[i] = minerSetPackage.storageMinerMinSet[i].signer;
            powers[i] = minerSetPackage.storageMinerMinSet[i].amount;
        }
        return (addrs, powers);
    }


    function _isActiveMiner(address minerAddr) private view returns (bool) {
        uint256 minerId = signerToStorageMiner[minerAddr];
        if (minerId <= 0) {
            return false;
        }
        uint256 _currentEpoch = getCurrentEpoch(block.number);
        StorageMiner memory miner = storageMiners[minerId];
        return ((miner.activationEpoch == 0 || miner.activationEpoch < _currentEpoch) && miner.amount > 0 && (miner.deactivationEpoch == 0 || miner.deactivationEpoch > _currentEpoch) && miner.status == Status.Active);
    }

    function isActiveMiner(address minerAddr) external override view returns (bool) {
        return _isActiveMiner(minerAddr);
    }


    function getMinerBaseInfo(uint256 minerId) external view override returns (uint256, uint256, address, address, uint256, uint256) {
        return (
            storageMiners[minerId].amount,
            storageMiners[minerId].delegatedAmount,
            storageMiners[minerId].signer,
            storageMiners[minerId].contractAddress,
            storageMiners[minerId].reward.sub(INITIALIZED_AMOUNT),
            storageMiners[minerId].delegatorsReward.sub(INITIALIZED_AMOUNT)
        );
    }

    function getMinerId(address minerAddr) external view override returns (uint256) {
        return signerToStorageMiner[minerAddr];
    }

    function withdrawalDelay() public override view returns (uint256) {
        return UNSTAKE_CLAIM_DELAY;
    }

}
