// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

// @dev Using bitwise math for the matrix
// Two bits are for Border type, and two other for the Background
//
//                  Basic 0000   Gold 0001   Diamond 0010   Rainbow 0011
//  Common    0000     0000        0001          0010           0011
//  Rare      0100     0100        0101          0110           0111
//  Epic      1000     1000        1001          1010           1011
//  Legendary 1100     1100        1101          1110           1111
//
library InitializeData {
    uint8 public constant BORDER_Common = 0;
    uint8 public constant BORDER_Rare = 4;
    uint8 public constant BORDER_Epic = 8;
    uint8 public constant BORDER_Legendary = 12;

    uint8 public constant BACKGROUND_Basic = 0;
    uint8 public constant BACKGROUND_Gold = 1;
    uint8 public constant BACKGROUND_Diamond = 2;
    uint8 public constant BACKGROUND_Rainbow = 3;

    function initCaps() internal pure returns (uint32[16] memory) {
        uint32[16] memory cardCaps;

        cardCaps[BORDER_Common | BACKGROUND_Basic] = 20e6;
        cardCaps[BORDER_Common | BACKGROUND_Gold] = 4e6;
        cardCaps[BORDER_Common | BACKGROUND_Diamond] = 2e6;
        cardCaps[BORDER_Common | BACKGROUND_Rainbow] = 200e3;

        cardCaps[BORDER_Rare | BACKGROUND_Basic] = 4e6;
        cardCaps[BORDER_Rare | BACKGROUND_Gold] = 800e3;
        cardCaps[BORDER_Rare | BACKGROUND_Diamond] = 400e3;
        cardCaps[BORDER_Rare | BACKGROUND_Rainbow] = 40e3;

        cardCaps[BORDER_Epic | BACKGROUND_Basic] = 2e6;
        cardCaps[BORDER_Epic | BACKGROUND_Gold] = 400e3;
        cardCaps[BORDER_Epic | BACKGROUND_Diamond] = 200e3;
        cardCaps[BORDER_Epic | BACKGROUND_Rainbow] = 20e3;

        cardCaps[BORDER_Legendary | BACKGROUND_Basic] = 200e3;
        cardCaps[BORDER_Legendary | BACKGROUND_Gold] = 40e3;
        cardCaps[BORDER_Legendary | BACKGROUND_Diamond] = 20e3;
        cardCaps[BORDER_Legendary | BACKGROUND_Rainbow] = 200;

        return cardCaps;
    }

    function typeCaps1() internal pure returns (uint32) {
        return 380_050;
    }

    function typeCaps2() internal pure returns (uint32) {
        return 8_200_000;
    }

    // Matrix for LB1
    function initChances1() internal pure returns (uint24[] memory) {
        uint24[] memory typeChances = new uint24[](6);

        // BORDERS.Rare => BACKGROUNDS.Gold => 4.30%
        typeChances[0] = BORDER_Rare | BACKGROUND_Gold | (430 << 4);
        // BORDERS.Common => BACKGROUNDS.Diamond => 7.42%
        typeChances[1] = BORDER_Common | BACKGROUND_Diamond | (742 << 4);
        // BORDERS.Epic => BACKGROUNDS.Basic => 7.42%
        typeChances[2] = BORDER_Epic | BACKGROUND_Basic | (742 << 4);
        // BORDERS.Common => BACKGROUNDS.Gold => 14.84%
        typeChances[3] = BORDER_Common | BACKGROUND_Gold | (1484 << 4);
        // BORDERS.Rare => BACKGROUNDS.Basic => 14.84%
        typeChances[4] = BORDER_Rare | BACKGROUND_Basic | (1484 << 4);
        // BORDERS.Common => BACKGROUNDS.Basic => 51.19%
        typeChances[5] = BORDER_Common | BACKGROUND_Basic | (5119 << 4);

        return typeChances;
    }

    // Matrix for LB2 4x Random
    function initChances2() internal pure returns (uint24[] memory) {
        uint24[] memory typeChances = new uint24[](10);

        // BORDERS.Legendary => BACKGROUNDS.Rainbow => 0.14%
        typeChances[0] = BORDER_Legendary | BACKGROUND_Rainbow | (14 << 4);
        // BORDERS.Epic => BACKGROUNDS.Rainbow => 1.43%
        typeChances[1] = BORDER_Epic | BACKGROUND_Rainbow | (143 << 4);
        // BORDERS.Legendary => BACKGROUNDS.Diamond => 1.43%
        typeChances[2] = BORDER_Legendary | BACKGROUND_Diamond | (143 << 4);
        // BORDERS.Rare => BACKGROUNDS.Rainbow => 2.86%
        typeChances[3] = BORDER_Rare | BACKGROUND_Rainbow | (286 << 4);
        // BORDERS.Legendary => BACKGROUNDS.Gold => 2.86%
        typeChances[4] = BORDER_Legendary | BACKGROUND_Gold | (286 << 4);
        // BORDERS.Legendary => BACKGROUNDS.Basic => 9.87%
        typeChances[5] = BORDER_Legendary | BACKGROUND_Basic | (987 << 4);
        // BORDERS.Common => BACKGROUNDS.Rainbow => 9.87%
        typeChances[6] = BORDER_Common | BACKGROUND_Rainbow | (987 << 4);
        // BORDERS.Epic => BACKGROUNDS.Diamond => 14.31%
        typeChances[7] = BORDER_Epic | BACKGROUND_Diamond | (1431 << 4);
        // BORDERS.Rare => BACKGROUNDS.Diamond => 28.61%
        typeChances[8] = BORDER_Rare | BACKGROUND_Diamond | (2861 << 4);
        // BORDERS.Epic => BACKGROUNDS.Gold => 28.61%
        typeChances[9] = BORDER_Epic | BACKGROUND_Gold | (2861 << 4);

        return typeChances;
    }

    // uint24 FUNCTIONS
    function probability(uint24 data) internal pure returns (uint24) {
        return data >> 4;
    }

    function bgAndBorder(uint24 data) internal pure returns (uint8) {
        return uint8(data & 15);
        //   15 => 1111
    }

    function bgBorderAndChar(uint24 data, uint8 character) internal pure returns (uint16) {
        return uint16((data & 15) | (character<<4));
        //   15 => 1111
    }

    function background(uint24 data) internal pure returns (uint8) {
        return uint8(data & 3);
        //   3 => 0011
    }

    function border(uint24 data) internal pure returns (uint8) {
        return uint8(data & 12);
        // 12 => 1100;
    }
}
