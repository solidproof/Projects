// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Mechanium - Official $MECHA ERC20 for MechaChain play to earn project
 * @notice 100 000 000 $MECHA are preminted on deployment to the admin wallet
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
contract Mechanium is ERC20 {

    /**
     * @dev Contract constructor
     * @param adminWallet address of the MechaChain admin wallet
     */
    constructor(address adminWallet) ERC20("Mechanium", "$MECHA") {
        _mint(adminWallet, 100000000 * 10**decimals());
    }
}
