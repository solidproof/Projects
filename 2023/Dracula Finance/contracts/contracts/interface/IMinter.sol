// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IMinter {
    function updatePeriod() external;

    function activePeriod() external view returns (uint256);
}
