// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract NFT is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /**
     * @dev NFT URI, MAX supply
     */
    string private _baseURIValue;
    uint256 public MAX_SUPPLY;

    /**
     * @dev Mint role details.
     */
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    CountersUpgradeable.Counter private _tokenIdCounter;

    /**
     * @dev Events
     */
    event setMaxSupplyEvent(uint256 indexed maxSupply);
    event setBaseURIEvent(string indexed newBaseURI);

    /**
     * @dev Initialize function. Only called one time at time of deployment.
     */
    function initialize(
        string memory newName,
        string memory newSymbol,
        uint256 maxSupply
    ) public initializer {
        ERC721Upgradeable.__ERC721_init(newName, newSymbol);
        OwnableUpgradeable.__Ownable_init();
        __AccessControl_init();
        MAX_SUPPLY = maxSupply;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Internal function to get base URI.
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseURIValue;
    }

    /**
     * @dev Base URI for NFT.
     */
    function baseURI() public view returns (string memory) {
        return _baseURI();
    }

    /**
     * @notice Change the base URI for NFT.
     *
     * @param newBase. The new base URI.
     */
    function setBaseURI(string memory newBase) public onlyOwner {
        _baseURIValue = newBase;
        emit setBaseURIEvent(newBase);
    }

    /**
     * @notice Pause the minting of token.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the minting of token.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @notice Change the max supply.
     *
     * @param newMaxSupply. The new max supply.
     */
    function setNewMaxSupply(uint256 newMaxSupply) public onlyOwner {
        require(
            newMaxSupply >= totalSupply(),
            "setNewMaxSupply: New supply cannot be less than total supply"
        );
        MAX_SUPPLY = newMaxSupply;
        emit setMaxSupplyEvent(newMaxSupply);
    }

    /**
     * @notice Give approval to account for token based on Id.
     *
     * @param to. Address to give approval.
     * @param tokenId. Token Id to give approval
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address tokenOwner = ownerOf(tokenId);
        require(to != tokenOwner, "ERC721: approval to current owner");

        require(
            _msgSender() == tokenOwner || isApprovedForAll(tokenOwner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );
        _approve(to, tokenId);
    }

    /**
     * @dev Internal function to do the actual minting.
     */
    function _mintTokens(address to) internal {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    /**
     * @notice Mint tokens.
     *
     * @param numberOfTokens. Number of token to mint.
     * @param _address. Address to receive minted tokens
     */
    function mintTokens(uint256 numberOfTokens, address _address)
        public
        whenNotPaused
        onlyRole(MINTER_ROLE)
    {
        require(
            numberOfTokens + totalSupply() <= MAX_SUPPLY,
            "mintTokens: Max supply reached"
        );
        require(numberOfTokens > 0, "mintTokens: Number of token to mint is 0");
        uint256 i;
        for (i = 0; i < numberOfTokens; i++) {
            _mintTokens(_address);
        }
    }

    /**
     * @dev Authorize upgrade so that only owner can upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}