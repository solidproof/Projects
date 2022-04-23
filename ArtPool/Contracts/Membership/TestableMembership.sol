// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import './Membership.sol';

contract TestableMembership is Membership {
  uint256 fakeRandom = 0;

  constructor(
    string memory name,
    string memory symbol,
    string memory baseUri,
    address artpoolWallet,
    uint256 dropStart,
    // Set to 0 if the project should never end
    uint256 dropEnd,
    NftParams[] memory nftParamsArr,
    uint256[] memory tierList,
    address[] memory preSaleAccess
  )
    Membership(
      name,
      symbol,
      baseUri,
      artpoolWallet,
      dropStart,
      dropEnd,
      nftParamsArr,
      tierList,
      preSaleAccess
    )
  {}

  function random() internal override returns (uint256) {
    return fakeRandom++;
  }
}
