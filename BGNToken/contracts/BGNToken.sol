// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BGNToken is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("BeatGen", "BGN") {
        _mint(msg.sender, 30_000_000 * 10 ** decimals());
    }
}