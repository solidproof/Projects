// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract veNFT is ERC721Enumerable, Ownable {

    error Paused();
    using Strings for uint256;
    /**
        * @dev _baseTokenURI for computing {tokenURI}. If set, the resulting URI for each
        * token will be the concatenation of the `baseURI` and the `tokenId`.
        */
    string _baseTokenURI;

    // _paused is used to pause the contract in case of an emergency
    bool public _paused;

    // total number of tokenIds minted
    uint256 public tokenIds;

    modifier onlyWhenNotPaused {
        if (_paused) revert Paused();
        _;
    }

    constructor (string memory baseURI) payable ERC721("veNFT", "veNFT") {
        _baseTokenURI = baseURI;
    }

    /// @dev mint allows an user to mint 1 NFT per transaction.
    function mint() internal onlyWhenNotPaused {
        _safeMint(msg.sender, tokenIds);
        tokenIds = tokenIds + 1;
    }

    /// @dev _baseURI overrides the Openzeppelin's ERC721 implementation which by default
    /// returned an empty string for the baseURI
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external payable onlyOwner {
        _baseTokenURI = baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        // Here it checks if the length of the baseURI is greater than 0, if it is return the baseURI and attach
        // the tokenId and `.json` to it so that it knows the location of the metadata json file for a given
        // tokenId stored on IPFS
        // If baseURI is empty return an empty string
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), '.json')) : "";
    }

    /**
    * @dev setPaused makes the contract paused or unpaused
        */
    function setPaused(bool val) public payable onlyOwner {
        _paused = val;
    }


}