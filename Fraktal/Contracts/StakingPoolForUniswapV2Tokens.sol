// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingPoolForUniswapV2Tokens is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount; // Amount of staked tokens provided by user
        uint256 rewardDebt; // Reward debt
    }

    uint256 public constant PRECISION_FACTOR = 10**12;

    IERC20 public immutable fraktalToken;

    IERC20 public immutable stakedToken;

    uint256 public immutable START_BLOCK;

    uint256 public accTokenPerShare;

    uint256 public endBlock;

    uint256 public lastRewardBlock;

    uint256 public rewardPerBlock;

    mapping(address => UserInfo) public userInfo;

    event AdminRewardWithdraw(uint256 amount);
    event Deposit(address indexed user, uint256 amount, uint256 harvestedAmount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 harvestedAmount);
    event NewRewardPerBlockAndEndBlock(uint256 rewardPerBlock, uint256 endBlock);
    event Withdraw(address indexed user, uint256 amount, uint256 harvestedAmount);


    constructor(
        address _stakedToken,//LP token
        address _fraktalToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock//_startBlock + 1 million
    ) {
        stakedToken = IERC20(_stakedToken);
        fraktalToken = IERC20(_fraktalToken);
        rewardPerBlock = _rewardPerBlock;
        START_BLOCK = _startBlock;
        endBlock = _endBlock;

        // Set the lastRewardBlock as the start block
        lastRewardBlock = _startBlock;
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Deposit: Amount must be > 0");

        _updatePool();

        uint256 pendingRewards;

        if (userInfo[msg.sender].amount > 0) {
            pendingRewards =
                ((userInfo[msg.sender].amount * accTokenPerShare) / PRECISION_FACTOR) -
                userInfo[msg.sender].rewardDebt;

            if (pendingRewards > 0) {
                fraktalToken.safeTransfer(msg.sender, pendingRewards);
            }
        }

        stakedToken.safeTransferFrom(msg.sender, address(this), amount);

        userInfo[msg.sender].amount += amount;
        userInfo[msg.sender].rewardDebt = (userInfo[msg.sender].amount * accTokenPerShare) / PRECISION_FACTOR;

        emit Deposit(msg.sender, amount, pendingRewards);
    }

    function harvest() external nonReentrant {
        _updatePool();

        uint256 pendingRewards = ((userInfo[msg.sender].amount * accTokenPerShare) / PRECISION_FACTOR) -
            userInfo[msg.sender].rewardDebt;

        require(pendingRewards > 0, "Harvest: Pending rewards must be > 0");

        userInfo[msg.sender].rewardDebt = (userInfo[msg.sender].amount * accTokenPerShare) / PRECISION_FACTOR;
        fraktalToken.safeTransfer(msg.sender, pendingRewards);

        emit Harvest(msg.sender, pendingRewards);
    }

    function emergencyWithdraw() external nonReentrant whenPaused {
        uint256 userBalance = userInfo[msg.sender].amount;

        require(userBalance != 0, "Withdraw: Amount must be > 0");

        // Reset internal value for user
        userInfo[msg.sender].amount = 0;
        userInfo[msg.sender].rewardDebt = 0;

        stakedToken.safeTransfer(msg.sender, userBalance);

        emit EmergencyWithdraw(msg.sender, userBalance);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(
            (userInfo[msg.sender].amount >= amount) && (amount > 0),
            "Withdraw: Amount must be > 0 or lower than user balance"
        );

        _updatePool();

        uint256 pendingRewards = ((userInfo[msg.sender].amount * accTokenPerShare) / PRECISION_FACTOR) -
            userInfo[msg.sender].rewardDebt;

        userInfo[msg.sender].amount -= amount;
        userInfo[msg.sender].rewardDebt = (userInfo[msg.sender].amount * accTokenPerShare) / PRECISION_FACTOR;

        stakedToken.safeTransfer(msg.sender, amount);

        if (pendingRewards > 0) {
            fraktalToken.safeTransfer(msg.sender, pendingRewards);
        }

        emit Withdraw(msg.sender, amount, pendingRewards);
    }

    function adminRewardWithdraw(uint256 amount) external onlyOwner {
        fraktalToken.safeTransfer(msg.sender, amount);

        emit AdminRewardWithdraw(amount);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function updateRewardPerBlockAndEndBlock(uint256 newRewardPerBlock, uint256 newEndBlock) external onlyOwner {
        if (block.number >= START_BLOCK) {
            _updatePool();
        }
        require(newEndBlock > block.number, "Owner: New endBlock must be after current block");
        require(newEndBlock > START_BLOCK, "Owner: New endBlock must be after start block");

        endBlock = newEndBlock;
        rewardPerBlock = newRewardPerBlock;

        emit NewRewardPerBlockAndEndBlock(newRewardPerBlock, newEndBlock);
    }

    function calculatePendingRewards(address user) external view returns (uint256) {
        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));

        if ((block.number > lastRewardBlock) && (stakedTokenSupply != 0)) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
            uint256 tokenReward = multiplier * rewardPerBlock;
            uint256 adjustedTokenPerShare = accTokenPerShare + (tokenReward * PRECISION_FACTOR) / stakedTokenSupply;

            return (userInfo[user].amount * adjustedTokenPerShare) / PRECISION_FACTOR - userInfo[user].rewardDebt;
        } else {
            return (userInfo[user].amount * accTokenPerShare) / PRECISION_FACTOR - userInfo[user].rewardDebt;
        }
    }

    function _updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }

        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));

        if (stakedTokenSupply == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
        uint256 tokenReward = multiplier * rewardPerBlock;

        // Update only if token reward for staking is not null
        if (tokenReward > 0) {
            accTokenPerShare = accTokenPerShare + ((tokenReward * PRECISION_FACTOR) / stakedTokenSupply);
        }

        // Update last reward block only if it wasn't updated after or at the end block
        if (lastRewardBlock <= endBlock) {
            lastRewardBlock = block.number;
        }
    }

    function _getMultiplier(uint256 from, uint256 to) internal view returns (uint256) {
        if (to <= endBlock) {
            return to - from;
        } else if (from >= endBlock) {
            return 0;
        } else {
            return endBlock - from;
        }
    }
}