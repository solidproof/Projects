// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IXFlashTokenUsage {
    function allocate(address userAddress, uint256 amount, bytes calldata data) external;
    function deallocate(address userAddress, uint256 amount, bytes calldata data) external;
}