// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IShibaBurn {
    function buyAndBurn(address tokenAddress, uint256 minOut) external payable;
}