// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract MODSMDS is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, OwnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    CountersUpgradeable.Counter private _tokenIdCounter;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /**
     * @dev NFT URI, MAX supply
     */
    string private _baseURIValue;

    /**
     * @dev Events
     */
    event setBaseURIEvent(string indexed newBaseURI);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721_init("Modulus Domain Service", "MDS");
          OwnableUpgradeable.__Ownable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
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
     * @notice Mint tokens.
     *
     * @param _to. Address to receive minted tokens
     */
    function mintTokens(address _to)
        public
        onlyRole(MINTER_ROLE)
    {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);
    }
 
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}