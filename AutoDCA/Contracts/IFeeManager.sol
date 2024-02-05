// SPDX-License-Identifier: UNLICENSED
// © Copyright AutoDCA. All Rights Reserved
pragma solidity ^0.8.9;

interface IFeeManager {
    // percentage amount divided by 1000000
    function getFeePercentage(
        uint256 poolId,
        address user
    ) external view returns (uint256);

    function calculateFee(
        uint256 poolId,
        address user,
        uint256 amount
    ) external returns (uint256);
}
