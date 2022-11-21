pragma solidity ^0.6.6;

interface IW3fsStakeManager {

    // stake amount function
    function stakeFor(address user, uint256 amount, uint256 fee, uint256 storagePromise, bool acceptDelegation, bytes calldata signerPubkey) external payable;

    function isActiveMiner(address minerAddr) external view returns (bool);

    //function isHasRewardMiner(address minerAddr) external view returns(bool);

    //function rewardLeave(address minerAddr) external returns (bool,uint256);

    function updateRewardsMiner(address minerAddr, uint256 amount) external returns (uint256);

    function getBorMiners() external view returns (address[] memory, uint256[] memory);

    function decreaseMinerDelegatedAmount(uint256 minerId, uint256 amount) external;

    function updateMinerState(uint256 minerId, int256 amount) external;

    function withdrawDelegatorsReward(uint256 minerId) external returns (uint256);

    function getMinerBaseInfo(uint256 minerId) external view returns (uint256, uint256, address, address, uint256, uint256);

    function getMinerId(address minerAddr) external view returns (uint256);

    function unstake(uint256 validatorId) external;

    function withdrawalDelay() external view returns (uint256);

    function getCurrentEpoch(uint256 number) external view returns (uint256);

    function transferFunds(uint256 minerId, uint256 amount, address delegator) external returns(bool);

    function getInitialValidators() external view returns (address[] memory, uint256[] memory);

    function slash(address minerAddr, uint256 slashAmount, bool doJail) external;

    function topupFee(address user, uint256 fee) external payable;

}
