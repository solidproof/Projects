// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IMerlinPoolFactory {
  function emergencyRecoveryAddress() external view returns (address);
  function feeAddress() external view returns (address);
  function getMerlinPoolFee(address nitroPoolAddress, address ownerAddress) external view returns (uint256);
  function publishMerlinPool(address nftAddress) external;
  function setMerlinPoolOwner(address previousOwner, address newOwner) external;
}