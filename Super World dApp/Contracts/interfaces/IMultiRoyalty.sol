// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @dev Interface for the NFT Royalty Standard for NFTSalonV2
 */
interface IMultiRoyalty is IERC2981 {
    /**
     * @dev Called with the sale price to determine how much royalty is owed and to whom.
     * @param tokenId - the NFT asset queried for royalty information
     * @param salePrice - the sale price of the NFT asset specified by `tokenId`
     * @return receivers - addresses of who should be sent the royalty payment
     * @return royaltyAmounts - the royalty payment amounts for `salePrice`
     */
    function royaltiesInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address[] memory receivers, uint256[] memory royaltyAmounts);
}
