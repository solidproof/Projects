// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./extensions/NoContract.sol";

/// @title ADSE LP Farming
/// @notice Users can stake their ADSE ecosystem LP tokens to get ADSE rewards
/// @dev This contract doesn't mint ADSE tokens, instead the owner (the ADSE DAO) allocates x amount of ADSE to be distributed as a reward for liquidity providers.
/// To ensure that enough tokens are allocated, an epoch system is implemented.
/// The owner is required to allocate enough tokens (`_rewardPerBlock * (_endBlock - _startBlock)`) when creating a new epoch.
/// When there no epoch is ongoing, the contract stops emitting rewards
contract LPFarming is ReentrancyGuard, NoContract {
    using SafeERC20 for IERC20;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);
    event ClaimAll(address indexed user, uint256 amount);

    /// @dev Data relative to a user's staking position
    /// @param amount The amount of LP tokens the user has provided
    /// @param lastAccRewardPerShare The `accRewardPerShare` pool value at the time of the user's last claim
    struct UserInfo {
        uint256 amount;
        uint256 lastAccRewardPerShare;
    }

    /// @dev Data relative to an LP pool
    /// @param lpToken The LP token accepted by the pool
    /// @param allocPoint Allocation points assigned to the pool. Determines the share of `rewardPerBlock` allocated to this pool
    /// @param lastRewardBlock Last block number in which reward distribution occurred
    /// @param accRewardPerShare Accumulated rewards per share, times 1e36. The amount of rewards the pool has accumulated per unit of LP token deposited
    /// @param depositedAmount Total number of tokens deposited in the pool.
    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
        uint256 depositedAmount;
    }

    /// @dev Data relative to an epoch
    /// @param startBlock The epoch's starting block
    /// @param endBlock The epoch's starting block
    /// @param rewardPerBlock The amount of ADSE rewards distributed per block during this epoch
    struct EpochInfo {
        uint256 startBlock;
        uint256 endBlock;
        uint256 rewardPerBlock;
    }

    /// @notice The reward token, ADSE
    IERC20 public immutable adse;

    /// @notice The current epoch
    /// @dev We don't need to store data about previous epochs, to simplify logic we only store data about the current epoch
    EpochInfo public epoch;
    /// @notice All the LP pools, active and inactive
    PoolInfo[] public poolInfo;
    /// @notice User staking positions, divided by PID
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    /// @notice Sum of the allocation points for all the pools
    /// @dev Used to calculate the share of `rewardPerBlock` for each pool.
    uint256 public totalAllocPoint;

    /// @dev User's withdrawable rewards per pool
    mapping(address => mapping(uint256 => uint256)) private userRewards;

    /// @param _adse The reward token
    constructor(address _adse) {
        adse = IERC20(_adse);
    }

    /// @notice Allows the owner to start a new epoch. Can only be called when there's no ongoing epoch
    /// @param _startBlock The new epoch's start block. If 0, takes the value of `block.number`
    /// @param _endBlock The new epoch's end block. Has to be greater than `_startBlock`
    /// @param _rewardPerBlock The new epoch's amount of rewards to distribute per block. Must be greater than 0
    function newEpoch(
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _rewardPerBlock
    ) external onlyOwner {
        if (_startBlock == 0) _startBlock = block.number;
        else require(_startBlock >= block.number, "Invalid start block");
        require(_endBlock > _startBlock, "Invalid end block");
        require(_rewardPerBlock != 0, "Invalid reward per block");

        //update all pools to ensure that they have all been updated up to the last epoch's `endBlock`
        _massUpdatePools();

        uint256 remainingRewards = epoch.rewardPerBlock *
            (epoch.endBlock - _blockNumber());
        uint256 newRewards = _rewardPerBlock * (_endBlock - _startBlock);

        epoch.startBlock = _startBlock;
        epoch.endBlock = _endBlock;
        epoch.rewardPerBlock = _rewardPerBlock;

        if (remainingRewards > newRewards) {
            unchecked {
                adse.safeTransfer(msg.sender, remainingRewards - newRewards);
            }
        } else if (remainingRewards < newRewards) {
            unchecked {
                adse.safeTransferFrom(
                    msg.sender,
                    address(this),
                    newRewards - remainingRewards
                );
            }
        }
    }

    /// @notice Allows the owner to add a new pool
    /// @param _allocPoint Allocation points to assign to the new pool
    /// @param _lpToken The LP token accepted by the new pool
    function add(uint256 _allocPoint, IERC20 _lpToken) external onlyOwner {
        _massUpdatePools();

        uint256 lastRewardBlock = _blockNumber();
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accRewardPerShare: 0,
                depositedAmount: 0
            })
        );
    }

    /// @notice Allows the owner to change a pool's allocation points
    /// @param _pid The pool id of the pool to modify
    /// @param _allocPoint The new allocation points
    function set(uint256 _pid, uint256 _allocPoint) external onlyOwner {
        _massUpdatePools();

        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint - prevAllocPoint + _allocPoint;
        }
    }

    /// @notice Returns the number of pools available
    /// @return The length of the `poolInfo` array
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /// @notice Frontend function used to calculate the amount of rewards `_user` can claim from the pool with id `_pid`
    /// @param _pid The pool id
    /// @param _user The address of the user
    /// @return The amount of rewards claimable from `_pid` by user `_user`
    function pendingReward(
        uint256 _pid,
        address _user
    ) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 blockNumber = _blockNumber();
        //normalizing the pool's `lastRewardBlock` ensures that no rewards are distributed by staking outside of an epoch
        uint256 lastRewardBlock = _normalizeBlockNumber(pool.lastRewardBlock);
        uint256 lpSupply = pool.depositedAmount;
        //if blockNumber is greater than the pool's `lastRewardBlock` the pool's `accRewardPerShare` is outdated,
        //we need to calculate the up to date amount to return an accurate reward value
        if (blockNumber > lastRewardBlock && lpSupply != 0) {
            uint256 reward = ((blockNumber - lastRewardBlock) *
                epoch.rewardPerBlock *
                1e36 *
                pool.allocPoint) / totalAllocPoint;
            accRewardPerShare += reward / lpSupply;
        }
        return
            //rewards that the user had already accumulated but not claimed
            userRewards[_user][_pid] +
            //subtracting the user's `lastAccRewardPerShare` from the pool's `accRewardPerShare` results in the amount of rewards per share
            //the pool has accumulated since the user's last claim, multiplying it by the user's shares results in the amount of new rewards claimable
            //by the user
            (user.amount * (accRewardPerShare - user.lastAccRewardPerShare)) /
            1e36;
    }

    /// @notice Allows users to deposit `_amount` of LP tokens in the pool with id `_pid`. Non whitelisted contracts can't call this function
    /// @dev Emits a {Deposit} event
    /// @param _pid The id of the pool to deposit into
    /// @param _amount The amount of LP tokens to deposit
    function deposit(uint256 _pid, uint256 _amount) external noContract {
        require(_amount != 0, "invalid_amount");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        _updatePool(_pid);
        _withdrawReward(_pid);

        pool.depositedAmount += _amount;
        user.amount += _amount;
        pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _pid, _amount);
    }

    /// @notice Allows users to withdraw `_amount` of LP tokens from the pool with id `_pid`. Non whitelisted contracts can't call this function
    /// @dev Emits a {Withdraw} event
    /// @param _pid The id of the pool to withdraw from
    /// @param _amount The amount of LP tokens to withdraw
    function withdraw(uint256 _pid, uint256 _amount) external noContract {
        require(_amount != 0, "invalid_amount");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "insufficient_amount");

        _updatePool(_pid);
        _withdrawReward(_pid);

        pool.depositedAmount -= _amount;
        unchecked {
            user.amount -= _amount;
        }

        pool.lpToken.safeTransfer(address(msg.sender), _amount);

        emit Withdraw(msg.sender, _pid, _amount);
    }

    /// @dev Normalizes the current `block.number`. See {_normalizeBlockNumber} for more info
    /// @return Normalized `block.number`
    function _blockNumber() internal view returns (uint256) {
        return _normalizeBlockNumber(block.number);
    }

    /// @dev Normalizes `blockNumber` to fit within the bounds of an epoch.
    /// This is done to ensure that no rewards are distributed for staking outside of an epoch without modifying the reward logic.
    /// For example:
    /// `blockNumber` is 1100, the epoch's `endBlock` is 1000. In this case the function would return 1000. If this value were to be used
    /// in the {_updatePool} function, where the pool's `lastRewardBlock` is 990, only the rewards from block 990 to block 1000 would be distributed
    /// @return Normalized `blockNumber`
    function _normalizeBlockNumber(
        uint256 blockNumber
    ) internal view returns (uint256) {
        if (blockNumber < epoch.startBlock) return epoch.startBlock;

        if (blockNumber > epoch.endBlock) return epoch.endBlock;

        return blockNumber;
    }

    /// @dev Calls {_updatePool} for every pool
    function _massUpdatePools() internal {
        uint256 length = poolInfo.length;
        for (uint256 pid; pid < length; ++pid) {
            _updatePool(pid);
        }
    }

    /// @dev Updates the state of the pool at index `_pid`
    /// @param _pid The pool to update
    function _updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.allocPoint == 0) {
            return;
        }

        uint256 blockNumber = _blockNumber();
        //normalizing the pool's `lastRewardBlock` ensures that no rewards are distributed by staking outside of an epoch
        uint256 lastRewardBlock = _normalizeBlockNumber(pool.lastRewardBlock);
        if (blockNumber <= lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.depositedAmount;
        if (lpSupply == 0) {
            pool.lastRewardBlock = blockNumber;
            return;
        }
        uint256 reward = ((blockNumber - lastRewardBlock) *
            epoch.rewardPerBlock *
            1e36 *
            pool.allocPoint) / totalAllocPoint;
        pool.accRewardPerShare = pool.accRewardPerShare + reward / lpSupply;
        pool.lastRewardBlock = blockNumber;
    }

    /// @dev Updates `msg.sender`'s claimable rewards by adding pending rewards from `_pid`
    /// @param _pid The pool to withdraw rewards from
    function _withdrawReward(uint256 _pid) internal returns (uint256) {
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 accRewardPerShare = poolInfo[_pid].accRewardPerShare;
        uint256 pending = (user.amount *
            (accRewardPerShare - user.lastAccRewardPerShare)) / 1e36;
        if (pending != 0) {
            userRewards[msg.sender][_pid] += pending;
        }

        user.lastAccRewardPerShare = accRewardPerShare;

        return pending;
    }

    /// @notice Allows users to claim rewards from the pool with id `_pid`. Non whitelisted contracts can't call this function
    /// @dev Emits a {Claim} event
    /// @param _pid The pool to claim rewards from
    function claim(uint256 _pid) external nonReentrant noContract {
        _updatePool(_pid);
        _withdrawReward(_pid);

        uint256 rewards = userRewards[msg.sender][_pid];
        require(rewards != 0, "no_reward");

        userRewards[msg.sender][_pid] = 0;
        adse.safeTransfer(msg.sender, rewards);

        emit Claim(msg.sender, _pid, rewards);
    }

    /// @notice Allows users to claim rewards from all pools. Non whitelisted contracts can't call this function
    /// @dev Emits a {ClaimAll} event
    function claimAll() external nonReentrant noContract {
        uint256 length = poolInfo.length;
        uint256 rewards;
        for (uint256 i; i < length; ++i) {
            _updatePool(i);
            _withdrawReward(i);
            rewards += userRewards[msg.sender][i];
            userRewards[msg.sender][i] = 0;
        }
        require(rewards != 0, "no_reward");

        adse.safeTransfer(msg.sender, rewards);

        emit ClaimAll(msg.sender, rewards);
    }

    /// @dev Prevent the owner from renouncing ownership. Having no owner would render this contract unusable due to the inability to create new epochs
    function renounceOwnership() public view override onlyOwner {
        revert("Cannot renounce ownership");
    }
}
