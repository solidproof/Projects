// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract CultPunksWL is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Pausable,
    Ownable,
    ERC721Burnable
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    uint256 public MAX_SUPPLY = 10000;

    event MaxSupply(uint256 _oldSupply, uint256 _newSupply);

    constructor() ERC721("CultPunks Whitelist", "PunksWL") {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function updateMaxSupply(uint256 _newMaxSupply) public onlyOwner {
        require(_newMaxSupply >= totalSupply(), "Invalid Max Supply");
        
        emit MaxSupply(MAX_SUPPLY, _newMaxSupply);
        MAX_SUPPLY = _newMaxSupply;
    }

    function safeMint(
        address to,
        string memory uri
    ) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        require(tokenId < MAX_SUPPLY, "Max supply limit reached");
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function safeBatchMint(
        address[] memory to,
        string[] memory uri
    ) public onlyOwner {
        require(to.length == uri.length, "Invalid Data.");
        for(uint256 i=0; i<to.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            require(tokenId < MAX_SUPPLY, "Max supply limit reached");
            _tokenIdCounter.increment();
            _safeMint(to[i], tokenId);
            _setTokenURI(tokenId, uri[i]);
        }
    }

    function safeBatchTransfer(address[] memory _to, uint256[] memory _tokenIds)
        public
    {
        require(_to.length == _tokenIds.length, "Arrays length must be equal");
        for (uint256 i = 0; i < _to.length; i++) {
            require(_exists(_tokenIds[i]), "Token does not exist");
            require(msg.sender == ownerOf(_tokenIds[i]), "Not Owner of token");
            safeTransferFrom(msg.sender, _to[i], _tokenIds[i], "");
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // The following functions are overrides required by Solidity.
    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}