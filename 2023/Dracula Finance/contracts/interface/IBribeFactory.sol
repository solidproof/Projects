// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IBribeFactory {
    function createBribe(
        address[] memory _allowedRewardTokens
    ) external returns (address);
}
