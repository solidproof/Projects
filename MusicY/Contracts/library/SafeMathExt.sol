// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeMathExt {
    function add128(uint128 a, uint128 b) internal pure returns (uint128) {
        uint128 c = a + b;
        require(c >= a, "uint128: addition overflow");

        return c;
    }

    function sub128(uint128 a, uint128 b) internal pure returns (uint128) {
        require(b <= a, "uint128: subtraction overflow");
        uint128 c = a - b;

        return c;
    }

    function add64(uint64 a, uint64 b) internal pure returns (uint64) {
        uint64 c = a + b;
        require(c >= a, "uint64: addition overflow");

        return c;
    }

    function sub64(uint64 a, uint64 b) internal pure returns (uint64) {
        require(b <= a, "uint64: subtraction overflow");
        uint64 c = a - b;

        return c;
    }

    function safe128(uint256 a) internal pure returns (uint128) {
        require(
            a < 0x0100000000000000000000000000000000,
            "uint128: number overflow"
        );
        return uint128(a);
    }

    function safe64(uint256 a) internal pure returns (uint64) {
        require(a < 0x010000000000000000, "uint64: number overflow");
        return uint64(a);
    }

    function safe32(uint256 a) internal pure returns (uint32) {
        require(a < 0x0100000000, "uint32: number overflow");
        return uint32(a);
    }

    function safe16(uint256 a) internal pure returns (uint16) {
        require(a < 0x010000, "uint32: number overflow");
        return uint16(a);
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
