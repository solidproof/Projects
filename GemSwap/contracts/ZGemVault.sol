// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: not owner");
        _;
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

/**
 * @dev Farm vault contract.
 * Users stake xZGem tokens into the vault to earn the corresponding tokens for the pool. 
 */
contract ZGemVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Max harvest interval: 14 days
    uint256 public constant MAXIMUM_HARVEST_INTERVAL = 14 days;

    // Info of each user.
    struct UserInfo {
        uint256 amount;             // How many x tokens the user has staked.
        uint256 rewardDebt;         // Reward debt.
        uint256 rewardLockedUp;     // Reward locked up.
        uint256 nextHarvestUntil;   // When can the user harvest again.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;             // Address of LP token contract open to users to mine.
        uint256 outputTime;         // Mining pool supply sustainable time. ie. 7days
        uint256 lastRewardTime;     // Last block timestamp that rewards distribution occurs.
        uint256 earnTokenPerShare;  // Accumulated rewards per share, times 1e12. See below.
        uint256 harvestInterval;    // Harvest interval in seconds.
        uint256 totalStakedToken;   // Total x tokens staked in Pool.
        bool status;                // Pool status.
    }

    // Stake token: xZGem
    IERC20 public stakeToken;

    // Info of each pool
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // The block timestamp when mining starts.
    uint256 public startTime;

    // Total locked up rewards
    uint256 public totalLockedUpRewards;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardLockedUp(address indexed user, uint256 indexed pid, uint256 amountLockedUp);

    /**
     * @dev Constructor
     * @param   _token  xzgem token address
     */
    constructor(address _token) {
        //StartTime always many years later from contract construct, will be set later in StartFarming function
        startTime = block.timestamp + (10 * 365 * 24 * 60 * 60);

        stakeToken = IERC20(_token);
    }

    // Return reward multiplier over the given _from time to _to time.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to - _from;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // View function to see pending rewards on frontend.
    function pendingRewards(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 earnTokenPerShare = pool.earnTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (
            block.timestamp > pool.lastRewardTime && 
            lpSupply > 0 && 
            pool.totalStakedToken > 0 && 
            pool.outputTime > 0
        ) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardTime,
                block.timestamp
            );
            uint256 tokenReward = multiplier * lpSupply / pool.outputTime;
            earnTokenPerShare += tokenReward * 1e12 / pool.totalStakedToken;
        }

        uint256 pending = user.amount * earnTokenPerShare / 1e12 - user.rewardDebt;
        return pending + user.rewardLockedUp;
    }

    // View function to see if user can harvest earnToken.
    function canHarvest(uint256 _pid, address _user) public view returns (bool) {
        UserInfo memory user = userInfo[_pid][_user];
        return
            block.timestamp >= startTime &&
            block.timestamp >= user.nextHarvestUntil;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }

        uint256 supply = pool.lpToken.balanceOf(address(this));
        if (supply == 0 || pool.totalStakedToken == 0 || pool.outputTime == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        uint256 tokenReward = multiplier * supply / pool.outputTime;

        pool.earnTokenPerShare += tokenReward * 1e12 / pool.totalStakedToken;
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit tokens to the pool for earnToken allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        require(block.timestamp >= startTime, "Can not deposit before start");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.status == true, "Invalid pool");

        UserInfo storage user = userInfo[_pid][_msgSender()];

        updatePool(_pid);
        payOrLockPendingRewards(_pid);

        if (_amount > 0) {
            uint256 beforeDeposit = stakeToken.balanceOf(address(this));
            stakeToken.safeTransferFrom(_msgSender(), address(this), _amount);
            uint256 afterDeposit = stakeToken.balanceOf(address(this));

            _amount = afterDeposit - beforeDeposit;
            user.amount += _amount;
            pool.totalStakedToken += _amount;
        }
        user.rewardDebt = user.amount * pool.earnTokenPerShare / 1e12;
        emit Deposit(_msgSender(), _pid, _amount);
    }

    // Withdraw tokens from the pool.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        require(block.timestamp >= startTime, "Can not withdraw before start");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        // Make sure that user can only withdraw from his pool
        require(user.amount >= _amount, "User amount not enough");
        // Cannot withdraw more than pool's staked
        require(pool.totalStakedToken >= _amount, "Pool total not enough");
        // Cannot withdraw more than pool's balance
        require(stakeToken.balanceOf(address(this)) >= _amount, "Pool balance not enough");

        updatePool(_pid);
        payOrLockPendingRewards(_pid);

        if (_amount > 0) {
            user.amount -= _amount;
            pool.totalStakedToken -= _amount;
            stakeToken.safeTransfer(_msgSender(), _amount);
        }
        user.rewardDebt = user.amount * pool.earnTokenPerShare / 1e12;
        emit Withdraw(_msgSender(), _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        uint256 amount = user.amount;

        // Make sure that user have available amount
        require(amount > 0, "User amount not enough");
        // Cannot withdraw more than pool's staked
        require(pool.totalStakedToken >= amount, "Pool total not enough");
        // Cannot withdraw more than pool's balance
        require(stakeToken.balanceOf(address(this)) >= amount, "Pool balance not enough");

        user.amount = 0;
        user.rewardDebt = 0;
        if (totalLockedUpRewards >= user.rewardLockedUp) {
            totalLockedUpRewards -= user.rewardLockedUp;
        }
        user.rewardLockedUp = 0;
        user.nextHarvestUntil = 0;
        pool.totalStakedToken -= amount;

        stakeToken.safeTransfer(_msgSender(), amount);

        emit EmergencyWithdraw(_msgSender(), _pid, amount);
    }

    // Calculate the benefits that users can earned and than handle the transfer.
    function payOrLockPendingRewards(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        if (user.nextHarvestUntil == 0) {
            user.nextHarvestUntil = block.timestamp + pool.harvestInterval;
        }

        uint256 pending = user.amount * pool.earnTokenPerShare / 1e12 - user.rewardDebt;
        if (canHarvest(_pid, _msgSender())) {
            if (pending > 0 || user.rewardLockedUp > 0) {
                uint256 totalRewards = pending + user.rewardLockedUp;

                totalLockedUpRewards -= user.rewardLockedUp;
                user.rewardLockedUp = 0;
                user.nextHarvestUntil = block.timestamp + pool.harvestInterval;

                pool.lpToken.safeTransfer(_msgSender(), totalRewards);
            }
        } else if (pending > 0) {
            user.rewardLockedUp += pending;
            totalLockedUpRewards += pending;
            emit RewardLockedUp(_msgSender(), _pid, pending);
        }
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // The same LP token can only have one corresponding mining pool.
    function add(
        IERC20 _lpToken,
        uint256 _outputTime,
        uint256 _harvestInterval,
        bool _withUpdate
    ) public onlyOwner {
        require(_harvestInterval <= MAXIMUM_HARVEST_INTERVAL, "Harvest interval too high");

        if (_withUpdate) massUpdatePools();
        uint256 lastRewardTime = block.timestamp > startTime
            ? block.timestamp
            : startTime;
        
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                outputTime: _outputTime,
                lastRewardTime: lastRewardTime,
                harvestInterval: _harvestInterval,
                earnTokenPerShare: 0,
                totalStakedToken: 0,
                status: true
            })
        );
    }

    // Update the given pool's output time and harvest interval.
    function set(
        uint256 _pid,
        uint256 _outputTime,
        uint256 _harvestInterval,
        bool _status,
        bool _withUpdate
    ) public onlyOwner {
        require(_harvestInterval <= MAXIMUM_HARVEST_INTERVAL, "Harvest interval too high");

        if (_withUpdate) massUpdatePools();

        poolInfo[_pid].outputTime = _outputTime;
        poolInfo[_pid].harvestInterval = _harvestInterval;
        poolInfo[_pid].status = _status;
    }

    // Set farming start, only can be call once
    function startFarming() public onlyOwner {
        require(block.timestamp < startTime, "Farm started already");

        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            poolInfo[pid].lastRewardTime = block.timestamp;
        }

        startTime = block.timestamp;
    }
}
