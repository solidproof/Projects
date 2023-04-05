pragma solidity ^0.8.14;

// SPDX-License-Identifier: MIT

interface IEvoturesNFT {
    struct Stats {
        uint256 no; // Number (1-50)
        uint256 hp; // HP Points
        uint256 attack; // Attack Points
        uint256 defense; // Defense Points
        uint256 speed; // Speed Points
        uint256 special; // Special Points
        Alignment alignment; // Divine or Abomination alignment
        Rarity rarity; // Rarity
        uint8 multiplier; // Multiplier for Darwin Staking (0.01 = 1, 0.05 = 5, 0.10 = 10, 0.25 = 25, 0.50 = 50)
    }

    enum Rarity {
        COMMON,
        RARE,
        ULTRARARE,
        MYTHICAL,
        ANCIENT
    }

    enum Alignment {
        DIVINE,
        ABOMINATION
    }

    function mint(address _to, uint _ticketChances) external;
    function stats(uint _tokenId) external view returns(Stats memory);
}