//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HeroInfinityToken is ERC20 {
  constructor() ERC20("Hero Infinity Token", "HRI") {
    _mint(msg.sender, 10**(9 + 18)); // 1B total supply
  }
}