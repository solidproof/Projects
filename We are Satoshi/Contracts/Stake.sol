// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./interfaces/IERC20.sol";
import "./libraries/Math.sol";
import "./libraries/SafeERC20.sol";

//solhint-disable not-rely-on-time
contract StandardStake {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    IERC20 public stakingToken;
    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;

    TimeData private _time;

    // Pack all time data into struct
    struct TimeData {
        uint64 periodFinish;
        uint64 rewardsDuration;
        uint64 lastUpdateTime;
    }

    ContractData private _data;

    struct ContractData {
        uint8 mutex; // 1 = open, 2 = locked
        uint160 distributor; // addr as uint160 to save storage slot
    }

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _distributor,
        address _rewardsToken,
        address _stakingToken,
        uint64 _stakingDuration
    ) {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        _time.rewardsDuration = _stakingDuration * 1 days;

        _data.mutex = 1;
        _data.distributor = uint160(_distributor);
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, _time.periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored + (
                (lastTimeRewardApplicable() - _time.lastUpdateTime) * rewardRate * 1e18 / _totalSupply
            );
    }

    function earned(address account) public view returns (uint256) {
        return _balances[account] * (
            rewardPerToken() - userRewardPerTokenPaid[account]
        ) / 1e18 + rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * _time.rewardsDuration;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply += amount;
        _balances[msg.sender] += amount;
        // stakingToken.transferFrom(msg.sender, address(this), amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");

        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        // stakingToken.transfer(msg.sender, amount);
        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];

        if (reward > 0) {
            rewards[msg.sender] = 0;
            // rewardsToken.transfer(msg.sender, reward);
            rewardsToken.safeTransfer(msg.sender, reward);

            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function fundContract(uint256 amount) external onlyDistributor {
        require(amount > 0, "Must send more than 0");
        // rewardsToken.transferFrom(msg.sender, address(this), amount);
        rewardsToken.safeTransferFrom(msg.sender, address(this), amount);
        notifyRewardAmount(amount);
    }

    function notifyRewardAmount(uint256 reward) private onlyDistributor updateReward(address(0)) {
        if (block.timestamp >= _time.periodFinish) {
            rewardRate = reward / _time.rewardsDuration;
        } else {
            uint256 remaining = _time.periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / _time.rewardsDuration;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardsToken.balanceOf(address(this));

        require(rewardRate <= balance / _time.rewardsDuration, "Provided reward too high");

        _time.lastUpdateTime = uint64(block.timestamp);
        _time.periodFinish = uint64(block.timestamp) + _time.rewardsDuration;

        emit RewardAdded(reward);
    }

    /* ========== MODIFIERS ========== */

    modifier nonReentrant() {
        require(_data.mutex == 1, "No reentrancy allowed");
        _data.mutex = 2;
        _;
        _data.mutex = 1;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        _time.lastUpdateTime = uint64(lastTimeRewardApplicable());

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier onlyDistributor() {
        require(msg.sender == address(_data.distributor), "Caller is not owner");
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
}