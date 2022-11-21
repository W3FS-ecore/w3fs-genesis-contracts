pragma solidity ^0.6.6;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {OwnableExpand} from "../common/utils/OwnableExpand.sol";
import {Registry} from "../common/misc/Registry.sol";
import {IW3fsStakeManager} from "./stakeManager/IW3fsStakeManager.sol";
import {IDelegateShare} from "./delegateShare/IDelegateShare.sol";

// solc --bin-runtime @openzeppelin/=node_modules/@openzeppelin/ /=/ contracts/staking/W3fsStakingInfo.sol
contract W3fsStakingInfo is OwnableExpand {
    using SafeMath for uint256;
    mapping(uint256 => uint256) public minerNonce;
    bool private inited = false;
    Registry public registry;

    event Staked(
        address indexed signer,
        uint256 indexed validatorId,
        uint256 nonce,
        uint256 indexed activationEpoch,
        uint256 amount,
        uint256 total,
        bytes signerPubkey
    );

    event StakeUpdate(
        uint256 indexed minerId,
        uint256 indexed nonce,
        uint256 indexed newAmount
    );

    event ShareMinted(
        uint256 indexed validatorId,
        address indexed user,
        uint256 indexed amount,
        uint256 tokens
    );


    event DelegatorClaimedRewards(
        uint256 indexed minerId,
        address indexed user,
        uint256 indexed rewards
    );

    event DelegatorRestaked(
        uint256 indexed minerId,
        address indexed user,
        uint256 indexed totalStaked
    );

    event DelegatorUnstakeWithId(
        uint256 indexed minerId,
        address indexed user,
        uint256 amount,
        uint256 nonce
    );

    event ShareBurned(
        uint256 indexed minerId,
        address indexed user,
        uint256 indexed amount,
        uint256 tokens
    );

    event DelegatorUnstaked(
        uint256 indexed minerId,
        address indexed user,
        uint256 amount
    );

    event AddSector(
        address indexed signer,
        uint256 SealProofType, uint256 SectorNumber,
        uint256 TicketEpoch,
        uint256 SeedEpoch,
        bytes SealedCID,
        bytes UnsealedCID,
        bytes Proof
    );

    event UnJailed(uint256 indexed minerId, address indexed signer);
    event Jailed(uint256 indexed minerId, uint256 indexed exitEpoch, address indexed signer);
    event Restaked(uint256 indexed minerId, uint256 amount, uint256 total);
    event ReceiverReward(uint256 indexed blockNumber, address indexed minerAddr, uint256 reward, uint256 delegatorsReward);
    event ThresholdChange(uint256 newThreshold, uint256 oldThreshold);
    event TopUpFee(address indexed user, uint256 indexed fee);

    modifier initializer() {
        require(!inited, "already inited");
        inited = true;
        _;
    }


    constructor() public {}

    function initialize(address _registry) external initializer {
        registry = Registry(_registry);
    }


    modifier onlyStakeManager() {
        require(registry.getW3fsStakeManagerAddress() == msg.sender, "Invalid sender, not stake manager");
        _;
    }

    modifier onlyStakeManagerOrMinerContract(uint256 minerId){
        address _contract;
        address _stakeManager = registry.getW3fsStakeManagerAddress();
        ( , , , _contract, , ) = IW3fsStakeManager(_stakeManager).getMinerBaseInfo(minerId);
        require(_stakeManager == msg.sender || _contract == msg.sender, "Invalid sender, not stake manager or validator contract");
        _;
    }

    modifier onlyMinerContract(uint256 minerId) {
        address _stakeManager = registry.getW3fsStakeManagerAddress();
        ( , , , address _contract, , ) = IW3fsStakeManager(_stakeManager).getMinerBaseInfo(minerId);
        require(_contract == msg.sender, "Invalid sender, not validator");
        _;
    }


    function logThresholdChange(uint256 newThreshold, uint256 oldThreshold) public onlyStakeManager {
        emit ThresholdChange(newThreshold, oldThreshold);
    }

    // staked event
    function logStaked(
        address signer,
        bytes memory signerPubkey,
        uint256 minerId,
        uint256 activationEpoch,
        uint256 amount,
        uint256 total
    ) public onlyStakeManager {
        minerNonce[minerId] = minerNonce[minerId].add(1);
        emit Staked(
            signer,
            minerId,
            minerNonce[minerId],
            activationEpoch,
            amount,
            total,
            signerPubkey
        );
    }

    function logStakeUpdate(uint256 minerId) public onlyStakeManagerOrMinerContract(minerId) {
        minerNonce[minerId] = minerNonce[minerId].add(1);
        emit StakeUpdate(
            minerId,
            minerNonce[minerId],
            totalValidatorStake(minerId)
        );
    }

    function totalValidatorStake(uint256 minerId) public view returns (uint256 validatorStake) {
        address contractAddress;
        (validatorStake, , , contractAddress,,) = IW3fsStakeManager(registry.getW3fsStakeManagerAddress()).getMinerBaseInfo(minerId);
        if (contractAddress != address(0x0)) {
            validatorStake += IDelegateShare(contractAddress).getActiveAmount();
        }
    }

    function logRestaked(uint256 validatorId, uint256 amount, uint256 total) public onlyStakeManager {
        emit Restaked(validatorId, amount, total);
    }

    function logJailed(uint256 minerId, uint256 exitEpoch, address signer) public onlyStakeManager{
        emit Jailed(minerId, exitEpoch, signer);
    }

    function logUnjailed(uint256 minerId, address signer) public onlyStakeManager {
        emit UnJailed(minerId, signer);
    }

    function logShareMinted(
        uint256 validatorId,
        address user,
        uint256 amount,
        uint256 tokens
    ) public onlyMinerContract(validatorId) {
        emit ShareMinted(validatorId, user, amount, tokens);
    }

    function logDelegatorClaimRewards(uint256 minerId, address user, uint256 rewards) public onlyMinerContract(minerId) {
        emit DelegatorClaimedRewards(minerId, user, rewards);
    }

    function logDelegatorRestaked(uint256 minerId, address user, uint256 totalStaked) public onlyMinerContract(minerId){
        emit DelegatorRestaked(minerId, user, totalStaked);
    }

    function logDelegatorUnstakedWithId(
        uint256 minerId,
        address user,
        uint256 amount,
        uint256 nonce
    ) public onlyMinerContract(minerId) {
        emit DelegatorUnstakeWithId(minerId, user, amount, nonce);
    }

    function logShareBurned(
        uint256 minerId,
        address user,
        uint256 amount,
        uint256 tokens
    ) public onlyMinerContract(minerId) {
        emit ShareBurned(minerId, user, amount, tokens);
    }

    function logDelegatorUnstaked(uint256 minerId, address user, uint256 amount) public onlyMinerContract(minerId)
    {
        emit DelegatorUnstaked(minerId, user, amount);
    }

    function logTopUpFee(address user, uint256 fee) public onlyStakeManager {
        emit TopUpFee(user, fee);
    }

    function logAddSector(address signer, uint256 SealProofType, uint256 SectorNumber, uint256 TicketEpoch, uint256 SeedEpoch, bytes memory SealedCID, bytes memory UnsealedCID, bytes memory Proof) public {
        emit AddSector(signer, SealProofType, SectorNumber, TicketEpoch, SeedEpoch, SealedCID, UnsealedCID, Proof);
    }

}
