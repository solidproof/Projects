// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import '../LazyMinting/LazyMinting.sol';

contract Membership is LazyMinting {
  using Counters for Counters.Counter;

  struct AddressInfo {
    bool hasPreSaleAccess;
    uint256 preSalesMintedCount;
    uint256 salesMintedCount;
  }

  //nftId -> membership tier
  mapping(string => uint256) private _tierIndex;
  mapping(address => AddressInfo) private _addressInfoIndex;

  uint256 private constant PRE_SALES_MINT_LIMIT = 3;
  uint256 private constant SALES_MINT_LIMIT = 5;
  address public artpoolWallet;
  string[] private _nftIdsNotSoldOut;

  constructor(
    string memory name,
    string memory symbol,
    string memory baseUri,
    address artpoolWalletAdd,
    uint256 dropStart,
    // Set to 0 if the project should never end
    uint256 dropEnd,
    NftParams[] memory nftParamsArr,
    uint256[] memory tierList,
    address[] memory preSaleAccess
  ) LazyMinting(name, symbol, baseUri, dropStart, dropEnd, nftParamsArr) {
    artpoolWallet = artpoolWalletAdd;

    require(dropEnd == 0, 'The membership contract should have dropEnd == 0');

    require(
      tierList.length == nftParamsArr.length,
      'the tier quantity MUST be the same as the numbers of nfts'
    );

    for (uint256 i = 0; i < nftParamsArr.length; i++) {
      _tierIndex[nftParamsArr[i]._id] = tierList[i];
      _nftIdsNotSoldOut.push(nftParamsArr[i]._id);
    }

    for (uint256 i = 0; i < preSaleAccess.length; i++) {
      _addressInfoIndex[preSaleAccess[i]].hasPreSaleAccess = true;
    }
  }

  function _canMintPreSale(AddressInfo storage addressInfo)
    internal
    view
    returns (string memory)
  {
    if (!addressInfo.hasPreSaleAccess) {
      return 'Only whitelisted users can make a pre-sale purchase';
    }

    if (addressInfo.preSalesMintedCount >= PRE_SALES_MINT_LIMIT) {
      return 'You have reached the maximum pre-sales mints allowed per wallet';
    }

    return '';
  }

  function canMintNft(
    string memory nftId,
    address minter,
    uint256 msgValue
  ) public view override returns (string memory) {
    Nft storage nft = _getNft(nftId);

    if (nft.maxEditions <= nft.numMinted.current()) {
      return 'All editions of this NFT have been minted';
    }

    AddressInfo storage addressInfo = _addressInfoIndex[minter];

    if (msgValue != nft.price) {
      return 'You need to submit the correct nft price';
    }

    if (block.timestamp < _dropStart) {
      return _canMintPreSale(addressInfo);
    }

    if (addressInfo.salesMintedCount >= SALES_MINT_LIMIT) {
      return 'You have reached the maximum mints allowed per wallet';
    }

    return '';
  }

  function mint(string memory) public payable override nonReentrant {
    string memory nftId = nextNftIdToMint();

    string memory error = canMintNft(nftId, msg.sender, msg.value);
    require(isEmptyString(error), error);

    _mintToken(nftId, msg.sender);

    Nft storage nft = _getNft(nftId);
    uint256 editionNumber = nft.numMinted.current();
    uint256 tokenId = nft.firstTokenId + editionNumber - 1;

    _mintingTransfer(nftId, editionNumber, tokenId, artpoolWallet, msg.value);

    incrementWalletMintedCount();
  }

  function incrementWalletMintedCount() internal {
    AddressInfo storage addressInfo = _addressInfoIndex[msg.sender];

    if (block.timestamp < _dropStart) {
      addressInfo.preSalesMintedCount++;
      return;
    }

    addressInfo.salesMintedCount++;
  }

  function random() internal virtual returns (uint256) {
    return
      uint256(
        keccak256(
          abi.encodePacked(block.difficulty, block.timestamp, block.number)
        )
      );
  }

  function nextNftIdToMint() internal returns (string memory) {
    while (_nftIdsNotSoldOut.length > 0) {
      uint256 randomIndex = random() % _nftIdsNotSoldOut.length;
      string memory chosenNftId = _nftIdsNotSoldOut[randomIndex];

      if (hasAllEditionMinted(chosenNftId)) {
        //Here we are removing the nfts that are already sold out from the array to avoid that be chosen again
        _nftIdsNotSoldOut[randomIndex] = _nftIdsNotSoldOut[
          _nftIdsNotSoldOut.length - 1
        ];
        _nftIdsNotSoldOut.pop();
      } else {
        return chosenNftId;
      }
    }
    revert('All nfts are sold out');
  }

  function getHighestMembershipTier(address wallet)
    public
    view
    returns (uint256)
  {
    uint256 balance = this.balanceOf(wallet);
    uint256 maxTier = 0;

    for (uint256 i = 0; i < balance; i++) {
      uint256 idx = tokenOfOwnerByIndex(wallet, i);
      string memory nftId = _tokenIdIndex[idx];
      uint256 tier = _tierIndex[nftId];

      // tier 3 is greater than tier 2 and so on, the max tier in value for artpool will be the maximum integer value
      if (tier > maxTier) {
        maxTier = tier;
      }
    }
    return maxTier;
  }
}
