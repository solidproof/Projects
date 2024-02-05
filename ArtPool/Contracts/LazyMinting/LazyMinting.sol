// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';

abstract contract LazyMinting is
  ERC721,
  ERC721URIStorage,
  ERC721Burnable,
  ERC721Enumerable,
  Ownable,
  ReentrancyGuard,
  IERC2981
{
  using Counters for Counters.Counter;
  using SafeMath for uint256;

  uint256 constant ONE_HUNDRED_PERCENT = 10000;

  event MintingTransfer(
    string indexed nftIdIndex,
    string nftId,
    uint256 indexed editionNumber,
    uint256 tokenId,
    address wallet,
    uint256 paymentValue
  );

  event EditionMinted(
    string indexed nftIdIndex,
    string nftId,
    uint256 indexed editionNumber,
    uint256 tokenId,
    address owner,
    uint256 amount
  );

  // This is for the benefit of OpenSea https://docs.opensea.io/docs/metadata-standards#freezing-metadata
  event PermanentURI(string _value, uint256 indexed _id);

  struct NftParams {
    string _id;
    uint256 maxEditions;
    address artist;
    uint256 price;
    Stakeholder[] primaryStakeholders;
    Stakeholder eip2981Stakeholder;
    uint256 minMembershipTier;
  }

  struct Nft {
    uint256 maxEditions;
    Counters.Counter numMinted;
    uint256 firstTokenId;
    address artist;
    uint256 price;
    Stakeholder eip2981Stakeholder;
    uint256 minMembershipTier;
  }

  struct CollectionInfo {
    uint256 dropStart;
    uint256 dropEnd;
  }

  struct NftInfo {
    string nftId;
    uint256 numMinted;
    uint256 maxEditions;
    uint256 price;
    uint256 minMembershipTier;
  }

  struct Stakeholder {
    address wallet;
    uint256 stake;
  }

  // Mapping of nftId => Nft
  mapping(string => Nft) internal _nfts;

  // Mapping of tokenId => nftId
  mapping(uint256 => string) internal _tokenIdIndex;

  string private _customBaseUri;
  uint256 internal _dropStart;
  uint256 internal _dropEnd;

  constructor(
    string memory name,
    string memory symbol,
    string memory baseUri,
    uint256 dropStart,
    // Set to 0 if the project should never end
    uint256 dropEnd,
    NftParams[] memory nftParamsArr
  ) ERC721(name, symbol) {
    _customBaseUri = baseUri;
    _dropStart = dropStart;
    _dropEnd = dropEnd;

    uint256 tokenCounter;
    for (uint256 i = 0; i < nftParamsArr.length; i++) {
      NftParams memory nftParams = nftParamsArr[i];
      Nft storage nft = _nfts[nftParams._id];
      nft.artist = nftParams.artist;
      nft.maxEditions = nftParams.maxEditions;
      nft.price = nftParams.price;
      nft.firstTokenId = tokenCounter;
      nft.eip2981Stakeholder = nftParams.eip2981Stakeholder;
      nft.minMembershipTier = nftParams.minMembershipTier;

      tokenCounter += nft.maxEditions;
    }
  }

  /**
   * Returns empty string if `minter` can mint, or otherwise an error message explaining
   * why the user is not allowed to mint
   */
  function canMintNft(
    string memory nftId,
    address minter,
    uint256 msgValue
  ) public view virtual returns (string memory);

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

  function mint(string memory nftId) public payable virtual;

  /**
   * Ensure that calling functions are nonReentrant
   */
  function _mintToken(string memory nftId, address to) internal {
    Nft storage nft = _getNft(nftId);

    uint256 editionNumber = nft.numMinted.current() + 1;
    require(
      editionNumber <= nft.maxEditions,
      'All the editions for this nftId have been minted'
    );
    // Mint the token to artist to establish provenance on-chain
    uint256 tokenId = nft.firstTokenId + nft.numMinted.current();
    _mint(nft.artist, tokenId);

    _tokenIdIndex[tokenId] = nftId;

    string memory uri = buildTokenUri(nftId, editionNumber);
    _setTokenURI(tokenId, uri);

    // Incrementing before transfer adds extra protection against reentrancy attacks
    nft.numMinted.increment();

    // Transfer the token to {@code to}
    _transfer(nft.artist, to, tokenId);

    emit EditionMinted(nftId, nftId, editionNumber, tokenId, to, msg.value);
    emit PermanentURI(uri, tokenId);
  }

  function ownerMintTo(string memory nftId, address to)
    public
    onlyOwner
    nonReentrant
  {
    _mintToken(nftId, to);
  }

  function getNftInfo(string memory nftId)
    public
    view
    returns (NftInfo memory)
  {
    Nft storage nft = _getNft(nftId);
    return
      NftInfo(
        nftId,
        nft.numMinted.current(),
        nft.maxEditions,
        nft.price,
        nft.minMembershipTier
      );
  }

  function nftInfoForToken(uint256 tokenId)
    public
    view
    returns (NftInfo memory)
  {
    return getNftInfo(_tokenIdIndex[tokenId]);
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

  function buildTokenUri(string memory nftId, uint256 editionNumber)
    public
    view
    returns (string memory)
  {
    return
      string(
        abi.encodePacked(
          _customBaseUri,
          '/',
          nftId,
          '-',
          Strings.toString(editionNumber),
          '.json'
        )
      );
  }

  function _getNft(string memory nftId) internal view returns (Nft storage) {
    Nft storage nft = _nfts[nftId];
    require(nft.maxEditions > 0, 'No such nft, or maxEditions of nft is 0');
    return nft;
  }

  // Keep in mind those divisions will be treated as integers so 10/100 will be return 0 instead of 0.1
  // because of that if we want to calculate 10% of 400 we need to do as follow
  // CORRECT way  1000 * 400 / 10000 => 40
  // WRONG way 1000 / 10000 * 400 => 0
  function computeStake(uint256 stake, uint256 price)
    internal
    pure
    returns (uint256)
  {
    return (stake * price) / ONE_HUNDRED_PERCENT;
  }

  function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
    external
    view
    override
    returns (address receiver, uint256 royaltyAmount)
  {
    string memory nftId = _tokenIdIndex[_tokenId];
    Nft storage nft = _getNft(nftId);
    uint256 amountToBePaid = computeStake(
      nft.eip2981Stakeholder.stake,
      _salePrice
    );
    return (nft.eip2981Stakeholder.wallet, amountToBePaid);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721, ERC721Enumerable, IERC165)
    returns (bool)
  {
    return (interfaceId == type(IERC2981).interfaceId ||
      super.supportsInterface(interfaceId));
  }

  function getCollectionInfo() public view returns (CollectionInfo memory) {
    return CollectionInfo(_dropStart, _dropEnd);
  }

  function hasAllEditionMinted(string memory _nftId)
    internal
    view
    returns (bool)
  {
    Nft storage nft = _getNft(_nftId);

    return nft.maxEditions == nft.numMinted.current();
  }

  function isEmptyString(string memory s) internal pure returns (bool) {
    return bytes(s).length == 0;
  }

  function _mintingTransfer(
    string memory nftId,
    uint256 editionNumber,
    uint256 tokenId,
    address wallet,
    uint256 amount
  ) internal {
    payable(wallet).transfer(amount);
    emit MintingTransfer(nftId, nftId, editionNumber, tokenId, wallet, amount);
  }
}
