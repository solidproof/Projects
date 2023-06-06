// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol"; 

abstract contract Taxable is Context {
	uint256 private _thetax;
    uint256 private _maxtax;
    uint256 private _mintax; 
    address private _taxdestination;

    event TaxChanged(address account); 
	event TaxDestinationChanged(address account);

	constructor() {
        _thetax = 1; 
        _maxtax = 100; 
        _mintax = 1; 
        _taxdestination = _msgSender(); 
    }

    function thetax() public view virtual returns (uint256) {
        return _thetax; 
    }

    function taxdestination() public view virtual returns (address) { 
        return _taxdestination;
    }

    function _updatetax(uint256 newtax) internal virtual {
        require(newtax <= _maxtax, "Taxable: tax is too high");
        require(newtax >= _mintax, "Taxable: tax is too low"); 
        _thetax = newtax; 
        emit TaxChanged(_msgSender());  
    }

	function _updatetaxdestination(address newdestination) internal virtual { 
        _taxdestination = newdestination; 
        emit TaxDestinationChanged(_msgSender());  
    }
}