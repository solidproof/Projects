// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

// interfaces
import "./IFarmingRange.sol";
import "./IStaking.sol";

interface IRewardManager {
    /**
     * @notice used to resetAllowance with farming contract to take rewards
     * @param _campaignId campaign id
     */
    function resetAllowance(uint256 _campaignId) external;

    /**
     * @notice used to get the farming contract address
     * @return farming contract address (or FarmingRange contract type in Solidity)
     */
    function farming() external view returns (IFarmingRange);

    /**
     * @notice used to get the staking contract address
     * @return staking contract address (or Staking contract type in Solidity)
     */
    function staking() external view returns (IStaking);
}
