// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ILock{
    function bridge() external view  returns (address);
    function withdraw(address to, uint256 amount) external;
}
