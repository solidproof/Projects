// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IZyberChef {
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardLockedUp; // Reward locked up.
        uint256 nextHarvestUntil; // When can the user harvest again.
    }

    function totalAllocPoint() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function poolLength() external view returns (uint256);

    function poolTotalLp(uint256 pid) external view returns (uint256);

    function userInfo(
        uint256 _pid,
        address _user
    ) external view returns (UserInfo memory);
}
