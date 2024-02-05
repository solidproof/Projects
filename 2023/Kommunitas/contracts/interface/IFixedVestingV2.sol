// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IFixedVestingV2 {
  function init(
    address _token,
    address _stable,
    address _projectOwner,
    uint256 _tokenPrice,
    uint256 _lastRefundAt,
    uint256[] calldata _datetime,
    uint256[] calldata _ratio_d2
  ) external;
}
