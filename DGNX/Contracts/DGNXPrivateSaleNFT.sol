// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract DGNXPrivateSaleNFT is
    Ownable,
    ReentrancyGuard,
    ERC721,
    ERC721Enumerable
{
    using Strings for uint256;
    using Counters for Counters.Counter;

    enum TicketType {
        BRONZE,
        SILVER,
        GOLD
    }

    bool private _mintingStarted = false;
    bool private _mintingStartedGold = false;
    bool private _mintingStartedSilver = false;
    bool private _mintingStartedBronze = false;
    string private _assetsBaseURI;
    uint256 public _mintPriceBronze;
    uint256 public _mintPriceSilver;
    uint256 public _mintPriceGold;
    uint256 public _bronzeMaxSupply;
    uint256 public _silverMaxSupply;
    uint256 public _goldMaxSupply;

    // whitelisting
    mapping(address => bool) private whitelist;
    mapping(address => TicketType) private whitelistType;
    mapping(address => bool) private whitelistAdmins;

    // status
    Counters.Counter private _tokenIds;

    mapping(uint256 => TicketType) private _tokenTicketTypes;
    uint256 public _bronzeCurrentSupply;
    uint256 public _silverCurrentSupply;
    uint256 public _goldCurrentSupply;

    // events
    event StartMinting(address sender);
    event StopMinting(address sender);
    event StartMintingBronze(address sender);
    event StopMintingBronze(address sender);
    event StartMintingSilver(address sender);
    event StopMintingSilver(address sender);
    event StartMintingGold(address sender);
    event StopMintingGold(address sender);
    event FundsDirectlyDeposited(address sender, uint256 amount);
    event FundsReceived(address sender, uint256 amount);
    event TokensMinted(
        address minter,
        uint256 currentSupply,
        uint256 bronzeSupply,
        uint256 silverSupply,
        uint256 goldSupply,
        uint256 bronzeMaxSupply,
        uint256 silverMaxSupply,
        uint256 goldMaxSupply
    );
    event TokensBurned(
        address burner,
        uint256 currentSupply,
        uint256 bronzeSupply,
        uint256 silverSupply,
        uint256 goldSupply,
        uint256 bronzeMaxSupply,
        uint256 silverMaxSupply,
        uint256 goldMaxSupply
    );

    constructor(
        string memory name,
        string memory symbol,
        string memory assetsBaseURI,
        uint256 goldMaxSupply,
        uint256 silverMaxSupply,
        uint256 bronzeMaxSupply
    ) ERC721(name, symbol) {
        // set bronze info for contract
        _goldMaxSupply = goldMaxSupply;
        _silverMaxSupply = silverMaxSupply;
        _bronzeMaxSupply = bronzeMaxSupply;
        _mintPriceBronze = 2;
        _mintPriceSilver = 2;
        _mintPriceGold = 2;
        _assetsBaseURI = assetsBaseURI;
    }

    // --- fallback/received --- //
    receive() external payable {
        emit FundsReceived(_msgSender(), msg.value);
    }

    fallback() external payable {
        emit FundsDirectlyDeposited(_msgSender(), msg.value);
    }

    modifier onlyAllowed() {
        require(
            _msgSender() == owner() || whitelistAdmins[_msgSender()],
            '!rights'
        );
        _;
    }

    // --- overrides --- //
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view override(ERC721) returns (string memory) {
        return _assetsBaseURI;
    }

    // --- modifiers --- //
    modifier whenMintingAllowed() {
        require(
            _mintingStarted &&
                _tokenIds.current() <
                _bronzeMaxSupply + _silverMaxSupply + _goldMaxSupply,
            'DGNXPrivateSaleNFT::whenMintingAllowed not started or sold-out'
        );
        _;
    }

    // -- utils -- //
    function _actualMintPrice(TicketType sType)
        internal
        view
        returns (uint256)
    {
        if (sType == TicketType.BRONZE) {
            return _mintPriceBronze * (10**(18));
        } else if (sType == TicketType.SILVER) {
            return _mintPriceSilver * (10**(18));
        } else {
            return _mintPriceGold * (10**(18));
        }
    }

    /**
     * all tokens belonging to a wallet address
     */
    function _tokensByOwner(address tOwner)
        internal
        view
        returns (uint256[] memory)
    {
        uint256 balOf = balanceOf(tOwner);
        uint256[] memory tokens = new uint256[](balOf);
        for (uint256 i = 0; i < balOf; i++) {
            tokens[i] = tokenOfOwnerByIndex(tOwner, i);
        }
        return tokens;
    }

    // --- owners call --- //
    /**
     *  withdraw
     */
    function withdrawFunds() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * airdrop minting - this function is only to be called in case
     * of not minting out and community vote to airdrop the remainders
     * to all holders.
     */
    function airdropMint(address recipient, TicketType sType)
        external
        onlyOwner
    {
        require(
            balanceOf(recipient) == 0,
            'DGNXPrivateSaleNFT::airdropMint Exceeds maximum amount per ticket per wallet'
        );
        bool allowedToMint = false;
        if (sType == TicketType.BRONZE) {
            allowedToMint = (_bronzeCurrentSupply + 1) <= _bronzeMaxSupply;
        }
        if (sType == TicketType.SILVER) {
            allowedToMint = (_silverCurrentSupply + 1) <= _silverMaxSupply;
        }
        if (sType == TicketType.GOLD) {
            allowedToMint = (_goldCurrentSupply + 1) <= _goldMaxSupply;
        }

        require(
            allowedToMint,
            'DGNXPrivateSaleNFT::airdropMint Exceeds max supply allowed'
        );
        mintToken(recipient, sType, 1);
    }

    // --- token --- //
    /**
     * actual mint function
     */
    function mintToken(
        address recipient,
        TicketType sType,
        uint256 amount
    ) internal {
        uint256 tokenId;
        for (uint256 i = 0; i < amount; i++) {
            _tokenIds.increment();
            tokenId = _tokenIds.current();
            _mint(recipient, tokenId);
            _tokenTicketTypes[tokenId] = sType;
        }

        if (sType == TicketType.BRONZE) {
            _bronzeCurrentSupply += amount;
        } else if (sType == TicketType.SILVER) {
            _silverCurrentSupply += amount;
        } else {
            _goldCurrentSupply += amount;
        }

        emit TokensMinted(
            recipient,
            totalSupply(),
            _bronzeCurrentSupply,
            _silverCurrentSupply,
            _goldCurrentSupply,
            _bronzeMaxSupply,
            _silverMaxSupply,
            _goldMaxSupply
        );
    }

    function mint() public payable whenMintingAllowed nonReentrant {
        require(
            !whitelist[_msgSender()],
            'DGNXPrivateSaleNFT::mint not allowed to mint ticket'
        );
        require(
            balanceOf(_msgSender()) == 0,
            'DGNXPrivateSaleNFT::mint Exceeds maximum amount per ticket per wallet'
        );
        require(
            msg.value >= _actualMintPrice(TicketType.SILVER),
            'DGNXPrivateSaleNFT::mint Insufficient payment'
        );
        require(
            (_silverCurrentSupply + 1) <= _silverMaxSupply,
            'DGNXPrivateSaleNFT::mint Exceeds max supply allowed for ticket'
        );
        require(
            _mintingStartedSilver,
            'DGNXPrivateSaleNFT::mintWhitelist Silver minting not started yet'
        );

        mintToken(_msgSender(), TicketType.SILVER, 1);
    }

    function mintWhitelist() public payable whenMintingAllowed nonReentrant {
        TicketType _type = whitelistType[_msgSender()];
        delete whitelistType[_msgSender()];
        require(
            whitelist[_msgSender()],
            'DGNXPrivateSaleNFT::mintWhitelist not allowed to mint ticket'
        );
        require(
            balanceOf(_msgSender()) == 0,
            'DGNXPrivateSaleNFT::mintWhitelist Exceeds maximum amount per ticket per wallet'
        );
        require(
            msg.value >= _actualMintPrice(_type),
            'DGNXPrivateSaleNFT::mintWhitelist Insufficient payment'
        );

        bool allowedToMint = false;
        if (_type == TicketType.GOLD) {
            require(
                _mintingStartedGold,
                'DGNXPrivateSaleNFT::mintWhitelist Gold minting not started yet'
            );
            allowedToMint = (_goldCurrentSupply + 1) <= _goldMaxSupply;
        }
        if (_type == TicketType.BRONZE) {
            require(
                _mintingStartedBronze,
                'DGNXPrivateSaleNFT::mintWhitelist Bronze minting not started yet'
            );
            allowedToMint = (_bronzeCurrentSupply + 1) <= _bronzeMaxSupply;
        }

        require(
            allowedToMint,
            'DGNXPrivateSaleNFT::mintWhitelist Exceeds max supply allowed for ticket'
        );

        mintToken(_msgSender(), _type, 1);
    }

    function burn(uint256 tokenId) public nonReentrant {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            'DGNXPrivateSaleNFT::burn Not owner nor approved'
        );
        _burn(tokenId);
        emit TokensBurned(
            _msgSender(),
            totalSupply(),
            _bronzeCurrentSupply,
            _silverCurrentSupply,
            _goldCurrentSupply,
            _bronzeMaxSupply,
            _silverMaxSupply,
            _goldMaxSupply
        );
    }

    /**
     * @dev returns the token metadata uri - initially we'll be hosting our own
     * once we get some metrics in how metadata & assets are being used by the ecosystem
     * we will find a place to host it permanently and decentralized (e.g: ipfs)
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721)
        returns (string memory)
    {
        require(
            _exists(tokenId),
            'DGNXPrivateSaleNFT::tokenURI Nonexistent token'
        );
        string memory baseURI = _baseURI();
        string memory typeName;
        if (_tokenTicketTypes[tokenId] == TicketType.GOLD) {
            typeName = 'gold.jpg';
        } else if (_tokenTicketTypes[tokenId] == TicketType.SILVER) {
            typeName = 'silver.jpg';
        } else {
            typeName = 'bronze.jpg';
        }
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, typeName))
                : '';
    }

    function lookupTicketType(uint256 tokenId) public view returns (uint256) {
        require(
            _exists(tokenId),
            'DGNXPrivateSaleNFT::lookupTicketType Nonexistent token'
        );
        return uint256(_tokenTicketTypes[tokenId]);
    }

    // whitelisting
    function addToWhitelist(address _addr, TicketType _type)
        external
        onlyAllowed
    {
        require(
            _addr != address(0),
            'DGNXPrivateSaleNFT::addToWhitelist not valid address'
        );
        require(
            _type == TicketType.GOLD || _type == TicketType.BRONZE,
            'DGNXPrivateSaleNFT::addToWhitelist not valid ticket type'
        );
        whitelist[_addr] = true;
        whitelistType[_addr] = _type;
    }

    function revokeFromWhitelist(address _addr) external onlyAllowed {
        require(
            _addr != address(0),
            'DGNXPrivateSaleNFT::revokeFromWhitelist not valid address'
        );
        whitelist[_addr] = false;
        delete whitelistType[_addr];
    }

    function isWhitelistedForType(address _addr, TicketType _type)
        external
        view
        returns (bool)
    {
        return whitelist[_addr] && whitelistType[_addr] == _type;
    }

    function isWhitelisted(address _addr) external view returns (bool) {
        return whitelist[_addr];
    }

    function addWhitelistAdmin(address _addr) external onlyOwner {
        require(
            _addr != address(0),
            'DGNXPrivateSaleNFT::addWhitelistAdmin not valid address'
        );
        whitelistAdmins[_addr] = true;
    }

    function revokeWhitelistAdmin(address _addr) external onlyOwner {
        require(
            _addr != address(0) && whitelistAdmins[_addr],
            'DGNXPrivateSaleNFT::revokeWhitelistAdmin not valid address'
        );
        whitelistAdmins[_addr] = false;
    }

    function isWhitelistAdmin(address _addr)
        external
        view
        onlyOwner
        returns (bool)
    {
        return whitelistAdmins[_addr];
    }

    function startMintingGold() external onlyOwner {
        _mintingStartedGold = true;
        emit StartMintingGold(_msgSender());
    }

    function stopMintingGold() external onlyOwner {
        _mintingStartedGold = false;
        emit StopMintingGold(_msgSender());
    }

    function hasMintingGoldStarted() external view returns (bool) {
        return _mintingStartedGold;
    }

    function startMintingSilver() external onlyOwner {
        _mintingStartedSilver = true;
        emit StartMintingSilver(_msgSender());
    }

    function stopMintingSilver() external onlyOwner {
        _mintingStartedSilver = false;
        emit StopMintingSilver(_msgSender());
    }

    function hasMintingSilverStarted() external view returns (bool) {
        return _mintingStartedSilver;
    }

    function startMintingBronze() external onlyOwner {
        _mintingStartedBronze = true;
        emit StartMintingBronze(_msgSender());
    }

    function stopMintingBronze() external onlyOwner {
        _mintingStartedBronze = false;
        emit StopMintingBronze(_msgSender());
    }

    function hasMintingBronzeStarted() external view returns (bool) {
        return _mintingStartedBronze;
    }

    function startMinting() external onlyOwner {
        _mintingStarted = true;
        emit StartMinting(_msgSender());
    }

    function stopMinting() external onlyOwner {
        _mintingStarted = false;
        emit StopMinting(_msgSender());
    }

    function hasMintingtarted() external view returns (bool) {
        return _mintingStarted;
    }
}
