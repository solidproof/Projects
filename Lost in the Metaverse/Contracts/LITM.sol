// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface ITypeHelper {
  function typeOf(uint) external returns (uint);
}

interface IRoyaltyDividener {
  function addHolder(address) external;
}

contract ApeDadLITM is ERC721("ApeDad 2662: Lost In The Metaverse", "ApeDadLITM"), Ownable {
  using Strings for uint;

  uint public price = 0.11 ether;
  uint constant  public limitPerAddress = 33;

  uint constant public maxSupply = 1111;
  uint constant public maxRoyaltySupply = 101;
  uint public royaltySupply;

  mapping(address=>uint[]) public userTokens;
  mapping(uint=>bool) public used;
  mapping(address=>uint) public royaltyToken;

  uint private _currentIndex;

  ITypeHelper public typeHelper;

  string public baseURI;
  string public baseExtension;
  string public royaltyBaseURI;
  string public royaltyBaseExtension;

  IRoyaltyDividener public royaltyDividener;

  bool public inSale;

  event TokenUsed(uint token1, uint token2, uint token3);

  constructor(ITypeHelper _typeHelper) {
    typeHelper = _typeHelper;
  }

  function setPrice(uint _price) external onlyOwner {
    price = _price;
  }

  function setBaseURI(string memory baseURI_, string memory baseExtension_) external onlyOwner {
    baseURI = baseURI_;
    baseExtension = baseExtension_;
  }

  function setRoyaltyBaseURI(string memory baseURI_, string memory baseExtension_) external onlyOwner {
    royaltyBaseURI = baseURI_;
    royaltyBaseExtension = baseExtension_;
  }

  function setRoyaltyDividener(IRoyaltyDividener _dividener) external onlyOwner {
    royaltyDividener = _dividener;
  }

  function startSale() external onlyOwner {
    inSale = true;
  }

  function stopSale() external onlyOwner {
    inSale = false;
  }

  function mint(uint amount) external payable {
    require (amount > 0, "Invalid request");
    require (msg.value >= price * amount, "Insufficient payment");
    require (balanceOf(msg.sender) + amount <= limitPerAddress, "You can't have more than 33");
    require (_currentIndex + amount <= maxSupply, "You cannot mint any more");
    require (inSale, "Sale not started yet");

    uint i = 0;
    for (i = 0; i < amount; i+=1) {
      _currentIndex++;
      _mint(msg.sender, _currentIndex);
      userTokens[msg.sender].push(_currentIndex);
    }
  }

  function mintRoyalty(uint token1, uint token2, uint token3) external {
    require (royaltyToken[msg.sender] == 0, "You already have minted royalty");
    require (!used[token1] && !used[token2] && !used[token3], "The NFTs are not virgin");
    require (ownerOf(token1) == msg.sender && ownerOf(token2) == msg.sender && ownerOf(token3) == msg.sender, "You are not the tokens owner");
    require (typeHelper.typeOf(token1) | typeHelper.typeOf(token2) | typeHelper.typeOf(token3) == 7, "Invalid token types");
    require (maxRoyaltySupply > royaltySupply, "All royalty NFTs minted");

    royaltySupply++;
    royaltyToken[msg.sender] = royaltySupply;

    used[token1] = true;
    used[token2] = true;
    used[token3] = true;

    emit TokenUsed(token1, token2, token3);

    royaltyDividener.addHolder(msg.sender);
  }

  function tokenURI(uint tokenId) public view override returns (string memory) {
    require (_exists(tokenId), "Nonexistent token ID");

    return string(abi.encodePacked(baseURI, tokenId.toString(), baseExtension));
  }

  function totalSupply() public view returns (uint) {
    return _currentIndex;
  }

  function royaltyTokenURI(address user) public view returns (string memory) {
    require (royaltyToken[user] > 0, "The user doesn't have a royalty NFT");

    return string(abi.encodePacked(royaltyBaseURI, royaltyToken[user], royaltyBaseExtension));
  }

  function walletOf(address user) public view returns (uint[] memory) {
    return userTokens[user];
  }

  function withdraw(address to) external onlyOwner {
    Address.sendValue(payable(to), address(this).balance);
  }
}
