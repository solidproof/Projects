//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FraktalNFT.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract FraktalMarket is
Initializable,
OwnableUpgradeable,
ReentrancyGuardUpgradeable,
ERC1155Holder
{
  uint16 public fee;
  uint256 public listingFee;
  uint256 private feesAccrued;
  struct Proposal {
    uint256 value;
    bool winner;
  }
  struct Listing {
    address tokenAddress;
    uint256 price;
    uint256 numberOfShares;
  }
  struct AuctionListing {
    address tokenAddress;
    uint256 reservePrice;
    uint256 numberOfShares;
    uint256 auctionEndTime;
  }
  mapping(address => mapping(address => Listing)) listings;

  mapping(address => mapping(address => mapping(uint256 => AuctionListing))) public auctionListings;
  mapping(address => uint256) public auctionNonce;
  mapping(address => mapping(uint256 => uint256)) public auctionReserve;
  mapping(address => mapping(uint256 => bool)) public auctionSellerRedeemed;
  //use below mapping as like this: participantContribution[auctioneer][sellerNonce][participant]
  mapping(address => mapping(uint256 => mapping(address => uint256))) public participantContribution;

  mapping(address => mapping(address => Proposal)) public offers;
  mapping(address => uint256) public sellersBalance;
  mapping(address => uint256) public maxPriceRegistered;

  event Bought(
    address buyer,
    address seller,
    address tokenAddress,
    uint256 numberOfShares
  );
  event FeeUpdated(uint16 newFee);
  event ListingFeeUpdated(uint256 newFee);
  event ItemListed(
    address owner,
    address tokenAddress,
    uint256 price,
    uint256 amountOfShares
  );
  event AuctionItemListed(
    address owner,
    address tokenAddress,
    uint256 reservePrice,
    uint256 amountOfShares,
    uint256 endTime,
    uint256 nonce
  );
  event AuctionContribute(
    address participant,
    address tokenAddress,
    address seller,
    uint256 sellerNonce,
    uint256 value
  );
  event FraktalClaimed(address owner, address tokenAddress);
  event SellerPaymentPull(address seller, uint256 balance);
  event AdminWithdrawFees(uint256 feesAccrued);
  event OfferMade(address offerer, address tokenAddress, uint256 value);
  event OfferVoted(address voter, address offerer, address tokenAddress, bool sold);


  function initialize() public initializer {
    __Ownable_init();
    fee = 500; //5%
  }

  // Admin Functions
  //////////////////////////////////
  function setFee(uint16 _newFee) external onlyOwner {
    require(_newFee >= 0);
    require(_newFee < 10000);
    fee = _newFee;
    emit FeeUpdated(_newFee);
  }

  function setListingFee(uint256 _newListingFee) external onlyOwner {
    require(_newListingFee >= 0);
    require(_newListingFee < 10000);
    listingFee = _newListingFee;
    emit ListingFeeUpdated(_newListingFee);
  }

  function withdrawAccruedFees()
    external
    onlyOwner
    nonReentrant
    returns (bool)
  {
    address payable wallet = payable(_msgSender());
    uint256 bufferedFees = feesAccrued;
    feesAccrued = 0;
    AddressUpgradeable.sendValue(wallet, bufferedFees);
    emit AdminWithdrawFees(bufferedFees);
    return true;
  }

  // Users Functions
  //////////////////////////////////
  function rescueEth() external nonReentrant {
    require(sellersBalance[_msgSender()] > 0, "No claimed ETH");
    address payable seller = payable(_msgSender());
    uint256 balance = sellersBalance[_msgSender()];
    sellersBalance[_msgSender()] = 0;
    AddressUpgradeable.sendValue(seller, balance);
    emit SellerPaymentPull(_msgSender(), balance);
  }

  function redeemAuctionSeller(
    address _tokenAddress,
    address _seller,
    uint256 _sellerNonce
    ) external nonReentrant {
    require(_seller == _msgSender());
    require(!auctionSellerRedeemed[_seller][_sellerNonce]);//is seller already claim?
    AuctionListing storage auctionListed = auctionListings[_tokenAddress][_msgSender()][_sellerNonce];
    require(block.timestamp >= auctionListed.auctionEndTime);//is auction ended?
    uint256 _auctionReserve = auctionReserve[_seller][_sellerNonce];
    //auction successful
    //give eth minus fee to seller
    if(_auctionReserve>=auctionListed.reservePrice){
      uint256 totalForSeller = _auctionReserve - ((_auctionReserve * fee) / 10000);
      feesAccrued += _auctionReserve - totalForSeller;

      (bool sent,) = _msgSender().call{value: totalForSeller}("");
      auctionSellerRedeemed[_seller][_sellerNonce] = true;
      require(sent);//check if ether failed to send
    }

    //auction failed
    else{
      auctionSellerRedeemed[_seller][_sellerNonce] = true;
      
      FraktalNFT(_tokenAddress).safeTransferFrom(
      address(this),
      _msgSender(),
      FraktalNFT(_tokenAddress).fraktionsIndex(),
      auctionListed.numberOfShares,
      ""
      );
    }

  }

  function redeemAuctionParticipant(
    address _tokenAddress,
    address _seller,
    uint256 _sellerNonce
  ) external nonReentrant {
    AuctionListing storage auctionListing = auctionListings[_tokenAddress][_seller][_sellerNonce];
    require(block.timestamp >= auctionListing.auctionEndTime);//is auction ended?
    require(auctionListing.auctionEndTime>0);//is auction exist?
    uint256 _auctionReserve = auctionReserve[_seller][_sellerNonce];
    uint256 fraktionsIndex = FraktalNFT(_tokenAddress).fraktionsIndex();
    //auction successful
    //give participant fraktions according to their contribution
    if(_auctionReserve>=auctionListing.reservePrice){
      uint256 auctionFraks = auctionListing.numberOfShares;
      uint256 _participantContribution = participantContribution[_seller][_sellerNonce][_msgSender()];
      uint256 eligibleFrak = (_participantContribution * auctionFraks) / _auctionReserve;
      participantContribution[_seller][_sellerNonce][_msgSender()] = 0;

      FraktalNFT(_tokenAddress).safeTransferFrom(
      address(this),
      _msgSender(),
      fraktionsIndex,
      eligibleFrak,
      ""
      );
    }

    //auction failed
    //give back contributed eth to participant
    else{
      uint256 _contributed = participantContribution[_seller][_sellerNonce][_msgSender()];
      participantContribution[_seller][_sellerNonce][_msgSender()] = 0;

      (bool sent,) = _msgSender().call{value: _contributed}("");
      require(sent);//check if ether failed to send
    }

  }

  function importFraktal(address tokenAddress, uint256 fraktionsIndex)
    external
  {
    FraktalNFT(tokenAddress).safeTransferFrom(
      _msgSender(),
      address(this),
      0,
      1,
      ""
    );
    FraktalNFT(tokenAddress).fraktionalize(_msgSender(), fraktionsIndex);
    FraktalNFT(tokenAddress).lockSharesTransfer(
      _msgSender(),
      10000*10**18,
      address(this)
    );
    FraktalNFT(tokenAddress).unlockSharesTransfer(_msgSender(), address(this));
  }

  function buyFraktions(
    address from,
    address tokenAddress,
    uint256 _numberOfShares
  ) external payable nonReentrant {
    Listing storage listing = listings[tokenAddress][from];
    require(!FraktalNFT(tokenAddress).sold(), "item sold");
    require(
      listing.numberOfShares >= _numberOfShares
    );//"Not enough Fraktions on sale"
    uint256 buyPrice = (listing.price * _numberOfShares)/(10**18);
    require(buyPrice!=0);
    uint256 totalFees = (buyPrice * fee) / 10000;
    uint256 totalForSeller = buyPrice - totalFees;
    uint256 fraktionsIndex = FraktalNFT(tokenAddress).fraktionsIndex();
    require(msg.value >= buyPrice);//"FraktalMarket: insufficient funds"
    listing.numberOfShares = listing.numberOfShares - _numberOfShares;
    if (listing.price * 10000 > maxPriceRegistered[tokenAddress]) {
      maxPriceRegistered[tokenAddress] = listing.price * 10000;
    }
    feesAccrued += msg.value - totalForSeller;
    sellersBalance[from] += totalForSeller;
    FraktalNFT(tokenAddress).safeTransferFrom(
      from,
      _msgSender(),
      fraktionsIndex,
      _numberOfShares,
      ""
    );
    emit Bought(_msgSender(), from, tokenAddress, _numberOfShares);
  }

  function participateAuction(
    address tokenAddress,
    address seller,
    uint256 sellerNonce
  ) external payable nonReentrant {
    AuctionListing storage auctionListing = auctionListings[tokenAddress][seller][sellerNonce];
    require(block.timestamp < auctionListing.auctionEndTime);//is auction still ongoing?
    require(auctionListing.auctionEndTime>0);//is auction exist?
    uint256 contribution = msg.value;
    require(contribution>0);//need eth to participate


    //note of Eth contribution to auction reserve and participant
    auctionReserve[seller][sellerNonce] += msg.value;
    participantContribution[seller][sellerNonce][_msgSender()] += contribution;
    emit AuctionContribute(_msgSender(), tokenAddress, seller, sellerNonce, contribution);
  }

  function listItem(
    address _tokenAddress,
    uint256 _price,//wei per frak
    uint256 _numberOfShares
  ) payable external returns (bool) {
    require(msg.value >= listingFee);
    require(_price>0);
    uint256 fraktionsIndex = FraktalNFT(_tokenAddress).fraktionsIndex();
    require(
      FraktalNFT(_tokenAddress).balanceOf(address(this), 0) == 1
    );// "nft not in market"
    require(!FraktalNFT(_tokenAddress).sold());//"item sold"
    require(
      FraktalNFT(_tokenAddress).balanceOf(_msgSender(), fraktionsIndex) >=
        _numberOfShares
    );//"no valid Fraktions"
    Listing memory listed = listings[_tokenAddress][_msgSender()];
    require(listed.numberOfShares == 0);//"unlist first"
    Listing memory listing = Listing({
      tokenAddress: _tokenAddress,
      price: _price,
      numberOfShares: _numberOfShares
    });
    listings[_tokenAddress][_msgSender()] = listing;
    emit ItemListed(_msgSender(), _tokenAddress, _price, _numberOfShares);
    return true;
  }

  function listItemAuction(
    address _tokenAddress,
    uint256 _reservePrice,
    uint256 _numberOfShares
  ) payable external returns (uint256) {
    require(msg.value >= listingFee);
    uint256 fraktionsIndex = FraktalNFT(_tokenAddress).fraktionsIndex();
    require(
      FraktalNFT(_tokenAddress).balanceOf(address(this), 0) == 1
    );//"nft not in market"
    require(!FraktalNFT(_tokenAddress).sold());// "item sold"
    require(
      FraktalNFT(_tokenAddress).balanceOf(_msgSender(), fraktionsIndex) >=
        _numberOfShares
    );//"no valid Fraktions"
    require(_reservePrice>0);
    uint256 sellerNonce = auctionNonce[_msgSender()]++;

    uint256 _endTime = block.timestamp + (10 days);

    auctionListings[_tokenAddress][_msgSender()][sellerNonce] = AuctionListing({
      tokenAddress: _tokenAddress,
      reservePrice: _reservePrice,
      numberOfShares: _numberOfShares,
      auctionEndTime: _endTime
    });

    FraktalNFT(_tokenAddress).safeTransferFrom(
      _msgSender(),
      address(this),
      fraktionsIndex,
      _numberOfShares,
      ""
    );
    emit AuctionItemListed(_msgSender(), _tokenAddress, _reservePrice, _numberOfShares, _endTime, sellerNonce);
    return auctionNonce[_msgSender()];
  }

  function exportFraktal(address tokenAddress) public {
    uint256 fraktionsIndex = FraktalNFT(tokenAddress).fraktionsIndex();
    FraktalNFT(tokenAddress).safeTransferFrom(_msgSender(), address(this), fraktionsIndex, 10000*10**18, '');
    FraktalNFT(tokenAddress).defraktionalize();
    FraktalNFT(tokenAddress).safeTransferFrom(address(this), _msgSender(), 0, 1, '');
  }

  function makeOffer(address tokenAddress, uint256 _value) public payable {
    require(msg.value >= _value);//"No pay"
    Proposal storage prop = offers[_msgSender()][tokenAddress];
    address payable offerer = payable(_msgSender());
    require(!prop.winner);// "offer accepted"
    if (_value >= prop.value) {
      require(_value >= maxPriceRegistered[tokenAddress], "Min offer");
      require(msg.value >= _value - prop.value);
    } else {
      uint256 bufferedValue = prop.value;
      prop.value = 0;
      AddressUpgradeable.sendValue(offerer, bufferedValue);
    }
    offers[_msgSender()][tokenAddress] = Proposal({
      value: _value,
      winner: false
    });
    emit OfferMade(_msgSender(), tokenAddress, _value);
  }

  function rejectOffer(address from, address to, address tokenAddress) external {
      FraktalNFT(tokenAddress).unlockSharesTransfer(
      from,
      to
    );
  }

  function voteOffer(address offerer, address tokenAddress) external {
    uint256 fraktionsIndex = FraktalNFT(tokenAddress).fraktionsIndex();
    Proposal storage offer = offers[offerer][tokenAddress];
    uint256 lockedShares = FraktalNFT(tokenAddress).lockedShares(fraktionsIndex,_msgSender());
    uint256 votesAvailable = FraktalNFT(tokenAddress).balanceOf(
      _msgSender(),
      fraktionsIndex
    ) - lockedShares;
    FraktalNFT(tokenAddress).lockSharesTransfer(
      _msgSender(),
      votesAvailable,
      offerer
    );
    uint256 lockedToOfferer = FraktalNFT(tokenAddress).lockedToTotal(fraktionsIndex,offerer);
    bool sold = false;
    if (lockedToOfferer > FraktalNFT(tokenAddress).majority()) {
      FraktalNFT(tokenAddress).sellItem();
      offer.winner = true;
      sold = true;
    }
    emit OfferVoted(_msgSender(), offerer, tokenAddress, sold);
  }

  function claimFraktal(address tokenAddress) external {
    uint256 fraktionsIndex = FraktalNFT(tokenAddress).fraktionsIndex();
    if (FraktalNFT(tokenAddress).sold()) {
      Proposal memory offer = offers[_msgSender()][tokenAddress];
      require(
        FraktalNFT(tokenAddress).lockedToTotal(fraktionsIndex,_msgSender())
         > FraktalNFT(tokenAddress).majority(),
        "not buyer"
      );
      FraktalNFT(tokenAddress).createRevenuePayment{ value: offer.value }(address(this));
      maxPriceRegistered[tokenAddress] = 0;
    }
    FraktalNFT(tokenAddress).safeTransferFrom(
      address(this),
      _msgSender(),
      0,
      1,
      ""
    );
    emit FraktalClaimed(_msgSender(), tokenAddress);
  }

  function unlistItem(address tokenAddress) external {
    delete listings[tokenAddress][_msgSender()];
    emit ItemListed(_msgSender(), tokenAddress, 0, 0);
  }

  function unlistAuctionItem(address tokenAddress,uint256 sellerNonce) external {
    AuctionListing storage auctionListed = auctionListings[tokenAddress][_msgSender()][sellerNonce];
    require(auctionListed.auctionEndTime>0);

    auctionListed.auctionEndTime = block.timestamp;

    emit AuctionItemListed(_msgSender(), tokenAddress, 0, 0, auctionListed.auctionEndTime,sellerNonce);
  }

  // GETTERS
  //////////////////////////////////
  function getFee() external view returns (uint256) {
    return (fee);
  }

  function getListingPrice(address _listOwner, address tokenAddress)
    external
    view
    returns (uint256)
  {
    return listings[tokenAddress][_listOwner].price;
  }

  function getListingAmount(address _listOwner, address tokenAddress)
    external
    view
    returns (uint256)
  {
    return listings[tokenAddress][_listOwner].numberOfShares;
  }

  function getSellerBalance(address _who) external view returns (uint256) {
    return (sellersBalance[_who]);
  }

  function getOffer(address offerer, address tokenAddress)
    external
    view
    returns (uint256)
  {
    return (offers[offerer][tokenAddress].value);
  }
  fallback() external payable {
      feesAccrued += msg.value;
  }
  
  receive() external payable {
      feesAccrued += msg.value;
  }
}
