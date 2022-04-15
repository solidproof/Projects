//SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/AccessProtected.sol";


contract TesNFT is ERC721URIStorage,AccessProtected {
    using Counters for Counters.Counter;
    Counters.Counter public token_ids;
    uint256 public fee=10*10**17;

    constructor() ERC721("Test NFT", "TNT") {}

    /** Mint Function
     * @param recipient - Wallet Address of recipient.
     * @param uris - Meta data array.
     */

    function Mint(
        address recipient,
        string memory uris

    ) external payable returns (uint256 tknIds) {

            require(msg.value >= fee,"insufficient amount");
            token_ids.increment();
            uint256 newTokenId = token_ids.current();
            address payable owner;
            owner.transfer(msg.value);
            _mint(recipient, newTokenId);
            _setTokenURI(newTokenId, uris);

            tknIds = newTokenId;
            return tknIds;
        }


    /** setTokenURI Function
     * @param token_Id- Token ID of NFT.
     * @param uri - URI from Pinata.
     */

    function setTokenURI(uint256 token_Id, string memory uri) public onlyOwner {
        _setTokenURI(token_Id, uri);
    }

    function setFee(uint256 newFee) external onlyOwner returns(uint256) {
        fee=newFee;
        return fee;
    }

}