// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Staking.sol";

struct Tier {
    string name;
    uint256 amountNeeded;
    uint16 weight;
}

contract Helper is Ownable {
    using SafeERC20 for IERC20;
    error TiersShouldBeOrderByAmountNeeded();

    Staking[] public stakingContracts;
    Tier[] public tiers;
    mapping(string => Tier) public tiersMap;

    /**
     * @dev Tiers should be ordered asc by amountNeeded
     * @param _stakingContracts Array of all of staking contracts deployed
     * @param _tiers Array of all staking tiers
     */
    constructor(Staking[] memory _stakingContracts, Tier[] memory _tiers) {
        for (uint8 i = 0; i < _stakingContracts.length; i++) {
            stakingContracts.push(_stakingContracts[i]);
        }

        Tier memory noneTier = Tier("NONE", 0, 0);
        tiers.push(noneTier);
        tiersMap["NONE"] = noneTier;

        Tier memory prevTier = tiers[0];
        for (uint256 i = 0; i < _tiers.length; i++) {
            if (prevTier.amountNeeded >= _tiers[i].amountNeeded) {
                revert TiersShouldBeOrderByAmountNeeded();
            }
            tiers.push(_tiers[i]);
            tiersMap[_tiers[i].name] = _tiers[i];

            prevTier = _tiers[i];
        }
    }

    /**
     * @notice Returns array of all possible tiers including "NONE"
     */
    function getTiersData() external view returns (Tier[] memory) {
        return tiers;
    }

    /**
     * @notice Aggregates data from all staking contracts to determine user tier
     * @param user  Address of the staker
     */
    function getUserStakingData(address user)
        external
        view
        returns (
            string memory tierName,
            uint256 totalAmount,
            Deposit[] memory userDeposits
        )
    {
        userDeposits = new Deposit[](stakingContracts.length);

        for (uint256 i = 0; i < stakingContracts.length; i++) {
            userDeposits[i] = stakingContracts[i].getUserDeposit(user);

            if (
                !userDeposits[i].paid &&
                // wait for at least one block before validating user deposit
                block.timestamp > userDeposits[i].depositTime
            ) {
                totalAmount += userDeposits[i].depositAmount;
            }
        }

        for (uint256 j = tiers.length - 1; j >= 0; j--) {
            if (totalAmount >= tiers[j].amountNeeded) {
                tierName = tiers[j].name;
                break;
            }
        }

        return (tierName, totalAmount, userDeposits);
    }

    /**
     * @notice Aggregates contract info from all staking contracts to make things easier on FE
     */
    function getStakingContractsInfo()
        external
        view
        returns (StakingContractInfo[] memory stakingContractsInfo)
    {
        stakingContractsInfo = new StakingContractInfo[](
            stakingContracts.length
        );

        for (uint256 i = 0; i < stakingContracts.length; i++) {
            stakingContractsInfo[i] = stakingContracts[i].getContractInfo();
        }

        return stakingContractsInfo;
    }

    // @notice rescue any token accidentally sent to this contract
    function emergencyWithdrawToken(IERC20 token) external onlyOwner {
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }
}
