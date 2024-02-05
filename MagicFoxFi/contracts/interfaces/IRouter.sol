// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IRouter {
    function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);
}
