// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 *  @dev Structs to store user staking data.
 */
struct Deposit {
    uint256 depositAmount;
    uint256 depositTime;
    uint256 endTime;
    uint32 rate;
    bool paid;
}

/**
 *  @dev Structs to store staking contract basic information
 */
struct StakingContractInfo {
    string name;
    address addr;
    uint32 lockDuration; // in hours
    uint32 rate;
    uint8 withdrawFeePercent;
}

contract Staking is Ownable {
    using SafeERC20 for IERC20;

    error AllowanceTooLow(uint256 current, uint256 required);
    error InsufficientRewardsPleaseAddRewardsOrUseEmergencyExit(
        uint256 available,
        uint256 required
    );
    error MustNotBeZero(string param);
    error NoStakeFoundForUser(address user);
    error NoZeroAddress(string param);
    error MaturityDateExpiredPleaseWithdraw();
    error StakingIsPaused();
    error MustBeLessOrEqual100();

    mapping(address => Deposit) private deposits;
    mapping(address => bool) private hasStaked;

    StakingContractInfo internal contractInfo;
    IERC20 public tokenAddress;
    address public treasury;
    uint256 public stakedBalance;
    uint256 public rewardBalance;
    uint256 public totalParticipants;
    bool public isStopped;
    uint256 public constant INTEREST_RATE_CONVERTER = 100;
    uint256 public constant YEAR_IN_SECONDS = 31536000;

    /**
     *  @notice Emitted when user stakes new value of tokens
     */
    event Staked(
        address indexed token,
        address indexed staker,
        uint256 stakedAmount
    );

    /**
     *  @notice Emitted when user withdraws his deposit
     */
    event PaidOut(
        address indexed token,
        address indexed staker,
        uint256 amount,
        uint256 reward
    );

    /**
     *  @notice Emitted when user withdraws his deposit
     */
    event RateAndLockdurationChanged(
        uint32 newRate,
        uint32 lockDuration,
        uint256 time
    );

    /**
     *  @notice Emitted when new amount of rewards is added to contract
     */
    event RewardsAdded(uint256 amount, uint256 time);

    /**
     *  @notice Emitted when contract is paused/unpaused
     */
    event StakingStatusChanged(bool status, uint256 time);

    /**
     *  @notice Emitted when owner changes withdraw fee
     */
    event WithdrawFeeChanged(uint8 newFee, uint256 time);

    modifier withdrawCheck(address from) {
        if (!hasStaked[from]) revert NoStakeFoundForUser(from);
        _;
    }

    modifier hasAllowance(address allower, uint256 amount) {
        // Make sure the allower has provided the right allowance.
        uint256 ourAllowance = tokenAddress.allowance(allower, address(this));

        if (amount > ourAllowance) revert AllowanceTooLow(ourAllowance, amount);
        _;
    }

    /**
     *   @param name name of the contract
     *   @param tokenAddress_ contract address of the token
     *   @param rate percentage
     *   @param lockDuration duration in hours
     */
    constructor(
        string memory name,
        IERC20 tokenAddress_,
        uint32 rate,
        uint32 lockDuration,
        uint8 withdrawFeePercent,
        address treasury_
    ) {
        if (withdrawFeePercent > 100) revert MustBeLessOrEqual100();
        if (address(tokenAddress_) == address(0)) {
            revert NoZeroAddress("tokenAddress_");
        }
        if (address(treasury_) == address(0)) {
            revert NoZeroAddress("treasury_");
        }

        contractInfo = StakingContractInfo(
            name,
            address(this),
            lockDuration,
            rate,
            withdrawFeePercent
        );

        tokenAddress = tokenAddress_;
        treasury = treasury_;
    }

    /**
     *  @notice owner can change current withdraw fee for stakers
     *  @param percent withdraw fee percentage
     */
    function setWithdrawFee(uint8 percent) external onlyOwner {
        if (percent > 100) revert MustBeLessOrEqual100();

        contractInfo.withdrawFeePercent = percent;

        emit WithdrawFeeChanged(percent, block.timestamp);
    }

    /**
     *  @notice to set new interest rates and lock duration
     *  @param rate New effective interest rate
     *  @param lockDuration Duration of lock for new deposits in hours
     *  @dev lockduration is in hours
     */
    function setRateAndLockduration(uint32 rate, uint32 lockDuration)
        external
        onlyOwner
    {
        contractInfo.rate = rate;
        contractInfo.lockDuration = lockDuration;

        emit RateAndLockdurationChanged(rate, lockDuration, block.timestamp);
    }

    /**
     *  @dev if _status is false contract will be "stopped" and
     *  no new deposits will be allowed
     */
    function changeStakingStatus(bool _status) external onlyOwner {
        isStopped = _status;

        emit StakingStatusChanged(_status, block.timestamp);
    }

    /**
     *  @param amount Amount to be staked
     *  @dev to stake 'amount' value of tokens
     *  once the user has given allowance to the staking contract
     */
    function stake(uint256 amount) external hasAllowance(msg.sender, amount) {
        if (amount == 0) revert MustNotBeZero("amount");
        if (isStopped) revert StakingIsPaused();

        address from = msg.sender;
        if (hasStaked[from] && (block.timestamp >= deposits[from].endTime)) {
            revert MaturityDateExpiredPleaseWithdraw();
        }

        uint256 newAmount;
        if (hasStaked[from]) {
            newAmount =
                amount +
                deposits[from].depositAmount +
                _calculate(from, block.timestamp);
        } else {
            hasStaked[from] = true;

            newAmount = amount;
            totalParticipants += 1;
        }

        deposits[from] = Deposit({
            depositAmount: newAmount,
            depositTime: block.timestamp,
            endTime: block.timestamp +
                uint256(contractInfo.lockDuration) *
                3600,
            rate: contractInfo.rate,
            paid: false
        });

        stakedBalance = stakedBalance + amount;
        tokenAddress.safeTransferFrom(from, address(this), amount);

        emit Staked(address(tokenAddress), from, amount);
    }

    function getUserDeposit(address _userAddress)
        external
        view
        returns (Deposit memory)
    {
        return deposits[_userAddress];
    }

    function getContractInfo()
        public
        view
        returns (StakingContractInfo memory)
    {
        return contractInfo;
    }

    /**
     * @notice Calcule withdraw penalty for user if deposit is withdrawn now
     *
     */
    function calculateWithdrawFee(address user) public view returns (uint256) {
        Deposit storage userDeposit = deposits[user];

        if (block.timestamp > userDeposit.endTime) {
            return 0;
        }

        return
            (userDeposit.depositAmount * contractInfo.withdrawFeePercent) / 100;
    }

    /**
     *  @param rewardAmount rewards to be added to the staking contract
     *  @dev to add rewards to the staking contract
     *  once the allowance is given to this contract for 'rewardAmount' by the user
     */
    function addReward(uint256 rewardAmount)
        external
        hasAllowance(msg.sender, rewardAmount)
    {
        if (rewardAmount == 0) revert MustNotBeZero("rewardAmount");

        rewardBalance = rewardBalance + rewardAmount;

        tokenAddress.safeTransferFrom(msg.sender, address(this), rewardAmount);

        emit RewardsAdded(rewardAmount, block.timestamp);
    }

    function withdraw() external withdrawCheck(msg.sender) {
        address from = msg.sender;
        uint256 endTime = Math.min(block.timestamp, deposits[from].endTime);
        uint256 reward = _calculate(from, endTime);

        if (rewardBalance < reward) {
            revert InsufficientRewardsPleaseAddRewardsOrUseEmergencyExit(
                rewardBalance,
                reward
            );
        }

        _withdraw(from, reward);
    }

    function _withdraw(address from, uint256 reward) private {
        uint256 penalty = calculateWithdrawFee(from);
        uint256 amount = deposits[from].depositAmount;
        uint256 amountAfterPenalty = amount - penalty;

        stakedBalance = stakedBalance - amount;
        rewardBalance = rewardBalance - reward;

        deposits[from].paid = true;
        hasStaked[from] = false;
        totalParticipants -= 1;

        // send user his deposit
        tokenAddress.safeTransfer(from, amountAfterPenalty + reward);
        if (penalty > 0) {
            // send any penalty to treasury wallet
            tokenAddress.safeTransfer(treasury, penalty);
        }

        emit PaidOut(address(tokenAddress), from, amountAfterPenalty, reward);
    }

    /**
     * @notice in case contract runs out of rewards and user is impatient
     */
    function emergencyWithdraw() external withdrawCheck(msg.sender) {
        _withdraw(msg.sender, 0);
    }

    /**
     * @param user User wallet address
     * @return totalRewards Rewards from staking if user waits for maturity/end date
     * @return currentRewards Rewards from staking if user decide to withdraw right now
     */
    function calculateRewards(address user)
        external
        view
        returns (uint256 totalRewards, uint256 currentRewards)
    {
        totalRewards = _calculate(user, deposits[user].endTime);
        currentRewards = _calculate(
            user,
            Math.min(block.timestamp, deposits[user].endTime)
        );
    }

    function _calculate(address from, uint256 endTime)
        private
        view
        returns (uint256 interest)
    {
        if (!hasStaked[from]) return 0;

        Deposit memory deposit = deposits[from];

        uint256 time = endTime - deposit.depositTime;

        interest =
            (deposit.depositAmount * deposit.rate * time) /
            (YEAR_IN_SECONDS * INTEREST_RATE_CONVERTER);

        return interest;
    }
}
