// SPDX-License-Identifier: UNLICENSED

//contracts/interfaces/IAtpadNft.sol

pragma solidity 0.8.16;

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface IAtpadNft is IERC721Upgradeable {
    function getWeight(uint256 _tokenId) external returns (uint256);
}