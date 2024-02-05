// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library BarbarianMetadataLib {
  uint256 public constant ALL_RARITY = 0;

  struct BarbarianMetadataStruct {
    uint256 id;
    uint8 rarity;
    uint16 skin;
    uint16 vitality;
    uint16 force;
    uint16 agility;
    uint16 speed;
    uint16[] perks;
  }
}