// SPDX-License-Identifier: No License
pragma solidity 0.8.3;

interface IBinanceApePropulsor {
    function deposit(uint256 amount) external returns (bool);
    function withdraw(uint256 amount) external returns (bool);
    function pulse(uint256 fees) external returns (bool);
}