//SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IPrismaToken {
  function compoundPrisma(address _staker, uint256 _prismaToCompound) external;

  function getOwner() external view returns (address);

  function getTreasuryReceiver() external view returns (address);

  function getItfReceiver() external view returns (address);

  function getStakedPrisma(address _user) external view returns (uint256);

  function getTotalStakedAmount() external view returns (uint256);

  function getSellLiquidityFee() external view returns (uint256);

  function getSellTreasuryFee() external view returns (uint256);

  function getTotalSellFees() external view returns (uint256);
}