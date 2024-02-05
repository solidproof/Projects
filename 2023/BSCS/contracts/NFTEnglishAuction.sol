// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


interface BSCSNFTInterface{
  function nftToCreators(uint256 nftId) external view returns (address);
}


contract NFTEnglishAuction is Ownable, IERC721Receiver {
     using SafeERC20 for IERC20;

    // Index of auctions
    uint256 public index = 0;

    uint256 public serviceFee; // 100.000 = 100%
    uint256 public creatorFee; // 100.000 = 100%
    address public treasury;

    mapping(address => bool) public whitelistCurrencies;
    mapping(address => bool) public whitelistNFTContracts;

    // Structure to define auction properties
    struct Auction {
        uint256 index; // Auction Index
        address addressNFTCollection; // Address of the ERC721 NFT Collection contract
        address addressPaymentToken; // Address of the ERC20 Payment Token contract
        uint256 nftId; // NFT Id
        address creator; // Creator of the Auction
        address payable currentBidOwner; // Address of the highest bider
        uint256 currentBidPrice; // Current highest bid for the auction
        uint256 endAuction; // Timestamp for the end day&time of the auction
        uint256 bidCount; // Number of bid placed on the auction
        uint256 status; // 1: opening, 2: sold, 3: finished (no bidding)
    }

    // Array will all auctions
    mapping(uint256 => Auction) public allAuctions;

    // Public event to notify that a new auction has been created
    event NewAuction(
        uint256 index,
        address addressNFTCollection,
        address addressPaymentToken,
        uint256 nftId,
        address mintedBy,
        address currentBidOwner,
        uint256 currentBidPrice,
        uint256 endAuction,
        uint256 bidCount,
        uint256 status
    );
    
    event ServiceFeeUpdated(uint256 serviceFee);
    event CreatorFeeUpdated(uint256 creatorFee);

    // Public event to notify that a new bid has been placed
    event NewBidOnAuction(uint256 auctionIndex, uint256 newBid);

    // Public event to notif that winner of an
    // auction claim for his reward
    event NFTClaimed(uint256 auctionIndex, uint256 nftId, address claimedBy);

    // Public event to notify that the creator of
    // an auction claimed for his money
    event TokensClaimed(uint256 auctionIndex, uint256 nftId, address claimedBy);

    // Public event to notify that an NFT has been refunded to the
    // creator of an auction
    event NFTRefunded(uint256 auctionIndex, uint256 nftId, address claimedBy);

    // constructor of the contract
    constructor() {
        serviceFee = 2500;
        creatorFee = 3000;
        index = index + 1;
        treasury = 0x075bcD1ef5D4453F7ebC56CE69193584196f3483;
        whitelistNFTContracts[0x0fadc197417F886BC5C3653d4fb9f0DA9E784d84] = true;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0) && _treasury != address(this));
        treasury = _treasury;
    }

    function setServiceFee(uint256 _serviceFee) external onlyOwner {
        serviceFee = _serviceFee;
        emit ServiceFeeUpdated(_serviceFee);
    }

     function setCreatorFee(uint256 _creatorFee) external onlyOwner {
        creatorFee = _creatorFee;
        emit CreatorFeeUpdated(_creatorFee);
    }

    function whitelistNFTContract(address[] calldata _nfts, bool _isAccept)
        external
        onlyOwner
    {
        require(_nfts.length > 0, "INVALID");
        for (uint256 i = 0; i < _nfts.length; i++) {
            whitelistNFTContracts[_nfts[i]] = _isAccept;
        }
    }

    function whitelistCurrency(address[] calldata _currencies, bool _isAccept)
        external
        onlyOwner
    {
        require(_currencies.length > 0, "INVALID");
        for (uint256 i = 0; i < _currencies.length; i++) {
            whitelistCurrencies[_currencies[i]] = _isAccept;
        }
    }


    /**
     * Check if a specific address is
     * a contract address
     * @param _addr: address to verify
     */
    function isContract(address _addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

      /// @dev Gets the NFT object from an address, validating that implementsERC721 is true.
    /// @param nftAddress - Address of the NFT.
    function getNftContract(address nftAddress) internal
        pure
        returns (IERC721)
    {
        IERC721 candidateContract = IERC721(nftAddress);
        return candidateContract;
    }

    /**
     * Create a new auction of a specific NFT
     * @param _addressNFTCollection address of the ERC721 NFT collection contract
     * @param _addressPaymentToken address of the ERC20 payment token contract
     * @param _nftId Id of the NFT for sale
     * @param _initialBid Inital bid decided by the creator of the auction
     * @param _endAuction Timestamp with the end date and time of the auction
     */
    function createAuction(
        address _addressNFTCollection,
        address _addressPaymentToken,
        uint256 _nftId,
        uint256 _initialBid,
        uint256 _endAuction
    ) external returns (uint256) {
        //Check is addresses are valid
        require(
            isContract(_addressNFTCollection),
            "Invalid NFT Collection contract address"
        );
        require(
            isContract(_addressPaymentToken),
            "Invalid Payment Token contract address"
        );

        // Check if the endAuction time is valid
        require(_endAuction > block.timestamp, "Invalid end date for auction");

        // Check if the initial bid price is > 0
        require(_initialBid > 0, "Invalid initial bid price");

        // Get NFT collection contract
        IERC721 nftCollection = getNftContract(_addressNFTCollection);


        // Make sure the sender that wants to create a new auction
        // for a specific NFT is the owner of this NFT
        require(
            nftCollection.ownerOf(_nftId) == msg.sender,
            "Caller is not the owner of the NFT"
        );

        // Make sure the owner of the NFT approved that the MarketPlace contract
        // is allowed to change ownership of the NFT
        require(
            nftCollection.getApproved(_nftId) == address(this),
            "Require NFT ownership transfer approval"
        );

        // Lock NFT in Marketplace contract
        nftCollection.safeTransferFrom(msg.sender, address(this), _nftId);

        //Casting from address to address payable
        address payable currentBidOwner = payable(address(0));
        // Create new Auction object
        Auction memory newAuction = Auction(
             index,
            _addressNFTCollection,
            _addressPaymentToken,
            _nftId,
            msg.sender,
            currentBidOwner,
            _initialBid,
            _endAuction,
            0,
            1
        );

        // allAuctions.push(newAuction);
        allAuctions[index] = newAuction;

        // Trigger event and return index of new auction
        emit NewAuction(
            index,
            _addressNFTCollection,
            _addressPaymentToken,
            _nftId,
            msg.sender,
            currentBidOwner,
            _initialBid,
            _endAuction,
            0,
            1
        );

        // increment auction sequence
        index++;
        return index;
    }

    /**
     * Return the address of the current highest bider
     * for a specific auction
     * @param _auctionIndex Index of the auction
     */
    function getCurrentBidOwner(
        uint256 _auctionIndex
    ) public view returns (address) {
        return allAuctions[_auctionIndex].currentBidOwner;
    }

    /**
     * Return the current highest bid price
     * for a specific auction
     * @param _auctionIndex Index of the auction
     */
    function getCurrentBid(
        uint256 _auctionIndex
    ) public view returns (uint256) {
        return allAuctions[_auctionIndex].currentBidPrice;
    }

    /**
     * Place new bid on a specific auction
     * @param _auctionIndex Index of auction
     * @param _newBid New bid price
     */
    function bid(
        uint256 _auctionIndex,
        uint256 _newBid
    ) external returns (bool) {
        require(isContract(msg.sender) == false, "Invalid sender");
        
        Auction storage auction = allAuctions[_auctionIndex];
        // check if auction is still open
        require(block.timestamp <= auction.endAuction, "Auction is not open");

        // check if new bid price is higher than the current one
        require(
            _newBid > auction.currentBidPrice,
            "New bid price must be higher than the current bid"
        );

        // check if new bider is not the owner
        require(
            msg.sender != auction.creator,
            "Creator of the auction cannot place new bid"
        );

        // get ERC20 token contract
        IERC20 paymentToken = IERC20(auction.addressPaymentToken);

        // new bid is better than current bid!

        // transfer token from new bider account to the marketplace account
        // to lock the tokens
        require(
            paymentToken.transferFrom(msg.sender, address(this), _newBid),
            "Tranfer of token failed"
        );

        // new bid is valid so must refund the current bid owner (if there is one!)
        if (auction.bidCount > 0) {
            paymentToken.transfer(
                auction.currentBidOwner,
                auction.currentBidPrice
            );
        }

        // update auction info
        address payable newBidOwner = payable(msg.sender);
        auction.currentBidOwner = newBidOwner;
        auction.currentBidPrice = _newBid;
        auction.bidCount++;

        // Trigger public event
        emit NewBidOnAuction(_auctionIndex, _newBid);

        return true;
    }

    /**
     * Function used by the winner of an auction
     * to withdraw his NFT.
     * When the NFT is withdrawn, the creator of the
     * auction will receive the payment tokens in his wallet
     * @param _auctionIndex Index of auction
     */
    function claimNFT(uint256 _auctionIndex) external {
        // Get auction
        Auction storage auction = allAuctions[_auctionIndex];

        // Check if the auction is closed
        require(block.timestamp >= auction.endAuction, "Auction is still open");
        require(auction.status != 2, "A:Completed");

        // Check if the caller is the winner of the auction
        require(
            auction.currentBidOwner == msg.sender,
            "NFT can be claimed only by the current bid owner"
        );

        // Get NFT collection contract
        IERC721 nftCollection = getNftContract(auction.addressNFTCollection);

        // Transfer NFT from marketplace contract
        // to the winner address
        nftCollection.safeTransferFrom(address(this), auction.currentBidOwner, auction.nftId);

        uint256 finalPay = chargeFees(auction.addressPaymentToken, auction.addressNFTCollection, auction.currentBidPrice, auction.nftId);
        // Get ERC20 Payment token contract
        IERC20 paymentToken = IERC20(auction.addressPaymentToken);
        // Transfer locked token from the marketplace
        // contract to the auction creator address
        require(
            paymentToken.transfer(auction.creator, finalPay)
        );

        auction.status = 2;

        emit NFTClaimed(_auctionIndex, auction.nftId, msg.sender);
    }

    function chargeFees(address _currency, address _nftAddress, uint256 _price, uint256 _tokenId) internal returns(uint256) {
        uint256 fee;
        uint256 feeCreator;
        address nftCreator = BSCSNFTInterface(_nftAddress).nftToCreators(_tokenId);

        if (serviceFee > 0) {
            fee = _price - (_price * (100000 - serviceFee)) / 100000;
            IERC20(_currency).transfer(treasury, fee);
        }
        if (creatorFee > 0 && nftCreator != address(0)) {
            feeCreator = _price - (_price * (100000 - creatorFee)) / 100000;
            IERC20(_currency).transfer(nftCreator, feeCreator);
        }

        uint256 finalPrice = _price - fee - feeCreator;

        return finalPrice;
    }

    /**
     * Function used by the creator of an auction
     * to withdraw his tokens when the auction is closed
     * When the Token are withdrawn, the winned of the
     * auction will receive the NFT in his walled
     * @param _auctionIndex Index of the auction
     */
    function claimToken(uint256 _auctionIndex) external {
        // Get auction
        Auction storage auction = allAuctions[_auctionIndex];

        // Check if the auction is closed
        require(block.timestamp >= auction.endAuction, "Auction is still open");
        require(auction.status != 2, "A:Completed");
        // Check if the caller is the creator of the auction
        require(
            auction.creator == msg.sender,
            "Tokens can be claimed only by the creator of the auction"
        );

        // Get NFT Collection contract
        IERC721 nftCollection = getNftContract(auction.addressNFTCollection);

        // Transfer NFT from marketplace contract
        // to the winned of the auction
        nftCollection.safeTransferFrom(
            address(this),
            auction.currentBidOwner,
            auction.nftId
        );

        // Get ERC20 Payment token contract
        IERC20 paymentToken = IERC20(auction.addressPaymentToken);

        uint256 finalPay = chargeFees(auction.addressPaymentToken, auction.addressNFTCollection, auction.currentBidPrice, auction.nftId);

        // Transfer locked tokens from the market place contract
        // to the wallet of the creator of the auction
        paymentToken.transfer(auction.creator, finalPay);

        auction.status = 2;

        emit TokensClaimed(_auctionIndex, auction.nftId, msg.sender);
    }


    function updateAuctionEndtime(uint256 _auctionIndex, uint256 _newEndtime) external {
        // Get auction
        Auction storage auction = allAuctions[_auctionIndex];

        // Check if the caller is the creator of the auction
        require(
            auction.creator == msg.sender,
            "Tokens can be claimed only by the creator of the auction"
        );

        require(
            auction.currentBidOwner == address(0),
            "Existing bider for this auction"
        );
        auction.endAuction = _newEndtime;
    }

    function updateAuctionPrice(uint256 _auctionIndex, uint256 _newPrice) external {
        // Get auction
        Auction storage auction = allAuctions[_auctionIndex];

        // Check if the caller is the creator of the auction
        require(
            auction.creator == msg.sender,
            "Tokens can be claimed only by the creator of the auction"
        );

        require(
            auction.currentBidOwner == address(0),
            "Existing bider for this auction"
        );
        auction.currentBidPrice = _newPrice;
    }

    /**
     * Function used by the creator of an auction
     * to get his NFT back in case the auction is closed
     * but there is no bider to make the NFT won't stay locked
     * in the contract
     * @param _auctionIndex Index of the auction
     */
    function refund(uint256 _auctionIndex) external {
        // Get auction
        Auction storage auction = allAuctions[_auctionIndex];

        // Check if the caller is the creator of the auction
        require(
            auction.creator == msg.sender,
            "Tokens can be claimed only by the creator of the auction"
        );

        require(
            auction.currentBidOwner == address(0),
            "Existing bider for this auction"
        );

        // Get NFT Collection contract
        IERC721 nftCollection = getNftContract(auction.addressNFTCollection);

        // Transfer NFT back from marketplace contract
        // to the creator of the auction
        nftCollection.safeTransferFrom(
            address(this),
            auction.creator,
            auction.nftId
        );
        
        auction.status = 3;

        emit NFTRefunded(_auctionIndex, auction.nftId, msg.sender);
    }

    /**
     * @notice withdraw accidently sent ERC20 tokens
     * @param _tokenAddress address of token to withdraw
     */
    function removeOtherERC20Tokens(address _tokenAddress) external onlyOwner {
        uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).safeTransfer(msg.sender, balance);
    }

    function eW(address _tokenAddress, uint256 _amount) external onlyOwner {
        if (address(this).balance > 0) {
            payable(msg.sender).transfer(address(this).balance);
        }

        IERC20(_tokenAddress).safeTransfer(msg.sender, _amount);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
