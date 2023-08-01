// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IMultiRewardsPool {
    function underlying() external view returns (address);

    function derivedSupply() external view returns (uint256);

    function derivedBalances(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function rewardTokens(uint256 id) external view returns (address);

    function isRewardToken(address token) external view returns (bool);

    function rewardTokensLength() external view returns (uint256);

    function derivedBalance(address account) external view returns (uint256);

    function left(address token) external view returns (uint256);

    function earned(
        address token,
        address account
    ) external view returns (uint256);

    function registerRewardToken(address token) external;

    function removeRewardToken(address token) external;
}
