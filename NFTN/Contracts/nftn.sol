//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NFTNToken is ERC20 {
  constructor() ERC20("NFTNetwork", "NFTN") {
    _mint(msg.sender, 200_000_000_000_000_000_000);
  }

  function decimals() public view virtual override returns (uint8) {
    return 9;
  }
}