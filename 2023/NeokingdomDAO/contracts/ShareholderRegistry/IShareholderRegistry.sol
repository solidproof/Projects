// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../extensions/ISnapshot.sol";

interface IShareholderRegistry is ISnapshot {
    function SHAREHOLDER_STATUS() external view returns (bytes32);

    function INVESTOR_STATUS() external view returns (bytes32);

    function CONTRIBUTOR_STATUS() external view returns (bytes32);

    function MANAGING_BOARD_STATUS() external view returns (bytes32);

    function getStatus(address account) external view returns (bytes32);

    function getStatusAt(
        address account,
        uint256 snapshotId
    ) external view returns (bytes32);

    function isAtLeast(
        bytes32 status,
        address account
    ) external view returns (bool);

    function isAtLeastAt(
        bytes32 status,
        address account,
        uint256 snapshotId
    ) external view returns (bool);

    function balanceOfAt(
        address account,
        uint256 snapshotId
    ) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function totalSupplyAt(uint256 snapshotId) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
