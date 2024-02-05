// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IRewardDistributor {
    function rewardToken() external view returns (address);

    function pendingRewards() external view returns (uint256);

    function pendingMlpRewards() external view returns (uint256 toMlpAmount);

    function pendingMuxRewards() external view returns (uint256 toMuxAmount);

    function distribute() external;

    function rewardRate() external view returns (uint256);
}
