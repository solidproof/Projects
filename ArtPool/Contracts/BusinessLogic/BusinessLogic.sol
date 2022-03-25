// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

abstract contract BusinessLogic {

  function checkMintAllowed(
    uint256 dropStart,
    uint256 dropEnd,
    address buyer,
    uint256 price,
    uint256 msgValue
  ) public view virtual;

}
