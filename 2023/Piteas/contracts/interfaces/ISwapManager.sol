// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ISwapManager {
    function swap(bytes calldata data) external payable returns (uint256);
}