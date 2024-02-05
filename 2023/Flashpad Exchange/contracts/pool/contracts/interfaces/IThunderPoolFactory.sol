// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IThunderPoolFactory {
  function emergencyRecoveryAddress() external view returns (address);
  function feeAddress() external view returns (address);
  function getThunderPoolFee(address nitroPoolAddress, address ownerAddress) external view returns (uint256);
  function publishThunderPool(address nftAddress) external;
  function setThunderPoolOwner(address previousOwner, address newOwner) external;
}