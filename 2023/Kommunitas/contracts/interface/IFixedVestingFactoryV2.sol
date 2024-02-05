// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IFixedVestingFactoryV2 {
  event VestingCreated(address indexed vesting, uint index);

  function owner() external view returns (address);

  function beacon() external view returns (address);

  function allVestingsLength() external view returns (uint256);

  function allVestings(uint256) external view returns (address);

  function createVesting(
    address _token,
    address _stable,
    address _projectOwner,
    uint256 _tokenPrice,
    uint256 _lastRefundAt,
    uint256[] calldata _datetime,
    uint256[] calldata _ratio_d2
  ) external returns (address);
}
