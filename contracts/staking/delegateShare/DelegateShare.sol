pragma solidity ^0.6.6;

import {IDelegateShare} from "./IDelegateShare.sol";
import {OwnableLockable} from "../../common/utils/OwnableLockable.sol";
import {Initializable} from "../../common/utils/Initializable.sol";
import {IW3fsStakeManager} from "../stakeManager/IW3fsStakeManager.sol";
import {W3fsStakingInfo} from "../W3fsStakingInfo.sol";
import {ERC20NonTradable} from "./ERC20NonTradable.sol";
import {Registry} from "../../common/misc/Registry.sol";
import {IW3fsStorageManager} from "../../storage/IW3fsStorageManager.sol";

contract DelegateShare is IDelegateShare, ERC20NonTradable, OwnableLockable, Initializable {

    uint256 constant EXCHANGE_RATE_PRECISION = 100;
    uint256 constant REWARD_PRECISION = 10 ** 25;
    bool public delegation;
    uint256 public minerId;
    uint256 public minAmount;
    uint256 public activeAmount;
    uint256 public rewardPerShare;
    address public stakeManagerAdd;

    uint256 public withdrawPool;
    uint256 public withdrawShares;

    struct DelegatorUnbond {
        uint256 shares;
        uint256 withdrawEpoch;
    }

    IW3fsStakeManager public w3fsStakeManager;
    W3fsStakingInfo public w3fsStakingInfo;
    address public registry;
    IW3fsStorageManager public storageManager;

    mapping(address => uint256) public unbondNonces;
    mapping(address => mapping(uint256 => DelegatorUnbond)) public unbonds_new;
    mapping(address => uint256) public initalRewardPerShare;
    mapping(address => uint256) public liquidRewardsMap;

    modifier onlySystemReward(){
        require(Registry(registry).getSystemRewardAddress() == msg.sender, "on system contract");
        _;
    }


    function initialize(uint256 _minerId, address _stakingLogger, address _stakeManager, address _registry, address _storageManager) external initializer {
        minerId = _minerId;
        delegation = true;
        minAmount = 10**18;
        stakeManagerAdd = _stakeManager;
        w3fsStakeManager = IW3fsStakeManager(_stakeManager);
        w3fsStakingInfo = W3fsStakingInfo(_stakingLogger);
        registry = _registry;
        storageManager = IW3fsStorageManager(_storageManager);
        _transferOwnership(_stakeManager);
    }


    // ????????????
    function buyVoucher(uint256 _amount, uint256 _minSharesToMint) public payable {
        _withdrawAndTransferReward(msg.sender); //?????????????????????
        uint256 amountToDeposit = _buyShares(_amount, _minSharesToMint, msg.sender);
        require(_amount == msg.value, "activeAmount zero");
        (bool success,) = payable(stakeManagerAdd).call{value : _amount}("");
        require(success, "Failed to stake W3fs");
    }

    // ???????????????
    function _withdrawAndTransferReward(address user) private returns (uint256) {
        uint256 liquidRewards = _withdrawReward(user);  //??????????????????????????????
        if (liquidRewards != 0) {
            // ??????????????????????????????????????????????????????systemReward??????????????????????????????????????????????????????
            liquidRewardsMap[user] = liquidRewardsMap[user].add(liquidRewards);
        }
        return liquidRewards;
    }

    function _withdrawReward(address user) private returns (uint256) {
        uint256 _rewardPerShare = _calculateRewardPerShareWithRewards(
            // ?????????????????????DelegatorsReward??????????????????
            w3fsStakeManager.withdrawDelegatorsReward(minerId)
        );
        uint256 liquidRewards = _calculateReward(user, _rewardPerShare);
        rewardPerShare = _rewardPerShare;
        initalRewardPerShare[user] = _rewardPerShare;
        return liquidRewards;
    }

    // accumulatedReward ???????????????????????????
    function _calculateRewardPerShareWithRewards(uint256 accumulatedReward) private view returns (uint256) {
        uint256 _rewardPerShare = rewardPerShare;
        if (accumulatedReward != 0) {
            uint256 totalShares = totalSupply();
            if (totalShares != 0) {
                // _rewardPerShare +  [??????????????? * (10 ** 7) ] / ????????????
                _rewardPerShare = _rewardPerShare.add(accumulatedReward.mul(REWARD_PRECISION).div(totalShares));
            }
        }
        return _rewardPerShare;
    }


    // ??????????????????????????????
    function _calculateReward(address user, uint256 _rewardPerShare) private view returns (uint256) {
        uint256 shares = balanceOf(user);
        if (shares == 0) {
            return 0;
        }
        uint256 _initialRewardPerShare = initalRewardPerShare[user];
        if (_initialRewardPerShare == _rewardPerShare) {
            return 0;
        }
        return _rewardPerShare.sub(_initialRewardPerShare).mul(shares).div(REWARD_PRECISION);
    }


    function _buyShares(uint256 _amount, uint256 _minSharesToMint, address user) private onlyWhenUnlocked returns (uint256) {
        require(delegation, "Delegation is disabled");
        uint256 rate = exchangeRate();
        // totalShares == 0 ? precision : stakeManager.delegatedAmount(validatorId).mul(precision).div(totalShares)
        uint256 precision = _getRatePrecision();
        uint256 shares = _amount.mul(precision).div(rate);
        require(shares >= _minSharesToMint, "Too much slippage");
        // ????????????????????????rate????????????100%????????????shares??????
        _mint(user, shares);
        _amount = rate.mul(shares).div(precision);
        require(storageManager.checkCandelegatorsMore(minerId, _amount), "the miner no enough stake eligibility");
        // ???????????????????????????
        w3fsStakeManager.updateMinerState(minerId, int256(_amount));
        activeAmount = activeAmount.add(_amount);
        w3fsStakingInfo.logShareMinted(minerId, user, _amount, shares);
        w3fsStakingInfo.logStakeUpdate(minerId);
        return _amount;
    }

    // ?????????????????????
    function sellVoucher_new(uint256 claimAmount, uint256 maximumSharesToBurn) public {
        (uint256 shares, uint256 _withdrawPoolShare) = _sellVoucher(claimAmount, maximumSharesToBurn);
        uint256 unbondNonce = unbondNonces[msg.sender].add(1);
        uint256 cureentEpoch = getCurrentEpoch(block.number);
        // ???????????????????????????????????????????????????????????????
        DelegatorUnbond memory unbond = DelegatorUnbond({
            shares: _withdrawPoolShare,
            withdrawEpoch: cureentEpoch
        });
        unbonds_new[msg.sender][unbondNonce] = unbond;
        unbondNonces[msg.sender] = unbondNonce;
        // ???????????????
        w3fsStakingInfo.logStakeUpdate(minerId);
    }

    /**
        claimAmount ?????????????????????
    */
    function _sellVoucher(uint256 claimAmount, uint256 maximumSharesToBurn) private returns(uint256, uint256) {
        // ???????????????????????????
        (uint256 totalStaked, uint256 rate) = getTotalStake(msg.sender);
        require(totalStaked != 0 && totalStaked >= claimAmount, "Too much requested");
        uint256 precision = _getRatePrecision();
        uint256 shares = claimAmount.mul(precision).div(rate);
        require(shares <= maximumSharesToBurn, "too much slippage");
        _withdrawAndTransferReward(msg.sender); // ???????????????
        _burn(msg.sender, shares);  // ????????????????????????
        w3fsStakeManager.updateMinerState(minerId, -int256(claimAmount)); //?????????????????????????????????
        activeAmount = activeAmount.sub(claimAmount);
        uint256 _withdrawPoolShare = claimAmount.mul(precision).div(withdrawExchangeRate());
        withdrawPool = withdrawPool.add(claimAmount);
        withdrawShares = withdrawShares.add(_withdrawPoolShare);
        return (shares, _withdrawPoolShare);
    }


    // ??????????????????
    function unstakeClaimTokens_new(uint256 unbondNonce) public {
        DelegatorUnbond memory unbond = unbonds_new[msg.sender][unbondNonce];
        uint256 amount = _unstakeClaimTokens(unbond);
        delete unbonds_new[msg.sender][unbondNonce];
        w3fsStakingInfo.logDelegatorUnstakedWithId(minerId, msg.sender, amount, unbondNonce);
    }

    function _unstakeClaimTokens(DelegatorUnbond memory unbond) private returns(uint256) {
        uint256 shares = unbond.shares;
        // ???????????????????????????????????????
        uint256 currentEpoch = getCurrentEpoch(block.number);
        require(unbond.withdrawEpoch.add(w3fsStakeManager.withdrawalDelay()) <= currentEpoch && shares > 0 , "Incomplete withdrawal period");
        uint256 _amount = withdrawExchangeRate().mul(shares).div(_getRatePrecision());
        withdrawShares = withdrawShares.sub(shares);
        withdrawPool = withdrawPool.sub(_amount);
        // stakeManager.sol????????????????????????
        require(w3fsStakeManager.transferFunds(minerId, _amount, msg.sender), "Insufficent rewards");
        return _amount;
    }


    // ????????????
    function exchangeRate() public view returns (uint256) {
        uint256 totalShares = totalSupply();
        uint256 precision = _getRatePrecision();
        if (totalShares == 0) {
            return precision;
        } else {
            uint256 delegatedAmount;
            (, delegatedAmount, , , ,) = w3fsStakeManager.getMinerBaseInfo(minerId);
            // ????????? * 100 / ???????????????
            return delegatedAmount.mul(precision).div(totalShares);
        }
    }


    function getActiveAmount() external override view returns (uint256) {
        return activeAmount;
    }

    // ????????????????????? -- ??? systemReward.sol??????
    function withdrawRewards(address user) public onlySystemReward override returns(uint256){
        uint256 rewards = _withdrawAndTransferReward(user);
        require(rewards >= minAmount, "Too small rewards amount");
        uint256 backReward = liquidRewardsMap[user];
        liquidRewardsMap[user] = 0;
        return backReward;
    }


    function restake() public override returns (uint256, uint256) {
        address user =msg.sender;
        // ?????????????????????
        uint256 liquidReward = _withdrawReward(user);
        require(liquidReward >= minAmount, "Too small rewards to restake");
        // ?????????????????? + ???????????????????????? ???????????????????????????
        uint256 newAmountRestaked = liquidReward.add(liquidRewardsMap[user]);
        // ???????????????
        liquidRewardsMap[user] = 0;
        uint256 amountRestaked;
        if(newAmountRestaked != 0) {
            // ?????????????????????????????????
            amountRestaked = _buyShares(newAmountRestaked, 0, user);
            if(newAmountRestaked > amountRestaked) {
                // ??????????????????????????????
                liquidRewardsMap[user] = liquidRewardsMap[user].add(newAmountRestaked - amountRestaked);
                // TODO ???????????????????
            }
            (uint256 totalStaked, ) = getTotalStake(user);
            w3fsStakingInfo.logDelegatorRestaked(minerId, user, totalStaked);
        }
        return (amountRestaked, newAmountRestaked);
    }


    function getLiquidRewards(address user) public override view returns (uint256) {
        return _calculateReward(user, getRewardPerShare());
    }


    function unlockExpand() external override {
        super.unlock();
    }

    function lockExpand() external override {
        super.lock();
    }

    function drain(
        address token,
        address payable destination,
        uint256 amount
    ) external override onlyOwner {

    }

    // minerStake - miner stake amount
    // delegatedAmount - delegator stake amount
    // totalAmountToSlash - slash amount
    function slash(
        uint256 minerStake,
        uint256 delegatedAmount,
        uint256 totalAmountToSlash
    ) external override onlyOwner returns (uint256) {
        uint256 _withdrawPool = withdrawPool;
        uint256 delegationAmount = delegatedAmount.add(_withdrawPool);
        if (delegationAmount == 0) {
            return 0;
        }
        // amountToSlash = totalAmountToSlash * (delegationAmount / all stake amount)
        uint256 _amountToSlash = delegationAmount.mul(totalAmountToSlash).div(minerStake.add(delegationAmount));
        uint256 _amountToSlashWithdrawalPool = _withdrawPool.mul(_amountToSlash).div(delegationAmount);
        uint256 stakeSlashed = _amountToSlash.sub(_amountToSlashWithdrawalPool);
        w3fsStakeManager.decreaseMinerDelegatedAmount(minerId, stakeSlashed);
        withdrawPool = withdrawPool.sub(_amountToSlashWithdrawalPool);
        return _amountToSlash;
    }

    function updateDelegation(bool _delegation) external override onlyOwner {
        delegation = _delegation;
    }

    // ???????????????????????????????????????????????? ??????migrateIn?????????????????????
    function migrateOut(address user, uint256 amount) external override onlyOwner {
        _withdrawAndTransferReward(user);
        (uint256 totalStaked, uint256 rate) = getTotalStake(user);
        require(totalStaked >= amount, "Migrating too much");
        uint256 precision = _getRatePrecision();
        uint256 shares = amount.mul(precision).div(rate);   // ???????????????????????????
        _burn(user, shares);
        w3fsStakeManager.updateMinerState(minerId, -int256(amount));
        activeAmount = activeAmount.sub(amount);
        w3fsStakingInfo.logShareBurned(minerId, user, amount, shares);
        w3fsStakingInfo.logStakeUpdate(minerId);
        w3fsStakingInfo.logDelegatorUnstaked(minerId, user, amount);
    }

    function migrateIn(address user, uint256 amount) external override onlyOwner {
        _withdrawAndTransferReward(user);
        _buyShares(amount, 0, user);
    }

    function ownerExpand() external override view returns (address) {
        return super.owner();
    }

    function _getRatePrecision() private view returns (uint256) {
        return EXCHANGE_RATE_PRECISION;
    }

    function getRewardPerShare() public view returns (uint256) {
        (, , , , , uint256 delegatorsReward) = w3fsStakeManager.getMinerBaseInfo(minerId);
        return _calculateRewardPerShareWithRewards(delegatorsReward);
    }



    function getTotalStake(address user) public view returns (uint256, uint256) {
        uint256 shares = balanceOf(user);
        uint256 rate = exchangeRate();
        if(shares == 0) {
            return (0, rate);
        }
        return (rate.mul(shares).div(_getRatePrecision()), rate);
    }

    // ????????????
    function withdrawExchangeRate() public view returns(uint256){
        uint256 precision = _getRatePrecision();
        uint256 _withdrawShares = withdrawShares;
        return _withdrawShares == 0 ? precision : withdrawPool.mul(precision).div(_withdrawShares);
    }

    function getCurrentEpoch(uint256 number) public view returns (uint256) {
        return w3fsStakeManager.getCurrentEpoch(number);
    }

}


