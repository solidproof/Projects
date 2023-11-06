// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IRefunderFactory {
  event RefundCreated(address indexed refund, uint index);

  function owner() external view returns (address);

  function beacon() external view returns (address);

  function allRefundsLength() external view returns (uint256);

  function allRefunds(uint256) external view returns (address);

  function createRefund(
    address _stable,
    address _projectOwner,
    uint256 _payToProjectOwnerAt
  ) external returns (address);
}
