//SPDX-License-Identifier: LicenseRef-LICENSE

pragma solidity ^0.8.0;

import './token/BEP20/IBEP20.sol';

interface IStaking {

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many Staking tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint32 lockedTill;
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 stakingToken;           // Address of Staking token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. DPADs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that DPADs distribution occurs.
        uint256 accDpadPerShare; // Accumulated DPADs per share, times 1e12. See below.
        uint32 lockTime;
    }

    // Info of each pool.
    function poolInfo(uint256 _pid) external view returns (PoolInfo memory);

    // Info of each user that stakes Staking tokens.
    function userInfo(uint256 _pid, address _user) external view returns (UserInfo memory);

    // Total allocation points. Must be the sum of all allocation points in all pools.
    function totalAllocPoint() external view returns (uint256);

    // The block number when DPAD mining starts.
    function startBlock() external view returns (uint256);

    function poolLength() external view returns (uint256);

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) external view returns (uint256);

    // View function to see pending DPADs on frontend.
    function pendingDpad(uint256 _pid, address _user) external view returns (uint256);

    // Deposit Staking tokens to Staking for DPAD allocation.
    function deposit(uint256 _pid, uint256 _amount) external;

    // Withdraw Staking tokens from Staking.
    function withdraw(uint256 _pid, uint256 _amount) external;
}
