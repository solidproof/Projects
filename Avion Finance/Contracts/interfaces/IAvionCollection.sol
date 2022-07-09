// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IAvionCollection is IERC721 {
    function getHigherTier(address account) external view returns (uint256 _highestTier);
}