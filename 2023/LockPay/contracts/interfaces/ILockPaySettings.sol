pragma solidity ^0.8.0;

interface ILockPaySettings {
    function setLockerFees(address _locker) external;
    function updateLockerFees(
        uint256 _lockFee,
        uint256 _relockFee,
        uint256 _referralFee
    ) external;
    function referrerIsValid(address _referrer) external view returns (bool);
    function getLockerFees(address _locker) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, address);
    function getFeesAmount () external view returns (uint256);
    function getFeesBeneficiary () external view returns (address);
    function getFeesToken () external view returns (address);
}