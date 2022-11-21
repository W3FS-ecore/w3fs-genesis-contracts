pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import {IW3fsStorageManager} from "./IW3fsStorageManager.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {RLPReader} from "solidity-rlp/contracts/RLPReader.sol";
import {Registry} from "../common/misc/Registry.sol";
import {System} from "../System.sol";
import {GovernanceLockable} from "../common/gov/GovernanceLockable.sol";
import {IGovernance} from "../common/gov/IGovernance.sol";
import {OwnableExpand} from "../common/utils/OwnableExpand.sol";
import {IW3fsStakeManager} from "../staking/stakeManager/IW3fsStakeManager.sol";
import {ECVerify} from "../ECVerify.sol";
import {W3fsStakingInfo} from "../staking/W3fsStakingInfo.sol";
import {BorValidatorSet} from "../BorValidatorSet.sol";


// solc --bin-runtime @openzeppelin/=node_modules/@openzeppelin/ solidity-rlp/=node_modules/solidity-rlp/ /=/ contracts/storage/W3fsStorageManager.sol
contract W3fsStorageManager is IW3fsStorageManager, GovernanceLockable, OwnableExpand {
    using SafeMath for uint256;
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    uint256 internal constant KB_2 = 2;
    uint256 internal constant MB_8 = 8 * (10 ** 3);
    uint256 internal constant MB_512 = 512 * (10 ** 3);
    uint256 internal constant GB_32 = 32 * (10 ** 6);
    uint256 internal constant GB_64 = 64 * (10 ** 6);
    uint256 internal constant TB_1 = 1 * (10 ** 9);
    uint256 internal constant TB_10 = 10 * (10 ** 9);

    struct Vote {
        uint256 sectorInx;
        uint256 sealProofType;
        bytes sealedCID;
        bytes proof;
    }

    struct Sector {
        uint256 SealProofType;
        uint256 SectorNumber;
        uint256 TicketEpoch;
        uint256 SeedEpoch;
        bytes SealedCID;
        bytes UnsealedCID;
        bytes Proof;
        bool Check;
        bool isReal;
    }
    W3fsStakingInfo public logger;
    BorValidatorSet borValidatorSet;
    bool private inited = false;
    uint256 public stakeLimit;                                // min can stake
    uint256 public factor;
    uint256 public delegatedStakeLimit;
    uint256 public percentage;
    uint256 public baseStakeAmount;                           // base stake amount
    uint256 public totalPower;
    mapping(address => uint256) public validatorNonce;
    mapping(address => uint256) public validatorPowers;        // Current miner computing power
    mapping(address => uint256) public validatorStorageSize;  // Current miner computing storage size
    mapping(address => uint256) public validatorPromise;      // current miner computing promise size
    //mapping(address => Vote[]) public validatorVotes;                    // address sealing vote
    mapping(address => mapping(uint256 => Sector)) public validatorSector;
    mapping(address => uint256[]) randSeadMap;                           // rand sead
    mapping(address => uint256[]) realSeadMap;                           // real sead
    address public registry;

    event UpdatePromise(address indexed signer, uint256 indexed storageSize);
    event AddNewSealPowerAndSize(uint256 indexed newPower, uint256 indexed newStorageSize, address indexed signer, uint256 nonce);

    modifier onlyStakeManagerOrOwner() {
        require(msg.sender == owner() || Registry(registry).getW3fsStakeManagerAddress() == msg.sender);
        _;
    }

    modifier onlyMiner(address signer) {
        require(IW3fsStakeManager(Registry(registry).getW3fsStakeManagerAddress()).isActiveMiner(signer), "on miner");
        _;
    }

    modifier initializer() {
        require(!inited, "already inited");
        inited = true;
        _;
    }

    constructor() public GovernanceLockable(address(0x0)) {
    }

    function initialize(address _owner, address _registry, address _governance, address _stakingLogger) external initializer {
        stakeLimit = 20000 * (10 ** 18);
        delegatedStakeLimit = 50000 * (10 ** 18);
        percentage = 5;
        factor = 7;
        baseStakeAmount = 2000 * (10 ** 18);
        registry = _registry;
        governance = IGovernance(_governance);
        _transferOwnership(_owner);
        logger = W3fsStakingInfo(_stakingLogger);
        borValidatorSet = BorValidatorSet(0x0000000000000000000000000000000000001000);
    }


    function checkCanStakeMore(address validatorAddr, uint256 amount, uint256 addStakeMount) external override view returns (bool) {
        if (amount + addStakeMount > stakeLimit) {
            uint256 canStakeAmountLimit = showCanStakeAmount(validatorAddr);
            if (amount + addStakeMount <= canStakeAmountLimit + stakeLimit) {
                return true;
            }
            return false;
        } else {
            return true;
        }
    }


    function checkCandelegatorsMore(uint256 minerId, uint256 addStakeMount) external override view returns (bool) {
        (, uint256 delegatedAmount, address validatorAddr, , ,) = IW3fsStakeManager(Registry(registry).getW3fsStakeManagerAddress()).getMinerBaseInfo(minerId);
        if (delegatedAmount + addStakeMount > delegatedStakeLimit) {
            uint256 canStakeAmountLimit = showCanStakeAmount(validatorAddr);
            canStakeAmountLimit = canStakeAmountLimit.mul(factor);
            if (delegatedAmount + addStakeMount <= canStakeAmountLimit + delegatedStakeLimit) {
                return true;
            }
            return false;
        } else {
            return true;
        }
    }


    function showCanStakeAmount(address validatorAddr) public override view returns (uint256) {
        uint256 basePloidy = 1;
        uint256 resultAmount = baseStakeAmount;
        uint256 promiseStorage = validatorPromise[validatorAddr];
        uint realStorage = validatorStorageSize[validatorAddr];
        if (promiseStorage < 0 || realStorage < 0) {
            return 0;
        }
        if (!checkEnoughStorage(validatorAddr)) {
            return 0;
        }
        if (realStorage >= TB_1) {
            basePloidy = 7 + realStorage.div(TB_10);
        } else if (realStorage >= GB_32) {
            basePloidy = 4;
        } else if (realStorage >= MB_512) {
            basePloidy = 2;
        } else {
            basePloidy = 1;
        }
        resultAmount = basePloidy.mul(baseStakeAmount);
        return resultAmount;
    }


    function checkEnoughStorage(address validatorAddr) private view returns (bool) {
        uint256 promiseStorage = validatorPromise[validatorAddr];
        uint256 realStorage = validatorStorageSize[validatorAddr];
        uint256 p_temp = promiseStorage.mul(percentage);
        uint256 r_temp = realStorage.mul(100);
        return r_temp >= p_temp ? true : false;
    }


    function updateStoragePromise(address signer, uint256 storageSize) external override onlyStakeManagerOrOwner {
        validatorPromise[signer] = storageSize;
        emit UpdatePromise(signer, storageSize);
    }


    function updateStakeLimit(uint256 newStakeLimit) external override onlyGovernance {
        require(newStakeLimit >= 1000 * (10 ** 18));
        stakeLimit = newStakeLimit;
    }

    function updateDelegatedStakeLimit(uint256 newDelegatedStakeLimit) external override onlyGovernance {
        require(newDelegatedStakeLimit >= 1000 * (10 ** 18));
        delegatedStakeLimit = newDelegatedStakeLimit;
    }

    function updatePercentage(uint256 newPercentage) external override onlyGovernance {
        require(newPercentage > 0, "newPercentage is wrong");
        percentage = newPercentage;
    }

    function getSealInfo(address signer, uint256 sectorNumber) public view returns (Sector memory) {
        return validatorSector[signer][sectorNumber];
    }



    function getSealInfoAllBySigner(address signer, bool isCheck) public view returns (Sector[] memory) {
        uint256 realSize = realSeadMap[signer].length;
        uint256 randSize = randSeadMap[signer].length;
        uint256 count = 0;
        if (realSize > 0) {
            for (uint256 i = 0; i < realSize; i++) {
                if(isCheck) {
                    if (validatorSector[signer][realSeadMap[signer][i]].Check == true) {
                        count++;
                    }
                }else {
                    count++;
                }
            }
        }
        if (randSize > 0) {
            for (uint256 i = 0; i < randSize; i++) {
                if (isCheck) {
                    if (validatorSector[signer][randSeadMap[signer][i]].Check == true) {
                        count++;
                    }
                }else {
                    count++;
                }
            }
        }
        Sector[] memory sectors = new Sector[](count);
        count = 0;
        if (realSize > 0) {
            for (uint256 i = 0; i < realSize; i++) {
                if(isCheck) {
                    if(validatorSector[signer][realSeadMap[signer][i]].Check == true) {
                        sectors[count] = validatorSector[signer][realSeadMap[signer][i]];
                        count = count + 1;
                    }
                }else {
                    sectors[count] = validatorSector[signer][realSeadMap[signer][i]];
                    count = count + 1;
                }
            }
        }
        if (randSize > 0) {
            for (uint256 i = 0; i < randSize; i++) {
                if(isCheck) {
                    if (validatorSector[signer][randSeadMap[signer][i]].Check == true) {
                        sectors[count] = validatorSector[signer][randSeadMap[signer][i]];
                        count = count + 1;
                    }
                }else {
                    sectors[count] = validatorSector[signer][randSeadMap[signer][i]];
                    count = count + 1;
                }
            }
        }
        return sectors;
    }

    function addSealInfo(bool isReal, address signer, bytes calldata votes) external onlyMiner(signer) {
        require(signer == msg.sender, "signer is wrong");
        RLPReader.RLPItem[] memory votesItems = votes.toRlpItem().toList();
        require(votesItems.length == 1, "length is wrong");
        for (uint256 i = 0; i < votesItems.length ; i++) {
            RLPReader.RLPItem[] memory v = votesItems[i].toList();
            require(validatorSector[signer][v[1].toUint()].SealProofType == 0 , "already exists");
            validatorSector[signer][v[1].toUint()] = Sector({
                SealProofType : v[0].toUint(),
                SectorNumber : v[1].toUint(),
                TicketEpoch : v[2].toUint(),
                SeedEpoch : v[3].toUint(),
                SealedCID : v[4].toBytes(),
                UnsealedCID : v[5].toBytes(),
                Proof : v[6].toBytes(),
                Check : false,
                isReal : isReal ? true : false
            });
            if (isReal) {
                realSeadMap[signer].push(v[1].toUint());
            } else {
                randSeadMap[signer].push(v[1].toUint());
            }
            validatorNonce[signer] = validatorNonce[signer].add(1);
            //validatorPowers[signer] = validatorPowers[signer].add(2000);
            //emit AddSector(signer, v[0].toUint(), v[1].toUint(), v[2].toUint(), v[3].toUint(), v[4].toBytes(), v[5].toBytes(), v[6].toBytes());
            logger.logAddSector(signer, v[0].toUint(), v[1].toUint(), v[2].toUint(), v[3].toUint(), v[4].toBytes(), v[5].toBytes(), v[6].toBytes());
        }
    }

    function checkSealSigs(bytes calldata data, uint[3][] calldata sigs) external override {
        uint256 _totalPower;
        uint256 _sigPower;
        (address signer, uint256 sealProofType, uint256 sectorNumber, uint256 blockNumber) = abi.decode(data, (address, uint256, uint256, uint256));
        /**
                prefix 01 to data
                01 represents positive vote on data and 00 is negative vote
                malicious validator can try to send 2/3 on negative vote so 01 is appended
        */
        bytes32 voteHash = keccak256(abi.encodePacked(bytes(hex"01"), data));
        (address[] memory validators, uint256[] memory powers) = borValidatorSet.getBorValidators(blockNumber);
        for (uint256 i = 0 ; i < powers.length ; ++i) {
            _totalPower = _totalPower.add(powers[i]);
        }
        for (uint256 i = 0; i < sigs.length; ++i) {
            address _signer = ECVerify.ecrecovery2(voteHash, sigs[i]);
            for(uint256 j = 0 ; j < validators.length ; ++j) {
                if(_signer == validators[j]) {
                    _sigPower = _sigPower.add(powers[j]);
                    break;
                }
            }
        }
        require(_sigPower >= _totalPower.mul(2).div(3), "2/3+1 Power required");
        Sector storage sector = validatorSector[signer][sectorNumber];
        if (sector.Check == false && sector.SealProofType == sealProofType && bytes(sector.Proof).length > 0) {
            // add power
            (uint256 newPower, uint256 storageSize) = getPowerByProofType(sealProofType);
            validatorPowers[signer] = validatorPowers[signer].add(newPower);
            validatorStorageSize[signer] = validatorStorageSize[signer].add(storageSize);
            totalPower = totalPower.add(newPower);
            sector.Check = true;
            // TODO save event log ...
        }
    }


    function _removeRealSeadMap(address signer, uint256 sectorNumberToDel) internal {
        uint256[] storage sectorNumbers = realSeadMap[signer];
        uint256 totalSigners = sectorNumbers.length;
        uint256 swapSectorNumber = sectorNumbers[totalSigners - 1];
        sectorNumbers.pop();
        for (uint256 i = totalSigners - 1; i > 0; --i) {
            if (swapSectorNumber == sectorNumberToDel) {
                break;
            }
            (swapSectorNumber, sectorNumbers[i - 1]) = (sectorNumbers[i - 1], swapSectorNumber);
        }
    }

    function _removeRandSeadMap(address signer, uint256 sectorNumberToDel) internal {
        uint256[] storage sectorNumbers = randSeadMap[signer];
        uint256 totalSigners = sectorNumbers.length;
        uint256 swapSectorNumber = sectorNumbers[totalSigners - 1];
        sectorNumbers.pop();
        for (uint256 i = totalSigners - 1; i > 0; --i) {
            if (swapSectorNumber == sectorNumberToDel) {
                break;
            }
            (swapSectorNumber, sectorNumbers[i - 1]) = (sectorNumbers[i - 1], swapSectorNumber);
        }
    }


    // get power by sealProofType
    function getPowerByProofType(uint256 sealProofType) private pure returns (uint256, uint256) {
        uint256 power;
        uint256 size;
        if (sealProofType == 0 || sealProofType == 5) {
            // 2KiB - 1024
            //sealSize = 2 ** 10;
            power = 1000;
            size = 2;
        } else if (sealProofType == 1 || sealProofType == 6) {
            // 8MiB - 8388608
            //sealSize = 8 * 2 ** 20;
            power = 5000;
            size = 8 * 1000;
        } else if (sealProofType == 2 || sealProofType == 7) {
            // 512MiB - 536870912
            //sealSize = 512 * 2 ** 20;
            power = 10000;
            size = 512 * 1000;
        } else if (sealProofType == 3 || sealProofType == 8) {
            // 32GiB - 34359738368
            //sealSize = 32 * 2 ** 30;
            power = 30000;
            size = 32 * 1000 * 1000;
        } else if (sealProofType == 4 || sealProofType == 9) {
            // 64GiB
            power = 40000;
            size = 64 * 1000 * 1000;
        }
        return (power, size);
    }

    function getValidatorPower(address signer) external override view returns (uint256) {
        return validatorPowers[signer];
    }

    function getAllValidatorPower(bytes memory validatorBytes) public view returns (address[] memory, uint256[] memory) {
        RLPReader.RLPItem[] memory validatorItems = validatorBytes.toRlpItem().toList();
        address[] memory addrs = new address[](validatorItems.length);
        uint256[] memory powers = new uint256[](validatorItems.length);
        for (uint256 i = 0; i < validatorItems.length; i++) {
            RLPReader.RLPItem[] memory v = validatorItems[i].toList();
            addrs[i] = v[0].toAddress();
            powers[i] = validatorPowers[v[0].toAddress()];
        }
        return (addrs, powers);
    }

}
