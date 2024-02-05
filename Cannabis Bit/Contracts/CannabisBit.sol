// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title CannabisBit
 */
contract CannabisBit is ERC20, Ownable {
  using SafeMath for uint256;

  uint256 public supply = 1_000_000 ether;
  uint256 public founderCoreteamAdvisor = 10_000 ether;
  uint256 public reserved = 10_000 ether;

  constructor() ERC20("CannabisBit", "CBC") {
    
  }

  /*
   * @dev mint function use to mint tokens to any wallet address
   * @param _recipients : address's array to mint tokens
   * @param _amount : amount to mint the tokens
   */
  function mint(address[] calldata _recipients, uint256[] calldata _amount) public onlyOwner {
    for (uint256 i = 0; i < _recipients.length; i++) {
      require(_recipients[i] != address(0), "ADDRESS REQUIRED");
      require(_amount[i] > 0, "AMOUNT REQUIRED");
      if(supply.sub(_amount[i]) > 0){
        supply = supply.sub(_amount[i]);
      }
      _mint(_recipients[i], _amount[i]);
    }
  }

  /*
   * @dev mintFounderCoreteamAdvisor function use to mint tokens to any wallet address
   * @param _recipients : address's array to mint tokens
   * @param _amount : amount to mint the tokens
   */
  function mintFounderCoreteamAdvisor(address[] calldata _recipients, uint256[] calldata _amount) public onlyOwner {
    for (uint256 i = 0; i < _recipients.length; i++) {
      require(_recipients[i] != address(0), "ADDRESS REQUIRED");
      require(_amount[i] > 0, "AMOUNT REQUIRED");
      require(_amount[i] <= founderCoreteamAdvisor, "AMOUNT REQUIRED");
      founderCoreteamAdvisor = founderCoreteamAdvisor.sub(_amount[i]);
      _mint(_recipients[i], _amount[i]);
    }
  }

  /*
   * @dev mintReserved function use to mint tokens to any wallet address
   * @param _recipients : address's array to mint tokens
   * @param _amount : amount to mint the tokens
   */
  function mintReserved(address[] calldata _recipients, uint256[] calldata _amount) public onlyOwner {
    for (uint256 i = 0; i < _recipients.length; i++) {
      require(_recipients[i] != address(0), "ADDRESS REQUIRED");
      require(_amount[i] > 0, "AMOUNT REQUIRED");
      require(_amount[i] <= reserved, "AMOUNT REQUIRED");
      reserved = reserved.sub(_amount[i]);
      _mint(_recipients[i], _amount[i]);
    }
  }

}
