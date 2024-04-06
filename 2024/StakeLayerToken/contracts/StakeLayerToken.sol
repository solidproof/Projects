// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';

contract StakeLayerToken is ERC20, ERC20Burnable, ERC20Permit {
  string private constant NAME = "StakeLayer";
  string private constant SYMBOL = "STAKE ";
  uint256 private constant TOTAL_SUPPLY = 5000000000 * 10 ** 18;

  constructor() ERC20(NAME, SYMBOL) ERC20Permit(NAME) {
    _mint(msg.sender, TOTAL_SUPPLY);
  }
}