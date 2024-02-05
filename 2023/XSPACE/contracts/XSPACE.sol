// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract XSPACE is ERC20, ERC20Burnable {
    constructor() ERC20("XSPACE", "XSP") {
        _mint(msg.sender, 10 ** 9 * 10 ** decimals());
    }
}