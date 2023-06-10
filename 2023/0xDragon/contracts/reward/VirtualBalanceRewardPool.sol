// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.18;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VirtualBalanceRewardPool is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public rewardToken;
    uint256 public constant duration = 30 days;

    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public historicalRewards;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    mapping(address => uint256) public balanceOf;
    uint public totalSupply;

    event RewardAdded(uint256 reward);
    event UpdateStaked(
        address indexed user,
        uint256 oldAmount,
        uint256 newAmount
    );
    event RewardPaid(address indexed user, uint256 reward);

    address public basePool;
    address public manager;

    constructor(address reward_, address basePool_) {
        rewardToken = IERC20(reward_);
        basePool = basePool_;
    }

    function setManager(address _manager) external onlyOwner {
        manager = _manager;
    }

    function updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRate *
                1e18) /
            totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return
            (balanceOf[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) /
            1e18 +
            rewards[account];
    }

    function updateStaked(address _account, uint256 newAmount) external {
        require(msg.sender == address(basePool), "!authorized");
        updateReward(_account);

        uint oldStaked = balanceOf[_account];
        totalSupply -= oldStaked;
        balanceOf[_account] = newAmount;
        totalSupply += newAmount;

        emit UpdateStaked(_account, oldStaked, newAmount);
    }

    function getReward(address _account) internal {
        updateReward(_account);
        uint256 reward = earned(_account);
        if (reward > 0) {
            rewards[_account] = 0;
            rewardToken.safeTransfer(_account, reward);
            emit RewardPaid(_account, reward);
        }
    }

    function getRewardBasePool(address _account) external {
        require(msg.sender == address(basePool), "!authorized");
        getReward(_account);
    }

    function getReward() external {
        getReward(msg.sender);
    }

    function notifyRewardAmount(uint256 reward) external {
        require(msg.sender == manager, "!authorized");
        updateReward(address(0));
        historicalRewards += reward;
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / duration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / duration;
        }

        uint balance = rewardToken.balanceOf(address(this));
        require(rewardRate <= balance / duration, "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;
        emit RewardAdded(reward);
    }

    function recoverToken(address[] calldata tokens) external onlyOwner {
        unchecked {
            for (uint8 i; i < tokens.length; i++) {
                IERC20(tokens[i]).safeTransfer(
                    msg.sender,
                    IERC20(tokens[i]).balanceOf(address(this))
                );
            }
        }
    }
}
