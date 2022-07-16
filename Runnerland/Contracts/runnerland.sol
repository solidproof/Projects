// SPDX-License-Identifier: Private License -


pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Authorized.sol";

contract RunnerLandToken is Authorized, ERC20 {
  string constant _name = "Runner Land Token";
  string constant _symbol = "RLT";

  string constant public url = "www.runner.land";
  string constant public author = "Lameni";

  uint256 constant maxSupply = 1_000_000_000e18;

  receive() external payable { }

  constructor()ERC20(_name, _symbol) {
    _mint(_msgSender(), maxSupply);
  }

  // ----------------- External Methods -----------------
  function burn(uint256 amount) external { _burn(_msgSender(), amount); }
}