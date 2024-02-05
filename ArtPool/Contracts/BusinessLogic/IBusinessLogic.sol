// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

interface IBusinessLogic {
  function checkMintAllowed(
    uint256 dropStart,
    uint256 dropEnd,
    address buyer,
    uint256 price,
    uint256 msgValue,
    uint256 minMembershipTier
  ) external view returns (string memory);
}
