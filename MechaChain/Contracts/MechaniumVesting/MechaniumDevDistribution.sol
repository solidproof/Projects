// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./MechaniumTeamDistribution.sol";

/**
 * @title MechaniumDevDistribution - Vesting and distribution smart contract for the MechaChain development team
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
contract MechaniumDevDistribution is MechaniumTeamDistribution {
    
    /**
     * @dev Contract constructor sets the configuration of the vesting schedule
     * @param token_ Address of the ERC20 token contract, this address cannot be changed later
     */
    constructor(IERC20 token_)
        MechaniumTeamDistribution(
            token_,
            0, // at the allocation
            20, // unlock 20%
            90 days // and repeat every 3 months
        )
    {}
}
