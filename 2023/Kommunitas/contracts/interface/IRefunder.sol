// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IRefunder {
  function init(address _stable, address _projectOwner, uint256 _payToProjectOwnerAt) external;
}
