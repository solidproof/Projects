// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC721.sol";

interface IERC721Enumerable is IERC721 {
    function totalSupply() external view returns (uint256);
    function tokenByIndex(uint256 index) external view returns (uint256);
}
