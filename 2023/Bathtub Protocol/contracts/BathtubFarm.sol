// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Note that this pool has no minter key of BATH (rewards).
// Instead, rewards will be sent to this pool at the beginning.
contract BathtubFarm is Ownable {
    using SafeERC20 for IERC20;

    /// User-specific information.
    struct UserInfo {
        /// How many tokens the user provided.
        uint256 amount;
        /// How many unclaimed rewards does the user have pending.
        uint256 rewardDebt;
        /// How many baths the user claimed.
        uint256 claimedBath;
    }

    /// Pool-specific information.
    struct PoolInfo {
        /// Address of the token staked in the pool.
        IERC20 token;
        /// Allocation points assigned to the pool.
        /// @dev Rewards are distributed in the pool according to formula:
        //      (allocPoint / totalAllocPoint) * bathPerSecond
        uint256 allocPoint;
        /// Last time the rewards distribution was calculated.
        uint256 lastRewardTime;
        /// Accumulated BATH per share.
        uint256 accBathPerShare;
        /// Deposit fee in %, where 100 == 1%.
        uint16 depositFee;
        uint16 withdrawFee;
        /// Is the pool rewards emission started.
        bool isStarted;
        /// Pool claimed Amount
        uint256 poolClaimedBath;
        /// Is the pool expired or not.
        bool isExpired;
    }

    /// Reward token.
    IERC20 public bath;

    /// Address where the deposit fees are transferred.
    address public feeCollector;
    address public mrkgFeeCollector;
    address public devFeeCollector;
    address public poolofficer;

    /// Information about each pool.
    PoolInfo[] public poolInfo;

    /// Information about each user in each pool.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    mapping(address => bool) public isExcludedFromFees;

    /// Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    /// The time when BATH emissions start.
    uint256 public poolStartTime;

    /// The time when BATH emissions end.
    uint256 public poolEndTime;

    /// Amount of BATH emitted each second.
    uint256 public bathPerSecond;
    /// Running time of emissions (in seconds).
    uint256 public runningTime;
    /// Total amount of tokens to be emitted.
    uint256 public totalRewards;

    /* Events */

    event AddPool(address indexed user, uint256 indexed pid, uint256 allocPoint, uint256 totalAllocPoint, uint16 depositFee, uint16 withdrawFee);
    event ModifyPool(address indexed user, uint256 indexed pid, uint256 allocPoint, uint256 totalAllocPoint, uint16 depositFee, uint16 withdrawFee);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, uint256 depositFee);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, uint16 withdrawFee);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(address indexed user, uint256 amount);
    event UpdateFeeCollector(address indexed user, address feeCollector);
    event RecoverUnsupported(address indexed user, address token, uint256 amount, address targetAddress);
    event EmissionRateUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);

    /// Default constructor.
    /// @param _bathAddress Address of BATH token.
    /// @param _poolStartTime Emissions start time.
    /// @param _runningTime Running time of emissions (in seconds).
    /// @param _bathPerSecond bath Per Second
    /// @param _feeCollector Address where the deposit fees are transferred.
    constructor(
        address _bathAddress,
        uint256 _poolStartTime,
        uint256 _runningTime,
        uint256 _bathPerSecond,
        address _feeCollector,
        address _mrkgFeeCollector,
        address _devFeeCollector
    ) {
        require(block.timestamp < _poolStartTime, "late");
        require(_feeCollector != address(0), "Address cannot be 0");
        require(_mrkgFeeCollector != address(0), "Address cannot be 0");
        require(_runningTime >= 1 days, "Running time has to be at least 1 day");

        if (_bathAddress != address(0)) bath = IERC20(_bathAddress);

        poolStartTime = _poolStartTime;
        runningTime = _runningTime;
        poolEndTime = poolStartTime + runningTime;

        bathPerSecond = _bathPerSecond;

        feeCollector = _feeCollector;
        mrkgFeeCollector = _mrkgFeeCollector;
        devFeeCollector = _devFeeCollector;
        poolofficer = msg.sender;
    }
    modifier onlyOwnerOrOfficer() {
        require(owner() == msg.sender || poolofficer == msg.sender, "Caller is not the owner or the officer");
        _;
    }
    /// Check if a pool already exists for specified token.
    /// @param _token Address of token to check for existing pools
    function checkPoolDuplicate(IERC20 _token) internal view {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            require(poolInfo[pid].token != _token, "BathGenesisRewardPool: existing pool?");
        }
    }

    /// Add a new pool.
    /// @param _allocPoint Allocations points assigned to the pool
    /// @param _token Address of token to be staked in the pool
    /// @param _depositFee Deposit fee in % (where 100 == 1%)
    /// @param _withdrawFee Deposit fee in % (where 100 == 1%)
    /// @param _withUpdate Whether to trigger update of all existing pools
    /// @param _lastRewardTime Start time of the emissions from the pool

    /// @dev Can only be called by the Operator.
    function add(
        uint256 _allocPoint,
        IERC20 _token,
        uint16 _depositFee,
        uint16 _withdrawFee,
        bool _withUpdate,
        uint256 _lastRewardTime
    ) public onlyOwnerOrOfficer {
        _token.balanceOf(address(this));    // guard to revert calls that try to add non-IERC20 addresses
        require(_depositFee <= 1500, "Deposit fee cannot be higher than 15%");
        checkPoolDuplicate(_token);
        if (_withUpdate) {
            massUpdatePools();
        }
        if (block.timestamp < poolStartTime) {
            // chef is sleeping
            if (_lastRewardTime == 0) {
                _lastRewardTime = poolStartTime;
            } else {
                if (_lastRewardTime < poolStartTime) {
                    _lastRewardTime = poolStartTime;
                }
            }
        } else {
            // chef is cooking
            if (_lastRewardTime == 0 || _lastRewardTime < block.timestamp) {
                _lastRewardTime = block.timestamp;
            }
        }
        bool _isStarted =
        (_lastRewardTime <= poolStartTime) ||
        (_lastRewardTime <= block.timestamp);
        poolInfo.push(PoolInfo({
            token : _token,
            allocPoint : _allocPoint,
            lastRewardTime : _lastRewardTime,
            accBathPerShare : 0,
            depositFee : _depositFee,
            withdrawFee : _withdrawFee,
            isStarted : _isStarted,
            poolClaimedBath : 0,
            isExpired : false
            }));
        if (_isStarted) {
            totalAllocPoint = totalAllocPoint + _allocPoint;
        }

        emit AddPool(msg.sender, poolInfo.length - 1, _allocPoint, totalAllocPoint, _depositFee, _withdrawFee);
    }

    /// Update the given pool's parameters.
    /// @param _pid Id of an existing pool
    /// @param _allocPoint New allocations points assigned to the pool
    /// @param _depositFee New deposit fee assigned to the pool
    /// @param _withdrawFee New deposit fee assigned to the pool
    /// @dev Can only be called by the Operator.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFee, uint16 _withdrawFee) public onlyOwnerOrOfficer {
        require(_depositFee <= 1500, "Deposit fee cannot be higher than 15%");
        require(_withdrawFee <= 1500, "Withdarw fee cannot be higher than 15%");
        massUpdatePools();
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.isStarted) {
            totalAllocPoint = (totalAllocPoint - pool.allocPoint) + _allocPoint;
        }
        pool.allocPoint = _allocPoint;
        pool.depositFee = _depositFee;
        pool.withdrawFee = _withdrawFee;
        emit ModifyPool(msg.sender, _pid, _allocPoint, totalAllocPoint, _depositFee, _withdrawFee);
    }

    /// Return amount of accumulated rewards over the given time, according to the bath per second emission.
    /// @param _fromTime Time from which the generated rewards should be calculated
    /// @param _toTime Time to which the generated rewards should be calculated
    function getGeneratedReward(uint256 _fromTime, uint256 _toTime) public view returns (uint256) {
        if (_fromTime >= _toTime) return 0;
        if (_toTime >= poolEndTime) {
            if (_fromTime >= poolEndTime) return 0;
            if (_fromTime <= poolStartTime) return (poolEndTime - poolStartTime) * bathPerSecond;
            return (poolEndTime - _fromTime) * bathPerSecond;
        } else {
            if (_toTime <= poolStartTime) return 0;
            if (_fromTime <= poolStartTime) return (_toTime - poolStartTime) * bathPerSecond;
            return (_toTime - _fromTime) * bathPerSecond;
        }
    }

    /// Estimate pending rewards for specific user.
    /// @param _pid Id of an existing pool
    /// @param _user Address of a user for which the pending rewards should be calculated
    /// @return Amount of pending rewards for specific user
    /// @dev To be used in UI

    function pendingBaths(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBathPerShare = pool.accBathPerShare;
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && tokenSupply != 0 && pool.isExpired != true) {
            uint256 _generatedReward = getGeneratedReward(pool.lastRewardTime, block.timestamp);
            uint256 _bathReward = (_generatedReward * pool.allocPoint) / totalAllocPoint;
            accBathPerShare = accBathPerShare + ((_bathReward * 1e18) / tokenSupply);
        }
        return ((user.amount * accBathPerShare) / 1e18) - user.rewardDebt;
    }
    /// Update reward variables for all pools.
    /// @dev Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    /// Update reward variables of the given pool to be up-to-date.
    /// @param _pid Id of the pool to be updated
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        if (pool.isExpired) {
            return;
        }
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (tokenSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        if (!pool.isStarted) {
            pool.isStarted = true;
            totalAllocPoint = totalAllocPoint + pool.allocPoint;
        }
        if (totalAllocPoint > 0) {
            uint256 _generatedReward = getGeneratedReward(pool.lastRewardTime, block.timestamp);
            uint256 _bathReward = (_generatedReward * pool.allocPoint) / totalAllocPoint;
            pool.accBathPerShare = pool.accBathPerShare + ((_bathReward * 1e18) / tokenSupply);
        }
        pool.lastRewardTime = block.timestamp;
    }

    /// Deposit tokens in a pool.
    /// @param _pid Id of the chosen pool
    /// @param _amount Amount of tokens to be staked in the pool
    function deposit(uint256 _pid, uint256 _amount) public {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        updatePool(_pid);
        require(pool.isExpired != true, "Expired Pool");
        if (user.amount > 0) {
            uint256 _pending = ((user.amount * pool.accBathPerShare) / 1e18) - user.rewardDebt;
            if (_pending > 0) {
                safeBathTransfer(_sender, _pending);
                emit RewardPaid(_sender, _pending);
            }
        }
        if (_amount > 0) {
            if(pool.depositFee > 0 && !isExcludedFromFees[_sender]) {
                uint256 depositFeeAmount = (_amount * pool.depositFee) / 10000;
                uint halfDepositFeeAmount = depositFeeAmount / 2;
                uint quarterDepositFeeAmount = halfDepositFeeAmount / 2;
                user.amount = user.amount + (_amount - depositFeeAmount);

                pool.token.safeTransferFrom(_sender, feeCollector, halfDepositFeeAmount);
                pool.token.safeTransferFrom(_sender, mrkgFeeCollector, quarterDepositFeeAmount);
                pool.token.safeTransferFrom(_sender, devFeeCollector, quarterDepositFeeAmount);
                pool.token.safeTransferFrom(_sender, address(this), _amount - depositFeeAmount);
            } else {
                user.amount = user.amount + _amount;
                pool.token.safeTransferFrom(_sender, address(this), _amount);
            }
        }
        user.rewardDebt = (user.amount * pool.accBathPerShare) / 1e18;
        emit Deposit(_sender, _pid, _amount, pool.depositFee);
    }

    /// Withdraw tokens from a pool.
    /// @param _pid Id of the chosen pool
    /// @param _amount Amount of tokens to be withdrawn from the pool
    function withdraw(uint256 _pid, uint256 _amount) public {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 bathBalance = bath.balanceOf(address(this));
        uint256 _pending = ((user.amount * pool.accBathPerShare) / 1e18) - user.rewardDebt;

        if (_pending > 0 && bathBalance > _pending) {
            safeBathTransfer(_sender, _pending);
            user.claimedBath = user.claimedBath + _pending;
            pool.poolClaimedBath = pool.poolClaimedBath + _pending;
            emit RewardPaid(_sender, _pending);
        }
        if (_amount > 0) {
            if(pool.withdrawFee > 0) {
                uint256 withdrawFeeAmount = (_amount * pool.withdrawFee) / 10000;
                uint halfWithdrawFeeAmount = withdrawFeeAmount / 2;
                uint quarterWithdrawFeeAmount = halfWithdrawFeeAmount / 2;

                pool.token.safeTransfer(feeCollector, halfWithdrawFeeAmount);
                pool.token.safeTransfer(mrkgFeeCollector, quarterWithdrawFeeAmount);
                pool.token.safeTransfer(devFeeCollector, quarterWithdrawFeeAmount);
                pool.token.safeTransfer(_sender, _amount - withdrawFeeAmount);
            }
            else {
                pool.token.safeTransfer(_sender, _amount);
            }
            user.amount = user.amount - _amount;
        }
        user.rewardDebt = (user.amount * pool.accBathPerShare) / 1e18;

        emit Withdraw(_sender, _pid, _amount, pool.withdrawFee);
    }

    /// Withdraw tokens from a pool without rewards. ONLY IN CASE OF EMERGENCY.
    /// @param _pid Id of the chosen pool
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 _amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.token.safeTransfer(msg.sender, _amount);
        emit EmergencyWithdraw(msg.sender, _pid, _amount);
    }

    /// Safe BATH transfer function.
    /// @param _to Recipient address of the transfer
    /// @param _amount Amount of tokens to be transferred
    /// @dev Used just in case if rounding error causes pool to not have enough BATH.
    function safeBathTransfer(address _to, uint256 _amount) internal {
        uint256 _bathBal = bath.balanceOf(address(this));
        if (_bathBal > 0) {
            if (_amount > _bathBal) {
                bath.safeTransfer(_to, _bathBal);
            } else {
                bath.safeTransfer(_to, _amount);
            }
        }
    }

    /// Set a new deposit fees collector address.
    /// @param _feeCollector A new deposit fee collector address
    /// @dev Can only be called by the Operator
    function setFeeCollector(address _feeCollector) external onlyOwner {
        require(_feeCollector != address(0), "Address cannot be 0");
        feeCollector = _feeCollector;
        emit UpdateFeeCollector(msg.sender, address(_feeCollector));
    }

    function setMrkgFeeCollector(address _mrkgFeeCollector) external onlyOwner {
        require(_mrkgFeeCollector != address(0), "Address cannot be 0");
        mrkgFeeCollector = _mrkgFeeCollector;
        emit UpdateFeeCollector(msg.sender, address(_mrkgFeeCollector));
    }

    function setDevFeeCollector(address _devFeeCollector) external onlyOwner {
        require(_devFeeCollector != address(0), "Address cannot be 0");
        devFeeCollector = _devFeeCollector;
        emit UpdateFeeCollector(msg.sender, address(_devFeeCollector));
    }

    function clearReward(uint256 _amount, address _receiver) public onlyOwnerOrOfficer{
        safeBathTransfer(_receiver, _amount);
    }

    function remove(uint256 _pid) public onlyOwnerOrOfficer {
        massUpdatePools();
        PoolInfo storage pool = poolInfo[_pid];
        pool.isExpired = true;
    }
    function updateEmissionRate(uint256 _bathPerSecond) public onlyOwnerOrOfficer {
        massUpdatePools();
        emit EmissionRateUpdated(msg.sender, bathPerSecond, _bathPerSecond);
        bathPerSecond = _bathPerSecond;
    }

    /// Transferred tokens sent to the contract by mistake.
    /// @param _token Address of token to be transferred (cannot be staking nor the reward token)
    /// @param _amount Amount of tokens to be transferred
    /// @param _to Recipient address of the transfer
    /// @dev Can only be called by the Operator
    function governanceRecoverUnsupported(IERC20 _token, uint256 _amount, address _to) external onlyOwnerOrOfficer {
        if (block.timestamp < poolEndTime + 7 days) {
            // do not allow to drain core token (BATH or lps) if less than 7 days after pool ends
            require(_token != bath, "BATH");
            uint256 length = poolInfo.length;
            for (uint256 pid = 0; pid < length; ++pid) {
                PoolInfo storage pool = poolInfo[pid];
                require(_token != pool.token, "pool.token");
            }
        }
        _token.safeTransfer(_to, _amount);
        emit RecoverUnsupported(msg.sender, address(_token), _amount, _to);
    }

    function setIsExcludedFromFees(address _address, bool _isExcluded) public onlyOwnerOrOfficer {
        isExcludedFromFees[_address] = _isExcluded;
    }

    receive() external payable {}

    function setPoolOfficer(address _poolofficer) public onlyOwner {
        poolofficer = _poolofficer;
    }
}