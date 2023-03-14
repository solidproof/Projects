// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract SWDTKN is ERC20, ERC20Permit {
    uint256 public constant cap = 1000 * 1000 * 1000 * 1 ether;

    constructor() ERC20("Sword Token", "SWDTKN") ERC20Permit("Sword Token") {
        _mint(_msgSender(), cap);
    }
}