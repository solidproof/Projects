// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract OilToken is ERC20, ERC20Burnable, ERC20Permit {
    constructor() ERC20("Oil Token", "OIL") ERC20Permit("Oil Token") {
        _mint(msg.sender, 100_000_000_000 * 10 ** decimals());
    }
}