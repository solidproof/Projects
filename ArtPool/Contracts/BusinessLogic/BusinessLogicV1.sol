// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "./BusinessLogic.sol";

contract BusinessLogicV1 is BusinessLogic {

  function checkMintAllowed(
    uint256 dropStart,
    uint256 dropEnd,
    address buyer,
    uint256 price,
    uint256 msgValue
  ) public view override {
    require(msgValue == price, 'Please submit the asking price');
    require(block.timestamp > dropStart, 'This drop has not started yet');
    require(dropEnd == 0 || block.timestamp < dropEnd, 'This drop has ended');
  }

}
