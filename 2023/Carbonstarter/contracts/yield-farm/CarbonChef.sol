// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./rewarders/IMultipleRewards.sol";
import "./libraries/BoringERC20.sol";
import "../interfaces/IXCarbonStarterToken.sol";

contract CarbonChef is Ownable, ReentrancyGuard {
    using BoringERC20 for IBoringERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardLockedUp; // Reward locked up.
        uint256 nextHarvestUntil; // When can the user harvest again.
    }

    // Info of each pool.
    struct PoolInfo {
        IBoringERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Carbon to distribute per block.
        uint256 lastRewardTimestamp; // Last block number that Carbon distribution occurs.
        uint256 accCarbonPerShare; // Accumulated Carbon per share, times 1e18. See below.
        uint16 depositFeeBP; // Deposit fee in basis points
        uint256 harvestInterval; // Harvest interval in seconds
        uint256 totalLp; // Total token in Pool
        IMultipleRewards[] rewarders; // Array of rewarder contract for pools with incentives
    }

    IBoringERC20 public immutable carbon;

    // Carbon tokens created per second
    uint256 public carbonPerSec;

    // Max harvest interval: 14 days
    uint256 public constant MAXIMUM_HARVEST_INTERVAL = 14 days;

    // Maximum deposit fee rate: 10%
    uint16 public constant MAXIMUM_DEPOSIT_FEE_RATE = 10_00;

    // Info of each pool
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    // The timestamp when Carbon mining starts.
    uint256 public startTimestamp;

    // Total locked up rewards
    uint256 public totalLockedUpRewards;

    // Total Carbon in Carbon Pools (can be multiple pools)
    uint256 public totalCarbonInPools;

    // deposit fee address if needed
    address public feeAddress;

    // x token address
    address public immutable xCarbonToken;

    // x token ratio
    uint256 public xCarbonRatio = 100; // 100% of rewards distributed in xToken

    // The precision factor
    uint256 private constant ACC_TOKEN_PRECISION = 1e12;

    modifier validatePoolByPid(uint256 _pid) {
        require(_pid < poolInfo.length, "Pool does not exist");
        _;
    }

    event Add(
        uint256 indexed pid,
        uint256 allocPoint,
        IBoringERC20 indexed lpToken,
        uint16 depositFeeBP,
        uint256 harvestInterval,
        IMultipleRewards[] indexed rewarders
    );

    event Set(
        uint256 indexed pid,
        uint256 allocPoint,
        uint16 depositFeeBP,
        uint256 harvestInterval,
        IMultipleRewards[] indexed rewarders
    );

    event UpdatePool(
        uint256 indexed pid,
        uint256 lastRewardTimestamp,
        uint256 lpSupply,
        uint256 accCarbonPerShare
    );

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);

    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    event EmissionRateUpdated(
        address indexed caller,
        uint256 previousValue,
        uint256 newValue
    );

    event RewardLockedUp(
        address indexed user,
        uint256 indexed pid,
        uint256 amountLockedUp
    );

    event AllocPointsUpdated(
        address indexed caller,
        uint256 previousAmount,
        uint256 newAmount
    );

    event RewardPaid(address indexed user, uint256 indexed pid, uint256 reward);

    event XRewardPaid(
        address indexed user,
        uint256 indexed pid,
        uint256 xreward
    );

    event SetFeeAddress(address indexed oldAddress, address indexed newAddress);

    constructor(
        IBoringERC20 _carbon,
        uint256 _carbonPerSec,
        address _feeAddress,
        address _xCarbonToken
    ) {
        startTimestamp = block.timestamp + (60 * 60 * 24 * 365);

        carbon = _carbon;
        carbonPerSec = _carbonPerSec;
        feeAddress = _feeAddress;
        xCarbonToken = _xCarbonToken;
        IBoringERC20(_carbon).approve(_xCarbonToken, type(uint256).max);
    }

    // Set farming start, can call only once
    function startFarming() public onlyOwner {
        require(block.timestamp < startTimestamp, "farm already started");

        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ) {
            PoolInfo storage pool = poolInfo[pid];
            pool.lastRewardTimestamp = block.timestamp;
            unchecked {
                ++pid;
            }
        }

        startTimestamp = block.timestamp;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // Can add multiple pool with same lp token without messing up rewards, because each pool's balance is tracked using its own totalLp
    function add(
        uint256 _allocPoint,
        IBoringERC20 _lpToken,
        uint16 _depositFeeBP,
        uint256 _harvestInterval,
        IMultipleRewards[] calldata _rewarders
    ) public onlyOwner {
        require(_rewarders.length <= 10, "add: too many rewarders");
        require(
            _depositFeeBP <= MAXIMUM_DEPOSIT_FEE_RATE,
            "add: deposit fee too high"
        );
        require(
            _harvestInterval <= MAXIMUM_HARVEST_INTERVAL,
            "add: invalid harvest interval"
        );
        for (uint256 rewarderId = 0; rewarderId < _rewarders.length; ) {
            require(
                Address.isContract(address(_rewarders[rewarderId])),
                "add: rewarder must be contract"
            );
            unchecked {
                ++rewarderId;
            }
        }

        _massUpdatePools();

        uint256 lastRewardTimestamp = block.timestamp > startTimestamp
            ? block.timestamp
            : startTimestamp;

        totalAllocPoint += _allocPoint;

        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accCarbonPerShare: 0,
                depositFeeBP: _depositFeeBP,
                harvestInterval: _harvestInterval,
                totalLp: 0,
                rewarders: _rewarders
            })
        );

        emit Add(
            poolInfo.length - 1,
            _allocPoint,
            _lpToken,
            _depositFeeBP,
            _harvestInterval,
            _rewarders
        );
    }

    // Update the given pool's Carbon allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint16 _depositFeeBP,
        uint256 _harvestInterval,
        IMultipleRewards[] calldata _rewarders
    ) public onlyOwner validatePoolByPid(_pid) {
        require(_rewarders.length <= 10, "set: too many rewarders");

        require(
            _depositFeeBP <= MAXIMUM_DEPOSIT_FEE_RATE,
            "set: deposit fee too high"
        );
        require(
            _harvestInterval <= MAXIMUM_HARVEST_INTERVAL,
            "set: invalid harvest interval"
        );

        for (uint256 rewarderId = 0; rewarderId < _rewarders.length; ) {
            require(
                Address.isContract(address(_rewarders[rewarderId])),
                "set: rewarder must be contract"
            );
            unchecked {
                ++rewarderId;
            }
        }

        _massUpdatePools();

        PoolInfo storage pool = poolInfo[_pid];

        totalAllocPoint = totalAllocPoint - pool.allocPoint + _allocPoint;

        pool.allocPoint = _allocPoint;
        pool.depositFeeBP = _depositFeeBP;
        pool.harvestInterval = _harvestInterval;
        pool.rewarders = _rewarders;

        emit Set(
            _pid,
            _allocPoint,
            _depositFeeBP,
            _harvestInterval,
            _rewarders
        );
    }

    // View function to see pending rewards on frontend.
    function pendingTokens(
        uint256 _pid,
        address _user
    )
        external
        view
        validatePoolByPid(_pid)
        returns (
            address[] memory addresses,
            string[] memory symbols,
            uint256[] memory decimals,
            uint256[] memory amounts
        )
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCarbonPerShare = pool.accCarbonPerShare;
        uint256 lpSupply = pool.totalLp;

        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 multiplier = block.timestamp - pool.lastRewardTimestamp;

            uint256 carbonReward = (multiplier *
                carbonPerSec *
                pool.allocPoint) / totalAllocPoint;

            accCarbonPerShare += ((carbonReward * ACC_TOKEN_PRECISION) /
                lpSupply);
        }

        uint256 pendingCarbon = ((user.amount * accCarbonPerShare) /
            ACC_TOKEN_PRECISION) -
            user.rewardDebt +
            user.rewardLockedUp;

        uint256 rewardersLength = pool.rewarders.length;

        addresses = new address[](rewardersLength + 1);
        symbols = new string[](rewardersLength + 1);
        amounts = new uint256[](rewardersLength + 1);
        decimals = new uint256[](rewardersLength + 1);

        addresses[0] = address(carbon);
        symbols[0] = IBoringERC20(carbon).safeSymbol();
        decimals[0] = IBoringERC20(carbon).safeDecimals();
        amounts[0] = pendingCarbon;

        for (uint256 rewarderId = 0; rewarderId < rewardersLength; ) {
            addresses[rewarderId + 1] = address(
                pool.rewarders[rewarderId].rewardToken()
            );

            symbols[rewarderId + 1] = IBoringERC20(
                pool.rewarders[rewarderId].rewardToken()
            ).safeSymbol();

            decimals[rewarderId + 1] = IBoringERC20(
                pool.rewarders[rewarderId].rewardToken()
            ).safeDecimals();

            amounts[rewarderId + 1] = pool.rewarders[rewarderId].pendingTokens(
                _pid,
                _user
            );
            unchecked {
                ++rewarderId;
            }
        }
    }

    /// @notice View function to see pool rewards per sec
    function poolRewardsPerSec(
        uint256 _pid
    )
        external
        view
        validatePoolByPid(_pid)
        returns (
            address[] memory addresses,
            string[] memory symbols,
            uint256[] memory decimals,
            uint256[] memory rewardsPerSec
        )
    {
        PoolInfo storage pool = poolInfo[_pid];

        uint256 rewardersLength = pool.rewarders.length;

        addresses = new address[](rewardersLength + 1);
        symbols = new string[](rewardersLength + 1);
        decimals = new uint256[](rewardersLength + 1);
        rewardsPerSec = new uint256[](rewardersLength + 1);

        addresses[0] = address(carbon);
        symbols[0] = IBoringERC20(carbon).safeSymbol();
        decimals[0] = IBoringERC20(carbon).safeDecimals();

        rewardsPerSec[0] = (pool.allocPoint * carbonPerSec) / totalAllocPoint;

        for (uint256 rewarderId = 0; rewarderId < rewardersLength; ) {
            address rewardToken = address(
                pool.rewarders[rewarderId].rewardToken()
            );
            addresses[rewarderId + 1] = rewardToken;

            symbols[rewarderId + 1] = IBoringERC20(rewardToken).safeSymbol();

            decimals[rewarderId + 1] = IBoringERC20(rewardToken).safeDecimals();

            rewardsPerSec[rewarderId + 1] = pool
                .rewarders[rewarderId]
                .poolRewardsPerSec(_pid);
            unchecked {
                ++rewarderId;
            }
        }
    }

    // View function to see rewarders for a pool
    function poolRewarders(
        uint256 _pid
    )
        external
        view
        validatePoolByPid(_pid)
        returns (address[] memory rewarders)
    {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 rewardersLength = pool.rewarders.length;
        rewarders = new address[](rewardersLength);
        for (uint256 rewarderId = 0; rewarderId < rewardersLength; ) {
            rewarders[rewarderId] = address(pool.rewarders[rewarderId]);
            unchecked {
                ++rewarderId;
            }
        }
    }

    // View function to see if user can harvest Carbon.
    function canHarvest(
        uint256 _pid,
        address _user
    ) public view validatePoolByPid(_pid) returns (bool) {
        UserInfo storage user = userInfo[_pid][_user];
        return
            block.timestamp >= startTimestamp &&
            block.timestamp >= user.nextHarvestUntil;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() external nonReentrant {
        _massUpdatePools();
    }

    // Internal method for massUpdatePools
    function _massUpdatePools() internal {
        uint256 poolInfoLength = poolInfo.length;
        for (uint256 pid = 0; pid < poolInfoLength; ) {
            _updatePool(pid);
            unchecked {
                ++pid;
            }
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) external nonReentrant {
        _updatePool(_pid);
    }

    // Internal method for _updatePool
    function _updatePool(uint256 _pid) internal validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];

        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }

        uint256 lpSupply = pool.totalLp;

        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }

        uint256 multiplier = block.timestamp - pool.lastRewardTimestamp;

        uint256 carbonReward = ((multiplier * carbonPerSec) * pool.allocPoint) /
            totalAllocPoint;

        carbon.mint(address(this), carbonReward);

        pool.accCarbonPerShare +=
            (carbonReward * ACC_TOKEN_PRECISION) /
            pool.totalLp;

        pool.lastRewardTimestamp = block.timestamp;

        emit UpdatePool(
            _pid,
            pool.lastRewardTimestamp,
            lpSupply,
            pool.accCarbonPerShare
        );
    }

    // Deposit tokens for Carbon allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        _deposit(_pid, _amount);
    }

    // Deposit tokens for Carbon allocation.
    function _deposit(
        uint256 _pid,
        uint256 _amount
    ) internal validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        _updatePool(_pid);

        payOrLockupPendingCarbon(_pid);

        if (_amount > 0) {
            uint256 beforeDeposit = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
            uint256 afterDeposit = pool.lpToken.balanceOf(address(this));

            _amount = afterDeposit - beforeDeposit;

            if (pool.depositFeeBP > 0) {
                uint256 depositFee = (_amount * pool.depositFeeBP) / 10_000;
                pool.lpToken.safeTransfer(feeAddress, depositFee);

                _amount = _amount - depositFee;
            }

            user.amount += _amount;

            if (address(pool.lpToken) == address(carbon)) {
                totalCarbonInPools += _amount;
            }
        }
        user.rewardDebt =
            (user.amount * pool.accCarbonPerShare) /
            ACC_TOKEN_PRECISION;

        uint256 poolRewardersLength = pool.rewarders.length;
        for (uint256 rewarderId = 0; rewarderId < poolRewardersLength; ) {
            pool.rewarders[rewarderId].onCarbonReward(
                _pid,
                msg.sender,
                user.amount
            );
            unchecked {
                ++rewarderId;
            }
        }

        if (_amount > 0) {
            pool.totalLp += _amount;
        }

        emit Deposit(msg.sender, _pid, _amount);
    }

    //withdraw tokens
    function withdraw(
        uint256 _pid,
        uint256 _amount
    ) public nonReentrant validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        //this will make sure that user can only withdraw from his pool
        require(user.amount >= _amount, "withdraw: user amount not enough");

        //cannot withdraw more than pool's balance
        require(pool.totalLp >= _amount, "withdraw: pool total not enough");

        _updatePool(_pid);

        payOrLockupPendingCarbon(_pid);

        if (_amount > 0) {
            user.amount -= _amount;
            if (address(pool.lpToken) == address(carbon)) {
                totalCarbonInPools -= _amount;
            }
            pool.lpToken.safeTransfer(msg.sender, _amount);
        }

        user.rewardDebt =
            (user.amount * pool.accCarbonPerShare) /
            ACC_TOKEN_PRECISION;

        uint256 poolRewardersLength = pool.rewarders.length;
        for (uint256 rewarderId = 0; rewarderId < poolRewardersLength; ) {
            pool.rewarders[rewarderId].onCarbonReward(
                _pid,
                msg.sender,
                user.amount
            );
            unchecked {
                ++rewarderId;
            }
        }

        if (_amount > 0) {
            pool.totalLp -= _amount;
        }

        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;

        //Cannot withdraw more than pool's balance
        require(
            pool.totalLp >= amount,
            "emergency withdraw: pool total not enough"
        );

        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardLockedUp = 0;
        user.nextHarvestUntil = 0;
        pool.totalLp -= amount;

        uint256 poolRewardersLength = pool.rewarders.length;
        for (uint256 rewarderId = 0; rewarderId < poolRewardersLength; ) {
            pool.rewarders[rewarderId].onCarbonReward(_pid, msg.sender, 0);
            unchecked {
                ++rewarderId;
            }
        }

        if (address(pool.lpToken) == address(carbon)) {
            totalCarbonInPools -= amount;
        }

        pool.lpToken.safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Pay or lockup pending Carbon.
    function payOrLockupPendingCarbon(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.nextHarvestUntil == 0 && block.timestamp >= startTimestamp) {
            user.nextHarvestUntil = block.timestamp + pool.harvestInterval;
        }

        uint256 pending = ((user.amount * pool.accCarbonPerShare) /
            ACC_TOKEN_PRECISION) - user.rewardDebt;

        if (canHarvest(_pid, msg.sender)) {
            if (pending > 0 || user.rewardLockedUp > 0) {
                uint256 pendingRewards = pending + user.rewardLockedUp;

                // reset lockup
                totalLockedUpRewards -= user.rewardLockedUp;
                user.rewardLockedUp = 0;
                user.nextHarvestUntil = block.timestamp + pool.harvestInterval;
                uint256 xCarbonAmount = (pendingRewards * xCarbonRatio) / 100;
                if (xCarbonAmount > 0) {
                    IXCarbonStarterToken(xCarbonToken).convertTo(
                        xCarbonAmount,
                        msg.sender
                    );
                    emit XRewardPaid(msg.sender, _pid, xCarbonAmount);
                }
                if (pendingRewards - xCarbonAmount > 0) {
                    safeCarbonTransfer(
                        msg.sender,
                        pendingRewards - xCarbonAmount
                    );
                    emit RewardPaid(
                        msg.sender,
                        _pid,
                        pendingRewards - xCarbonAmount
                    );
                }
            }
        } else if (pending > 0) {
            totalLockedUpRewards += pending;
            user.rewardLockedUp += pending;
            emit RewardLockedUp(msg.sender, _pid, pending);
        }
    }

    // Safe Carbon transfer function, just in case if rounding error causes pool do not have enough Carbon.
    function safeCarbonTransfer(address _to, uint256 _amount) internal {
        if (carbon.balanceOf(address(this)) > totalCarbonInPools) {
            //carbonBal = total Carbon in CarbonChef - total Carbon in Carbon pools, this will make sure that CarbonDistributor never transfer rewards from deposited Carbon pools
            uint256 carbonBal = carbon.balanceOf(address(this)) -
                totalCarbonInPools;
            if (_amount >= carbonBal) {
                carbon.safeTransfer(_to, carbonBal);
            } else if (_amount > 0) {
                carbon.safeTransfer(_to, _amount);
            }
        }
    }

    function updateEmissionRate(uint256 _carbonPerSec) public onlyOwner {
        _massUpdatePools();

        emit EmissionRateUpdated(msg.sender, carbonPerSec, _carbonPerSec);

        carbonPerSec = _carbonPerSec;
    }

    function updateAllocPoint(
        uint256 _pid,
        uint256 _allocPoint
    ) public onlyOwner {
        _massUpdatePools();

        PoolInfo storage pool = poolInfo[_pid];

        emit AllocPointsUpdated(msg.sender, pool.allocPoint, _allocPoint);

        totalAllocPoint = totalAllocPoint - pool.allocPoint + _allocPoint;
        pool.allocPoint = _allocPoint;
    }

    function poolTotalLp(uint256 pid) external view returns (uint256) {
        return poolInfo[pid].totalLp;
    }

    // Function to harvest many pools in a single transaction
    function harvestMany(uint256[] calldata _pids) public nonReentrant {
        require(_pids.length <= 30, "harvest many: too many pool ids");
        for (uint256 index = 0; index < _pids.length; ) {
            _deposit(_pids[index], 0);
            unchecked {
                ++index;
            }
        }
    }

    // Update fee address.
    function setFeeAddress(address _feeAddress) public onlyOwner {
        require(_feeAddress != address(0), "invalid new fee address");
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    // sets the xCarbon ratio
    function setXCarbonRatio(uint256 _ratio) external onlyOwner {
        require(_ratio <= 100, "Ratio is to high");
        xCarbonRatio = _ratio;
    }
}
