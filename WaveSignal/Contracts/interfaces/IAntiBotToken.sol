// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IAntiBotToken is IERC20 {
  function owner() external view returns (address);
}