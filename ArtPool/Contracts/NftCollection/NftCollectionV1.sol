// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import '../LazyMinting/LazyMinting.sol';
import '../BusinessLogic/IBusinessLogic.sol';

contract NftCollectionV1 is LazyMinting {
  using Counters for Counters.Counter;

  address public businessLogicAddress;

  address internal _artpoolWallet;

  mapping(string => Stakeholder[]) private _primaryStakeholders;

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
  ) LazyMinting(name, symbol, baseUri, dropStart, dropEnd, nftParamsArr) {
    require(
      artpoolWallet != address(0),
      'artpoolWallet cannot be zero address'
    );

    _artpoolWallet = artpoolWallet;
    setBusinessLogicAddress(businessLogicAdd);

    for (uint256 i = 0; i < nftParamsArr.length; i++) {
      NftParams memory nftParams = nftParamsArr[i];
      Stakeholder[] storage stakeholders = _primaryStakeholders[nftParams._id];

      uint256 totalStake = 0;

      for (uint256 j = 0; j < nftParams.primaryStakeholders.length; j++) {
        Stakeholder memory stakeholder = nftParams.primaryStakeholders[j];
        totalStake += stakeholder.stake;
        stakeholders.push(stakeholder);
      }

      require(
        totalStake == ONE_HUNDRED_PERCENT,
        'Stakeholder stakes must sum to 10000 (this represents 100%)'
      );
    }
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

    return
      IBusinessLogic(businessLogicAddress).checkMintAllowed(
        _dropStart,
        _dropEnd,
        minter,
        nft.price,
        msgValue,
        nft.minMembershipTier
      );
  }

  function mint(string memory nftId) public payable override nonReentrant {
    uint256 msgValue = msg.value;
    Stakeholder[] storage stakeholders = _primaryStakeholders[nftId];

    string memory err = canMintNft(nftId, msg.sender, msgValue);
    require(isEmptyString(err), err);

    uint256 totalWei = msgValue;

    Nft storage nft = _getNft(nftId);

    uint256 editionNumber = nft.numMinted.current() + 1;
    uint256 tokenId = nft.firstTokenId + nft.numMinted.current();

    for (uint256 i = 0; i < stakeholders.length; i++) {
      address toAddress = stakeholders[i].wallet;
      //Here is to save some gas, we can sum the artpool change + artpool stake earning and make a single transfer
      if (toAddress == _artpoolWallet) {
        continue;
      }

      uint256 weiToTransfer = computeStake(stakeholders[i].stake, msgValue);
      totalWei -= weiToTransfer;
      if (weiToTransfer > 0) {
        _mintingTransfer(
          nftId,
          editionNumber,
          tokenId,
          toAddress,
          weiToTransfer
        );
      }
    }
    _mintingTransfer(nftId, editionNumber, tokenId, _artpoolWallet, totalWei);
    _mintToken(nftId, msg.sender);
  }

  function setBusinessLogicAddress(address add) public onlyOwner {
    require(
      add != address(0),
      'Business logic address cannot be the zero address'
    );
    businessLogicAddress = add;
  }
}
