pragma solidity ^0.8.0;

interface ILockPayGenerator {
    function getFees(address _locker) external returns (uint256, uint256, uint256, uint256, uint256, uint256, address);
    function settings() external view returns (address);
}