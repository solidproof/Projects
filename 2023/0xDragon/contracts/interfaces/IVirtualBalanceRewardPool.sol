// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.18;

interface IVirtualBalanceRewardPool {
    function updateStaked(address _account, uint newAmount) external;

    function getRewardBasePool(address _account) external;

    function notifyRewardAmount(uint256 reward) external;
}
