// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Taxable.sol";

contract PUSS is ReentrancyGuard, ERC20, ERC20Burnable, AccessControl, Taxable {

    bytes32 public constant EXCLUDED_ROLE = keccak256("EXCLUDED_ROLE");   // Any address added to this excluded role will be excluded from taxes, if turned on.

    constructor() ERC20("PUSS", "PUSS") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EXCLUDED_ROLE, msg.sender);
        _mint(msg.sender, 100000000000000 * 10 ** decimals());
    }

/// @dev Add the public functions for the GOVERNOR_ROLE to enable, disable, an update the tax:

    function updateTax(uint newtax) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _updatetax(newtax);
    }

    function updateTaxDestination(address newdestination) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _updatetaxdestination(newdestination);
    }

/// @dev Override the _transfer() function to perform the necessary tax functions:

   function _transfer(address from, address to, uint256 amount)
        internal
        virtual
        override(ERC20)
        nonReentrant
    {
        if(hasRole(EXCLUDED_ROLE, from) || hasRole(EXCLUDED_ROLE, to)) {
            super._transfer(from, to, amount);
        } else {
            require(balanceOf(from) >= amount, "ERC20: transfer amount exceeds balance");
            super._transfer(from, taxdestination(), amount*thetax()/10000); 
            super._transfer(from, to, amount*(10000-thetax())/10000); 
        }
    }
}