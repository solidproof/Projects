// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract FeeSharingSystem is Initializable,ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct UserInfo {
        uint256 shares; // shares of token staked
        uint256 userRewardPerTokenPaid; // user reward per token paid
        uint256 rewards; // pending rewards
    }

    // Precision factor for calculating rewards and exchange rate
    uint256 public constant PRECISION_FACTOR = 10**18;

    IERC20Upgradeable public frakToken;

    // Reward rate (block)
    uint256 public currentRewardPerBlock;

    // Last reward adjustment block number
    uint256 public lastRewardAdjustment;

    // Last update block for rewards
    uint256 public lastUpdateBlock;

    // Current end block for the current reward period
    uint256 public periodEndBlock;

    // Reward per token stored
    uint256 public rewardPerTokenStored;

    // Total existing shares
    uint256 public totalShares;

    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount, uint256 harvestedAmount);
    event Harvest(address indexed user, uint256 harvestedAmount);
    event NewRewardPeriod(uint256 numberBlocks, uint256 rewardPerBlock, uint256 reward);
    event Withdraw(address indexed user, uint256 amount, uint256 harvestedAmount);

    function initialize(
        address _frakToken
    ) public initializer {
        __Ownable_init();
        frakToken = IERC20Upgradeable(_frakToken);
    }

    function deposit(uint256 amount, bool claimRewardToken) external nonReentrant {
        require(amount >= PRECISION_FACTOR, "Deposit: Amount must be >= 1 FRAK");


        // Update reward for user
        _updateReward(msg.sender);

        // Retrieve total amount staked by this contract
        uint256 totalAmountStaked = frakToken.balanceOf(address(this));

        // Transfer FRAK tokens to this address
        frakToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 currentShares;

        // Calculate the number of shares to issue for the user
        if (totalShares != 0) {
            currentShares = (amount * totalShares) / totalAmountStaked;
            // This is a sanity check to prevent deposit for 0 shares
            require(currentShares != 0, "Deposit: Fail");
        } else {
            currentShares = amount;
        }

        // Adjust internal shares
        userInfo[msg.sender].shares += currentShares;
        totalShares += currentShares;

        uint256 pendingRewards;

        if (claimRewardToken) {
            // Fetch pending rewards
            pendingRewards = userInfo[msg.sender].rewards;

            if (pendingRewards > 0) {
                userInfo[msg.sender].rewards = 0;
                // rewardToken.safeTransfer(msg.sender, pendingRewards);
                (bool sent,) = msg.sender.call{value: pendingRewards}("");
                require(sent, "Failed to send Ether");
            }
        }

        emit Deposit(msg.sender, amount, pendingRewards);
    }

    function harvest() external nonReentrant {

        // Update reward for user
        _updateReward(msg.sender);

        // Retrieve pending rewards
        uint256 pendingRewards = userInfo[msg.sender].rewards;

        // If pending rewards are null, revert
        require(pendingRewards > 0, "Harvest: Pending rewards must be > 0");

        // Adjust user rewards and transfer
        userInfo[msg.sender].rewards = 0;

        // Transfer reward token to sender
        // rewardToken.safeTransfer(msg.sender, pendingRewards);
        // address payable receiver = payable(msg.sender);
        (bool sent,) = msg.sender.call{value: pendingRewards}("");
        require(sent, "Failed to send Ether");

        emit Harvest(msg.sender, pendingRewards);
    }

    function withdraw(uint256 shares, bool claimRewardToken) external nonReentrant {
        require(
            (shares > 0) && (shares <= userInfo[msg.sender].shares),
            "Withdraw: Shares equal to 0 or larger than user shares"
        );

        _withdraw(shares, claimRewardToken);
    }

    function withdrawAll(bool claimRewardToken) external nonReentrant {
        _withdraw(userInfo[msg.sender].shares, claimRewardToken);
    }

    function updateRewards(uint256 reward, uint256 rewardDurationInBlocks) external onlyOwner {
        // Adjust the current reward per block
        if (block.number >= periodEndBlock) {
            currentRewardPerBlock = reward / rewardDurationInBlocks;
        } else {
            currentRewardPerBlock =
                (reward + ((periodEndBlock - block.number) * currentRewardPerBlock)) /
                rewardDurationInBlocks;
        }

        lastUpdateBlock = block.number;
        periodEndBlock = block.number + rewardDurationInBlocks;

        emit NewRewardPeriod(rewardDurationInBlocks, currentRewardPerBlock, reward);
    }

    function calculatePendingRewards(address user) external view returns (uint256) {
        return _calculatePendingRewards(user);
    }

    function calculateSharesValueInFRAK(address user) external view returns (uint256) {
        // Retrieve amount staked
        uint256 totalAmountStaked = frakToken.balanceOf(address(this));


        // Return user pro-rata of total shares
        return userInfo[user].shares == 0 ? 0 : (totalAmountStaked * userInfo[user].shares) / totalShares;
    }

    function calculateSharePriceInFRAK() external view returns (uint256) {
        uint256 totalAmountStaked = frakToken.balanceOf(address(this));

        // Adjust for pending rewards

        return totalShares == 0 ? PRECISION_FACTOR : (totalAmountStaked * PRECISION_FACTOR) / (totalShares);
    }

    function lastRewardBlock() external view returns (uint256) {
        return _lastRewardBlock();
    }

    function _calculatePendingRewards(address user) internal view returns (uint256) {
        return
            ((userInfo[user].shares * (_rewardPerToken() - (userInfo[user].userRewardPerTokenPaid))) /
                PRECISION_FACTOR) + userInfo[user].rewards;
    }

    function _checkAndAdjustFRAKTokenAllowanceIfRequired(uint256 _amount, address _to) internal {
        if (frakToken.allowance(address(this), _to) < _amount) {
            frakToken.approve(_to, type(uint256).max);
        }
    }

    function _lastRewardBlock() internal view returns (uint256) {
        return block.number < periodEndBlock ? block.number : periodEndBlock;
    }

    function _rewardPerToken() internal view returns (uint256) {
        if (totalShares == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            ((_lastRewardBlock() - lastUpdateBlock) * (currentRewardPerBlock * PRECISION_FACTOR)) /
            totalShares;
    }

    function _updateReward(address _user) internal {
        if (block.number != lastUpdateBlock) {
            rewardPerTokenStored = _rewardPerToken();
            lastUpdateBlock = _lastRewardBlock();
        }

        userInfo[_user].rewards = _calculatePendingRewards(_user);
        userInfo[_user].userRewardPerTokenPaid = rewardPerTokenStored;
    }

    function _withdraw(uint256 shares, bool claimRewardToken) internal {

        // Update reward for user
        _updateReward(msg.sender);

        // Retrieve total amount staked and calculated current amount (in FRAK)
        uint256 totalAmountStaked = frakToken.balanceOf(address(this));
        uint256 currentAmount = (totalAmountStaked * shares) / totalShares;

        userInfo[msg.sender].shares -= shares;
        totalShares -= shares;

        uint256 pendingRewards;

        if (claimRewardToken) {
            // Fetch pending rewards
            pendingRewards = userInfo[msg.sender].rewards;

            if (pendingRewards > 0) {
                userInfo[msg.sender].rewards = 0;
                // rewardToken.safeTransfer(msg.sender, pendingRewards);
                (bool sent,) = msg.sender.call{value: pendingRewards}("");
                require(sent, "Failed to send Ether");
            }
        }

        // Transfer FRAK tokens to sender
        frakToken.safeTransfer(msg.sender, currentAmount);

        emit Withdraw(msg.sender, currentAmount, pendingRewards);
    }

    //for gnosis multisig
    function emergencyWithdraw() external onlyOwner{
        (bool sent,) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    receive() external payable{
    }


}