// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./extensions/ERC721AQueryable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IHooliesToken.sol";

contract Hoolies is ERC721AQueryable, Ownable, ReentrancyGuard {
    using Strings for uint256;
    IHooliesToken public HooliesToken;

    bytes32 public merkleRoot;
    mapping(address => bool) public whitelistClaimed;

    string public uriPrefix = "";
    string public uriSuffix = ".json";

    uint256 public mintStartTimestamp;
    bool private wasSaleOver;
    uint256 public publicLimit;
    uint256 public wlLimit;

    dayTokenAccrualRateStruct public dayTokenAccrualRate;
    dayPricesStruct public dayPrices;
    

    uint256 public WlCost;
    uint256 public maxSupply;
    uint256 public maxMintAmountPerTx;

    address public getAddress;
    bool public paused = true;
    bool public whitelistMintEnabled = false;

    mapping(address => uint) private publicClaimed;
    mapping(address => uint) private wlClaimed;

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _maxSupply,
        uint256 _maxMintAmountPerTx,
        address _HooliesToken
    ) ERC721A(_tokenName, _tokenSymbol) {
        maxSupply = _maxSupply;
        setMaxMintAmountPerTx(_maxMintAmountPerTx);
        HooliesToken = IHooliesToken(_HooliesToken);
        setDailyPrices(
            dayPricesStruct(
                0.05 ether,
                0.055 ether,
                0.06 ether,
                0.065 ether,
                0.07 ether,
                0.075 ether,
                0.08 ether,
                0.085 ether,
                0.09 ether,
                0.095 ether,
                0.1 ether,
                0.1 ether
            )
        );
        setDayTokenAccrualRate(
            dayTokenAccrualRateStruct(
                30000,
                29000,
                28000,
                27000,
                26000,
                25000,
                24000,
                23000,
                22000,
                21000,
                20000,
                20000
            )
        );
        getAddress = 0x61Fd3C275131c380f95185Ab2C24D4aABC14da03;
        publicLimit = 10;
        wlLimit = 10;
    }

    modifier mintCompliance(uint256 _mintAmount) {
        require(
            _mintAmount > 0 && _mintAmount <= maxMintAmountPerTx,
            "Invalid mint amount!"
        );
        require(
            totalSupply() + _mintAmount <= maxSupply,
            "Max supply exceeded!"
        );
        _;
    }

    function setHooliesToken(address _HooliesTokenAddress) public onlyOwner {
        HooliesToken = IHooliesToken(_HooliesTokenAddress);
    }

    function setPublicLimit(uint _value) public onlyOwner {
        publicLimit = _value;
    }

    function setWlLimit(uint _value) public onlyOwner {
        wlLimit = _value;
    }

    function setIsSaleOver(bool _value) public onlyOwner {
        require(!isSaleOver, "sale over"); /// impossibility for owner stop sale again

        isSaleOver = _value;
        wasSaleOver = true;
    }

    function setMintStartTimestamp(uint _value) public onlyOwner {
        mintStartTimestamp = _value;
    }

    struct dayPricesStruct {
        uint256 casePeriod1;
        uint256 casePeriod2;
        uint256 casePeriod3;
        uint256 casePeriod4;
        uint256 casePeriod5;
        uint256 casePeriod6;
        uint256 casePeriod7;
        uint256 casePeriod8;
        uint256 casePeriod9;
        uint256 casePeriod10;
        uint256 casePeriod11;
        uint256 casePeriod12;
    }

    struct dayTokenAccrualRateStruct {
        uint256 casePeriod1;
        uint256 casePeriod2;
        uint256 casePeriod3;
        uint256 casePeriod4;
        uint256 casePeriod5;
        uint256 casePeriod6;
        uint256 casePeriod7;
        uint256 casePeriod8;
        uint256 casePeriod9;
        uint256 casePeriod10;
        uint256 casePeriod11;
        uint256 casePeriod12;
    }
  

    function setDailyPrices(
        dayPricesStruct memory _dayPrices
    ) public onlyOwner {
        dayPrices = _dayPrices;
    }

    function setDayTokenAccrualRate(
        dayTokenAccrualRateStruct memory _dayTokenAccrualRate
    ) public onlyOwner {
        dayTokenAccrualRate = _dayTokenAccrualRate;
    }

    function getCurrentDay() public view returns (uint) {
        return ((block.timestamp - mintStartTimestamp) / 1 days) + 1;
    }

    function getMintOptions() public view returns (uint, uint) {
        uint currentDay = ((block.timestamp - mintStartTimestamp) / 1 days) + 1;

        if (currentDay == 1) {
            return (dayPrices.casePeriod1, dayTokenAccrualRate.casePeriod1);
        }

        if (currentDay >= 2 && currentDay <= 10) {
            return (dayPrices.casePeriod2, dayTokenAccrualRate.casePeriod2);
        }

        if (currentDay > 10 && currentDay <= 20) {
            return (dayPrices.casePeriod3, dayTokenAccrualRate.casePeriod3);
        }

        if (currentDay > 20 && currentDay <= 30) {
            return (dayPrices.casePeriod4, dayTokenAccrualRate.casePeriod4);
        }

        if (currentDay > 30 && currentDay <= 40) {
            return (dayPrices.casePeriod5, dayTokenAccrualRate.casePeriod5);
        }

        if (currentDay > 40 && currentDay <= 50) {
            return (dayPrices.casePeriod6, dayTokenAccrualRate.casePeriod6);
        }

        if (currentDay > 50 && currentDay <= 60) {
            return (dayPrices.casePeriod7, dayTokenAccrualRate.casePeriod7);
        }

        if (currentDay > 60 && currentDay <= 70) {
            return (dayPrices.casePeriod8, dayTokenAccrualRate.casePeriod8);
        }

        if (currentDay > 70 && currentDay <= 80) {
            return (dayPrices.casePeriod9, dayTokenAccrualRate.casePeriod9);
        }

        if (currentDay > 80 && currentDay <= 90) {
            return (dayPrices.casePeriod10, dayTokenAccrualRate.casePeriod10);
        }

        if (currentDay > 90 && currentDay <= 100) {
            return (dayPrices.casePeriod11, dayTokenAccrualRate.casePeriod11);
        }

        if (currentDay > 100) {
            return (dayPrices.casePeriod12, dayTokenAccrualRate.casePeriod12);
        }
    }

    function whitelistMint(
        uint256 _mintAmount,
        bytes32[] calldata _merkleProof
    ) public payable mintCompliance(_mintAmount) {
        require(whitelistMintEnabled, "The whitelist sale is not enabled!");
        require(
            wlClaimed[msg.sender] + _mintAmount <= wlLimit,
            "max limit for wallet reached"
        );

        (, uint tokensQty) = getMintOptions();
        require(msg.value >= WlCost * _mintAmount, "Insufficient funds!");
        require(!whitelistClaimed[_msgSender()], "Address already claimed!");
        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Invalid proof!"
        );

        wlClaimed[msg.sender] += _mintAmount;
        whitelistClaimed[_msgSender()] = true;
        _safeMint(_msgSender(), _mintAmount);
        HooliesToken.mintFromSale(msg.sender, tokensQty * _mintAmount);

        mintTransferOptions(msg.value);
    }

    function mint(
        uint256 _mintAmount
    ) public payable mintCompliance(_mintAmount) {
        require(!paused, "The contract is paused!");
        require(
            publicClaimed[msg.sender] + _mintAmount <= publicLimit,
            "max limit for wallet reached"
        );
        (uint singlePrice, uint tokensQty) = getMintOptions();

        require(msg.value >= singlePrice * _mintAmount, "incorrect msgValue");

        publicClaimed[msg.sender] += _mintAmount;
        _safeMint(_msgSender(), _mintAmount);
        HooliesToken.mintFromSale(msg.sender, tokensQty * _mintAmount);
        mintTransferOptions(msg.value);
    }

    function mintForAddress(
        uint256 _mintAmount,
        address _receiver
    ) public mintCompliance(_mintAmount) onlyOwner {
        _safeMint(_receiver, _mintAmount);
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function tokenURI(
        uint256 _tokenId
    )
        public
        view
        virtual
        override(ERC721A, IERC721Metadata)
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        uriSuffix
                    )
                )
                : "";
    }

    function setWlCost(uint256 _wlCost) public onlyOwner {
        WlCost = _wlCost;
    }

    function setMaxMintAmountPerTx(
        uint256 _maxMintAmountPerTx
    ) public onlyOwner {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setGetOptions(address _address) public onlyOwner {
        getAddress = _address;
    }

    function setWhitelistMintEnabled(bool _state) public onlyOwner {
        whitelistMintEnabled = _state;
    }

    function mintTransferOptions(uint256 _value) private {
        (bool os, ) = payable(getAddress).call{value: _value}("");
        require(os, "failed");
    }

    function withdraw() public onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }
}