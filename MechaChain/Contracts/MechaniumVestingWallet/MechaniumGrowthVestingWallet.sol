// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./MechaniumVestingWallet.sol";

/**
 * @title MechaniumGrowthVestingWallet - Hold $MECHA allocated to the growth and marketing operations with a vesting schedule
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
contract MechaniumGrowthVestingWallet is MechaniumVestingWallet {
    
    /**
     * @dev Contract constructor sets the configuration of the vesting schedule
     * @param token_ Address of the ERC20 token contract, this address cannot be changed later
     */
    constructor(IERC20 token_)
        MechaniumVestingWallet(
            token_,
            40, // Initially unlock 40%
            15, // then unlock 15%
            180 days // every 6 months
        )
    {}
}
