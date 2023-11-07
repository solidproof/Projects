// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IRewardsDistributionRecipient } from "../interfaces/IRewardsDistributionRecipient.sol";

/**
 * @title  RewardsDistributionRecipient
 * @author Originally: Synthetix (forked from /Synthetixio/synthetix/contracts/RewardsDistributionRecipient.sol) 
 * @notice RewardsDistributionRecipient gets notified of additional rewards by the rewardsDistributor
 * @dev    Changes: Addition of `getRewardToken` func + cosmetic
 */
abstract contract RewardsDistributionRecipient is IRewardsDistributionRecipient, Ownable {
    /** @notice RewardsDistributor Event */
    event RewardsDistributor(address indexed sender, address rewardsDistributor);

    // @abstract
    function notifyRewardAmount(uint256 reward) external virtual override;

    function getRewardToken() external view virtual override returns (IERC20);

    // This address has the ability to distribute the rewards
    address public rewardsDistributor;

    /**  
     *  @param _rewardsDistributor Rewards distributor address
    */
    constructor(address _rewardsDistributor) {
        require(_rewardsDistributor != address(0), "invalid rewardsDistributor address");
        rewardsDistributor = _rewardsDistributor;
        emit RewardsDistributor(msg.sender, rewardsDistributor);
    }

    /**
     * @dev Only the rewards distributor can notify about rewards
     */
    modifier onlyRewardsDistributor() {
        require(msg.sender == rewardsDistributor, "Caller is not reward distributor");
        _;
    }

    /**
     * @dev Change the rewardsDistributor - only called by Carbon Starter owner
     * @param _rewardsDistributor   Address of the new distributor
     */
    function setRewardsDistribution(address _rewardsDistributor) external onlyOwner {
        rewardsDistributor = _rewardsDistributor;
        emit RewardsDistributor(msg.sender, rewardsDistributor);
    }
}
