//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

interface IHLAWToken {
    function decimals() external view returns (uint8);
}

interface IHLAWExchange {
    function buyFromFee(uint256 amount) external;
}

interface IDEXRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IMigration {
    function migrate(address user, uint256 migrateAmount) external;
}

contract HLAWStaking is Ownable, ReentrancyGuard {
    using Address for address;
    // Libraries
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Structs
    struct UserInfo {
        uint256 amount;
        uint256 totalRedeemed;
        uint256 lastRewardTime;
        uint256 lastAccRewardsPerShare;
    }

    struct PoolInfo {
        IERC20 stakingToken;
        IERC20 dripToken;
        address rewardsPool;
        uint256 allocPoint;
        uint256 accRewardsPerShare;
        uint256 lastCalcTime;
        uint256 totalStaked;
        uint256 totalRewards;
        bool active;
    }

    // Private Constants, Variables, and Mappings
    uint256 private constant MULTIPLIER = 1e12;
    uint256 private constant SECONDS_PER_YEAR = 60 * 60 * 24 * 365;
    uint256 private constant FEE_DENOMINATOR = 10000;

    IERC20 private hlawToken;
    IHLAWExchange private hlawExchange;
    IERC20 private constant incToken =
        IERC20(0x2fa878Ab3F87CC1C9737Fc071108F904c0B0C95d); // Incentive Token Address
    IERC20 private constant wplsToken =
        IERC20(0xA1077a294dDE1B09bB078844df40758a5D0f9a27); // Wrapped PLS Token Address
    IERC20 private constant daiToken =
        IERC20(0xefD766cCb38EaF1dfd701853BFCe31359239F305); // DAI Token Address
    IERC20 private constant daiWplsLpToken =
        IERC20(0xE56043671df55dE5CDf8459710433C10324DE0aE); // DAI/WPLS LP Token Address
    IDEXRouter private constant pulseRouter =
        IDEXRouter(0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02); // PulseX Router

    address private rewardPool;
    address public prizePool;
    address private incRewardPool;
    address private instantRewardPool;
    address public boostContract;
    address public teamFeeReceiver;
    address public treasuryFeeReceiver;
    address public signer;
    uint256 private startTime;
    bool private migration;
    IMigration private migrationAddress;

    struct I2Reward {
        // Incentive & Instant
        uint256 lastAccIncentiveRewardsPerShare;
        uint256 redeemedIncentive;
        uint256 lastAccInstantRewardsPerShare;
        uint256 redeemedInstant;
    }

    uint256 private accIncentiveRewardsPerShare;
    uint256 private accInstantRewardsPerShare;

    uint256 private rewardPoolFee = 4000;
    uint256 private instantRewardFee = 1000;
    uint256 private treasuryFee = 2000;
    uint256 private teamFee = 2000;
    uint256 private prizePoolFee = 1000;

    mapping(uint256 => PoolInfo) private poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) private userInfo;
    mapping(address => I2Reward) private i2RewardInfo;

    // Public Variables and Mappings
    uint256 public totalPools;
    uint256 public totalStakedTokens;
    uint256 public lastUpdateTime;
    uint256 public updateInterval = 24 hours;
    uint256 public updateRatio = 80; // 80% of the balance
    uint256 public updateThreshold = 5; // 5% change
    bool public autoUpdate;
    uint256 public incClaimFee = 1000;
    uint256 public totalIncRewarded;
    uint256 public totalInstantRewarded;
    mapping(address => bool) public existingUser;
    uint256 public totalUsers;

    // Events
    event Stake(address indexed user, uint256 indexed pid, uint256 amount);
    event Unstake(address indexed user, uint256 indexed pid, uint256 amount);
    event Migrated(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);
    event IncentiveClaimed(address indexed user, uint256 amount);
    event IncentiveDistributed(uint256 amount);
    event InstantRewardClaimed(address indexed user, uint256 amount);
    event InstantRewardDistributed(uint256 amount);
    event BoostRewardDistributed(uint256 amount);
    event PoolInitialized(
        uint256 pid,
        address stakingToken,
        address dripToken,
        uint256 allocPoint,
        bool active
    );
    event PoolUpdated(uint256 pid, uint256 allocPoint, bool active);
    event FeesUpdated(
        uint256 incClaimFee,
        uint256 rewardPoolFee,
        uint256 instantRewardFee,
        uint256 prizePoolFee,
        uint256 teamFee,
        uint256 treasuryFee
    );
    event FeeReceiversUpdated(
        address newTeam,
        address newTreasury,
        address newPrizePool
    );
    event BoostContractUpdated(address newBoostContract);
    event SignerSet(address newSigner);
    event AutoUpdateSettingsUpdated(
        uint256 updateInterval,
        uint256 updateRatio,
        uint256 updateThreshold,
        bool autoUpdate
    );

    modifier onlySigner() {
        require(signer == msg.sender, "Ownable: caller is not the signer");
        _;
    }

    constructor(
        uint256 _startTime,
        address _hlawToken,
        address _hlawExchange,
        address _rewardPool,
        address _prizePool,
        address _incRewardPool,
        address _instantRewardPool,
        address _teamFee,
        address _treasuryFee
    ) Ownable(msg.sender) {
        startTime = _startTime;
        signer = msg.sender;
        hlawToken = IERC20(_hlawToken);
        hlawExchange = IHLAWExchange(_hlawExchange);
        rewardPool = _rewardPool;
        prizePool = _prizePool;
        incRewardPool = _incRewardPool;
        instantRewardPool = _instantRewardPool;
        teamFeeReceiver = _teamFee;
        treasuryFeeReceiver = _treasuryFee;

        wplsToken.approve(address(pulseRouter), type(uint256).max);
        daiToken.approve(address(pulseRouter), type(uint256).max);
        incToken.approve(address(pulseRouter), type(uint256).max);
        daiWplsLpToken.approve(address(hlawExchange), type(uint256).max);
    }

    /*
     **********************************************************************************
     ***************************** User Functions ************************************
     **********************************************************************************
     */

    function stake(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.active, "pool not active");

        _claim(_pid, msg.sender);
        _claimInstantRewards(msg.sender);
        _claimIncentives(msg.sender, _pid, _amount, true);

        pool.stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        if (autoUpdate && lastUpdateTime + updateInterval <= block.timestamp) {
            _updatePool();
        }

        if (!existingUser[msg.sender]) {
            _addUser(msg.sender);
        }

        emit Stake(msg.sender, _pid, _amount);
    }

    function unstake(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(
            user.amount >= _amount && _amount > 0,
            "unstake: insufficient staked balance"
        );

        _claim(_pid, msg.sender);
        _claimInstantRewards(msg.sender);
        _claimIncentives(msg.sender, _pid, _amount, false);

        pool.stakingToken.safeTransfer(msg.sender, _amount);

        if (autoUpdate && lastUpdateTime + updateInterval <= block.timestamp) {
            _updatePool();
        }

        emit Unstake(msg.sender, _pid, _amount);
    }

    function exit(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount > 0, "unstake: no tokens staked");

        calcAccRewardsPerShare(_pid);

        pool.totalStaked = pool.totalStaked.sub(user.amount);
        totalStakedTokens = totalStakedTokens.sub(user.amount);
        uint256 transferAmount = user.amount;
        user.amount = 0;

        pool.stakingToken.safeTransfer(msg.sender, transferAmount);

        if (autoUpdate && lastUpdateTime + updateInterval <= block.timestamp) {
            _updatePool();
        }

        emit Unstake(msg.sender, _pid, transferAmount);
    }

    function claim(uint256 _pid) public nonReentrant {
        _claim(_pid, msg.sender);
        _claimInstantRewards(msg.sender);

        if (autoUpdate && lastUpdateTime + updateInterval <= block.timestamp) {
            _updatePool();
        }
    }

    function claimIncentives() public nonReentrant {
        _claimIncentives(msg.sender, 1, 0, true);

        if (autoUpdate && lastUpdateTime + updateInterval <= block.timestamp) {
            _updatePool();
        }
    }

    function claimInstantRewards() public nonReentrant {
        _claimInstantRewards(msg.sender);

        if (autoUpdate && lastUpdateTime + updateInterval <= block.timestamp) {
            _updatePool();
        }
    }

    function migrate(uint256 _pid) public nonReentrant {
        require(migration, "Migration must be enabled");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount > 0, "unstake: no tokens staked");

        calcAccRewardsPerShare(_pid);

        uint256 transferAmount = user.amount;

        migrationAddress.migrate(msg.sender, transferAmount);

        pool.totalStaked = pool.totalStaked.sub(user.amount);
        totalStakedTokens = totalStakedTokens.sub(user.amount);
        user.amount = 0;

        pool.stakingToken.safeTransfer(
            address(migrationAddress),
            transferAmount
        );

        emit Migrated(msg.sender, _pid, transferAmount);
    }

    /*
     **********************************************************************************
     ***************************** Admin Functions ************************************
     **********************************************************************************
     */

    function setBoostContract(address _newBoostContract) external onlyOwner {
        require(_newBoostContract.code.length > 0 && _newBoostContract != address(0), "Must be a contract address that is set as Boost.");
        boostContract = _newBoostContract;
        emit BoostContractUpdated(_newBoostContract);
    }

    function setReceivers(
        address _newTeam,
        address _newTreasury,
        address _newPrizePool
    ) public onlyOwner {
        require(
            _newTeam != address(0) && _newTreasury != address(0),
            "Invalid address set."
        );
        teamFeeReceiver = _newTeam;
        treasuryFeeReceiver = _newTreasury;
        prizePool = _newPrizePool;
        emit FeeReceiversUpdated(_newTeam, _newTreasury, _newPrizePool);
    }

    function setFees(
        uint256 _incClaimFee,
        uint256 _rewardPoolFee,
        uint256 _instantRewardFee,
        uint256 _prizePoolFee,
        uint256 _teamFee,
        uint256 _treasuryFee
    ) public onlyOwner {
        incClaimFee = _incClaimFee;
        rewardPoolFee = _rewardPoolFee;
        instantRewardFee = _instantRewardFee;
        prizePoolFee = _prizePoolFee;
        teamFee = _teamFee;
        treasuryFee = _treasuryFee;
        require(
            rewardPoolFee +
                instantRewardFee +
                prizePoolFee +
                teamFee +
                treasuryFee ==
                10000,
            "Must equal 100 percent"
        );
        require(incClaimFee <= 1000, "Maximum incClaimFee is 10 percent");

        emit FeesUpdated(
            _incClaimFee,
            _rewardPoolFee,
            _instantRewardFee,
            _prizePoolFee,
            _teamFee,
            _treasuryFee
        );
    }

    function setUpdateSettings(
        uint256 _updateInterval,
        uint256 _updateRatio,
        uint256 _updateThreshold,
        bool _autoUpdate
    ) public onlyOwner {
        updateInterval = _updateInterval;
        updateRatio = _updateRatio;
        updateThreshold = _updateThreshold;
        autoUpdate = _autoUpdate;
        require(updateRatio >= 0 && updateRatio <= 100, "Maximum of 100.");
        require(
            updateThreshold >= 0 && updateThreshold <= 100,
            "Maximum of 100."
        );

        emit AutoUpdateSettingsUpdated(
            _updateInterval,
            _updateRatio,
            _updateThreshold,
            _autoUpdate
        );
    }

    function setSigner(address _newSigner) public onlyOwner {
        require(_newSigner != address(0), "Invalid address set");
        signer = _newSigner;
        emit SignerSet(_newSigner);
    }

    function setMigration(bool _migrationEnabled) public onlyOwner {
        migration = _migrationEnabled;
    }

    function initializePool(
        IERC20 _stakingToken,
        IERC20 _dripToken,
        address _rewardsPool,
        uint256 _allocPoint
    ) public onlyOwner {
        require(totalPools == 0, "Can only have 1 pool per deploy.");
        require(
            address(_stakingToken).code.length > 0 &&
                address(_stakingToken) != address(0),
            "Invalid address set."
        );
        require(
            address(_dripToken).code.length > 0 &&
                address(_dripToken) != address(0),
            "Invalid address set."
        );
        PoolInfo storage pool = poolInfo[++totalPools];

        pool.stakingToken = _stakingToken;
        pool.dripToken = _dripToken;
        pool.rewardsPool = _rewardsPool;
        pool.allocPoint = _allocPoint;
        pool.lastCalcTime = block.timestamp;
        pool.totalStaked = 0;
        pool.active = true;

        emit PoolInitialized(
            totalPools,
            address(_stakingToken),
            address(_dripToken),
            _allocPoint,
            pool.active
        );
    }

    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _active
    ) external onlySigner {
        require(_pid <= totalPools, "invalid pool id");
        calcAccRewardsPerShare(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        pool.allocPoint = _allocPoint;
        pool.active = _active;

        emit PoolUpdated(_pid, _allocPoint, _active);
    }

    /*
     **********************************************************************************
     *************************** External Functions ***********************************
     **********************************************************************************
     */

    function autoStake(uint256 _pid, address _user, uint256 _amount) external {
        require(
            msg.sender == address(hlawExchange),
            "Only HLAW Exchange can call autoStake"
        );
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.active, "pool not active");

        _claim(_pid, _user);
        _claimInstantRewards(_user);
        _claimIncentives(_user, _pid, _amount, true);

        pool.stakingToken.safeTransferFrom(address(hlawExchange), address(this), _amount);

        if (autoUpdate && lastUpdateTime + updateInterval <= block.timestamp) {
            _updatePool();
        }
    }

    function distributeInstantRewardDividends(uint256 _amount) external {
        require(
            msg.sender == address(hlawExchange) || msg.sender == owner(),
            "Only HLAW Exchange, and owner can distribute instant rewards."
        );
        require(_amount > 0, "You must have something to distribute.");

        if (totalStakedTokens == 0) {
            return;
        }

        hlawToken.safeTransferFrom(msg.sender, instantRewardPool, _amount);

        uint256 instantRewardDistributionAmount = _amount.mul(MULTIPLIER).div(
            totalStakedTokens
        );
        accInstantRewardsPerShare = accInstantRewardsPerShare.add(
            instantRewardDistributionAmount
        );

        emit InstantRewardDistributed(_amount);
    }

    function distributeIncentiveDividends(uint256 _amount) external {
        require(
            msg.sender == address(hlawExchange) || msg.sender == owner(),
            "Only HLAW Exchange, and owner can distribute incentive rewards."
        );
        require(_amount > 0, "You must have something to distribute.");

        if (totalStakedTokens == 0) {
            return;
        }

        incToken.safeTransferFrom(msg.sender, incRewardPool, _amount);

        uint256 incentiveDistributionAmount = _amount.mul(MULTIPLIER).div(totalStakedTokens);
        accIncentiveRewardsPerShare = accIncentiveRewardsPerShare.add(incentiveDistributionAmount);

        emit IncentiveDistributed(_amount);
    }

    function distributeBoost(uint256 _amount) external {
        require(msg.sender == boostContract, "Only the boost contract can distribute boost");
        require(_amount > 0, "You must have something to distribute.");

        if (totalStakedTokens == 0) {
            return;
        }

        hlawToken.safeTransferFrom(msg.sender, instantRewardPool, _amount);

        uint256 instantRewardDistributionAmount = _amount.mul(MULTIPLIER).div(totalStakedTokens);
        accInstantRewardsPerShare = accInstantRewardsPerShare.add(instantRewardDistributionAmount);

        emit BoostRewardDistributed(_amount);
    }

    function addUser(address user) public {
        require(
            msg.sender == address(hlawExchange) || msg.sender == address(this),
            "Only hlaw exchange and staking contract can call addUser"
        );
        if (!existingUser[user]) {
            existingUser[user] = true;
            totalUsers += 1;
        }
    }

    /*
     **********************************************************************************
     ***************************** View Functions *************************************
     **********************************************************************************
     */

    function pendingRewards(
        uint256 _pid,
        address _user
    ) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        if (
            user.amount == 0 ||
            block.timestamp < user.lastRewardTime ||
            pool.totalStaked == 0
        ) {
            return 0;
        }

        uint256 beforeRewards = pool.accRewardsPerShare
            .sub(user.lastAccRewardsPerShare)
            .mul(user.amount);

        uint256 timeDiff = getTimeDiff(pool.lastCalcTime, block.timestamp);
        uint256 afterRewards = pool.allocPoint
            .mul(timeDiff)
            .mul(user.amount)
            .mul(MULTIPLIER)
            .div(SECONDS_PER_YEAR)
            .div(pool.totalStaked);

        return beforeRewards.add(afterRewards).div(MULTIPLIER);
    }

    function pendingIncentives(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[1][_user];
        uint256 _totalStaked = user.amount;

        I2Reward storage i2Reward = i2RewardInfo[_user];

        uint256 _pendingIncentive = accIncentiveRewardsPerShare
            .sub(i2Reward.lastAccIncentiveRewardsPerShare)
            .mul(_totalStaked)
            .div(MULTIPLIER);

        return _pendingIncentive;
    }

    function pendingInstantRewards(address _user) public view returns (uint256) {
        uint256 _totalStaked = 0;

        for (uint256 _pid = 1; _pid <= poolLength(); _pid++) {
            UserInfo storage user = userInfo[_pid][_user];
            _totalStaked = _totalStaked.add(user.amount);
        }

        I2Reward storage i2Reward = i2RewardInfo[_user];

        uint256 _pendingInstantReward = accInstantRewardsPerShare
            .sub(i2Reward.lastAccInstantRewardsPerShare)
            .mul(_totalStaked)
            .div(MULTIPLIER);

        return _pendingInstantReward;
    }

    function getUserInfo(
        uint256 _pid,
        address _account
    )
        public
        view
        returns (
            uint256 amount,
            uint256 totalRedeemed,
            uint256 lastRewardTime,
            uint256 lastAccRewardsPerShare
        )
    {
        UserInfo storage user = userInfo[_pid][_account];
        return (
            user.amount,
            user.totalRedeemed,
            user.lastRewardTime,
            user.lastAccRewardsPerShare
        );
    }

    function getPidInfo(
        uint256 _pid
    )
        public
        view
        returns (
            address stakingToken,
            address dripToken,
            uint256 totalStaked,
            uint256 totalRewards,
            uint256 allocPoint,
            bool active
        )
    {
        PoolInfo storage pool = poolInfo[_pid];
        return (
            address(pool.stakingToken),
            address(pool.dripToken),
            pool.totalStaked,
            pool.totalRewards,
            pool.allocPoint,
            pool.active
        );
    }

    function poolLength() public view returns (uint256) {
        return totalPools;
    }

    function getIncentiveInfo(
        address _user
    )
        public
        view
        returns (uint256 pendingIncentive, uint256 redeemedIncentives)
    {
        I2Reward storage i2Reward = i2RewardInfo[_user];

        pendingIncentive = pendingIncentives(_user);
        redeemedIncentives = i2Reward.redeemedIncentive;
    }

    function getInstantRewardInfo(
        address _user
    ) public view returns (uint256 pendingInstant, uint256 redeemedInstant) {
        I2Reward storage i2Reward = i2RewardInfo[_user];

        pendingInstant = pendingInstantRewards(_user);
        redeemedInstant = i2Reward.redeemedInstant;
    }

    function getFeeInfo()
        public
        view
        returns (
            uint256 _incClaimFee,
            uint256 _rewardPoolFee,
            uint256 _instantRewardFee,
            uint256 _prizePoolFee,
            uint256 _teamFee,
            uint256 _treasuryFee
        )
    {
        return (
            incClaimFee,
            rewardPoolFee,
            instantRewardFee,
            prizePoolFee,
            teamFee,
            treasuryFee
        );
    }

    /*
     **********************************************************************************
     ***************************** Internal Functions *********************************
     **********************************************************************************
     */

    function _claim(uint256 _pid, address _user) internal {
        calcAccRewardsPerShare(_pid);
        uint256 pendingAmount = pendingRewards(_pid, _user);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        user.lastRewardTime = block.timestamp;
        user.lastAccRewardsPerShare = pool.accRewardsPerShare;


        if (pendingAmount == 0) {
            return;
        }

        user.totalRedeemed = user.totalRedeemed.add(pendingAmount);
        pool.totalRewards = pool.totalRewards.add(pendingAmount);

        safeRewardTransfer(_pid, _user, pendingAmount);

        emit Claim(_user, _pid, pendingAmount);
    }

    function _claimInstantRewards(address _user) internal {
        uint256 pendingInstantReward = pendingInstantRewards(_user);

        I2Reward storage i2Reward = i2RewardInfo[_user];
        i2Reward.lastAccInstantRewardsPerShare = accInstantRewardsPerShare;

        if (pendingInstantReward == 0) {
            return;
        }

        i2Reward.redeemedInstant = i2Reward.redeemedInstant.add(pendingInstantReward);
        totalInstantRewarded += pendingInstantReward;

        hlawToken.safeTransferFrom(instantRewardPool, _user, pendingInstantReward);
        emit InstantRewardClaimed(_user, pendingInstantReward);
    }

    function _claimIncentives(address _user, uint256 _pid, uint256 _stakeAmount, bool _isPlus) internal {
        uint256 _pendingIncentives = pendingIncentives(_user);

        if (_stakeAmount > 0) {
            PoolInfo storage pool = poolInfo[_pid];
            UserInfo storage user = userInfo[_pid][_user];

            if (_isPlus) {
                pool.totalStaked = pool.totalStaked.add(_stakeAmount);
                user.amount = user.amount.add(_stakeAmount);
                totalStakedTokens = totalStakedTokens.add(_stakeAmount);
            } else {
                pool.totalStaked = pool.totalStaked.sub(_stakeAmount);
                user.amount = user.amount.sub(_stakeAmount);
                totalStakedTokens = totalStakedTokens.sub(_stakeAmount);
            }
        }

        I2Reward storage i2Reward = i2RewardInfo[_user];
        i2Reward.lastAccIncentiveRewardsPerShare = accIncentiveRewardsPerShare;

        if (_pendingIncentives == 0) {
            return;
        }

        uint256 feeAmount = 0;

        totalIncRewarded = totalIncRewarded.add(_pendingIncentives);

        if (_user != treasuryFeeReceiver && incClaimFee > 0) {
            feeAmount = _pendingIncentives.mul(incClaimFee).div(FEE_DENOMINATOR);
            _pendingIncentives = _pendingIncentives.sub(feeAmount);
        }

        i2Reward.redeemedIncentive = i2Reward.redeemedIncentive.add(_pendingIncentives);

        incToken.safeTransferFrom(incRewardPool, _user, _pendingIncentives);

        if (_user != treasuryFeeReceiver && incClaimFee > 0) {
            incToken.safeTransferFrom(incRewardPool, address(this), feeAmount);

            uint256 toTeam = feeAmount.mul(teamFee).div(FEE_DENOMINATOR);

            uint256 hlawGained = _incentiveSwap(feeAmount.sub(toTeam));

            uint256 toRewardPool = hlawGained.mul(rewardPoolFee).div(FEE_DENOMINATOR.sub(teamFee));
            uint256 toPrizePool = hlawGained.mul(prizePoolFee).div(FEE_DENOMINATOR.sub(teamFee));
            uint256 toTreasury = hlawGained.mul(treasuryFee).div(FEE_DENOMINATOR.sub(teamFee));
            uint256 toInstantReward = hlawGained.mul(instantRewardFee).div(FEE_DENOMINATOR.sub(teamFee));

            if (toRewardPool > 0) {
                hlawToken.safeTransfer(rewardPool, toRewardPool);
            }
            if (toPrizePool > 0) {
                hlawToken.safeTransfer(prizePool, toPrizePool);
            }
            if (toInstantReward > 0) {
                _distributeInstantRewardDividends(toInstantReward);
            }
            if (toTeam > 0) {
                incToken.safeTransfer(teamFeeReceiver, toTeam);
            }
            if (toTreasury > 0) {
                _autoStake(1, treasuryFeeReceiver, toTreasury);
            }
        }
        emit IncentiveClaimed(_user, _pendingIncentives);
    }

    function _distributeInstantRewardDividends(uint256 _claimedAmount) internal {
        if (totalStakedTokens == 0 || _claimedAmount == 0) {
            return;
        }

        hlawToken.safeTransfer(instantRewardPool, _claimedAmount);

        uint256 instantRewardDistributionAmount = _claimedAmount.mul(MULTIPLIER).div(totalStakedTokens);
        accInstantRewardsPerShare = accInstantRewardsPerShare.add(instantRewardDistributionAmount);

        emit InstantRewardDistributed(_claimedAmount);
    }

    function _autoStake(uint256 _pid, address _user, uint256 _amount) internal {
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.active, "pool not active");

        _claim(_pid, _user);
        _claimInstantRewards(_user);
        _claimIncentives(_user, _pid, _amount, true);

        if (autoUpdate && lastUpdateTime + updateInterval <= block.timestamp) {
            _updatePool();
        }
    }

    function safeRewardTransfer(
        uint256 _pid,
        address _to,
        uint256 _amount
    ) internal {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 rewardBal = pool.dripToken.balanceOf(pool.rewardsPool);
        require(
            _amount <= rewardBal,
            "You must wait for the rewardPool balance to be replenished."
        );

        pool.dripToken.safeTransferFrom(pool.rewardsPool, _to, _amount);
    }

    function calcAccRewardsPerShare(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];

        if (pool.totalStaked > 0) {
            uint256 timeDiff = getTimeDiff(pool.lastCalcTime, block.timestamp);
            uint256 newRewardsPerShare = pool.allocPoint
                .mul(timeDiff)
                .mul(MULTIPLIER)
                .div(SECONDS_PER_YEAR)
                .div(pool.totalStaked);

            pool.accRewardsPerShare = pool.accRewardsPerShare
                .add(newRewardsPerShare);
        }
        pool.lastCalcTime = block.timestamp;
    }

    function _updatePool() internal {
        PoolInfo storage pool = poolInfo[1];

        uint256 newRatio = pool.dripToken.balanceOf(pool.rewardsPool).mul(updateRatio).div(100);
        uint256 threshold = pool.allocPoint.mul(updateThreshold).div(100);

        lastUpdateTime = lastUpdateTime.add(updateInterval);

        if (
            newRatio >= pool.allocPoint + threshold ||
            newRatio <= pool.allocPoint - threshold
        ) {
            _set(1, newRatio, true);
        }
    }

    function _set(uint256 _pid, uint256 _allocPoint, bool _active) internal {
        require(_pid <= totalPools, "invalid pool id");
        calcAccRewardsPerShare(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        pool.allocPoint = _allocPoint;
        pool.active = _active;
    }

    function _incentiveSwap(uint256 amount) internal returns (uint256) {
        // Track starting WPLS balance
        uint256 wplsBefore = wplsToken.balanceOf(address(this));

        // Swap 100% of INC to WPLS
        address[] memory path = new address[](2);
        path[0] = address(incToken);
        path[1] = address(wplsToken);

        pulseRouter.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);

        // Track WPLS gained and DAI starting balance
        uint256 wplsGained = wplsToken.balanceOf(address(this)) - wplsBefore;
        uint256 daiBefore = daiToken.balanceOf(address(this));

        // Swap 50% of WPLS to DAI
        address[] memory path2 = new address[](2);
        path2[0] = address(wplsToken);
        path2[1] = address(daiToken);

        pulseRouter.swapExactTokensForTokens(wplsGained / 2, 0, path2, address(this), block.timestamp);

        // Track DAI gained
        uint256 daiGained = daiToken.balanceOf(address(this)) - daiBefore;

        // Add LP and track the amount of LP tokens gained
        (, , uint256 lpTokenGained) = pulseRouter.addLiquidity(address(wplsToken), address(daiToken), wplsGained / 2, daiGained, 0, 0, address(this), block.timestamp);

        // Track HLAW starting balance
        uint256 hlawBefore = hlawToken.balanceOf(address(this));

        // Buy HLAW with DAI/WPLS LP Tokens
        hlawExchange.buyFromFee(lpTokenGained);

        // Track HLAW gained
        uint256 hlawGained = hlawToken.balanceOf(address(this)) - hlawBefore;

        // There may be dust remnants remaining of WPLS/DAI, we will send these to the teamFeeReceiver so the contract remains good accounting.
        if (wplsToken.balanceOf(address(this)) > wplsBefore) {
            uint256 wplsRefund = wplsToken.balanceOf(address(this)) - wplsBefore;
            wplsToken.safeTransfer(teamFeeReceiver, wplsRefund);
        }

        if (daiToken.balanceOf(address(this)) > daiBefore) {
            uint256 daiRefund = daiToken.balanceOf(address(this)) - daiBefore;
            daiToken.safeTransfer(teamFeeReceiver, daiRefund);
        }

        return hlawGained;
    }

    function _addUser(address user) internal {
        existingUser[user] = true;
        totalUsers += 1;
    }

    function getTimeDiff(
        uint256 _from,
        uint256 _to
    ) internal pure returns (uint256) {
        return _to.sub(_from);
    }
}
