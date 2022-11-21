pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";
//import {Registry} from "../misc/Registry.sol";

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 *
 * Upgradeability is only provided internally through {_upgradeTo}. For an externally upgradeable proxy see
 * {TransparentUpgradeableProxy}.
 */
contract UpgradesAvailableProxy is Proxy {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
     * function call, and allows initializating the storage of the proxy like a Solidity constructor.
     */
    /*constructor(address _logic, bytes memory _data) public payable {
        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
        _setImplementation(_logic);
        if(_data.length > 0) {
            Address.functionDelegateCall(_logic, _data);
        }
    }*/

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    constructor() public {

    }

    function initialize(address addr) public {
        bool isInitialized = _getInitialized();
        require(!isInitialized, "The contract is already initialized");
        _setIsInitialized(true);
        _setOwner(addr);
    }



    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    modifier onlyProxyOwner() {
        //Registry _registry = Registry(address(0x0000000000000000000000000000000000003000));
        //require(_registry.isAdmin(msg.sender), "NOT_ADMIN");
        require(_getOwner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }



    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);
    event UpgradedIsInitialized(bool indexed initialized);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // This is the keccak-256 hash of "eip1967.proxy.implementation.isInitialized"
    bytes32 private constant _ISINITIALIZED_SLOT = 0x2da5462cfc5aefc74791833662ba61cd4cfeda3e1851cce5159de5f968d9d64d;
    // This is the keccak-256 hash of "eip1967.proxy.implementation.owner"
    bytes32 private constant _OWNER_SLOT = 0xb2011649e23991fd5b1fbd5b12a4d17f46b2c6148cce69f6f1b3a24fef79a94b;


    function updateAndCall(
        address newImplementation,
        bytes memory data
    ) public payable onlyProxyOwner {
        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
        _upgradeTo(newImplementation);
        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view virtual override returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            impl := sload(slot)
        }
    }

    //对外获取
    function implementation() external onlyProxyOwner returns (address implementation_) {
        implementation_ = _implementation();
    }


    function _getInitialized() internal view virtual returns (bool isinitialized) {
        bytes32 slot = _ISINITIALIZED_SLOT;
        assembly {
            isinitialized := sload(slot)
        }
    }

    // 对外获取
    function getInitialized() external view onlyProxyOwner returns (bool isinitialized_) {
        isinitialized_ = _getInitialized();
    }


    function _getOwner() internal view virtual returns (address owner) {
        bytes32 slot = _OWNER_SLOT;
        assembly {
            owner := sload(slot)
        }
    }

    function getOwner() external view onlyProxyOwner returns (address owner_) {
        owner_ = _getOwner();
    }


    function transferOwnership(address newOwner) public onlyProxyOwner {
        _setOwner(newOwner);
        emit OwnershipTransferred(_getOwner(), newOwner);
    }


    /**
     * @dev Upgrades the proxy to a new implementation.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal virtual {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "UpgradeableProxy: new implementation is not a contract");

        bytes32 slot = _IMPLEMENTATION_SLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, newImplementation)
        }
    }

    function _setIsInitialized(bool initialized) private {
        bytes32 slot = _ISINITIALIZED_SLOT;
        assembly {
            sstore(slot, initialized)
        }
    }

    function _setOwner(address _owner) private {
        bytes32 slot = _OWNER_SLOT;
        assembly {
            sstore(slot, _owner)
        }
    }

}
