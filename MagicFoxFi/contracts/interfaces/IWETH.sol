// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function withdraw(uint256) external;
}
