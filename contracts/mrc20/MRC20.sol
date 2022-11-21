pragma solidity ^0.6.6;

import "./BaseERC20.sol";
import "./IChildToken.sol";

contract MRC20 is BaseERC20,IChildToken {
    event Transfer(address indexed from, address indexed to, uint256 value);

    uint256 public currentSupply = 0;
    uint8 private constant DECIMALS = 18;
    bool isInitialized;

    constructor() public {}

    function initialize(address _childChain, address _token) public {
        // Todo: once BorValidator(@0x1000) contract added uncomment me
        // require(msg.sender == address(0x1000));
        require(!isInitialized, "The contract is already initialized");
        isInitialized = true;
        token = _token;
        _transferOwner(_childChain);
    }


    function deposit(address user, bytes memory depositData) public override onlyOwner{
        // check for amount and user
        uint256 amount = abi.decode(depositData, (uint256));
        require(
            amount > 0 && user != address(0x0),
            "Insufficient amount or invalid user"
        );

        // input balance
        uint256 input1 = balanceOf(user);

        // transfer amount to user
        address payable _user = address(uint160(user));
        _user.transfer(amount);

        currentSupply = currentSupply.add(amount);

        // deposit events
        emit Deposit(token, user, amount, input1, balanceOf(user));
    }

    function withdraw(uint256 amount) public override payable {
        address user = msg.sender;
        // input balance
        uint256 input = balanceOf(user);

        currentSupply = currentSupply.sub(amount);
        // check for amount
        require(
            amount > 0 && msg.value == amount,
            "Insufficient amount"
        );

        // Transfer
        emit Transfer(user, address(0), amount);
        // withdraw event
        emit Withdraw(token, user, amount, input, balanceOf(user));
    }

    function name() public pure returns (string memory) {
        return "W3FS Token";
    }

    function symbol() public pure returns (string memory) {
        return "W3FS";
    }

    function decimals() public pure returns (uint8) {
        return DECIMALS;
    }

    function totalSupply() public pure returns (uint256) {
        return 10000000000 * 10**uint256(DECIMALS);
    }

    function balanceOf(address account) public override view returns (uint256) {
        return account.balance;
    }

    /// @dev Function that is called when a user or another contract wants to transfer funds.
    /// @param to Address of token receiver.
    /// @param value Number of tokens to transfer.
    /// @return Returns success of function call.
    function transfer(address to, uint256 value) public payable returns (bool) {
        if (msg.value != value) {
            return false;
        }
        return _transferFrom(msg.sender, to, value);
    }

    /**
   * @dev _transfer is invoked by _transferFrom method that is inherited from BaseERC20.
   * This enables us to transfer MaticEth between users while keeping the interface same as that of an ERC20 Token.
   */
    function _transfer(address sender, address recipient, uint256 amount) internal override
    {
        require(recipient != address(this), "can't send to MRC20");
        address(uint160(recipient)).transfer(amount);
        emit Transfer(sender, recipient, amount);
    }
}
