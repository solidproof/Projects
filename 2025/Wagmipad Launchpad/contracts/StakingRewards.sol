// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// puaseable
import "@openzeppelin/contracts/utils/Pausable.sol";

// Inheritance
import "./interface/IStakingRewards.sol";
import "./RewardsDistributionRecipient.sol";

contract StakingRewards is
    IStakingRewards,
    RewardsDistributionRecipient,
    ReentrancyGuard,
    Ownable,
    Pausable
{
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    IERC20 public stakingToken;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 0 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public coolingPeriod = 7 days;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    struct WithdrawRequest {
        uint256 amount;
        uint256 requestTime;
    }
    mapping(address => WithdrawRequest) public withdrawRequests;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _rewardsDistribution,
        address _rewardsToken,
        uint256 _rewardsDuration, // Parameter in days
        address _stakingToken,
        address _initialOwner
    ) Ownable(_initialOwner) {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        rewardsDuration = _rewardsDuration * 1 days; // Conversion to seconds
        rewardsDistribution = _rewardsDistribution;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        uint256 timeDifference = lastTimeRewardApplicable() - lastUpdateTime;
        uint256 rewardAmount = timeDifference * rewardRate;
        uint256 adjustedReward = rewardAmount * 1e18;

        return rewardPerTokenStored + (adjustedReward / _totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        uint256 rewardDifference = rewardPerToken() -
            userRewardPerTokenPaid[account];
        uint256 rewardDue = _balances[account] * rewardDifference;
        uint256 adjustedRewardDue = rewardDue / 1e18;

        return adjustedRewardDue + rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    function isCoolingPeriodOver(address account) public view returns (bool) {
        WithdrawRequest storage withdrawRequest = withdrawRequests[account];
        if (withdrawRequest.amount == 0) {
            return false; // No active withdraw request
        }
        return block.timestamp - withdrawRequest.requestTime >= coolingPeriod;
    }

    function getWithdrawRequest(
        address account
    ) external view returns (uint256, uint256, uint256) {
        WithdrawRequest storage withdrawRequest = withdrawRequests[account];
        if (withdrawRequest.amount > 0) {
            uint256 timeLeft = (block.timestamp - withdrawRequest.requestTime >=
                coolingPeriod)
                ? 0
                : (withdrawRequest.requestTime +
                    coolingPeriod -
                    block.timestamp);
            return (
                withdrawRequest.amount,
                withdrawRequest.requestTime,
                timeLeft
            );
        }
        return (0, 0, 0);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(
        uint256 amount
    ) external nonReentrant whenNotPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply + amount;
        _balances[msg.sender] = _balances[msg.sender] + amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function getReward()
        public
        nonReentrant
        whenNotPaused
        updateReward(msg.sender)
    {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function withdraw()
        public
        nonReentrant
        whenNotPaused
        updateReward(msg.sender)
    {
        WithdrawRequest storage withdrawRequest = withdrawRequests[msg.sender];
        require(withdrawRequest.amount > 0, "No Request Found");
        require(isCoolingPeriodOver(msg.sender), "Still in cooling period");
        uint256 amount = withdrawRequest.amount;
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;
        withdrawRequest.amount = 0;
        withdrawRequest.requestTime = 0;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function requestWithdraw(
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid Amount");
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        WithdrawRequest storage withdrawRequest = withdrawRequests[msg.sender];
        require(withdrawRequest.amount == 0, "Duplicate Request");
        withdrawRequest.amount = amount;
        withdrawRequest.requestTime = block.timestamp;
        emit WithdrawRequestCreated(msg.sender, amount, block.timestamp);
    }

    function cancelWithdrawRequest() external nonReentrant whenNotPaused {
        WithdrawRequest storage withdrawRequest = withdrawRequests[msg.sender];
        require(withdrawRequest.amount > 0, "No Record Found");
        withdrawRequest.amount = 0;
        withdrawRequest.requestTime = 0;
        emit WithdrawRequestCancelled(msg.sender);
    }

    function updateCoolingPeriod(uint256 _coolingPeriod) external onlyOwner {
        require(
            _coolingPeriod >= 1 days && _coolingPeriod <= 90 days,
            "Invalid Cooling Period"
        );
        coolingPeriod = _coolingPeriod;
        emit CoolingPeriodUpdated(coolingPeriod);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(
        uint256 reward
    ) external override onlyRewardsDistribution updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = rewardsToken.balanceOf(address(this));
        require(
            rewardRate <= balance / rewardsDuration,
            "Provided reward too high"
        );

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(reward);
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event WithdrawRequestCancelled(address indexed user);
    event WithdrawRequestCreated(
        address indexed user,
        uint256 amount,
        uint256 requestTime
    );
    event CoolingPeriodUpdated(uint256 coolingPeriod);
}
