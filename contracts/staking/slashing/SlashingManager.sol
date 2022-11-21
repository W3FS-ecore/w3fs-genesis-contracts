pragma solidity ^0.6.6;

import {Registry} from "../../common/misc/Registry.sol";
import {W3fsStakingInfo} from "../W3fsStakingInfo.sol";
import {OwnableExpand} from "../../common/utils/OwnableExpand.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IW3fsStakeManager} from "../stakeManager/IW3fsStakeManager.sol";
import {GovernanceLockable} from "../../common/gov/GovernanceLockable.sol";
import {IGovernance} from "../../common/gov/IGovernance.sol";

// solc --bin-runtime @openzeppelin/=node_modules/@openzeppelin/ /=/ contracts/staking/slashing/SlashingManager.sol
contract SlashingManager is GovernanceLockable, OwnableExpand {

    using SafeMath for uint256;

    bool private inited;
    uint256 private previousHeight;
    uint256 public PERCENTAGE_SLASH;
    uint256 public felonyThreshold;
    uint256 public jailThreshold;
    mapping(address => uint256) public slashMap;

    Registry public registry;
    W3fsStakingInfo public logger;
    IW3fsStakeManager stakeManager;

    struct Indicator {
        uint256 height;
        uint256 count;
        uint256 totalCount;
        uint256 jailCount;
        uint256 prevAmount;
        bool exist;
    }
    mapping(address => Indicator) public indicators;


    event SlashEvent(address indexed from , address indexed miner);

    modifier onlyStakeManager() {
        require(registry.getW3fsStakeManagerAddress() == msg.sender, "no allowed");
        _;
    }

    modifier onlyCoinbase() {
        require(msg.sender == block.coinbase, "the message sender must be the block producer");
        _;
    }

    modifier initializer() {
        require(!inited, "already inited");
        inited = true;
        _;
    }

    modifier oncePerBlock() {
        require(block.number > previousHeight, "can not slash twice in one block");
        _;
        previousHeight = block.number;
    }

    modifier onlyZeroGasPrice() {
        require(tx.gasprice == 0 , "gasprice is not zero");
        _;
    }

    constructor() public GovernanceLockable(address(0x0)) {
    }

    function initialize(address _registry, address _governance, address _w3fsStakingInfo) external initializer {
        felonyThreshold = 32;
        jailThreshold = 64;
        PERCENTAGE_SLASH = 1;
        registry = Registry(_registry);
        governance = IGovernance(_governance);
        logger = W3fsStakingInfo(_w3fsStakingInfo);
        stakeManager = IW3fsStakeManager(registry.getW3fsStakeManagerAddress());
        _transferOwnership(msg.sender);
    }

    function slash(address minerAddr) external onlyCoinbase oncePerBlock onlyZeroGasPrice {
        if (address(stakeManager) == address(0x0) || !stakeManager.isActiveMiner(minerAddr)) {
            return;
        }
        Indicator memory indicator = indicators[minerAddr];
        if (indicator.exist) {
            indicator.count++;
            indicator.jailCount++;
            indicator.totalCount++;
        } else {
            indicator.exist = true;
            indicator.count = 1;
            indicator.jailCount = 1;
            indicator.totalCount = 1;
        }
        indicator.height = block.number;
        bool doJail = false;
        if (indicator.jailCount % jailThreshold == 0) {
            doJail = true;
            indicator.jailCount = 0;
        }
        if( indicator.count % felonyThreshold == 0) {
            indicator.count = 0;
        }
        if (indicator.count == 0 || indicator.jailCount == 0) {
            uint256 minerId = stakeManager.getMinerId(minerAddr);
            (uint256 amount, , , , , ) = stakeManager.getMinerBaseInfo(minerId);
            uint256 slashAmount = indicator.prevAmount + amount.mul(PERCENTAGE_SLASH).div(100);
            stakeManager.slash(minerAddr, slashAmount, doJail);
            indicator.prevAmount = slashAmount;
        }
        indicators[minerAddr] = indicator;
    }

    function updatePercentageSlash(uint256 newPercentage) external onlyGovernance {
        require(newPercentage >= 1 , "newPercentage error");
        PERCENTAGE_SLASH = newPercentage;
    }

    function updateFelonyThreshold(uint256 newFelonyThreshold) external onlyGovernance {
        require(newFelonyThreshold > 0 , "felonyThreshold is zero");
        require(newFelonyThreshold <= jailThreshold , "felonyThreshold must low to jailThreshold");
        felonyThreshold = newFelonyThreshold;
    }

    function updateJailThreshold(uint256 newJailThreshold) external onlyGovernance {
        require(newJailThreshold > 0 , "newJailThreshold is zero");
        require(newJailThreshold >= felonyThreshold , "jailThreshold must high to felonyThreshold");
        jailThreshold = newJailThreshold;
    }
}
