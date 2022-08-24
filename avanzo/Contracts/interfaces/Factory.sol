// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

interface Factory{
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
