pragma solidity ^0.8.0;

interface ILockPayFactory {
    function registerLocker(address _lockerAddress) external;
    function lockerIsRegistered(address _lockerAddress) external view returns (bool);
}