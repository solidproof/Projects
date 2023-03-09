// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BaseStaking is Context, Ownable {
    uint256 internal _stakePoolWeight;
    uint256 internal _rewardPoolSize;
    uint256 internal _unlockTime;
    address internal _penaltyAddress;

    mapping(address => bool) internal _exceptions;
    mapping(address => uint256) internal _penalties;
    mapping(address => uint256) internal _stake;
    mapping(address => uint256) internal _stakeWeight;

    event Staked(address user, uint256 amount);
    event UnStaked(address user, uint256 amount);
    event StakingTokenChanged(address token);
    event RewardTokenChanged(address token);
    event RewardsAdded(uint256 amount);
    event RewardsRecovered(uint256 amount);

    constructor() {
        _stake[msg.sender] = 0;
    }

    event UnlockTimeChanged(uint256 timestamp);

    /**
     * @dev Sets the unlock time of this staking contract
     * @param timestamp The unlock time of the contract
     */
    function setUnlockTime(uint256 timestamp) external onlyOwner {
        require(_unlockTime == 0, "Unlock time is already set");
        _unlockTime = timestamp;
        emit UnlockTimeChanged(_unlockTime);
    }

    /**
     * @dev Allows reading the current unlock time of the contract
     * @return uint256 The current unlock "timestamp"
     */
    function getUnlockTime() external view returns (uint256) {
        return _unlockTime;
    }

    event PenaltyAddressChanged(address addr);

    /**
     * @dev Sets the penalty collection address for early unstakings
     * @param penalty The address that collects the penalties
     */
    function setPenaltyAddress(address penalty) external onlyOwner {
        require(
            penalty != address(0),
            "Cannot set penalty collection address to 0x0"
        );
        _penaltyAddress = penalty;
        emit PenaltyAddressChanged(penalty);
    }

    /**
     * @dev Returns true or false depending on if the user can unstake
     * @param user Address of the user
     * @return bool true if the user can unstake
     */
    function canUnstake(address user) public view returns (bool) {
        return block.timestamp >= _unlockTime || _exceptions[user];
    }

    event PenaltySetForUser(address user, uint256 penalty);

    /**
     * @dev Allow `user` to unstake early with an optional penalty
     * @param user Address of the user to add to exceptions
     * @param penalty The penalty percentage (e.g. 5 means 5% penalty)
     */
    function allowUnstakeWithPenalty(address user, uint256 penalty)
        external
        onlyOwner
    {
        require(penalty <= 25, "Cannot set penalty over 25%");
        _exceptions[user] = true;
        _penalties[user] = penalty;
        emit PenaltySetForUser(user, penalty);
    }

    /**
     * @dev Disallows user from unstaking early (default behavior)
     * @param user Address of the user to remove from exceptions
     */
    function disallowUnstakeWithPenalty(address user) external onlyOwner {
        _exceptions[user] = false;
        _penalties[user] = 0;
        emit PenaltySetForUser(user, 0);
    }

    /**
     * @dev Returns the amount of tokens currently staked by the user
     * @param user Address of the user staking tokens
     * @return uint256 Amount of tokens staked by the `user`
     */
    function getStake(address user) external view returns (uint256) {
        return _stake[user];
    }

    /**
     * @dev Get the current reward size for `user`
     * @param user Address of the user
     */
    function getRewardSize(address user) public view returns (uint256) {
        uint256 weight = _stakeWeight[user];
        return (weight * _rewardPoolSize) / _stakePoolWeight;
    }

    /**
     * @dev Sets the stake weight for a user stake event
     * @param user The `user` to set the stake time for
     * @param amount The amount of tokens staked in this event
     * @param amount The amount of tokens already staked by the `user`
     */
    function recordStakeWeight(address user, uint256 amount) internal {
        uint256 timeToUnlock = _unlockTime - block.timestamp;
        uint256 weight = amount * timeToUnlock;
        _stakePoolWeight += weight;
        _stakeWeight[user] += weight;
    }

    /**
     * @dev Sends staking rewards to a user
     * @param user Address of the user to send the rewards to
     * @param amount Amount of tokens to transfer to the user
     */
    function sendRewards(address user, uint256 amount) internal virtual;
}
