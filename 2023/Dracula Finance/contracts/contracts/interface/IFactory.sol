// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IFactory {
    function treasury() external view returns (address);

    function isPair(address pair) external view returns (bool);

    function getInitializable() external view returns (address, address, bool);

    function isPaused() external view returns (bool);

    function pairCodeHash() external pure returns (bytes32);

    function getPair(
        address tokenA,
        address token,
        bool stable
    ) external view returns (address);

    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair);
}
