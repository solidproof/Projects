// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IMlpRewardTracker {
    function setHandler(address _handler, bool _isActive) external;

    function balanceOf(address _account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function depositBalances(
        address _account,
        address _depositToken
    ) external view returns (uint256);

    function stakedAmounts(address _account) external view returns (uint256);

    function updateRewards() external;

    function stake(address _depositToken, uint256 _amount) external;

    function stakeForAccount(
        address _fundingAccount,
        address _account,
        address _depositToken,
        uint256 _amount
    ) external;

    function unstake(address _depositToken, uint256 _amount) external;

    function unstakeForAccount(
        address _account,
        address _depositToken,
        uint256 _amount,
        address _receiver
    ) external;

    function tokensPerInterval() external view returns (uint256);

    function claim(address _receiver) external returns (uint256);

    function claimForAccount(address _account, address _receiver) external returns (uint256);

    function claimable(address _account) external returns (uint256);

    function averageStakedAmounts(address _account) external view returns (uint256);

    function cumulativeRewards(address _account) external view returns (uint256);

    function lastTimeRewardApplicable() external view returns (uint256);

    function notifyRewardAmount(uint256 amount) external;
}
