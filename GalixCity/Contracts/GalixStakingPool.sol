// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/// @title Galix staking.
/// @notice It is a smart contract staking erc20 token
/// earn erc20 token. Fork Synthetix StakingRewards
contract GalixStakingPool is 
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{

    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    IERC20Upgradeable public stakedToken;
    IERC20Upgradeable public rewardToken;
    address public rewardDistribution;

    uint256 public releaseTime;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public MIN_REWARD_CLAIM;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    modifier onlyRewardDistribution() {
        require(_msgSender() == rewardDistribution, "Caller is not reward distribution");
        _;
    }

    /// @notice Initialize the contract
    /// @param _stakedToken address of staked token
    /// @param _rewardToken address of reward token
    /// @param _rewardDistribution address of reward distribution
    function initialize(
        address _stakedToken,
        address _rewardToken,
        address _rewardDistribution
    ) external initializer {
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();

        stakedToken = IERC20Upgradeable(_stakedToken);
        rewardToken = IERC20Upgradeable(_rewardToken);
        rewardDistribution = _rewardDistribution;

        MIN_REWARD_CLAIM = 1 ether;
        releaseTime = 0;
    }

    /// @notice Deposit staked token to contract
    /// @dev Callable by users
    /// @param _amount amount of staked token to deposit
    function stake(uint256 _amount) external whenNotPaused nonReentrant {
        address account = _msgSender();

        _updateReward(account);

        stakedToken.safeTransferFrom(account, address(this), _amount);
        balances[account] = balances[account].add(_amount);

        emit Staked(account, _amount);
    }

    /// @notice Withdraw staked token
    /// @dev Callable by users
    /// @param _amount amount of staked token to withdraw
    function withdraw(uint256 _amount) public whenNotPaused nonReentrant {
        address account = _msgSender();

        require(balances[account] >= _amount, "withdraw: amount withdraw exceeds");

        _updateReward(account);

        balances[account] = balances[account].sub(_amount);
        stakedToken.safeTransfer(account, _amount);

        emit Withdrawn(account, _amount);
    }

    /// @notice Get reward
    /// @dev Callable by users
    function getReward() public whenNotPaused nonReentrant {
        address account = _msgSender();
        _updateReward(account);

        require(rewards[account] >= MIN_REWARD_CLAIM, "getReward: reward must be greater than MIN_REWARD_CLAIM");
        
        uint256 reward = rewards[account];
        rewards[account] = 0;
        rewardToken.safeTransfer(account, reward);

        emit RewardPaid(account, reward);
    }

    /// @notice Withdraw staked token and get reward
    /// @dev Callable by users
    function exit() external whenNotPaused nonReentrant {
        withdraw(balances[_msgSender()]);
        getReward();
    }

    /// @notice Set reward and distribution duration
    /// @dev This function is only callable by rewardDistribution.
    /// Must transfer reward token before call this function.
    /// @param _reward amount of reward
    /// @param _dayAmount amount of day paid reward
    function notifyRewardAmount(uint256 _reward, uint256 _dayAmount) external onlyRewardDistribution {
        require(_dayAmount > 0, "Day amount must not be 0");
        _updateReward(address(0));

        uint256 duration = _dayAmount.mul(1 days);

        if (_now() >= releaseTime) {
            rewardRate = _reward.div(duration);
        } else {
            require(_now().add(duration) > releaseTime, "");
            uint256 remaining = releaseTime.sub(_now());
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = _reward.add(leftover).div(duration);
        }
        lastUpdateTime = _now();
        releaseTime = _now().add(duration);
        emit RewardAdded(_reward);
    }

    /// @notice Update reward info
    /// @param _account address of user
    function _updateReward(address _account) internal {
        rewardPerTokenStored = _rewardPerToken();
        lastUpdateTime = _lastTimeRewardApplicable();
        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
    }

    /// @notice View last time reward applicable
    /// @return timestamp time reward applicable
    function _lastTimeRewardApplicable() internal view returns (uint256) {
        return MathUpgradeable.min(block.timestamp, releaseTime);
    }

    /// @notice View reward per staked token 
    /// @return rewardPerToken reward per token user staked
    function _rewardPerToken() internal view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                _lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    /// @notice View total reward token earned
    /// @dev Callable by users
    /// @param _account address of user
    /// @return reward total reward earned
    function earned(address _account) public view returns (uint256) {
        return
            balances[_account]
                .mul(_rewardPerToken().sub(userRewardPerTokenPaid[_account]))
                .div(1e18)
                .add(rewards[_account]);
    }

    /// @notice View total token staked
    /// @dev Explain to a developer any extra details
    /// @return totalSupply total balance of staked token
    function totalSupply() public view returns(uint256) {
        return stakedToken.balanceOf(address(this));
    }

    /// @notice Set new reward distribution
    /// @dev This function only callable by owner
    /// @param _rewardDistribution address of reward distribution
    function setRewardDistribution(address _rewardDistribution) external onlyOwner {
        rewardDistribution = _rewardDistribution;
    }

    /// @notice It allows the admin to recover wrong tokens sent to the contract
    /// @dev This function is only callable by owner
    /// @param _tokenAddress: the address of the token to withdraw
    /// @param _tokenAmount: the number of tokens to withdraw
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(stakedToken), "Cannot be staked token");
        require(_tokenAddress != address(rewardToken), "Cannot be reward token");

        IERC20Upgradeable(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function pause() external virtual onlyOwner {
        _pause();
    }

    function unpause() external virtual onlyOwner {
        _unpause();
    }

    function _now() internal view returns(uint256) {
        return block.timestamp;
    }

    function version() external view virtual returns (uint256) {
        return 202205171;
    }
}