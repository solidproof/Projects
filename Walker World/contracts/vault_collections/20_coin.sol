// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Coin is ERC20 {
    constructor() ERC20("Coin", "CN") {
        _mint(msg.sender, 100);
    }
}
