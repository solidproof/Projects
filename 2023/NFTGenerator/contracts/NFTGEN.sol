// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

import "./NFT.sol";

contract NFTGEN is NFT {
    mapping(uint256 => uint256) private _availableTokens;

    /**
    * @dev Overrides default logic of minting NFTs to the logic with minting NFTs in random order
    * @param recipient wallet address of the minter user
    */
    function _processTokenMint(address recipient) internal override returns (uint256 tokenId) {
        tokenId = getRandomAvailableTokenId(recipient) + 1;
        _safeMint(recipient, tokenId);
    }

    /**
    * @dev implementation of the mint NFT with random token id
    * @param recipient wallet address of the minter user
    */
    function getRandomAvailableTokenId(address recipient) private returns (uint256) {
        uint256 updatedNumAvailableTokens = limitSupply - totalSupply();
        uint256 randomNum = uint256(
            keccak256(
                abi.encode(
                    recipient,
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    block.difficulty,
                    blockhash(block.number - 1),
                    address(this),
                    updatedNumAvailableTokens
                )
            )
        );
        return getAvailableTokenAtIndex(randomNum % updatedNumAvailableTokens, updatedNumAvailableTokens);
    }

    // Implements https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle. Code taken from CryptoPhunksV2
    function getAvailableTokenAtIndex(uint256 indexToUse, uint256 updatedNumAvailableTokens) private returns (uint256 result) {
        uint256 valAtIndex = _availableTokens[indexToUse];
        result = valAtIndex == 0 ? indexToUse : valAtIndex;

        uint256 lastIndex = updatedNumAvailableTokens - 1;
        if (indexToUse != lastIndex) {
            // Replace the value at indexToUse, now that it's been used.
            // Replace it with the data from the last index in the array, since we are going to decrease the array size afterwards.
            uint256 lastValInArray = _availableTokens[lastIndex];
            if (lastValInArray != 0) {
                // Gas refund
                delete _availableTokens[lastIndex];

                // This means the index itself is not an available token, but the val at that index is.
                lastIndex = lastValInArray;
            }
            // This means the index itself is still an available token
            _availableTokens[indexToUse] = lastIndex;
        }
    }
}
