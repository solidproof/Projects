// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../Base.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

abstract contract ERC20Rewards is BaseStaking {
    IERC20 internal _rewardToken;

    /**
     * @dev Allows setting the reward token.
     * @param token The address of the reward token.
     */
    function setRewardToken(address token) external onlyOwner {
        require(token != address(0), "Can't set token to address(0)");
        _rewardToken = IERC20(token);
        emit RewardTokenChanged(token);
    }

    /**
     * @dev Returns the address of the reward token.
     * @return address The address of the reward token.
     */
    function getRewardToken() external view returns (address) {
        return address(_rewardToken);
    }

    /**
     * @dev Allows adding rewards to the pool.
     * @param amount The amount of rewards to be added to the pool.
     */
    function addReward(uint256 amount) external {
        require(amount > 0, "Cannot stake 0 tokens");
        _rewardPoolSize += amount;
        require(
            _rewardToken.transferFrom(_msgSender(), address(this), amount),
            "Transfer failed!"
        );
        emit RewardsAdded(amount);
    }

    /**
     * @dev Allows recovering rewards from the pool.
     * @param amount The amount of rewards to be recovered from the pool.
     */
    function recoverRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Cannot remove 0 tokens");
        require(
            _rewardPoolSize >= amount,
            "Cannot remove more than originally added"
        );
        _rewardPoolSize -= amount;
        require(
            _rewardToken.transfer(_msgSender(), amount),
            "Transfer failed!"
        );
        emit RewardsRecovered(amount);
    }

    /**
     * @dev Sends rewards to a user.
     * @param user The address of the user.
     * @param amount The amount of rewards to be sent to the user.
     */
    function sendRewards(address user, uint256 amount)
        internal
        override(BaseStaking)
    {
        if (amount > 0 && address(_rewardToken) != address(0)) {
            require(_rewardToken.transfer(user, amount), "Transfer failed!");
        }
    }
}
