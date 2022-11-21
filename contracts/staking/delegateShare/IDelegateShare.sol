pragma solidity ^0.6.6;

interface IDelegateShare {
    function withdrawRewards(address user) external returns(uint256);


    function getLiquidRewards(address user) external view returns (uint256);

    function restake() external returns(uint256, uint256);

    function ownerExpand() external view returns (address);

    function unlockExpand() external ;

    function lockExpand() external ;

    function drain(
        address token,
        address payable destination,
        uint256 amount
    ) external;

    function slash(uint256 valPow, uint256 delegatedAmount, uint256 totalAmountToSlash) external returns (uint256);

    function updateDelegation(bool delegation) external;

    function migrateOut(address user, uint256 amount) external;

    function migrateIn(address user, uint256 amount) external;

    function getActiveAmount() external view returns(uint256);
}
