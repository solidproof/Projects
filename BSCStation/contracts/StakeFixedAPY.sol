// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; 
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import '@openzeppelin/contracts/access/Ownable.sol';


contract StakeFixedAPY is AccessControl, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    event Stake(address indexed wallet, uint256 amount, uint256 date);
    event StakeRewards(address indexed wallet, uint256 amount, uint256 date);
    event Withdraw(address indexed wallet, uint256 amount, uint256 date);
    event Unstake(address indexed wallet, uint256 amount, uint256 date);
    event Claimed(address indexed wallet, address indexed rewardToken, uint256 amount);

    event RewardTokenChanged(address indexed oldRewardToken, uint256 returnedAmount, address indexed newRewardToken);
    event LockTimePeriodChanged(uint256 lockTimePeriod);
    event StakeRewardFactorChanged(uint256 stakeRewardFactor);
    event StakeRewardEndTimeChanged(uint256 stakeRewardEndTime);
    event ERC20TokensRemoved(address indexed tokenAddress, address indexed receiver, uint256 amount);
    event SetYeatToSeconds( uint256 _seconds);

    uint256 public constant PERCENT_MUL = 100;
    uint256 public constant PERCENT_DIV = 10000;

    uint256 public yearToSeconds;
    struct User {
        uint256 stakeTime;
        uint256 unstakeTime; // unstake requested time
        uint256 inUnStakeAmount; // unstake token inprogress to be withdrawn
        uint256 stakeAmount;
        uint256 accumulatedRewards;
    }

    mapping(address => User) public userMap;

    uint256 public tokenTotalStaked; // sum of all staked tokens
    uint256 public totalStakerCount; 

    address public stakingToken; // address of token which can be staked into this contract
    address public rewardToken; // address of reward token

    uint256 public lockTimePeriod; // time in seconds a user has to wait after calling unlock until staked token can be withdrawn
    uint256 public stakeRewardEndTime; // unix time in seconds when the reward scheme will end
    uint256 public stakeRewardAPY;

    constructor(address _stakingToken, address _rewardToken) {
        require(_stakingToken != address(0), "_stakingToken.address == 0");
        require(_rewardToken != address(0), "_rewardToken.address == 0");

        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        // set some defaults
        lockTimePeriod = 300; // 7 days in seconds
        stakeRewardAPY = 90; // 15%
        yearToSeconds = 31536000;
        stakeRewardEndTime = uint256(block.timestamp + 366 days);
    }

    /**
     * External API functions
     */

    function stakeTime(address _staker) external view returns (uint256 dateTime) {
        return userMap[_staker].stakeTime;
    }

    function stakeAmount(address _staker) external view returns (uint256 balance) {
        return userMap[_staker].stakeAmount;
    }

    function stakerCount() external view returns (uint256) {
        return totalStakerCount;
    }

    // redundant with stakeAmount() for compatibility
    function balanceOf(address _staker) external view returns (uint256 balance) {
        return userMap[_staker].stakeAmount;
    }

    function userAccumulatedRewards(address _staker) external view returns (uint256 rewards) {
        return userMap[_staker].accumulatedRewards;
    }

  
    function getUnlockTime(address _staker) public view returns (uint256 unlockTime) {
        return userMap[_staker].inUnStakeAmount > 0 ? block.timestamp - userMap[_staker].unstakeTime: 0;
    }

    /**
     * @return balance of reward tokens held by this contract
     */
    function getRewardTokenBalance() public view returns (uint256 balance) {
        if (rewardToken == address(0)) return 0;
        balance = IERC20(rewardToken).balanceOf(address(this));
        if (stakingToken == rewardToken) {
            balance -= tokenTotalStaked;
        }
    }

    // onlyOwner

    function setSecondsInYear(uint256 _seconds) external onlyOwner {
        yearToSeconds = _seconds;
        emit SetYeatToSeconds(_seconds);
    }

    /**
     * @notice setting rewardToken to address(0) disables claim/mint
     * @notice if there was a reward token set before, return remaining tokens to msg.sender/admin
     * @param newRewardToken address
     */
    function setRewardToken(address newRewardToken) external  onlyOwner {
        require(newRewardToken != address(0), "newRewardToken.address == 0");
        address oldRewardToken = rewardToken;
        uint256 rewardBalance = getRewardTokenBalance(); // balance of oldRewardToken
        if (rewardBalance > 0) {
            IERC20(oldRewardToken).safeTransfer(msg.sender, rewardBalance);
        }
        rewardToken = newRewardToken;
        emit RewardTokenChanged(oldRewardToken, rewardBalance, newRewardToken);
    }

    /**
     * @notice set time a user has to wait after calling unlock until staked token can be withdrawn
     * @param _lockTimePeriod time in seconds
     */
    function setLockTimePeriod(uint256 _lockTimePeriod) external onlyOwner {
        lockTimePeriod = _lockTimePeriod;
        emit LockTimePeriodChanged(_lockTimePeriod);
    }

    /**
     * @notice see calculateUserClaimableReward() docs
     * @dev requires that reward token has the same decimals as stake token
     * @param _stakeRewardAPY time in seconds * amount of staked token to receive 1 reward token
     */
    function setStakeRewardAPY(uint256 _stakeRewardAPY) external onlyOwner {
        stakeRewardAPY = _stakeRewardAPY;
        emit StakeRewardFactorChanged(_stakeRewardAPY);
    }

    /**
     * @notice set block time when stake reward scheme will end
     * @param _stakeRewardEndTime unix time in seconds
     */
    function setStakeRewardEndTime(uint256 _stakeRewardEndTime) external onlyOwner {
        require(stakeRewardEndTime > block.timestamp, "time has to be in the future");
        stakeRewardEndTime = _stakeRewardEndTime;
        emit StakeRewardEndTimeChanged(_stakeRewardEndTime);
    }

    /** public external view functions (also used internally) **************************/

    /**
     * calculates unclaimed rewards
     * @param _staker address
     * @return claimableRewards = timePeriod * stakeAmount
     */
    function userClaimableRewards(address _staker) public view returns (uint256) {
        User storage user = userMap[_staker];
        if (block.timestamp <= user.stakeTime) return 0;
        if (stakeRewardEndTime <= user.stakeTime) return 0;

        uint256 timePeriod;

        if (block.timestamp <= stakeRewardEndTime) {
            timePeriod = block.timestamp - user.stakeTime;
        } else {
            timePeriod = stakeRewardEndTime - user.stakeTime;
        }

        return timePeriod * user.stakeAmount;
    }

    function userTotalRewards(address _staker) public view returns (uint256) {
        return userClaimableRewards(_staker) + userMap[_staker].accumulatedRewards;
    }

    function getEarnedRewardTokens(address _staker) public view returns (uint256) {
        if (address(rewardToken) == address(0) || stakeRewardAPY == 0) {
            return 0;
        } else {
            return (userTotalRewards(_staker) * stakeRewardAPY * PERCENT_MUL) / PERCENT_DIV / yearToSeconds;
        }
    }

    /**
     *  @dev whenver the staked balance changes do ...
     *  @return user reference pointer for further processing
     */
    function _updateRewards(address _staker) internal returns (User storage user) {
        // calculate reward credits using previous staking amount and previous time period
        // add new reward credits to already accumulated reward credits
        user = userMap[_staker];
        user.accumulatedRewards += userClaimableRewards(_staker);

        user.stakeTime = block.timestamp;
    }

    /**
     * add stake token to staking pool
     * @dev requires the token to be approved for transfer
     * @dev we assume that (our) stake token is not malicious, so no special checks
     * @param _amount of token to be staked
     */
    function _stake(uint256 _amount) internal returns (uint256) {
        require(_amount > 0, "stake amount must be > 0");

        User storage user = _updateRewards(msg.sender); // update rewards and return reference to user
        if (user.stakeAmount == 0) {
            totalStakerCount++;
        }
        require(user.inUnStakeAmount <= 0, "eligible to stake");
        user.stakeAmount = user.stakeAmount + _amount;
        tokenTotalStaked += _amount;

        // using SafeERC20 for IERC20 => will revert in case of error
        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), _amount);

        emit Stake(msg.sender, _amount, block.timestamp);
        return _amount;
    }

    function _stakeRewards() internal returns (uint256) {
        User storage user = userMap[msg.sender];
        uint256 earnedRewardTokens = getEarnedRewardTokens(msg.sender);
        require(earnedRewardTokens > 0,"Not enough token");
        require(user.inUnStakeAmount <= 0, "eligible to stake");
        user.stakeAmount = user.stakeAmount + earnedRewardTokens;
        user.accumulatedRewards = 0;
        user.stakeTime = block.timestamp;

        tokenTotalStaked += earnedRewardTokens;

        emit StakeRewards(msg.sender, earnedRewardTokens, block.timestamp);
        return earnedRewardTokens;
    }

    /**
     * Request to withdraw staked token, ...
     * @return amount of tokens sent to user's account
     */
    function _unstake(uint256 amount) internal returns (uint256) {
        require(amount > 0, "amount to withdraw not > 0");

        User storage user = _updateRewards(msg.sender); // update rewards and return reference to user
        require(user.inUnStakeAmount <= 0, "eligible to stake");
        require(amount <= user.stakeAmount, "unstake amount > staked amount");
        require((block.timestamp - user.unstakeTime) > lockTimePeriod, "eligible to unstake");

        user.stakeAmount =  user.stakeAmount - amount;
        user.unstakeTime = block.timestamp;
        user.inUnStakeAmount = user.inUnStakeAmount + amount;

        tokenTotalStaked = tokenTotalStaked - amount;
        if (user.stakeAmount ==0 ) {
            totalStakerCount--;
        }

        emit Unstake(msg.sender, amount, block.timestamp);
        return amount;
    }

    
    /**
     * withdraw unstaked token, ...
     * @return amount of tokens sent to user's account
     */
    function _withdraw() internal returns (uint256) {
        User storage user = userMap[msg.sender];
        require((block.timestamp - user.unstakeTime) > lockTimePeriod, "staked tokens are still locked");
        uint256 amount = user.inUnStakeAmount;
        require(amount > 0, "Invalid amount");
        user.inUnStakeAmount = 0;
        // using SafeERC20 for IERC20 => will revert in case of error
        IERC20(stakingToken).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, block.timestamp); // = user.stakeTime
        return amount;
    }


    /**
     * claim reward tokens for accumulated reward credits
     */
    function _claim() internal returns (uint256) {
        require(rewardToken != address(0), "no reward token contract");
        uint256 earnedRewardTokens = getEarnedRewardTokens(msg.sender);
        require(earnedRewardTokens > 0, "no tokens to claim");

        // like _updateRewards() , but reset all rewards to 0
        User storage user = userMap[msg.sender];
        user.accumulatedRewards = 0;
        user.stakeTime = block.timestamp; // will reset userClaimableRewards to 0
        require(user.inUnStakeAmount <= 0, "eligible to stake");
        require(earnedRewardTokens <= getRewardTokenBalance(), "not enough reward tokens"); // redundant but dedicated error message
        IERC20(rewardToken).safeTransfer(msg.sender, earnedRewardTokens);

        emit Claimed(msg.sender, rewardToken, earnedRewardTokens);
        return earnedRewardTokens;
    }

    function stake(uint256 _amount) external  returns (uint256) {
        return _stake(_amount);
    }

    function stakeRewards() external  returns (uint256) {
        return _stakeRewards();
    }


    function claim() external  returns (uint256) {
        return _claim();
    }

    function unstake(uint256 _amount) external  returns (uint256) {
        return _unstake(_amount);
    }
    function withdraw() external  returns (uint256) {
        return _withdraw();
    }

    /**
     * @notice withdraw accidently sent ERC20 tokens
     * @param _tokenAddress address of token to withdraw
     */
    function removeOtherERC20Tokens(address _tokenAddress) external onlyOwner {
        uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).safeTransfer(msg.sender, balance);
        emit ERC20TokensRemoved(_tokenAddress, msg.sender, balance);
    }
}