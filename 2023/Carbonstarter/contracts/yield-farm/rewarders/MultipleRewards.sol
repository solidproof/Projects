// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IMultipleRewards.sol";
import "../ICarbonChef.sol";
import "../libraries/BoringERC20.sol";

contract MultipleRewards is IMultipleRewards, Ownable, ReentrancyGuard {
    using BoringERC20 for IBoringERC20;

    IBoringERC20 public immutable override rewardToken;
    ICarbonChef public immutable distributorV2;
    bool public immutable isNative;

    /// @notice Info of each distributorV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of REWARD entitled to the user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    /// @notice Info of each distributorV2 poolInfo.
    /// `accTokenPerShare` Amount of REWARD each LP token is worth.
    /// `startTimestamp` The start timestamp of rewards.
    /// `lastRewardTimestamp` The last timestamp REWARD was rewarded to the poolInfo.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// `totalRewards` The amount of rewards added to the pool.
    struct PoolInfo {
        uint256 accTokenPerShare;
        uint256 startTimestamp;
        uint256 lastRewardTimestamp;
        uint256 allocPoint;
        uint256 totalRewards;
    }

    /// @notice Reward info
    /// `startTimestamp` The start timestamp of rewards
    /// `endTimestamp` The end timestamp of rewards
    /// `rewardPerSec` The amount of rewards per second
    struct RewardInfo {
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 rewardPerSec;
    }

    /// @notice Info of each pool.
    mapping(uint256 => PoolInfo) public poolInfo;

    /// @dev this is mostly used for extending reward period
    /// @notice Reward info is a set of {endTimestamp, rewardPerSec}
    /// indexed by pool id
    mapping(uint256 => RewardInfo[]) public poolRewardInfo;

    uint256[] public poolIds;

    /// @notice Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    /// @notice limit length of reward info
    /// how many phases are allowed
    uint256 public immutable rewardInfoLimit = 52; //1y

    // The precision factor
    uint256 private immutable ACC_TOKEN_PRECISION;

    event OnReward(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event AddPool(uint256 indexed pid, uint256 allocPoint);
    event SetPool(uint256 indexed pid, uint256 allocPoint);
    event UpdatePool(
        uint256 indexed pid,
        uint256 lastRewardTimestamp,
        uint256 lpSupply,
        uint256 accTokenPerShare
    );

    event AddRewardInfo(
        uint256 indexed pid,
        uint256 indexed phase,
        uint256 endTimestamp,
        uint256 rewardPerSec
    );

    modifier onlyDistributorV2() {
        require(
            msg.sender == address(distributorV2),
            "onlyDistributorV2: only CarbonChef can call this function"
        );
        _;
    }

    constructor(
        IBoringERC20 _rewardToken,
        ICarbonChef _distributorV2,
        bool _isNative
    ) {
        require(
            Address.isContract(address(_rewardToken)),
            "constructor: reward token must be a valid contract"
        );
        require(
            Address.isContract(address(_distributorV2)),
            "constructor: CarbonChef must be a valid contract"
        );
        rewardToken = _rewardToken;
        distributorV2 = _distributorV2;
        isNative = _isNative;

        uint256 decimalsRewardToken = uint256(
            _isNative ? 18 : _rewardToken.safeDecimals()
        );
        require(
            decimalsRewardToken < 30,
            "constructor: reward token decimals must be inferior to 30"
        );

        ACC_TOKEN_PRECISION = uint256(
            10 ** (uint256(30) - (decimalsRewardToken))
        );
    }

    /// @notice Add a new pool. Can only be called by the owner.
    /// @param _pid pool id on DistributorV2
    /// @param _allocPoint allocation of the new pool.
    function add(
        uint256 _pid,
        uint256 _allocPoint,
        uint256 _startTimestamp
    ) public onlyOwner {
        require(poolInfo[_pid].lastRewardTimestamp == 0, "pool already exists");
        massUpdatePools();
        totalAllocPoint += _allocPoint;

        poolInfo[_pid] = PoolInfo({
            allocPoint: _allocPoint,
            startTimestamp: _startTimestamp,
            lastRewardTimestamp: _startTimestamp,
            accTokenPerShare: 0,
            totalRewards: 0
        });

        poolIds.push(_pid);
        emit AddPool(_pid, _allocPoint);
    }

    /// @notice if the new reward info is added, the reward & its end timestamp will be extended by the newly pushed reward info.
    function addRewardInfo(
        uint256 _pid,
        uint256 _endTimestamp,
        uint256 _rewardPerSec
    ) external payable onlyOwner {
        RewardInfo[] storage rewardInfo = poolRewardInfo[_pid];
        PoolInfo storage pool = poolInfo[_pid];
        RewardInfo memory lastRewardInfo = rewardInfo[rewardInfo.length - 1];

        require(
            rewardInfo.length < rewardInfoLimit,
            "add reward info: reward info length exceeds the limit"
        );
        require(
            rewardInfo.length == 0 ||
                lastRewardInfo.endTimestamp >= block.timestamp,
            "add reward info: reward period ended"
        );
        require(
            rewardInfo.length == 0 ||
                lastRewardInfo.endTimestamp < _endTimestamp,
            "add reward info: bad new endTimestamp"
        );

        uint256 startTimestamp = rewardInfo.length == 0
            ? pool.startTimestamp
            : lastRewardInfo.endTimestamp;

        uint256 timeRange = _endTimestamp - startTimestamp;
        uint256 totalRewards = timeRange * _rewardPerSec;

        if (!isNative) {
            require(msg.value == 0, "msg.value is not 0");
            rewardToken.safeTransferFrom(
                msg.sender,
                address(this),
                totalRewards
            );
        } else {
            require(
                msg.value == totalRewards,
                "add reward info: not enough funds to transfer"
            );
        }

        pool.totalRewards += totalRewards;

        rewardInfo.push(
            RewardInfo({
                startTimestamp: startTimestamp,
                endTimestamp: _endTimestamp,
                rewardPerSec: _rewardPerSec
            })
        );

        emit AddRewardInfo(
            _pid,
            rewardInfo.length - 1,
            _endTimestamp,
            _rewardPerSec
        );
    }

    function _endTimestampOf(
        uint256 _pid,
        uint256 _timestamp
    ) internal view returns (uint256) {
        RewardInfo[] memory rewardInfo = poolRewardInfo[_pid];
        uint256 len = rewardInfo.length;
        if (len == 0) {
            return 0;
        }
        for (uint256 i = 0; i < len; ) {
            if (_timestamp <= rewardInfo[i].endTimestamp)
                return rewardInfo[i].endTimestamp;

            unchecked {
                ++i;
            }
        }

        /// @dev when couldn't find any reward info, it means that _timestamp exceed endTimestamp
        /// so return the latest reward info.
        return rewardInfo[len - 1].endTimestamp;
    }

    /// @notice this will return end timestamp based on the current block timestamp.
    function currentEndTimestamp(uint256 _pid) external view returns (uint256) {
        return _endTimestampOf(_pid, block.timestamp);
    }

    /// @notice Return reward multiplier over the given _from to _to timestamp.
    function _getTimeElapsed(
        uint256 _from,
        uint256 _to,
        uint256 _endTimestamp
    ) public pure returns (uint256) {
        unchecked {
            if (_from >= _endTimestamp || _from > _to) {
                return 0;
            }
            if (_to <= _endTimestamp) {
                return _to - _from;
            }
            return _endTimestamp - _from;
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(
        uint256 _pid
    ) external nonReentrant returns (PoolInfo memory pool) {
        return _updatePool(_pid);
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function _updatePool(uint256 pid) internal returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        RewardInfo[] memory rewardInfo = poolRewardInfo[pid];

        if (block.timestamp <= pool.lastRewardTimestamp) {
            return pool;
        }

        uint256 lpSupply = distributorV2.poolTotalLp(pid);

        if (lpSupply == 0) {
            // if there is no total supply, return and use the pool's start timestamp as the last reward timestamp
            // so that ALL reward will be distributed.
            // however, if the first deposit is out of reward period, last reward timestamp will be its timestamp
            // in order to keep the multiplier = 0
            if (block.timestamp > _endTimestampOf(pid, block.timestamp)) {
                pool.lastRewardTimestamp = block.timestamp;
                emit UpdatePool(
                    pid,
                    pool.lastRewardTimestamp,
                    lpSupply,
                    pool.accTokenPerShare
                );
            }

            return pool;
        }

        /// @dev for each reward info
        for (uint256 i = 0; i < rewardInfo.length; ) {
            // @dev get multiplier based on current timestamp and rewardInfo's end timestamp
            // multiplier will be a range of either (current timestamp - pool.timestamp)
            // or (reward info's endtimestamp - pool.timestamp) or 0
            uint256 timeElapsed = _getTimeElapsed(
                pool.lastRewardTimestamp,
                block.timestamp,
                rewardInfo[i].endTimestamp
            );
            if (timeElapsed == 0) {
                unchecked {
                    ++i;
                }
                continue;
            }

            // @dev if currentTimestamp exceed end timestamp, use end timestamp as the last reward timestamp
            // so that for the next iteration, previous endTimestamp will be used as the last reward timestamp
            if (block.timestamp > rewardInfo[i].endTimestamp) {
                pool.lastRewardTimestamp = rewardInfo[i].endTimestamp;
            } else {
                pool.lastRewardTimestamp = block.timestamp;
            }

            uint256 tokenReward = (timeElapsed * rewardInfo[i].rewardPerSec);

            pool.accTokenPerShare += ((tokenReward * ACC_TOKEN_PRECISION) /
                lpSupply);

            unchecked {
                ++i;
            }
        }

        poolInfo[pid] = pool;

        emit UpdatePool(
            pid,
            pool.lastRewardTimestamp,
            lpSupply,
            pool.accTokenPerShare
        );

        return pool;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public nonReentrant {
        _massUpdatePools();
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function _massUpdatePools() internal {
        uint256 length = poolIds.length;
        for (uint256 pid = 0; pid < length; ) {
            _updatePool(poolIds[pid]);
            unchecked {
                ++pid;
            }
        }
    }

    /// @notice Function called by CarbonChef whenever staker claims Carbon harvest. Allows staker to also receive a 2nd reward token.
    /// @param _user Address of user
    /// @param _amount Number of LP tokens the user has
    function onCarbonReward(
        uint256 _pid,
        address _user,
        uint256 _amount
    ) external override onlyDistributorV2 nonReentrant {
        PoolInfo memory pool = _updatePool(_pid);
        UserInfo storage user = userInfo[_pid][_user];

        uint256 pending = 0;
        uint256 rewardBalance = 0;

        if (isNative) {
            rewardBalance = address(this).balance;
        } else {
            rewardBalance = rewardToken.balanceOf(address(this));
        }

        if (user.amount > 0) {
            pending = (((user.amount * pool.accTokenPerShare) /
                ACC_TOKEN_PRECISION) - user.rewardDebt);

            if (pending > 0) {
                if (isNative) {
                    if (pending > rewardBalance) {
                        (bool success, ) = _user.call{value: rewardBalance}("");
                        require(success, "Transfer failed");
                    } else {
                        (bool success, ) = _user.call{value: pending}("");
                        require(success, "Transfer failed");
                    }
                } else {
                    if (pending > rewardBalance) {
                        rewardToken.safeTransfer(_user, rewardBalance);
                    } else {
                        rewardToken.safeTransfer(_user, pending);
                    }
                }
            }
        }

        user.amount = _amount;

        user.rewardDebt =
            (user.amount * pool.accTokenPerShare) /
            ACC_TOKEN_PRECISION;

        emit OnReward(_user, pending);
    }

    /// @notice View function to see pending Reward on frontend.
    function pendingTokens(
        uint256 _pid,
        address _user
    ) external view override returns (uint256) {
        UserInfo memory userInfoData = userInfo[_pid][_user];
        return
            _pendingTokens(_pid, userInfoData.amount, userInfoData.rewardDebt);
    }

    function _pendingTokens(
        uint256 _pid,
        uint256 _amount,
        uint256 _rewardDebt
    ) internal view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo[_pid];
        RewardInfo[] memory rewardInfo = poolRewardInfo[_pid];

        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = distributorV2.poolTotalLp(_pid);

        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 cursor = pool.lastRewardTimestamp;

            for (uint256 i = 0; i < rewardInfo.length; ) {
                uint256 timeElapsed = _getTimeElapsed(
                    cursor,
                    block.timestamp,
                    rewardInfo[i].endTimestamp
                );
                if (timeElapsed == 0) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }
                cursor = rewardInfo[i].endTimestamp;

                uint256 tokenReward = (timeElapsed *
                    rewardInfo[i].rewardPerSec *
                    pool.allocPoint) / totalAllocPoint;

                accTokenPerShare +=
                    (tokenReward * ACC_TOKEN_PRECISION) /
                    lpSupply;
                unchecked {
                    ++i;
                }
            }
        }

        pending = (((_amount * accTokenPerShare) / ACC_TOKEN_PRECISION) -
            _rewardDebt);
    }

    function _rewardPerSecOf(
        uint256 _pid,
        uint256 _blockTimestamp
    ) internal view returns (uint256) {
        RewardInfo[] memory rewardInfo = poolRewardInfo[_pid];
        PoolInfo storage pool = poolInfo[_pid];
        uint256 len = rewardInfo.length;
        if (len == 0) {
            return 0;
        }
        for (uint256 i = 0; i < len; ) {
            if (_blockTimestamp <= rewardInfo[i].endTimestamp)
                return
                    (rewardInfo[i].rewardPerSec * pool.allocPoint) /
                    totalAllocPoint;
            unchecked {
                ++i;
            }
        }
        /// @dev when couldn't find any reward info, it means that timestamp exceed endblock
        /// so return 0
        return 0;
    }

    /// @notice View function to see pool rewards per sec
    function poolRewardsPerSec(
        uint256 _pid
    ) external view override returns (uint256) {
        return _rewardPerSecOf(_pid, block.timestamp);
    }

    /// @notice Withdraw reward. EMERGENCY ONLY.
    function emergencyRewardWithdraw(
        uint256 _pid,
        uint256 _amount,
        address _beneficiary
    ) external onlyOwner nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lpSupply = distributorV2.poolTotalLp(_pid);

        uint256 currentStakingPendingReward = _pendingTokens(_pid, lpSupply, 0);

        require(
            currentStakingPendingReward + _amount <= pool.totalRewards,
            "emergency reward withdraw: not enough reward token"
        );
        pool.totalRewards -= _amount;
        require(_amount > 0, "Amount for sending is zero");
        if (!isNative) {
            rewardToken.safeTransfer(_beneficiary, _amount);
        } else {
            (bool sent, ) = _beneficiary.call{value: _amount}("");
            require(sent, "emergency reward withdraw: failed to send");
        }
    }

    /// @notice Withdraw reward. EMERGENCY ONLY.
    function withdrawRewardsEmergency(
        uint256 _amount,
        address _beneficiary
    ) external onlyOwner nonReentrant {
        require(_amount > 0, "Amount for sending is zero");
        if (!isNative) {
            rewardToken.safeTransfer(_beneficiary, _amount);
        } else {
            (bool sent, ) = _beneficiary.call{value: _amount}("");
            require(sent, "emergency reward withdraw: failed to send");
        }
    }
}
