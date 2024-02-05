//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract StakingMRT is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    struct UserInfo {
        uint256 depositAmount;
        uint256 rewardDebt;
        uint256 reinvestDebt;
        uint256 timestamp;
        bool withdrawStatus;
    }

    struct PoolInfo {
        IERC20Upgradeable token;
        uint256 initializationTime;
        uint256 endingTime;
    }

    mapping(address => mapping(uint256 => UserInfo)) public userInfo;
    mapping(address => uint256) public uid;
    mapping(uint256 => bool) public claimTierStatus;
    PoolInfo public poolInfo;
    uint256 public totalMRTStaked;
    uint256 SECONDS_IN_DAY;
    uint256 TIERS;
    uint256 MIN_VAULT_DAYS;
    uint256 MAX_VAULT_DAYS;

    event depositTokens(address user, uint256 amount);
    event withdrawTokens(address user, uint256 amount);
    event claimTokens(address user, uint256 amount);
    event reinvestTokens(address user, uint256 amount);

    function initialize(
        IERC20Upgradeable _token,
        uint256 _startTime,
        uint256 _seconds,
        uint256 _vault
    ) public initializer {
        __Ownable_init();
        SECONDS_IN_DAY = _seconds;
        TIERS = 4;
        MIN_VAULT_DAYS = _vault;
        MAX_VAULT_DAYS = MIN_VAULT_DAYS * TIERS;
        poolInfo.token = _token;
        poolInfo.initializationTime = _startTime;
        poolInfo.endingTime = poolInfo.initializationTime.add(
            MAX_VAULT_DAYS.mul(SECONDS_IN_DAY)
        );
    }

    function deposit(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            poolInfo.token.balanceOf(msg.sender) >= _amount,
            "Not enough amount available"
        );

        uint256 minJoiningPeriod = poolInfo.initializationTime.add(
            (MIN_VAULT_DAYS.mul(3).mul(SECONDS_IN_DAY))
        );

        require(
            block.timestamp <= minJoiningPeriod.add(SECONDS_IN_DAY),
            "deposit disabled"
        );

        UserInfo storage user = userInfo[msg.sender][++uid[msg.sender]];
        poolInfo.token.transferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.depositAmount = _amount;
        if (poolInfo.initializationTime > block.timestamp) {
            user.timestamp = poolInfo.initializationTime;
        } else {
            user.timestamp = block.timestamp;
        }
        totalMRTStaked = totalMRTStaked.add(_amount);
        emit depositTokens(msg.sender, _amount);
    }

    function withdraw(uint256 _uid) public {
        require(checkEligibility(msg.sender, _uid), "Not eligible to withdraw");

        UserInfo storage user = userInfo[msg.sender][_uid];

        uint256 userReward = calculateRewards(msg.sender, _uid);

        poolInfo.token.transfer(
            address(msg.sender),
            user.depositAmount.add(userReward)
        );
        user.rewardDebt = user.rewardDebt.add(userReward);
        user.withdrawStatus = true;
        totalMRTStaked = totalMRTStaked.sub(user.depositAmount);
        user.depositAmount = 0;
        emit withdrawTokens(msg.sender, user.depositAmount.add(userReward));
    }

    function emergencyWithdraw(uint256 _uid) public {
        UserInfo storage user = userInfo[msg.sender][_uid];

        require(user.withdrawStatus == false, "Already withdrawn");

        uint256 userReward = calculateRewards(msg.sender, _uid);

        poolInfo.token.transfer(
            address(msg.sender),
            user.depositAmount.add(userReward)
        );
        user.rewardDebt = user.rewardDebt.add(userReward);
        user.withdrawStatus = true;
        totalMRTStaked = totalMRTStaked.sub(user.depositAmount);
        user.depositAmount = 0;
        emit withdrawTokens(msg.sender, user.depositAmount.add(userReward));
    }

    function emergencyWithdrawRewardsAdmin(uint256 _amount, address _account)
        public
        onlyOwner
    {
        uint256 balanceOnContract = poolInfo.token.balanceOf(address(this));

        require(
            balanceOnContract >= totalMRTStaked,
            "Not enough reward amount"
        );

        uint256 eligibleAdminAmount = balanceOnContract.sub(totalMRTStaked);

        require(
            _amount <= eligibleAdminAmount && _amount > 0,
            "Amount more than reward"
        );

        poolInfo.token.transfer(_account, _amount);
        emit withdrawTokens(_account, _amount);
    }

    function getUserCurrentTier(address _user, uint256 _uid)
        public
        view
        returns (uint256 tier)
    {
        UserInfo storage user = userInfo[_user][_uid];

        uint256 currentTime = block.timestamp;
        if (currentTime >= poolInfo.endingTime) {
            currentTime = poolInfo.endingTime;
        }

        tier = ((currentTime.sub(user.timestamp)).div(SECONDS_IN_DAY)).div(
            MIN_VAULT_DAYS
        );
    }

    function calculateRewards(address _user, uint256 _uid)
        public
        view
        returns (uint256 reward)
    {
        UserInfo storage user = userInfo[_user][_uid];

        reward = calculateReward(_user, _uid).sub(user.rewardDebt);
    }

    function calculateReward(address _user, uint256 _uid)
        internal
        view
        returns (uint256 reward)
    {
        UserInfo storage user = userInfo[_user][_uid];

        if (user.depositAmount == 0) {
            return 0;
        }

        uint256 tier = getUserCurrentTier(_user, _uid);

        reward = (user.depositAmount.mul(10).div(100)).mul(tier);
    }

    function checkEligibility(address _user, uint256 _uid)
        public
        view
        returns (bool eligible)
    {
        UserInfo storage user = userInfo[_user][_uid];

        uint256 currentTime = block.timestamp;
        if (currentTime >= poolInfo.endingTime) {
            currentTime = poolInfo.endingTime;
        }
        uint256 timeInSeconds = currentTime.sub(user.timestamp);
        uint256 tierNumber = timeInSeconds % MIN_VAULT_DAYS.mul(SECONDS_IN_DAY);

        if (
            (tierNumber <= SECONDS_IN_DAY ||
                block.timestamp >= poolInfo.endingTime) &&
            user.withdrawStatus == false &&
            timeInSeconds > SECONDS_IN_DAY
        ) {
            return true;
        } else {
            return false;
        }
    }

    function checkRewardEligibility(address _user, uint256 _uid)
        public
        view
        returns (bool eligible)
    {
        if (
            checkEligibility(_user, _uid) &&
            (claimTierStatus[getUserCurrentTier(_user, _uid)]) != true
        ) {
            eligible = true;
        } else {
            eligible = false;
        }
    }

    function claimReward(uint256 _uid) public {
        require(
            checkRewardEligibility(msg.sender, _uid),
            "Not eligible to claim reward"
        );

        UserInfo storage user = userInfo[msg.sender][_uid];

        uint256 userReward = calculateRewards(msg.sender, _uid);

        require(userReward > 0, "No reward to claim");

        poolInfo.token.transfer(address(msg.sender), userReward);
        user.rewardDebt = user.rewardDebt.add(userReward);

        uint256 userTiers = getUserCurrentTier(address(msg.sender), _uid);
        for (uint256 i = 1; i <= userTiers; i++) {
            claimTierStatus[i] = true;
        }
        emit claimTokens(msg.sender, userReward);
    }

    function reinvestReward(uint256 _uid) public {
        require(
            checkRewardEligibility(msg.sender, _uid),
            "Not eligible to reinvest reward"
        );

        uint256 minJoiningPeriod = poolInfo.initializationTime.add(
            (MIN_VAULT_DAYS.mul(3).mul(SECONDS_IN_DAY))
        );
        require(
            block.timestamp <= minJoiningPeriod.add(SECONDS_IN_DAY),
            "reinvest disabled"
        );

        UserInfo storage user = userInfo[msg.sender][_uid];

        uint256 userReward = calculateRewards(msg.sender, _uid);

        require(userReward > 0, "No reward to reinvest");

        user.depositAmount = user.depositAmount.add(userReward);
        uint256 userTiers = getUserCurrentTier(address(msg.sender), _uid);

        user.timestamp = user.timestamp.add(
            MIN_VAULT_DAYS.mul(SECONDS_IN_DAY).mul(userTiers)
        );
        user.reinvestDebt = user.reinvestDebt.add(user.rewardDebt);
        user.rewardDebt = 0;

        for (uint256 i = 1; i <= userTiers; i++) {
            claimTierStatus[i] = false;
        }
        totalMRTStaked = totalMRTStaked.add(userReward);
        emit reinvestTokens(msg.sender, userReward);
    }
}