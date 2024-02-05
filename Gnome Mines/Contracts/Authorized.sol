// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Authorized is Ownable {
  mapping(address => uint) internal _permissions;

  function safeApprove(address token, address spender, uint256 amount) external isAdmin { IERC20(token).approve(spender, amount); }
  function safeTransfer(address token, address receiver, uint256 amount) external isAdmin { IERC20(token).transfer(receiver, amount); }
  function safeWithdraw() external isAdmin { payable(_msgSender()).transfer(address(this).balance); }

  function setPermission(address wallet, uint8 typeIndex, bool state) external isAdmin { _permissions[wallet] = setMapAttribute(_permissions[wallet], typeIndex, state); }
  function checkMapAttribute(uint mapValue, uint8 shift) internal pure returns(bool) { return mapValue >> shift & 1 == 1; }
  function setMapAttribute(uint mapValue, uint8 shift, bool include) internal pure returns(uint) { return include ? 1 << shift | mapValue : 1 << shift ^ type(uint).max & mapValue; }
  function hasPermission(address wallet, uint8 typeIndex) external view returns(bool) { return checkMapAttribute(_permissions[wallet], typeIndex); }
  function checkPermission(uint8 typeIndex) private view { require(checkMapAttribute(_permissions[msg.sender], typeIndex) || owner() == msg.sender, "Wallet does not have permission"); }

  modifier isAdmin { checkPermission(0); _; }
  modifier isFinancial { checkPermission(1); _; }
  modifier isController { checkPermission(2); _; }
  modifier isUpdater { checkPermission(3); _; }
}