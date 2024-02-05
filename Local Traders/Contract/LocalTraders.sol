// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.1 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LocalTraders is ERC20 {
  constructor() ERC20("Local Traders", "LCT") {
        _mint(address(this), 300000000 * (10 ** uint256(decimals())));
        _approve(address(this), msg.sender, totalSupply());
        _transfer(address(this), msg.sender, totalSupply());
  }
}
