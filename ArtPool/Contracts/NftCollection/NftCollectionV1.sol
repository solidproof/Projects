// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import '../BusinessLogic/BusinessLogic.sol';

contract NftCollectionV1 is
  ERC721,
  ERC721URIStorage,
  ERC721Burnable,
  Ownable,
  ReentrancyGuard
{
  using Counters for Counters.Counter;
  using SafeMath for uint256;

  struct NftParams {
    string _id;
    uint256 maxEditions;
    address artist;
    uint256 price;
  }

  struct Nft {
    uint256 maxEditions;
    Counters.Counter numMinted;
    uint256 firstTokenId;
    address artist;
    uint256 price;
  }

  struct NftInfo {
    string nftId;
    uint256 numMinted;
    uint256 maxEditions;
  }

  uint256 tokenCounter;

  // Mapping of nftId => Nft
  mapping(string => Nft) private _nfts;

  string private _customBaseUri;
  address private _artpoolWallet;
  uint256 private _dropStart;
  uint256 private _dropEnd;
  address private _businessLogicAdd;

  constructor(
    string memory name,
    string memory symbol,
    string memory baseUri,
    address artpoolWallet,
    uint256 dropStart,
    // Set to 0 if the project should never end
    uint256 dropEnd,
    address businessLogicAdd,
    NftParams[] memory nftParamsArr
  ) ERC721(name, symbol) {
    _customBaseUri = baseUri;
    _artpoolWallet = artpoolWallet;
    _dropStart = dropStart;
    _dropEnd = dropEnd;
    _businessLogicAdd = businessLogicAdd;
    for (uint256 i = 0; i < nftParamsArr.length; i++) {
      NftParams memory nftParams = nftParamsArr[i];
      Nft storage nft = _nfts[nftParams._id];
      nft.artist = nftParams.artist;
      nft.maxEditions = nftParams.maxEditions;
      nft.price = nftParams.price;
      nft.firstTokenId = tokenCounter;
      tokenCounter += nft.maxEditions;
    }
  }

  function setBusinessLogicAdd(address add) public onlyOwner {
    _businessLogicAdd = add;
  }

  function getBusinessLogicAdd() public view onlyOwner returns(address) {
    return _businessLogicAdd;
  }

  function getTokenId(string memory nftId, uint256 editionNumber)
    public
    view
    returns (uint256)
  {
    require(editionNumber > 0, 'Edition numbers start from 1');

    Nft storage nft = _getNft(nftId);
    require(
      editionNumber <= nft.maxEditions,
      'Edition number exceeds maximum for this nft'
    );
    return nft.firstTokenId + editionNumber - 1;
  }

  function buildTokenUri(string memory nftId)
    public
    view
    returns (string memory)
  {
    return string(abi.encodePacked(_customBaseUri, '/', nftId, '.json'));
  }

  function mint(string memory nftId) public payable {
    Nft storage nft = _getNft(nftId);

    BusinessLogic(_businessLogicAdd).checkMintAllowed(
      _dropStart,
      _dropEnd,
      msg.sender,
      nft.price,
      msg.value
    );

    // TODO implement royalties
    payable(_artpoolWallet).transfer(msg.value);
    _mintToken(nftId, msg.sender);
  }

  function ownerMintTo(string memory nftId, address to) public onlyOwner {
    _mintToken(nftId, to);
  }

  function _mintToken(string memory nftId, address to) internal nonReentrant {
    Nft storage nft = _getNft(nftId);

    uint256 editionNumber = nft.numMinted.current() + 1;
    require(
      editionNumber <= nft.maxEditions,
      'All the editions for this nftId have been minted'
    );

    // Mint the token to artist to establish provenance on-chain
    uint256 tokenId = nft.firstTokenId + nft.numMinted.current();
    _mint(nft.artist, tokenId);

    _setTokenURI(tokenId, buildTokenUri(nftId));

    // Transfer the token to {@code to}
    _transfer(nft.artist, to, tokenId);

    nft.numMinted.increment();
  }

  function totalSupply() public view returns (uint256) {
    return tokenCounter;
  }

  function getNftInfo(string memory nftId)
    public
    view
    returns (NftInfo memory)
  {
    Nft storage nft = _getNft(nftId);
    return NftInfo(nftId, nft.numMinted.current(), nft.maxEditions);
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  function _getNft(string memory nftId) internal view returns (Nft storage) {
    Nft storage nft = _nfts[nftId];
    require(nft.maxEditions > 0, 'No such nft, or maxEditions of nft is 0');
    return nft;
  }
}
