// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRewardConvertor {
    function convert(
        address tokenToSell,
        address tokenToBuy,
        uint256 amount,
        bytes calldata additionalData
    ) external returns (uint256);
}