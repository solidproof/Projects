// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TokenIdentifiers {
    uint8 constant ADDRESS_BITS = 160;
    uint8 constant INDEX_BITS = 56;
    uint8 constant SUPPLY_BITS = 40;

    // 0x000000000000000000000000000000000000000000000000000000ffffffffff
    uint256 constant SUPPLY_MASK = (uint256(1) << SUPPLY_BITS) - 1;
    // 0x00000000000000000000000000000000000000000000000000ffff0000000000
    uint256 constant INDEX_MASK =
        ((uint256(1) << INDEX_BITS) - 1) ^ SUPPLY_MASK;

    function tokenMaxSupply(uint256 _id) internal pure returns (uint256) {
        if (tokenCreator(_id) == address(0)) {
            return 1;
        }
        return _id & SUPPLY_MASK;
    }

    function tokenIndex(uint256 _id) internal pure returns (uint256) {
        return _id & INDEX_MASK;
    }

    function tokenCreator(uint256 _id) internal pure returns (address) {
        return address(uint160(_id >> (INDEX_BITS + SUPPLY_BITS)));
    }
}
