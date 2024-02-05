pragma solidity ^0.8.14;

// SPDX-License-Identifier: MIT

interface ILootboxTicket {
    enum Rarity {
        COMMON,
        RARE,
        ULTRARARE,
        MYTHICAL,
        ANCIENT
    }

    function initialize(address _dev) external;
}