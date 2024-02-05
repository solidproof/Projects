// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface BSCSNFTInterface{
  function nftToCreators(uint256 nftId) external view returns (address);
}

contract NFTMarketplace is
    Ownable, IERC721Receiver
{
    // using SafeERC20Upgradeable for IERC20;
    using SafeMath for uint256;

    modifier validNFTContractAddress(address _address) {
        require(_address != address(0) && _address != address(this));
        _;
    }

    modifier onlySeller(address nftAddress, uint256 tokenId) {
        require(listings[nftAddress][tokenId].owner == msg.sender);
        _;
    }

    modifier onlyItemSeller(address nftAddress, uint256 _listingId) {
        require(
            itemListings[nftAddress][_listingId].owner == msg.sender,
            "caller is not owner"
        );
        _;
    }

    modifier onlyWhitelistNFT(address nftAddress) {
        require(
            whitelistNFTContracts[nftAddress],
            "INVALID_NFT_CONTRACT"
        );
        _;
    }

    // Map from token ID to their corresponding offer.
    uint256 public listingId;
    uint256 public serviceFee; // 100.000 = 100%
    uint256 public creatorFee; // 100.000 = 100%
    address public treasury;

    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => mapping(uint256 => ItemListing)) public itemListings;
    mapping(address => mapping(uint256 => bool)) legends;
    mapping(address => bool) public whitelistCurrencies;
    mapping(address => bool) public whitelistNFTContracts;

    struct Listing {
        // Price (in wei)
        uint256 price;
        // Current owner of NFT
        address owner;
        // current token address. only accept whitelist token
        address currency;
    }
    struct ItemListing {
        // Price (in wei)
        uint256 price;
        // Current owner of NFT
        address owner;
        // items
        uint256 tokenId;
        // amount of items
        uint256 amount;
    }

    constructor() {
        listingId = 0;
        serviceFee = 2500;
        creatorFee = 3000;
    }

    function getListing(address nftAddress, uint256 tokenId)
        external
        view
        returns (uint256 price, address owner)
    {
        Listing memory listing = listings[nftAddress][tokenId];
        require(listingExists(listing));
        return (listing.price, listing.owner);
    }

    function createListing(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        address currencyAddress
    )
        external
        validNFTContractAddress(nftAddress)
        onlyWhitelistNFT(nftAddress)
    {
        address seller = msg.sender;
        IERC721 nft = getNftContract(nftAddress);
        require(
            whitelistCurrencies[currencyAddress],
            "INVALID_CURRENCY"
        );
        require(
            whitelistNFTContracts[nftAddress],
            "INVALID_NFT_CONTRACT"
        );

        require(nft.ownerOf(tokenId) == seller, "NOT_NFT_OWNER");
        require(
            msg.sender != address(0) && msg.sender != address(this),
            "INVALID_SENDER"
        );

        nft.safeTransferFrom(seller, address(this), tokenId);

        Listing memory listing = Listing(price, seller, currencyAddress);
        listings[nftAddress][tokenId] = listing;

        emit ListingCreated(seller, nftAddress, tokenId, price);
    }

    function cancelListing(address nftAddress, uint256 tokenId)
        external
        onlySeller(nftAddress, tokenId)
    {
        IERC721 nft = getNftContract(nftAddress);
        Listing storage listing = listings[nftAddress][tokenId];
        nft.safeTransferFrom(address(this), listing.owner, tokenId);
        delete listings[nftAddress][tokenId];
        emit Unlisted(nftAddress, tokenId);
    }

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 _price
    ) external onlySeller(nftAddress, tokenId) {
        // update new listing
        listings[nftAddress][tokenId].price = _price;
        emit ListingUpdated(tokenId, _price);
    }

    /**
     * @notice
     */
    function buyNft(address nftAddress, uint256 tokenId)
        external
    {
        Listing storage listing = listings[nftAddress][tokenId];
        address nfrCreator = BSCSNFTInterface(nftAddress).nftToCreators(tokenId);
        require(listingExists(listing), "NOT_EXISTED");
        require(listing.currency != address(0),"Invalid currency");
        
        uint256 fee;
        uint256 feeCreator;
        if (serviceFee > 0) {
            fee = listing.price - (listing.price * (100000 - serviceFee)).div(100000);
            IERC20(listing.currency).transferFrom(msg.sender, treasury, fee);
        }
        if (creatorFee > 0 && nfrCreator != address(0)) {
            feeCreator = listing.price - (listing.price * (100000 - creatorFee)).div(100000);
            IERC20(listing.currency).transferFrom(msg.sender, nfrCreator, feeCreator);
        }

        uint256 price = listing.price - fee - feeCreator;
        IERC20(listing.currency).transferFrom(msg.sender, listing.owner, price);

        IERC721 nft = getNftContract(nftAddress);
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Trade(
            msg.sender,
            listing.owner,
            nftAddress,
            tokenId,
            listing.price
        );
        delete listings[nftAddress][tokenId];
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0) && _treasury != address(this));
        treasury = _treasury;
    }

    function setServiceFee(uint256 _serviceFee) external onlyOwner {
        serviceFee = _serviceFee;
        emit ServiceFeeUpdated(_serviceFee);
    }

     function setCreatorFee(uint256 _creatorFee) external onlyOwner {
        creatorFee = _creatorFee;
        emit CreatorFeeUpdated(_creatorFee);
    }

    /// @dev Returns true if the offer is on marketplace.
    /// @param listing - Listing to check.
    function listingExists(Listing memory listing)
        internal
        view
        returns (bool)
    {
        return (listing.owner != address(0));
    }

    /// @dev Gets the NFT object from an address, validating that implementsERC721 is true.
    /// @param nftAddress - Address of the NFT.
    function getNftContract(address nftAddress)
        internal
        pure
        returns (IERC721)
    {
        IERC721 candidateContract = IERC721(nftAddress);
        return candidateContract;
    }


    /**
     * @dev update listing price
     * @param nftAddress: address of NFT contract
     * @param _listingId: id of listing
     * @param _price: new price
     */
    function updateItemsListing(
        address nftAddress,
        uint256 _listingId,
        uint256 _price
    ) external onlyItemSeller(nftAddress, _listingId) {
        itemListings[nftAddress][_listingId].price = _price;
        emit ItemListingUpdated(_listingId, _price);
    }


    function whitelistNFTContract(address[] calldata _nfts, bool _isAccept)
        external
        onlyOwner
    {
        require(_nfts.length > 0, "INVALID");
        for (uint256 i = 0; i < _nfts.length; i++) {
            whitelistNFTContracts[_nfts[i]] = _isAccept;
        }
    }

    function whitelistCurrency(address[] calldata _currencies, bool _isAccept)
        external
        onlyOwner
    {
        require(_currencies.length > 0, "INVALID");
        for (uint256 i = 0; i < _currencies.length; i++) {
            whitelistCurrencies[_currencies[i]] = _isAccept;
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    event ListingCreated(
        address indexed owner,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event Unlisted(address indexed nftAddress, uint256 indexed tokenId);
    event ListingUpdated(uint256 indexed tokenId, uint256 price);
    event Trade(
        address indexed buyer,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 price
    );
    event ServiceFeeUpdated(uint256 serviceFee);
    event CreatorFeeUpdated(uint256 creatorFee);
    event ItemListingCreated(
        address indexed owner,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        uint256 _listingId
    );
    event ItemUnlisted(uint256 indexed _listingId);
    event ItemListingUpdated(uint256 indexed _listingId, uint256 price);
}
