// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract SIGN is ERC20 {
    uint8 private _decimals;
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _totalSupply
    ) ERC20(_name, _symbol) {       
        _decimals=__decimals;
        _mint(msg.sender, _totalSupply);
    }
    function decimals() public view override returns (uint8) {
        return _decimals;
    }    
}