// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MechaniumBis - $MECHABIS ERC20 for MechaChain play to earn project testing
 * @notice 100 000 000 $MECHABIS are preminted on deployment to the admin wallet
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
contract MechaniumBis is ERC20 {

    /**
     * @dev Contract constructor
     * @param adminWallet address of the MechaChain admin wallet
     */
    constructor(address adminWallet) ERC20("MechaniumBis", "$MECHABIS") {
        _mint(adminWallet, 100000000 * 10**decimals());
    }
}
