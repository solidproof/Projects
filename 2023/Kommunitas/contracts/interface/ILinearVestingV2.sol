// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface ILinearVestingV2 {
  function init(
    address _token,
    address _stable,
    address _projectOwner,
    uint256 _tokenPrice,
    uint256 _lastRefundAt,
    uint128 _tgeAt,
    uint128 _tgeRatio_d2,
    uint128[2] calldata _startEndLinearDatetime
  ) external;
}
