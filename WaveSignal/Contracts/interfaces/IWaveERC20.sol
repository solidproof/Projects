// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.2;

interface IWaveERC20 is IERC20 {
   function decimals() external view returns (uint8);
}