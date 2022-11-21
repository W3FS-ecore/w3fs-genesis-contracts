pragma solidity ^0.6.6;

interface IW3fsStorageManager {
    function updateStakeLimit(uint256 newStakeLimit) external;
    function updateDelegatedStakeLimit(uint256 newDelegatedStakeLimit) external;
    function updatePercentage(uint256 newPercentage) external;

    function showCanStakeAmount(address validatorAddr) external view returns (uint256);
    function checkCanStakeMore(address validatorAddr, uint256 amount, uint256 addStakeMount) external  view returns (bool);
    function checkCandelegatorsMore(uint256 minerId, uint256 addStakeMount) external  view returns(bool);

    function updateStoragePromise(address signer, uint256 storageSize) external;

    function getValidatorPower(address signer) external view returns (uint256);

    function checkSealSigs(bytes calldata data, uint[3][] calldata sigs) external;
}
