// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BarbarianMetadata.sol";

interface IRoadToGloryNFTMetadata {

  function create_random_metadata (
    uint256 seed,
    uint256 id,
    uint256 rarity
  ) external view returns (BarbarianMetadataLib.BarbarianMetadataStruct memory);
}