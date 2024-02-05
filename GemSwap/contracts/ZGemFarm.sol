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

interface IZERC20 is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

/**
 * @dev Mining pool contract.
 * Users stakes LP tokens to the corresponding mining pool to earn ZGem. 
 * The earned tokens are divided into two parts: instant release and installment unlocking.
 * Users can pledge xZGem to this contract to increase the release speed.
 */
contract ZGemFarm is Ownable, ReentrancyGuard {
    using SafeERC20 for IZERC20;

    // Percent cardinality
    uint256 public constant CARDINALITY = 100000;        
    // Maximum locked percent: 90%
    uint256 public constant MAXIMUM_LOCKED_PERCENT = 90000;
    // Maximum deposit fee rate: 10%
    uint256 public constant MAXIMUM_DEPOSIT_FEE_RATE = 10000;
    // Max harvest interval: 14 days
    uint256 public constant MAXIMUM_HARVEST_INTERVAL = 14 days;

    // Info of each user.
    struct UserInfo {
        uint256 amount;             // How many LP tokens the user has staked.
        uint256 rewardDebt;         // Reward debt.
        uint256 rewardLockedUp;     // Reward locked up.
        uint256 rewardReleased;     // Reward released, can for harvest.
        uint256 latestHarvestTime;  // User's last harvest time.
        uint256 nextHarvestUntil;   // When can the user harvest again.
        uint256 releaseTokenAmount; // How many release tokens the user has staked.
    }

    // Info of each pool.
    struct PoolInfo {
        IZERC20 lpToken;            // Address of LP token contract.
        address vaultAddress;       // Address of fee receiver.
        uint256 allocPoint;         // How many allocation points assigned to this pool.
        uint256 lastRewardTime;     // Last block timestamp that rewards distribution occurs.
        uint256 earnTokenPerShare;  // Accumulated rewards per share, times 1e12. See below.
        uint256 depositFeeBP;       // Deposit fee in basis points, based on CARDINALITY.
        uint256 harvestInterval;    // Harvest interval in seconds.
        uint256 totalLp;            // Total tokens staked in Pool.
        uint256 totalReleaseToken;  // Total release tokens staked in Pool.
    }

    // Rewards token: ZGem
    IMintableERC20 public earnToken;
    // Release token: xZGem
    IZERC20 public releaseToken;

    uint256 public lockedPercent = 80000;               // 80% of the rewards will be locked
    uint256 public releaseSpeedPerToken = 5;            // 0.005% release speed added by per release token staked
    uint256 public releaseTokenMaxPerPool = 2000;       // Max release tokens can be staked into the pool

    // Earn tokens created every second
    uint256 public earnTokenPerSecond;

    // Info of each pool
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The block timestamp when mining starts.
    uint256 public startTime;

    // Total locked up rewards
    uint256 public totalLockedUpRewards;

    // Total wait harvest rewards
    uint256 public totalWaitHarvestRewards;

    // Total EarnToken in Pools (can be multiple pools)
    uint256 public totalEarnTokenInPools = 0;

    // The operator can only update EmissionRate and AllocPoint to protect tokenomics
    //i.e some wrong setting and a pools get too much allocation accidentally
    address private _operator;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event DepositReleaseToken(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event WithdrawReleaseToken(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount, uint256 releaseTokenAmount);
    event EmissionRateUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);
    event RewardLockedUp(address indexed user, uint256 indexed pid, uint256 amountLockedUp, uint256 amountReleased);
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    event AllocPointsUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);

    modifier onlyOperator() {
        require(_operator == msg.sender, "Caller is not the operator");
        _;
    }

    /**
     * @dev Constructor
     * @param   _token          earnToken address
     * @param   _tokenPerSecond earn per second
     * @param   _releaseToken   release token address
     */
    constructor(address _token, uint256 _tokenPerSecond, address _releaseToken) {
        //StartTime always many years later from contract construct, will be set later in StartFarming function
        startTime = block.timestamp + (10 * 365 * 24 * 60 * 60);

        earnToken = IMintableERC20(_token);
        earnTokenPerSecond = _tokenPerSecond;
        releaseToken = IZERC20(_releaseToken);
        releaseTokenMaxPerPool = releaseTokenMaxPerPool * 10**releaseToken.decimals();

        _operator = msg.sender;
        emit OperatorTransferred(address(0), _operator);
    }

    function operator() public view returns (address) {
        return _operator;
    }

    // Return reward multiplier over the given _from time to _to time.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to - _from;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // View function to see pending rewards on frontend.
    function pendingRewards(uint256 _pid, address _user) external view returns (uint256 locked, uint256 released) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 earnTokenPerShare = pool.earnTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (block.timestamp > pool.lastRewardTime && lpSupply > 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardTime,
                block.timestamp
            );
            uint256 tokenReward = multiplier * earnTokenPerSecond * pool.allocPoint / totalAllocPoint;
            earnTokenPerShare += tokenReward * 1e12 / lpSupply;
        }

        if (user.amount > 0) {
            uint256 pending = user.amount * earnTokenPerShare / 1e12 - user.rewardDebt;
            uint256 needLocked = pending * lockedPercent / CARDINALITY;
            uint256 willReleased = pending - needLocked;
            locked = user.rewardLockedUp;
            released = user.rewardReleased;
            if (pending > 0) {
                uint256 timeLongReleased = 0;
                if (user.releaseTokenAmount > 0 && user.rewardLockedUp > 0) {
                    uint256 timeLong = block.timestamp - user.latestHarvestTime;
                    uint256 releaseSpeedDaily = user.releaseTokenAmount * releaseSpeedPerToken / 10**releaseToken.decimals();
                    timeLongReleased = user.rewardLockedUp * timeLong * releaseSpeedDaily / 86400 / CARDINALITY;
                }
                locked = locked + needLocked - timeLongReleased;
                released = released + willReleased + timeLongReleased;
            }
        }
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

        uint256 lpSupply = pool.totalLp;
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        uint256 rewardsPerSecond = multiplier * earnTokenPerSecond * pool.allocPoint / totalAllocPoint;

        pool.earnTokenPerShare += rewardsPerSecond * 1e12 / pool.totalLp;
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit tokens to the pool for earnToken allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        require(block.timestamp >= startTime, "Can not deposit before start");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.allocPoint > 0, "Invalid pool");

        UserInfo storage user = userInfo[_pid][_msgSender()];

        updatePool(_pid);
        payOrLockPendingRewards(_pid);

        if (_amount > 0) {
            uint256 beforeDeposit = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(_msgSender(), address(this), _amount);
            uint256 afterDeposit = pool.lpToken.balanceOf(address(this));

            _amount = afterDeposit - beforeDeposit;

            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount * pool.depositFeeBP / CARDINALITY;
                pool.lpToken.safeTransfer(pool.vaultAddress, depositFee);

                _amount -= depositFee;
            }

            user.amount += _amount;
            pool.totalLp += _amount;

            if (address(pool.lpToken) == address(earnToken)) {
                totalEarnTokenInPools += _amount;
            }
        }
        user.rewardDebt = user.amount * pool.earnTokenPerShare / 1e12;
        emit Deposit(_msgSender(), _pid, _amount);
    }

    // Deposit release tokens to the pool for accelerate the release speed of locked tokens.
    function depositReleaseToken(uint256 _pid, uint256 _amount) public nonReentrant {
        require(block.timestamp >= startTime, "Can not deposit before start");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.allocPoint > 0, "Invalid pool");

        UserInfo storage user = userInfo[_pid][_msgSender()];
        require(user.amount > 0, "Have no deposited any lp token");
        require(user.releaseTokenAmount + _amount <= releaseTokenMaxPerPool, "Cannot deposit more");

        updatePool(_pid);
        payOrLockPendingRewards(_pid);

        if (_amount > 0) {
            releaseToken.safeTransferFrom(_msgSender(), address(this), _amount);
            user.releaseTokenAmount += _amount;
            pool.totalReleaseToken += _amount;
            emit DepositReleaseToken(_msgSender(), _pid, _amount);
        }
        user.rewardDebt = user.amount * pool.earnTokenPerShare / 1e12;
    }

    // Withdraw tokens from the pool.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        require(block.timestamp >= startTime, "Can not withdraw before start");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        // Make sure that user can only withdraw from his pool
        require(user.amount >= _amount, "User amount not enough");
        // Cannot withdraw more than pool's balance
        require(pool.totalLp >= _amount, "Pool total not enough");

        updatePool(_pid);
        payOrLockPendingRewards(_pid);

        if (_amount > 0) {
            user.amount -= _amount;
            pool.totalLp -= _amount;
            if (address(pool.lpToken) == address(earnToken)) {
                totalEarnTokenInPools -= _amount;
            }
            pool.lpToken.safeTransfer(_msgSender(), _amount);
        }
        user.rewardDebt = user.amount * pool.earnTokenPerShare / 1e12;
        emit Withdraw(_msgSender(), _pid, _amount);
    }

    // Withdraw release tokens from the pool.
    function withdrawReleaseToken(uint256 _pid, uint256 _amount) public nonReentrant {
        require(block.timestamp >= startTime, "Can not withdraw before start");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        require(user.releaseTokenAmount >= _amount, "User amount not enough");
        require(pool.totalReleaseToken >= _amount, "Pool total not enough");

        updatePool(_pid);
        payOrLockPendingRewards(_pid);

        if (_amount > 0) {
            pool.totalReleaseToken -= _amount;
            user.releaseTokenAmount -= _amount;
            releaseToken.safeTransfer(_msgSender(), _amount);
            emit WithdrawReleaseToken(_msgSender(), _pid, _amount);
        }
        user.rewardDebt = user.amount * pool.earnTokenPerShare / 1e12;
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        uint256 amount = user.amount;

        // Make sure that user have available amount
        require(amount > 0, "User amount not enough");
        // Cannot withdraw more than pool's balance
        require(pool.totalLp >= amount, "Pool total not enough");

        user.amount = 0;
        user.rewardDebt = 0;
        if (totalLockedUpRewards >= user.rewardLockedUp) {
            totalLockedUpRewards -= user.rewardLockedUp;
        }
        user.rewardLockedUp = 0;
        if (totalWaitHarvestRewards >= user.rewardReleased) {
            totalWaitHarvestRewards -= user.rewardReleased;
        }
        user.rewardReleased = 0;
        user.nextHarvestUntil = 0;
        user.latestHarvestTime = 0;
        pool.totalLp -= amount;
        if (address(pool.lpToken) == address(earnToken)) {
            totalEarnTokenInPools -= amount;
        }

        pool.lpToken.safeTransfer(_msgSender(), amount);
        
        uint256 rAmount = user.releaseTokenAmount;
        if (rAmount > 0) {
            user.releaseTokenAmount = 0;
            if (pool.totalReleaseToken >= rAmount) {
                pool.totalReleaseToken -= rAmount;
            }
            releaseToken.safeTransfer(_msgSender(), rAmount);
        }

        emit EmergencyWithdraw(_msgSender(), _pid, amount, rAmount);
    }

    // Calculate the benefits that users can receive and need to lock, and perform related operations.
    function payOrLockPendingRewards(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        if (user.nextHarvestUntil == 0) {
            user.nextHarvestUntil = block.timestamp + pool.harvestInterval;
        }
        if (user.latestHarvestTime == 0) {
            user.latestHarvestTime = block.timestamp;
        }

        uint256 pending = user.amount * pool.earnTokenPerShare / 1e12 - user.rewardDebt;
        uint256 needLocked = pending * lockedPercent / CARDINALITY;
        uint256 released = pending - needLocked;
        if (canHarvest(_pid, _msgSender())) {
            if (pending > 0 || user.rewardReleased > 0 || user.rewardLockedUp > 0) {
                uint256 totalRewards = released + user.rewardReleased;
                uint256 timeLongReleased = 0;
                if (user.releaseTokenAmount > 0 && user.rewardLockedUp > 0) {
                    uint256 timeLong = block.timestamp - user.latestHarvestTime;
                    uint256 releaseSpeedDaily = user.releaseTokenAmount * releaseSpeedPerToken / 10**releaseToken.decimals();
                    timeLongReleased = user.rewardLockedUp * timeLong * releaseSpeedDaily / 86400 / CARDINALITY;
                }
                totalRewards += timeLongReleased;

                user.rewardLockedUp = user.rewardLockedUp + needLocked - timeLongReleased;
                totalLockedUpRewards = totalLockedUpRewards + needLocked - timeLongReleased;
                totalWaitHarvestRewards -= user.rewardReleased;
                user.rewardReleased = 0;
                user.nextHarvestUntil = block.timestamp + pool.harvestInterval;
                user.latestHarvestTime = block.timestamp;

                // Mint earn tokens to the user
                earnToken.mint(_msgSender(), totalRewards);
            }
        } else if (pending > 0) {
            user.rewardLockedUp += needLocked;
            totalLockedUpRewards += needLocked;
            user.rewardReleased += released;
            totalWaitHarvestRewards += released;
            emit RewardLockedUp(_msgSender(), _pid, needLocked, released);
        }
    }

    /** Operator */

    function setLockAndRelease(uint256 _lockedPercent, uint256 _releasePerToken, uint256 _releaseMax) public onlyOperator {
        require(_lockedPercent <= MAXIMUM_LOCKED_PERCENT, "Connot too high");
        lockedPercent = _lockedPercent;
        releaseSpeedPerToken = _releasePerToken;
        releaseTokenMaxPerPool = _releaseMax;
    }

    function updateEmissionRate(uint256 _tokenPerSecond) public onlyOperator {
        massUpdatePools();

        emit EmissionRateUpdated(msg.sender, earnTokenPerSecond, _tokenPerSecond);
        earnTokenPerSecond = _tokenPerSecond;
    }

    function updateAllocPoint(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOperator {
        if (_withUpdate) {
            massUpdatePools();
        }

        emit AllocPointsUpdated(_msgSender(), poolInfo[_pid].allocPoint, _allocPoint);

        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function transferOperator(address newOperator) public onlyOperator {
        require(newOperator != address(0), "New operator is the zero address");
        emit OperatorTransferred(_operator, newOperator);
        _operator = newOperator;
    }

    /** Owner */

    // Add a new lp to the pool. Can only be called by the owner.
    // Can add multiple pool with same lp token without messing up rewards, because each pool's balance is tracked using its own totalLp
    function add(
        uint256 _allocPoint,
        IZERC20 _lpToken,
        address _vaultAddr,
        uint256 _depositFeeBP,
        uint256 _harvestInterval,
        bool _withUpdate
    ) public onlyOwner {
        require(_depositFeeBP <= MAXIMUM_DEPOSIT_FEE_RATE, "Deposit fee too high");
        require(_harvestInterval <= MAXIMUM_HARVEST_INTERVAL, "Harvest interval too high");

        if (_withUpdate) massUpdatePools();
        uint256 lastRewardTime = block.timestamp > startTime
            ? block.timestamp
            : startTime;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                vaultAddress: _vaultAddr,
                allocPoint: _allocPoint,
                lastRewardTime: lastRewardTime,
                earnTokenPerShare: 0,
                depositFeeBP: _depositFeeBP,
                harvestInterval: _harvestInterval,
                totalLp: 0,
                totalReleaseToken: 0
            })
        );
    }

    // Update the given pool's allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint256 _depositFeeBP,
        uint256 _harvestInterval,
        address _vaultAddr,
        bool _withUpdate
    ) public onlyOwner {
        require(_depositFeeBP <= MAXIMUM_DEPOSIT_FEE_RATE, "Deposit fee too high");
        require(_harvestInterval <= MAXIMUM_HARVEST_INTERVAL, "Harvest interval too high");

        if (_withUpdate) massUpdatePools();
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
        poolInfo[_pid].harvestInterval = _harvestInterval;
        poolInfo[_pid].vaultAddress = _vaultAddr;
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
