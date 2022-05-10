// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staking is ReentrancyGuard, Pausable, Ownable {
    using Address for address;
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    IERC20 public stakingToken;
    IERC20 public rewardToken;
    uint256 public startTime;
    uint256 public stopTime;
    uint256 public stakingCap;
    uint256 public rewardAmount;
    uint256 public rewardRate;
    uint256 public rewardDuration;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    // unstaking possible after 30 days
    uint public constant cliffTime = 30 days;

    address constant penaltyWallet = 0x6572325374374629686aD44FBdec596A0C279a61;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public stakingStartTime;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardAmount,
        uint256 _startTime,
        uint256 _stopTime,
        uint256 _stakingCap
    ) {
        require(_stakingToken.isContract(), "Staking: stakingToken not a contract address");
        require(_rewardToken.isContract(), "Staking: rewardToken not a contract address");
        require(_rewardAmount > 0, "Staking: rewardAmount must be greater than zero");
        require(_startTime > block.timestamp && _startTime < _stopTime, "Staking: incorrect timestamps");

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardAmount = _rewardAmount;
        startTime = _startTime;
        stopTime = _stopTime;
        rewardDuration = _stopTime.sub(_startTime);
        stakingCap = _stakingCap;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < stopTime ? block.timestamp : stopTime;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
            );
    }

    function earned(address account) public view returns (uint256) {
        if(block.timestamp.sub(stakingStartTime[msg.sender]) < cliffTime){
            return 0;
        }
        else{
            return
            _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(
                rewards[account]
            );
        }
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Staking: cannot stake 0");
        require(block.timestamp >= startTime, "Staking: staking not started");
        require(block.timestamp <= stopTime, "Staking period over");
        if (stakingCap > 0) {
            require(_totalSupply.add(amount) <= stakingCap, "Staking: over cap limit");
        }
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakingToken.transferFrom(msg.sender, address(this), amount);
        stakingStartTime[msg.sender] = block.timestamp;
        updateReward(msg.sender);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public virtual nonReentrant {
        updateReward(msg.sender);
        require(block.timestamp.sub(stakingStartTime[msg.sender]) > cliffTime,"Please Wait, You are not eligible to unstake until 1 Month after staking");
        require(amount > 0, "Staking: cannot withdraw 0");
        require(amount <= _balances[msg.sender], "Staking: You cannot withdraw more than staked");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public virtual nonReentrant {
        updateReward(msg.sender);
        uint256 reward;
        uint fee;
        uint amountAfterFee;
        if(block.timestamp > stakingStartTime[msg.sender] + 30 days && block.timestamp < stakingStartTime[msg.sender] + 61 days){
            reward = rewards[msg.sender];
            if(reward > 0) {
                rewards[msg.sender] = 0;
                rewardToken.transfer(penaltyWallet, reward);
                emit RewardPaid(msg.sender, reward);
            }
        }
        if(block.timestamp > stakingStartTime[msg.sender] + 60 days && block.timestamp < stakingStartTime[msg.sender] + 91 days){
            reward = rewards[msg.sender];
            if(reward > 0) {
                fee = reward.mul(800).div(1e4);
                amountAfterFee = reward.sub(fee);
                rewards[msg.sender] = 0;
                rewardToken.transfer(msg.sender, amountAfterFee);
                rewardToken.transfer(penaltyWallet, fee);
                emit RewardPaid(msg.sender, reward);
            }
        }
        if(block.timestamp > stakingStartTime[msg.sender] + 90 days && block.timestamp < stakingStartTime[msg.sender] + 121 days){
            reward = rewards[msg.sender];
            if(reward > 0) {
                fee = reward.mul(600).div(1e4);
                amountAfterFee = reward.sub(fee);
                rewards[msg.sender] = 0;
                rewardToken.transfer(msg.sender, amountAfterFee);
                rewardToken.transfer(penaltyWallet, fee);
                emit RewardPaid(msg.sender, reward);
            }
        }
        if(block.timestamp > stakingStartTime[msg.sender] + 120 days && block.timestamp < stakingStartTime[msg.sender] + 151 days){
            reward = rewards[msg.sender];
            if(reward > 0) {
                fee = reward.mul(400).div(1e4);
                amountAfterFee = reward.sub(fee);
                rewards[msg.sender] = 0;
                rewardToken.transfer(msg.sender, amountAfterFee);
                rewardToken.transfer(penaltyWallet, fee);
                emit RewardPaid(msg.sender, reward);
            }
        }
        if(block.timestamp > stakingStartTime[msg.sender] + 150 days){
            reward = rewards[msg.sender];
            if (reward > 0) {
                rewards[msg.sender] = 0;
                rewardToken.transfer(msg.sender, reward);
                emit RewardPaid(msg.sender, reward);
            }
        }
    }

    function exit() public virtual whenNotPaused {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount() external {
        updateReward(address(0));
        rewardToken.transferFrom(msg.sender, address(this), rewardAmount);
        rewardRate = rewardAmount.div(rewardDuration);
        lastUpdateTime = block.timestamp;
        emit RewardAdded(rewardAmount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setCap(uint256 _newCap) public onlyOwner {
        require(_newCap >= _totalSupply, "Staking: new cap less than already staked amount");
        uint256 oldCap = stakingCap;
        stakingCap = _newCap;
        emit CapChange(oldCap, _newCap);
    }

    /* ========== MODIFIERS FUNCTION ========== */

    function updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event CapChange(uint256 oldCap, uint256 newCap);
}