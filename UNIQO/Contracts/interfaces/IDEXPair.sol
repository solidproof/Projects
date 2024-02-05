// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IDEXPair {
  function token0() external view returns (address);

  function token1() external view returns (address);

  function sync() external;

  function price0CumulativeLast() external view returns (uint256);

  function price1CumulativeLast() external view returns (uint256);

  function getReserves()
    external
    view
    returns (
      uint112 reserve0,
      uint112 reserve1,
      uint32 blockTimestampLast
    );
}
