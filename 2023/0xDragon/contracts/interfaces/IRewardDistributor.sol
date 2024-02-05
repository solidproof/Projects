// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.18;

interface IRewardDistributor {
    function distribute() external returns (uint);

    function pendingRewards() external view returns (uint);
}
