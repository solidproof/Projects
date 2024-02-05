// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract QuickIntel is ERC20 {

    //100M Supply
    constructor(uint256 _initialSupply) ERC20("Quick Intel", "QKNTL") {
        _mint(msg.sender, _initialSupply * 10 ** decimals());
    }

    function burn(uint256 value) public virtual {
        _burn(msg.sender, value);
    }

    function burnFrom(address account, uint256 value) public virtual {
        _spendAllowance(account, msg.sender, value);
        _burn(account, value);
    }
}