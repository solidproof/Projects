// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
//access control
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
// Helper functions OpenZeppelin provides.
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface ImageDataInf {
    function getCDNImageForElement(string calldata element, uint16 level)
        external
        view
        returns (string memory);

    function getIPFSImageForElement(string calldata element, uint16 level)
        external
        view
        returns (string memory);

    function getAnnimationForElement(string calldata element)
        external
        view
        returns (string memory);
}

interface TokenURIInf {
    function maketokenURi(
        uint256 _tokenId,
        uint256 wlSpots,
        uint256 winChances,
        uint256 softClay
    ) external view returns (string memory);

    function contractURI() external view returns (string memory);
}

interface WinContr {
    function getReferalIncrease() external view returns (uint16);

    function updateAfterLoss(
        uint256 passportId,
        string calldata city,
        uint32 buildingId
    ) external;
}

contract MetropolisWorldPassport is
    ERC721,
    ERC721Enumerable,
    Ownable,
    AccessControl
{
    address private IMAGE_DATA_CONTRACT;
    ImageDataInf ImageContract;
    address private WIN_CONTRACT;
    WinContr WinContract;
    address private WL_CONTRACT;
    address private TURI_CONTRACT;
    TokenURIInf TuriContract;

    //defining the access roles
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    //bytes32 public constant BALANCE_ROLE = keccak256("BALANCE_ROLE");
    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    //payment split contract
    address payable private _paymentSplit;

    // The tokenId is the NFTs unique identifier, it's just a number that goes
    // 0, 1, 2, 3, etc.
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds; //counter for token ids

    //updateable variables
    uint32 public _mintLimit = 5000;
    uint16 public _maxAllowedPerWallet = 301; //maximum allowed to mint per wallet
    string private _oddAvatar = "nomad";
    string private _evenAvatar = "citizen";

    uint256 public _navPrice = 0.001 ether;

    struct AccessToken {
        uint256 id;
        uint32 winChances;
        uint32 softClay; // max is 4 billion
        // string name;
        string rank;
        //string description;
        //string image;
        //string animation;
        //string cdnImage;
        string element;
        uint256 avatarWl;
        uint256[] whitelistSpots;
    }

    string[] elements = ["Fire", "Water", "Air", "Space", "Pixel", "Earth"];
    //store the list of minted tokens metadata to thier token id
    mapping(uint256 => AccessToken) nftAccessTokenAttribute;
    //give away wallets
    mapping(address => uint16) _freeMintable; //winners of free passport are mapped here and can mint for free.
    mapping(bytes => bool) _signatureUsed;

    //set up functions
    constructor(address imageContract, address admin)
        ERC721("Metropolis World Passport", "METWA")
    {
        //require(imageContract != address(0));
        IMAGE_DATA_CONTRACT = imageContract;
        ImageContract = ImageDataInf(IMAGE_DATA_CONTRACT);
        // I increment _tokenIds here so that my first NFT has an ID of 1.
        _tokenIds.increment();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPDATER_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //overides
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function contractURI() public view returns (string memory) {
        return TuriContract.contractURI();
    }

    function setWLContractAddress(
        address payable paymentContract,
        address winContract,
        address wlContract,
        address turiContract
    ) external onlyRole(UPDATER_ROLE) {
        WIN_CONTRACT = winContract;
        WinContract = WinContr(WIN_CONTRACT);
        WL_CONTRACT = wlContract;
        TURI_CONTRACT = turiContract;
        TuriContract = TokenURIInf(TURI_CONTRACT);
        _paymentSplit = paymentContract;
    }

    function setImageContract(address imageContract)
        external
        onlyRole(UPDATER_ROLE)
    {
        require(imageContract != address(0));
        IMAGE_DATA_CONTRACT = imageContract;
        ImageContract = ImageDataInf(IMAGE_DATA_CONTRACT);
    }

    //minting functions
    function _internalMint(address toWallet, uint32 winChance) internal {
        uint256 newItemId = _tokenIds.current();
        // make sure not above limit of available mints.
        require(newItemId <= _mintLimit, "To many minted");
        //make sure not already got 1
        require(
            balanceOf(toWallet) < _maxAllowedPerWallet,
            "address already owns max allowed"
        );
        _safeMint(toWallet, newItemId);
        //randomly assign the element
        string memory elm = elements[newItemId % 6];
        //randomly assign the chracter WL spot.
        uint256 avwl = 1; //_oddAvatar;
        if (newItemId % 2 == 1) {
            //is an odd number
            avwl = 2; //_evenAvatar;
        }

        nftAccessTokenAttribute[newItemId] = AccessToken({
            id: newItemId,
            winChances: winChance,
            softClay: 0,
            rank: "N",
            element: elm,
            avatarWl: avwl,
            whitelistSpots: new uint256[](0)
        });
        // Increment the tokenId for the next person that uses it.
        _tokenIds.increment();
    }

    function freeMint(address toWallet) external onlyRole(UPDATER_ROLE) {
        _internalMint(toWallet, 1);
    }

    function userFreeMint(uint16 mints) external {
        require(
            _freeMintable[msg.sender] >= mints,
            "not on the free mint list"
        );
        for (uint16 i; i < mints; i++) {
            _internalMint(msg.sender, 2);
        }
        _freeMintable[msg.sender] -= mints;
    }

    function myFreeMints() external view returns (uint16) {
        return _freeMintable[msg.sender];
    }

    function recoverSigner(bytes32 hash, bytes memory signature)
        internal
        pure
        returns (address)
    {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        return ECDSA.recover(messageDigest, signature);
    }

    function bulkMint(
        uint16 numberOfMints,
        address toAddress,
        uint256 referrerTokenId // , // bytes32 hash, // bytes memory signature
    ) external payable {
        //require(recoverSigner(hash, signature) == owner(), "invalid signature");
        //require(!_signatureUsed[signature], "Signature has already been used.");
        require(
            numberOfMints < _maxAllowedPerWallet,
            "Trying to mint more then max allowed per wallet"
        );
        require(msg.value >= (numberOfMints * _navPrice), "not paid enough");
        require(
            balanceOf(msg.sender) < _maxAllowedPerWallet - numberOfMints,
            "address already owns max allowed"
        );
        require(
            _tokenIds.current() + numberOfMints - 1 <= _mintLimit,
            "Will take you over max supply"
        );
        //_signatureUsed[signature] = true;
        for (uint16 i; i < numberOfMints; i++) {
            if (referrerTokenId != 0) {} else {
                _internalMint(toAddress, 1);
            }
        }
        //return the excess if any
        if (msg.value > (numberOfMints * _navPrice)) {
            Address.sendValue(
                payable(msg.sender),
                (msg.value - (numberOfMints * _navPrice))
            );
        }
    }

    function setPrice(uint256 price) external onlyRole(UPDATER_ROLE) {
        //set the price of minting.
        _navPrice = price;
    }

    function setMaxAllowed(uint16 maxA) external onlyRole(UPDATER_ROLE) {
        //max allowed per wallet
        _maxAllowedPerWallet = maxA;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        AccessToken memory accessTokenAttributes = nftAccessTokenAttribute[
            _tokenId
        ];
        return
            TuriContract.maketokenURi(
                _tokenId,
                accessTokenAttributes.whitelistSpots.length,
                accessTokenAttributes.winChances,
                accessTokenAttributes.softClay
            );
    }
}
