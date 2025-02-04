// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./LaunchPadData.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title LaunchPadVesting
 * @dev Contract handling vesting schedules for projects.
 */
contract LaunchPadVesting is LaunchPadData, OwnableUpgradeable {
    // --------------------------------------------------
    // Admin Functions
    // --------------------------------------------------

    /**
     * @dev Updates the vesting schedule for a project.
     * @param projectId The ID of the project.
     * @param percentages The percentages vested at each interval.
     * @param intervals The time intervals in seconds.
     * NOTE intervals must be incremental
     */
    function updateVestingSchedule(
        uint256 projectId,
        uint256[] memory percentages,
        uint256[] memory intervals
    ) external onlyOwner {
        require(
            projectId < projectCount,
            "UpdateVestingSchedule:: Invalid project id"
        );
        require(
            percentages.length == intervals.length,
            "UpdateVestingSchedule:: Mismatched percentages and intervals"
        );
        ProjectInfo storage project = projectInfos[projectId];
        require(!project.isSaleEnded, "UpdateVestingSchedule:: Sale Ended");

        uint256 sum = 0;
        uint256 previousInterval = 0;

        for (uint256 i = 0; i < percentages.length; i++) {
            require(
                percentages[i] > 0,
                "UpdateVestingSchedule:: Invalid percentage"
            );
            require(
                intervals[i] >= previousInterval,
                "UpdateVestingSchedule:: Intervals must be incremental"
            );

            sum += percentages[i];
            previousInterval = intervals[i];
        }

        require(sum == 100, "UpdateVestingSchedule:: Invalid percentages");

        VestingInfo storage vesting = vestingsInfo[projectId];
        vesting.percentages = percentages;
        vesting.intervals = intervals;
        vesting.isSet = true;

        emit VestingScheduleUpdated(projectId, chainId, percentages, intervals);
    }

    // --------------------------------------------------
    // Internal Functions
    // --------------------------------------------------

    /**
     * @dev Calculates the vested percentage based on elapsed time.
     * @param vesting The vesting information.
     * @param elapsedTime The elapsed time since the vesting started.
     * @return The vested percentage.
     */
    function _calculateVestedPercentage(
        VestingInfo storage vesting,
        uint256 elapsedTime
    ) internal view returns (uint256) {
        uint256 vestedPercentage = 0;
        uint256 cumulativeTime = 0;

        for (uint256 i = 0; i < vesting.intervals.length; i++) {
            cumulativeTime += vesting.intervals[i];
            if (elapsedTime >= cumulativeTime) {
                vestedPercentage += vesting.percentages[i];
            } else {
                break;
            }
        }

        return vestedPercentage;
    }

    // --------------------------------------------------
    // View Functions
    // --------------------------------------------------

    function getVestingSchedule(
        uint256 projectId
    )
        public
        view
        returns (
            bool isSet,
            uint256[] memory percentages,
            uint256[] memory intervals
        )
    {
        VestingInfo storage schedule = vestingsInfo[projectId];
        return (schedule.isSet, schedule.percentages, schedule.intervals);
    }

    function updateStakingTierRequirements(
        uint256 tier,
        uint256 requiredStake
    ) external onlyOwner {
        require(tier < 4, "UpdateStakingTierRequirements:: Invalid tier");
        requiredStakingPerTier[tier] = requiredStake;
        emit StakingTierRequirementsUpdated(tier, requiredStake, chainId);
    }

    function isContractOrZero(address account) public view returns (bool) {
        return (account == address(0) || account.code.length > 0);
    }

    function updateStakingContract(
        address newStakingContract
    ) public onlyOwner {
        require(
            isContractOrZero(newStakingContract),
            "UpdateStakingContract:: Invalid staking contract"
        );
        stakingContract = newStakingContract;
        emit StakingContractUpdated(newStakingContract, chainId);
    }

    function getUserSchedule(
        uint256 projectId,
        address user
    )
        public
        view
        returns (
            uint256[] memory schedule,
            uint256[] memory amounts,
            bool[] memory claimed
        )
    {
        return (
            vestingSchedule[projectId][user],
            vestingAmounts[projectId][user],
            vestingClaimed[projectId][user]
        );
    }
}
