// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract NFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string public baseURI;
    string public baseExtension;
    string public notRevealedUri;
    uint256 public maxSupply; 
    uint256 public pausedMintAmount; 
    uint256 public cost; 
    uint256 public freeMintAmount; 
    uint256 public freeMintAddressLimit; 
    uint256 public nftPerAddressLimit;
    uint256 public maxMintAmount;
    uint256 public publicMintStartTime;
    uint256 public publicMintEndTime;
    string public desc;
    bool public paused = false;
    bool public revealed = false;
    bool public onlyWhitelisted = false;
    bytes32 public merkleRoot;
    string public merkleIpfs;


    mapping(address => uint256) public addressFreeMintedBalance;

    uint256 public freeMintAmountTotal;

    mapping(address => uint256) public addressMintedBalance;

    constructor(
        string[6] memory _baseInfo, 
        uint256[9] memory _optionsInfo,
        bytes32 _merkleRoot,
        bool _onlyWhitelisted,
        address service
    ) payable ERC721(_baseInfo[0], _baseInfo[1]) {
        baseURI = _baseInfo[2];
        baseExtension = _baseInfo[3];
        desc = _baseInfo[4];
        merkleIpfs = _baseInfo[5];
        maxSupply = _optionsInfo[0];
        pausedMintAmount = _optionsInfo[1];
        cost = _optionsInfo[2];
        freeMintAmount = _optionsInfo[3];
        freeMintAddressLimit = _optionsInfo[4];
        nftPerAddressLimit = _optionsInfo[5];
        maxMintAmount = _optionsInfo[6];
        publicMintStartTime = _optionsInfo[7];
        publicMintEndTime = _optionsInfo[8];
        onlyWhitelisted = _onlyWhitelisted;
        merkleRoot = _merkleRoot;
        payable(service).transfer(msg.value);
    }


    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // public
    function mint(uint256 _mintAmount,bytes32[] calldata _nodeProof) public payable {
        require(!paused, "the contract is paused");
        require(block.timestamp >= publicMintStartTime, "Public Mint not yet started.");
        require(block.timestamp <= publicMintEndTime, "Public is over.");
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(maxMintAmount == 0 || _mintAmount <= maxMintAmount, "max mint amount per session exceeded");
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

        if(pausedMintAmount > 0 && supply + _mintAmount >= pausedMintAmount){
            paused = true;
            _mintAmount = pausedMintAmount - supply;
        }
        uint256 paidMintAmount; 
        if (freeMintAmount > 0 && freeMintAmountTotal < freeMintAmount) {
            uint256 uFreeMintAmount; 
            uint256 ownerFreeMintedCount = addressFreeMintedBalance[msg.sender];

            if(freeMintAddressLimit > 0){

                if(ownerFreeMintedCount + _mintAmount > freeMintAddressLimit){

                    if(ownerFreeMintedCount > freeMintAddressLimit){
                         paidMintAmount = _mintAmount;
                    }else{

                        paidMintAmount = (ownerFreeMintedCount + _mintAmount) - freeMintAddressLimit;

                        uFreeMintAmount = _mintAmount - paidMintAmount;
                    }
                }else{

                    uFreeMintAmount = _mintAmount;
                }
            }else{
                uFreeMintAmount = _mintAmount;
            }
            uint256 freeMintAmountLeft = max(0, freeMintAmount - freeMintAmountTotal); 

            if(freeMintAmountLeft < uFreeMintAmount){
                paidMintAmount += (uFreeMintAmount - freeMintAmountLeft);
                uFreeMintAmount -= (uFreeMintAmount - freeMintAmountLeft);
            }
            addressFreeMintedBalance[msg.sender] += uFreeMintAmount;
            freeMintAmountTotal += uFreeMintAmount;
        }else{
            paidMintAmount = _mintAmount;
        }

        if(onlyWhitelisted == true) {
            bytes32 node = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(_nodeProof, merkleRoot, node), "user is not whitelisted");
        }

        uint256 ownerMintedCount = addressMintedBalance[msg.sender];
        require(nftPerAddressLimit == 0 || ownerMintedCount + _mintAmount <= nftPerAddressLimit, "max NFT per address exceeded");

        require(msg.value >= cost * paidMintAmount, "insufficient funds");
        uint256 retAmount = msg.value - cost * paidMintAmount;
        if(retAmount > 0){
            payable(msg.sender).transfer(retAmount);
        }
        for (uint256 i = 1; i <= _mintAmount; i++) {
            addressMintedBalance[msg.sender]++;
            _safeMint(msg.sender, supply + i);
        }
    }

    function adminMint(uint256 _mintAmount,address _receiveAddress) public onlyOwner{
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");
        for (uint256 i = 1; i <= _mintAmount; i++) {
            addressMintedBalance[_receiveAddress]++;
            _safeMint(_receiveAddress, supply + i);
        }

    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function reveal() public onlyOwner {
        revealed = true;
    }

    function setOnlyWhitelisted(bool _state) public onlyOwner {
        onlyWhitelisted = _state;
    }

    function setPausedMintAmount(uint256 _pausedMintAmount) public onlyOwner {
        pausedMintAmount =  _pausedMintAmount;
    }

    function setPublicMintStartTime(uint256 _publicMintStartTime)public onlyOwner {
        publicMintStartTime = _publicMintStartTime;
    }

    function setPublicMintEndTime(uint256 _publicMintEndTime)public onlyOwner {
        publicMintEndTime = _publicMintEndTime;
    }

    function whitelistUsers(bytes32 _merkleRoot,string memory _merkleIpfs) public onlyOwner {
        merkleRoot = _merkleRoot;
        merkleIpfs = _merkleIpfs;
    }

    function setInfo(string memory _descIpfs) public onlyOwner {
        desc = _descIpfs;
    }

    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function setFreeMintAmount(uint256 _freeMintAmount) public onlyOwner {
        freeMintAmount = _freeMintAmount;
    }

    function setFreeMintAmountLimit(uint256 _freeMintAddressLimit) public onlyOwner {
        freeMintAddressLimit = _freeMintAddressLimit;
    }

    function setMaxMintAmount(uint256 _newMaxMintAmount) public onlyOwner {
        maxMintAmount = _newMaxMintAmount;
    }

    function setNftPerAddressLimit(uint256 _limit) public onlyOwner {
        nftPerAddressLimit = _limit;
    }
    
    function setMintTime(uint256 _publicMintStartTime,uint256 _publicMintEndTime) public onlyOwner {
        publicMintStartTime = _publicMintStartTime;
        publicMintEndTime = _publicMintEndTime;
    }


    function isWhitelisted(address _user,bytes32[] calldata _merkleProof) public view returns (bool) {
        bytes32 node = keccak256(abi.encodePacked(_user));
        return MerkleProof.verify(_merkleProof, merkleRoot, node);
    }

    function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
    {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if(revealed == false && bytes(notRevealedUri).length > 0) {
            return notRevealedUri;
        }

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
    }

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    function claimToken(address token, uint256 amount, address to) public payable onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    //utils
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }
}