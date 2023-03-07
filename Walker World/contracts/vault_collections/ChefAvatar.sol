// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC721A-CHEF.sol";
import "./ChefSaleManager.sol";

//import './SalChefRevealProvider.sol';

contract ChefAvatar is ERC721A, Ownable {
    using Strings for uint256;

    event RevealProviderChanged(address newRevealProvider);
    event SaleManagerChanged(address newSaleManager);

    // ChefRevealProvider public chefRevealProvider;
    ChefSaleManager public saleManager;

    uint256 public immutable maxSupply;
    string private _baseTokenURI;
    uint256 public revealOffset; // It will be used to shuffle IPFS files as (revealOffset + tokenId) % maxSupply

    constructor(
        uint256 _reserved,
        uint256 _maxSupply,
        address treasury,
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721A(name, symbol) {
        require(
            _reserved <= _maxSupply,
            "ChefAvatar: reserved must be less than or equal to maxSupply"
        );

        maxSupply = _maxSupply;
        _baseTokenURI = baseTokenURI;

        if (_reserved > 0) {
            //not all projects have reserved tokens
            _mint(treasury, _reserved);
        }
    }

    // function setChefRevealProvider(address _chefRevealProvider) external onlyOwner {
    //     chefRevealProvider = ChefRevealProvider(_chefRevealProvider);

    //     emit RevealProviderChanged(_chefRevealProvider);
    // }

    function setChefSaleManager(address _chefSaleManager) external onlyOwner {
        saleManager = ChefSaleManager(_chefSaleManager);

        emit SaleManagerChanged(_chefSaleManager);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseTokenURI(string calldata newTokenURI) public onlyOwner {
        _baseTokenURI = newTokenURI;
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "nonexistent token");

        uint256 offsetId = revealOffset == 0
            ? maxSupply // tokenId will always be less than maxSupply
            : tokenId;

        return string(abi.encodePacked(_baseTokenURI, offsetId.toString()));
    }

    function _mint(address to, uint256 quantity) private {
        require(totalSupply() + quantity <= maxSupply, "max supply reached");
        ERC721A._mint(to, quantity, "", true);
    }

    function mint(uint256 quantity, address to) public {
        require(
            msg.sender == address(saleManager),
            "only saleManager can mint"
        );

        _mint(to, quantity);
    }

    /// @notice Request randomness from a user-provided seed
    /// @dev Only callable by the Owner.
    /// @param userProvidedSeed: extra entrpy for the VRF
    // function callReveal(uint256 userProvidedSeed) external onlyOwner {
    //     require(revealOffset == 0, "Reveal already called");

    //     chefRevealProvider.getRandomNumber(userProvidedSeed);
    // }

    // function reveal(uint256 randomness) external {
    //     require(msg.sender == address(chefRevealProvider), "Only the Chef Reveal Provider can reveal");
    //     require(revealOffset == 0, "Reveal already called");

    //     revealOffset = randomness;
    // }
}
