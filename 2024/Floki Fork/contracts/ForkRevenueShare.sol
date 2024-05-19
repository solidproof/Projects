// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Staking Contract for ERC20 Tokens
/// @notice This contract allows users to stake ERC20 tokens and earn rewards based on staking duration
/// @dev This contract implements an upgradeable staking mechanism with Reentrancy protection
contract StakingContract is OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    /// @notice ERC20 token used for staking
    IERC20Upgradeable public stakingToken;

    /// @notice ERC20 token used for rewards
    IERC20Upgradeable public rewardToken;

    /// @notice Total tokens staked in the contract
    uint256 public totalStaked;

    /// @notice Total reward tokens available in the contract
    uint256 public totalRewardTokens;

    /// @notice Maximum Annual Percentage Yield (APY) for rewards calculation
    uint256 public maxAPY;

    /// @notice Minimum Annual Percentage Yield (APY) that can be set
    uint256 public constant minimumAPY = 1;

    /// @notice Blocks per year, used for rewards calculation
    uint256 constant annualBlocks = 2102400;

    /// @notice Mapping of user addresses to their staked balance
    mapping(address => uint256) public stakedBalances;

    /// @notice Mapping of user addresses to the block number when they last staked
    mapping(address => uint256) public stakeStartBlock;

    /// @notice Emitted when tokens are staked
    /// @param user The address of the user staking tokens
    /// @param amount The amount of tokens staked
    event Staked(address indexed user, uint256 amount);

    /// @notice Emitted when tokens are unstaked
    /// @param user The address of the user unstaking tokens
    /// @param amount The amount of tokens unstaked
    event Unstaked(address indexed user, uint256 amount);

    /// @notice Emitted when rewards are paid
    /// @param user The address of the user receiving rewards
    /// @param reward The amount of reward tokens paid
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice Emitted when APY is adjusted
    /// @param oldAPY The previous APY
    /// @param newAPY The new APY
    event APYAdjusted(uint256 oldAPY, uint256 newAPY);

    /// @notice Initializes the contract with given staking and reward token addresses
    /// @param _stakingToken The ERC20 token address used for staking
    /// @param _rewardToken The ERC20 token address used for rewards
    function initialize(address _stakingToken, address _rewardToken) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        stakingToken = IERC20Upgradeable(_stakingToken);
        rewardToken = IERC20Upgradeable(_rewardToken);
        maxAPY = 30; // Default APY is set at contract initialization
    }

    /// @notice Allows users to stake a specified amount of staking tokens
    /// @dev Transfers staking tokens from user's address to contract
    /// @param amount The amount of tokens to stake
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0 tokens");
        distributeReward(msg.sender);
        stakingToken.transferFrom(msg.sender, address(this), amount);
        stakedBalances[msg.sender] += amount;
        totalStaked += amount;
        stakeStartBlock[msg.sender] = block.number;
        emit Staked(msg.sender, amount);
    }

    /// @notice Allows users to unstake a specified amount of staking tokens
    /// @dev Transfers staking tokens from contract to user's address
    /// @param amount The amount of tokens to unstake
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot unstake 0 tokens");
        require(stakedBalances[msg.sender] >= amount, "Insufficient staked balance");
        distributeReward(msg.sender);
        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;
        stakingToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    /// @notice Allows users to claim their accumulated rewards
    function claimRewards() external nonReentrant {
        distributeReward(msg.sender);
        emit RewardPaid(msg.sender, calculateReward(msg.sender)); // Emitting event with reward details right after distribution
    }

    /// @dev Internal function to distribute rewards to a user
    /// @param user The address of the user to distribute rewards to
    function distributeReward(address user) private {
        uint256 reward = calculateReward(user);
        require(reward <= totalRewardTokens, "Not enough reward tokens available");
        rewardToken.transfer(user, reward);
        totalRewardTokens -= reward;
        stakeStartBlock[user] = block.number;
    }

    /// @notice Calculates the reward for a given user
    /// @dev Calculation is based on the staked amount, duration of staking, and the current APY
    /// @param user The address of the user to calculate rewards for
    /// @return The amount of reward tokens the user is entitled to
    function calculateReward(address user) public view returns (uint256) {
        if (totalStaked == 0) return 0;
        uint256 stakedAmount = stakedBalances[user];
        uint256 blocksStaked = block.number - stakeStartBlock[user];
        uint256 currentAPY = getCurrentAPY();
        return (stakedAmount * currentAPY * blocksStaked) / (annualBlocks * 100);
    }

    /// @notice Adds reward tokens to the contract
    /// @dev Can only be called by the owner of the contract
    /// @param amount The amount of reward tokens to add
    function addRewards(uint256 amount) external onlyOwner {
        rewardToken.transferFrom(msg.sender, address(this), amount);
        totalRewardTokens += amount;
    }

    /// @notice Adjusts the maximum APY for reward calculation
    /// @dev Can only be called by the owner of the contract
    /// @param newAPY The new APY percentage to set; must not be below the minimumAPY
    function adjustMaxAPY(uint256 newAPY) public onlyOwner {
        require(newAPY >= minimumAPY, "New APY must meet the minimum threshold");
        uint256 oldAPY = maxAPY;
        maxAPY = newAPY;
        emit APYAdjusted(oldAPY, newAPY);
    }

    /// @notice Authorizes an upgrade to a new implementation contract
    /// @dev This function is called internally by the proxy and can only be triggered by the contract owner
    /// @param newImplementation The address of the new contract implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        require(newImplementation != address(0), "Invalid new implementation address");
    }

    /// @notice Gets the current APY based on the staked amounts and total supply
    /// @dev Returns a modified APY if the current base APY exceeds the maxAPY limit
    /// @return The current applicable APY
    function getCurrentAPY() public view returns (uint256) {
        if (totalStaked == 0 || totalRewardTokens == 0) {
            return 0;
        }
        uint256 baseAPY = (stakedBalances[msg.sender] * 100) / totalStaked;
        if (baseAPY > maxAPY) {
            return maxAPY;
        }
        return baseAPY;
    }

    /// @notice Retrieves the percentage of earnings for a user based on the hypothetical annual reward
    /// @param user The address of the user to calculate for
    /// @return The percentage of earnings based on the staked amount
    function getUserEarningsPercentage(address user) public view returns (uint256) {
        uint256 userStakedAmount = stakedBalances[user];
        if (userStakedAmount == 0) {
            return 0;
        }

        uint256 hypotheticalYearlyReward = (userStakedAmount * getCurrentAPY() * annualBlocks) / (annualBlocks * 100);
        return (hypotheticalYearlyReward * 10000) / userStakedAmount;
    }
}