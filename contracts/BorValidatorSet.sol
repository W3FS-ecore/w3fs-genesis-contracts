pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { RLPReader } from "solidity-rlp/contracts/RLPReader.sol";

import { BytesLib } from "./BytesLib.sol";
import { System } from "./System.sol";
import { ECVerify } from "./ECVerify.sol";
import { ValidatorSet } from "./ValidatorSet.sol";

contract BorValidatorSet is System {
  using SafeMath for uint256;
  using RLPReader for bytes;
  using RLPReader for RLPReader.RLPItem;
  using ECVerify for bytes32;

  bytes32 public constant CHAIN = keccak256("heimdall-15001");
  bytes32 public constant ROUND_TYPE = keccak256("vote");
  bytes32 public constant BOR_ID = keccak256("15001");
  uint8 public constant VOTE_TYPE = 2;
  uint256 public constant FIRST_END_BLOCK = 255;
  uint256 public constant SPRINT = 64;
  bytes32 internal accountRootHash;

  struct Validator {
    uint256 id;
    uint256 power;
    address signer;
  }

  // span details
  struct Span {
    uint256 number;
    uint256 startBlock;
    uint256 endBlock;
  }

  mapping(uint256 => Validator[]) public validators;
  mapping(uint256 => Validator[]) public producers;

  mapping (uint256 => Span) public spans; // span number => span
  uint256[] public spanNumbers; // recent span numbers

  // event
  event NewSpan(uint256 indexed id, uint256 indexed startBlock, uint256 indexed endBlock);

  constructor() public {}

  modifier onlyValidator() {
    uint256 span = currentSpanNumber();
    require(isValidator(span, msg.sender));
    _;
  }

  function setInitialValidators() internal {
    address[] memory d;
    uint256[] memory p;

    (d, p) = getInitialValidators();

    uint256 span = 0;
    spans[span] = Span({
      number: span,
      startBlock: 0,
      endBlock: FIRST_END_BLOCK
    });
    spanNumbers.push(span);

    for (uint256 i = 0; i < d.length; i++) {

      validators[span].push(Validator({
        id: i,
        power: p[i],
        signer: d[i]
      }));
    }

    for (uint256 i = 0; i < d.length; i++) {

      producers[span].push(Validator({
        id: i,
        power: p[i],
        signer: d[i]
      }));
    }
  }

  function currentSprint() public view returns (uint256) {
    return block.number / SPRINT;
  }

  function getSpan(uint256 span) public view returns (uint256 number, uint256 startBlock, uint256 endBlock) {
    return (spans[span].number, spans[span].startBlock, spans[span].endBlock);
  }

  function getCurrentSpan() public view returns (uint256 number, uint256 startBlock, uint256 endBlock) {
    uint256 span = currentSpanNumber();
    return (spans[span].number, spans[span].startBlock, spans[span].endBlock);
  }

  function getNextSpan() public view returns (uint256 number, uint256 startBlock, uint256 endBlock) {
    uint256 span = currentSpanNumber().add(1);
    return (spans[span].number, spans[span].startBlock, spans[span].endBlock);
  }

  function getValidatorsBySpan(uint256 span) internal view returns (Validator[] memory) {
    return validators[span];
  }

  function getProducersBySpan(uint256 span) internal view returns (Validator[] memory) {
    return producers[span];
  }

  // get span number by block
  function getSpanByBlock(uint256 number) public view returns (uint256) {
    for (uint256 i = spanNumbers.length; i > 0; i--) {
      Span memory span = spans[spanNumbers[i - 1]];
      if (span.startBlock <= number && span.endBlock != 0 && number <= span.endBlock) {
        return span.number;
      }
    }
    if (spanNumbers.length > 0) {
      return spanNumbers[spanNumbers.length - 1];
    }
    return 0;
  }

  function currentSpanNumber() public view returns (uint256) {
    return getSpanByBlock(block.number);
  }

  function getValidatorsTotalStakeBySpan(uint256 span) public view returns (uint256) {
    Validator[] memory vals = validators[span];
    uint256 result = 0;
    for (uint256 i = 0; i < vals.length; i++) {
      result = result.add(vals[i].power);
    }
    return result;
  }

  function getProducersTotalStakeBySpan(uint256 span) public view returns (uint256) {
    Validator[] memory vals = producers[span];
    uint256 result = 0;
    for (uint256 i = 0; i < vals.length; i++) {
      result = result.add(vals[i].power);
    }
    return result;
  }

  function getValidatorBySigner(uint256 span, address signer) public view returns (Validator memory result) {
    Validator[] memory vals = validators[span];
    for (uint256 i = 0; i < vals.length; i++) {
      if (vals[i].signer == signer) {
        result = vals[i];
        break;
      }
    }
  }

  function isValidator(uint256 span, address signer) public view returns (bool) {
    Validator[] memory vals = validators[span];
    for (uint256 i = 0; i < vals.length; i++) {
      if (vals[i].signer == signer) {
        return true;
      }
    }
    return false;
  }

  function isProducer(uint256 span, address signer) public view returns (bool) {
    Validator[] memory vals = producers[span];
    for (uint256 i = 0; i < vals.length; i++) {
      if (vals[i].signer == signer) {
        return true;
      }
    }
    return false;
  }

  function isCurrentValidator(address signer) public view returns (bool) {
    return isValidator(currentSpanNumber(), signer);
  }

  function isCurrentProducer(address signer) public view returns (bool) {
    return isProducer(currentSpanNumber(), signer);
  }


  // get bor validator
  function getBorValidators(uint256 number) public view returns (address[] memory, uint256[] memory) {
    if (number <= FIRST_END_BLOCK) {
      return getInitialValidators();
    }

    // span number by block
    uint256 span = getSpanByBlock(number);

    address[] memory addrs = new address[](producers[span].length);
    uint256[] memory powers = new uint256[](producers[span].length);
    for (uint256 i = 0; i < producers[span].length; i++) {
      addrs[i] = producers[span][i].signer;
      powers[i] = producers[span][i].power;
    }

    return (addrs, powers);
  }

  /// Get current validator set (last enacted or initial if no changes ever made) with current stake.
  function getInitialValidators() public pure returns (address[] memory, uint256[] memory) {
    address[] memory addrs = new address[](2);
    addrs[0] = 0xb4551baB04854a09b93492bb61b1B011a82cC27A;
    addrs[1] = 0xCd372b7D1e5c9892d5d545e4b02521AC096F9456;
    uint256[] memory powers = new uint256[](2);
    powers[0] = 10000;
    powers[1] = 1000;
    return (addrs, powers);
  }

  /// Get current validator set (last enacted or initial if no changes ever made) with current stake.
  function getValidators() public view returns (address[] memory, uint256[] memory) {
    return getBorValidators(block.number);
  }

  function commitSpan(
    uint256 newSpan,
    uint256 startBlock,
    uint256 endBlock,
    bytes calldata validatorBytes,
    bytes calldata producerBytes,
    bytes32 stateRootHash
  ) external onlySystem {
    // current span
    uint256 span = currentSpanNumber();
    // set initial validators if current span is zero
    if (span == 0) {
      setInitialValidators();
    }

    // check conditions
    require(newSpan == span.add(1), "Invalid span id");
    require(endBlock > startBlock, "End block must be greater than start block");
    require((endBlock - startBlock + 1) % SPRINT == 0, "Difference between start and end block must be in multiples of sprint");
    require(spans[span].startBlock <= startBlock, "Start block must be greater than current span");

    // check if already in the span
    require(spans[newSpan].number == 0, "Span already exists");

    // store span
    spans[newSpan] = Span({
      number: newSpan,
      startBlock: startBlock,
      endBlock: endBlock
    });
    spanNumbers.push(newSpan);
    // set validators
    RLPReader.RLPItem[] memory validatorItems = validatorBytes.toRlpItem().toList();
    for (uint256 i = 0; i < validatorItems.length; i++) {
      RLPReader.RLPItem[] memory v = validatorItems[i].toList();
      validators[newSpan].push(Validator({
        id: v[0].toUint(),
        power: v[1].toUint(),
        signer: v[2].toAddress()
      }));
    }
    // set producers
    RLPReader.RLPItem[] memory producerItems = producerBytes.toRlpItem().toList();
    for (uint256 i = 0; i < producerItems.length; i++) {
      RLPReader.RLPItem[] memory v = producerItems[i].toList();
        producers[newSpan].push(Validator({
          id: v[0].toUint(),
          power: v[1].toUint(),
          signer: v[2].toAddress()
        }));
    }
    accountRootHash = stateRootHash;
  }

  function updateAccountRootHash(bytes32 stateRootHash) public {
    accountRootHash = stateRootHash;
  }

  // Get stake power by sigs and data hash
  function getStakePowerBySigs(uint256 span, bytes32 dataHash, bytes memory sigs) public view returns (uint256) {
    uint256 stakePower = 0;
    address lastAdd = address(0x0); // cannot have address(0x0) as an owner

    for (uint64 i = 0; i < sigs.length; i += 65) {
      bytes memory sigElement = BytesLib.slice(sigs, i, 65);
      address signer = dataHash.ecrecovery(sigElement);

      // check if signer is stacker and not proposer
      Validator memory validator = getValidatorBySigner(span, signer);
      if (isValidator(span, signer) && signer > lastAdd) {
        lastAdd = signer;
        stakePower = stakePower.add(validator.power);
      }
    }

    return stakePower;
  }

  function getAccountRootHash() public view returns (bytes32) {
      return accountRootHash;
  }


  function checkMembership(
    bytes32 rootHash,
    bytes32 leaf,
    bytes memory proof
  ) public pure returns (bool) {
    bytes32 proofElement;
    byte direction;
    bytes32 computedHash = leaf;

    uint256 len = (proof.length / 33) * 33;
    if (len > 0) {
      computedHash = leafNode(leaf);
    }

    for (uint256 i = 33; i <= len; i += 33) {
      bytes32 tempBytes;
      assembly {
        tempBytes := mload(add(proof, sub(i, 1)))
        proofElement := mload(add(proof, i))
      }

      direction = tempBytes[0];
      if (direction == 0) {
        computedHash = innerNode(proofElement, computedHash);
      } else {
        computedHash = innerNode(computedHash, proofElement);
      }
    }

    return computedHash == rootHash;
  }

  function leafNode(bytes32 d) public pure returns (bytes32) {
    return sha256(abi.encodePacked(byte(uint8(0)), d));
  }

  function innerNode(bytes32 left, bytes32 right) public pure returns (bytes32) {
    return sha256(abi.encodePacked(byte(uint8(1)), left, right));
  }
}
