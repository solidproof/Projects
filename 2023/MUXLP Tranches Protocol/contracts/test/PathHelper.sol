// SPDX-License-Identifier: MIT
// This file just references TransparentUpgradeableProxy
pragma solidity 0.8.17;

contract PathHelper {
    function buildPath2(
        address token1,
        uint24 fee1,
        address token2
    ) external pure returns (bytes memory path) {
        path = abi.encodePacked(bytes20(token1), bytes3(fee1), bytes20(token2));
    }

    function buildPath3(
        address token1,
        uint24 fee1,
        address token2,
        uint24 fee2,
        address token3
    ) external pure returns (bytes memory path) {
        path = abi.encodePacked(
            bytes20(token1),
            bytes3(fee1),
            bytes20(token2),
            bytes3(fee2),
            bytes20(token3)
        );
    }

    function buildPath4(
        address token1,
        uint24 fee1,
        address token2,
        uint24 fee2,
        address token3,
        uint24 fee3,
        address token4
    ) external pure returns (bytes memory path) {
        path = abi.encodePacked(
            bytes20(token1),
            bytes3(fee1),
            bytes20(token2),
            bytes3(fee2),
            bytes20(token3),
            bytes3(fee3),
            bytes20(token4)
        );
    }
}
