// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IYieldBooster {
  function deallocateAllFromPool(address userAddress, uint256 tokenId) external;
  function getMultiplier(address poolAddress, uint256 maxBoostMultiplier, uint256 amount, uint256 totalPoolSupply, uint256 allocatedAmount) external view returns (uint256);
}