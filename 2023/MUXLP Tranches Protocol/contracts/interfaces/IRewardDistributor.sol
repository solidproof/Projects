// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IRewardDistributor {
    function updateRewards(address account) external;

    function claimable(address account) external returns (uint256);

    function claim(address _receiver) external returns (uint256);

    function claimFor(address account, address _receiver) external returns (uint256);
}
