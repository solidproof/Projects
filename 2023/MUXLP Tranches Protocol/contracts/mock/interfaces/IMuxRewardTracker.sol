// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IMuxRewardTracker {
    function claimable(address _addr) external returns (uint256);

    function claim(address _addr) external returns (uint256);

    function claimForAccount(address _addr, address _rcv) external returns (uint256);

    function checkpointToken() external;

    function averageStakedAmounts(address _account) external view returns (uint256);

    function cumulativeRewards(address _account) external view returns (uint256);

    function setHandler(address _handler, bool _isActive) external;
}
