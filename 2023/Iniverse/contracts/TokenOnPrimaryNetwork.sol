// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenOnPrimaryNetwork is ERC20 {
    constructor(uint256 initialSupply) ERC20("Iniverse Token On Primary Network", "INI") {
        _mint(msg.sender, initialSupply);
    }
}