// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "../interfaces/ISuperAssetV2.sol";
import "../interfaces/IMultiRoyalty.sol";

library TokenType {
    function isSuperAssetV2(address _tokenAddress) internal view returns (bool) {
        return ISuperAssetV2(_tokenAddress).supportsInterface(type(ISuperAssetV2).interfaceId);
    }

    function isERC721(address _tokenAddress) internal view returns (bool) {
        return IERC721(_tokenAddress).supportsInterface(type(IERC721).interfaceId);
    }

    function isERC1155(address _tokenAddress) internal view returns (bool) {
        return IERC1155(_tokenAddress).supportsInterface(type(IERC1155).interfaceId);
    }

    function supportsMultiRoyalty(address _tokenAddress) internal view returns (bool) {
        return IMultiRoyalty(_tokenAddress).supportsInterface(type(IMultiRoyalty).interfaceId);
    }

    function supportsSingleRoyalty(address _tokenAddress) internal view returns (bool) {
        return IERC2981(_tokenAddress).supportsInterface(type(IERC2981).interfaceId);
    }
}
