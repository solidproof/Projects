// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IBullFarmFund {
    function sendTokens(address to, uint ethAmount) external;
}