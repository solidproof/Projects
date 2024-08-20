// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract DecentraLink is ERC20, ERC20Permit {
    constructor() ERC20("DecentraLink", "DLK") ERC20Permit("DecentraLink") {
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }
}