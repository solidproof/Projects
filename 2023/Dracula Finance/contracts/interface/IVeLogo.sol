// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IVeLogo {
    function _tokenURI(
        uint256 _tokenId,
        bool isBond,
        uint256 _balanceOf,
        uint256 untilEnd,
        uint256 _value
    ) external view returns (string memory output);
}
