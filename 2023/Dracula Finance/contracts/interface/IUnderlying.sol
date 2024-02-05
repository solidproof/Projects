// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IUnderlying {
    function approve(address spender, uint256 value) external returns (bool);

    function mint(address, uint256) external;

    function totalSupply() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function transfer(address, uint256) external returns (bool);

    function decimals() external returns (uint8);
}
