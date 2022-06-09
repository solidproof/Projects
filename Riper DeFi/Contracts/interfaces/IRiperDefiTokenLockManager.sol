// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IRiperDefiTokenLock.sol";

interface IRiperDefiTokenLockManager {
    // -- Factory --

    function setMasterCopy(address _masterCopy) external;

    function createTokenLockWallet(
        address _owner,
        address _beneficiary,
        uint256 _managedAmount,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _periods,
        uint256 _releaseStartTime,
        uint256 _vestingCliffTime,
        IRiperDefiTokenLock.Revocability _revocable
    ) external;

    // -- Funds Management --

    function token() external returns (IERC20);

    function deposit(uint256 _amount) external;

    function withdraw(uint256 _amount) external;
}