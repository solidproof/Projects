// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Snapshot {
    /**
     * @dev Creates a new snapshot.
     */
    function snapshot() external returns (uint256);
}