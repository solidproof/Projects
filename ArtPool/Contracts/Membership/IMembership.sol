// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

interface IMembership {
  function getHighestMembershipTier(address wallet)
    external
    view
    returns (uint256);
}
