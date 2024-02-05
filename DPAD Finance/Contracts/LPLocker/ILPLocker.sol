//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

interface ILPLocker {
    function lock(address _token, address _owner, uint _amount, uint unlocksAt) external returns (uint);

    function unlock(uint lockId) external;

    function unlockWithSpecifiedAmount(uint lockId, uint _amount) external;
}
