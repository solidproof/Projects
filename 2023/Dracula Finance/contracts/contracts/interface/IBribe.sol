// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IBribe {
    function notifyRewardAmount(address token, uint256 amount) external;

    function _deposit(uint256 amount, uint256 tokenId) external;

    function _withdraw(uint256 amount, uint256 tokenId) external;

    function getRewardForOwner(
        uint256 tokenId,
        address[] memory tokens
    ) external;
}
