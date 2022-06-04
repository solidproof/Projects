// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BlackBearFinanceToken is ERC20, Ownable {
  constructor(uint256 initialSupply) ERC20("Black Bear Finance", "BBF") {
    _mint(_msgSender(), initialSupply);
  }

  /**
   * @dev Mint token to address
   * @param _to address where to mint the token
   * @param _amount the amount of token to mint
   */
  function mint(address _to, uint256 _amount) external onlyOwner {
    _mint(_to, _amount);
  }

  /**
   * @dev Burn token to specific address
   * @param _from the address where to burn the token
   * @param _amount the number of token to burn
   */
  function burn(address _from, uint256 _amount) external onlyOwner {
    _burn(_from, _amount);
  }

  function _transfer(address _from, address _to, uint256 _amount) internal override {
    require(_to != address(this), "transfer to self not allowed");
    super._transfer(_from, _to, _amount);
  }

}