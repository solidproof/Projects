// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ReentrancyGuard.sol";
import "./interfaces/IMarket.sol";
import "./Crypto528.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract IMediaModified {
    mapping(uint256 => address) public tokenCreators;
    address public marketContract;
}

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);
}

contract Crypto528Marketplace is ReentrancyGuard, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Use OpenZeppelin's SafeMath library to prevent overflows.
    using SafeMath for uint256;

    // ============ Constants ============

    // The minimum amount of time left in an auction after a new bid is created; 15 min.
    uint16 public constant TIME_BUFFER = 900;
    // The ETH needed above the current bid for a new bid to be valid; 0.001 ETH.
    uint8 public constant MIN_BID_INCREMENT_PERCENT = 10;
    // Interface constant for ERC721, to check values in constructor.
    bytes4 private constant ERC721_INTERFACE_ID = 0x80ac58cd;
    // Allows external read `getVersion()` to return a version for the auction.
    uint256 private constant RESERVE_AUCTION_VERSION = 1;
    uint256 public MAX_LIMIT = 528;

    uint256 public marketFeeForETH = 75;
    uint256 public marketFeeForToken = 50;

    // ============ Immutable Storage ============

    // The address of the ERC721 contract for tokens auctioned via this contract.
    address public immutable nftContract;
    // The address of the WETH contract, so that ETH can be transferred via
    // WETH if native ETH transfers fail.
    address public immutable WETHAddress;
    // The address that initially is able to recover assets.
    address public immutable adminRecoveryAddress;

    bool private _adminRecoveryEnabled;

    bool private _paused;

    mapping (uint256 => uint256) public price;
    mapping (uint256 => bool) public listedMap;
    // A mapping of all of the auctions currently running.
    mapping(uint256 => Auction) public auctions;
    mapping (uint256 => address) public ownerMap;
    mapping (string => address) public tokenAddressMap;
    mapping(uint256 => string) public paymentTokenMap;
    mapping (uint256 => uint256) public levelMap;

    uint256[] public levelETHPrices = [5 ether/100, 25 ether/100, 50 ether/100, 250 ether/100, 5 ether, 10 ether, 20 ether, 50 ether];
    uint256[] public levelPrices = [50000000, 250000000, 500000000, 2500000000, 5000000000, 10000000000, 20000000000, 20000000000];
    uint256[] public soldoutLimits = [17, 225, 200, 40, 20, 5, 2, 1];
    uint256[] public levelCounter = [0, 0, 0, 0, 0, 0, 0, 0];

    // ============ Structs ============

    struct Auction {
        // The value of the current highest bid.
        uint256 amount;
        // The amount of time that the auction should run for,
        // after the first bid was made.
        uint256 duration;
        // The time of the first bid.
        uint256 firstBidTime;
        // The minimum price of the first bid.
        uint256 reservePrice;
        string paymentType;

        uint8 CreatorFeePercent;
        // The address of the auction's Creator. The Creator
        // can cancel the auction if it hasn't had a bid yet.
        address Creator;
        // The address of the current highest bid.
        address payable bidder;
        // The address that should receive funds once the NFT is sold.
        address payable fundsRecipient;
    }

    // ============ Events ============

    // All of the details of a new auction,
    // with an index created for the tokenId.
    event AuctionCreated(
        uint256 indexed tokenId,
        uint256 auctionStart,
        uint256 duration,
        uint256 reservePrice,
        string paymentType,
        address Creator
    );

    // All of the details of a new bid,
    // with an index created for the tokenId.
    event AuctionBid(
        uint256 indexed tokenId,
        address nftContractAddress,
        address sender,
        uint256 value
    );

    // All of the details of an auction's cancelation,
    // with an index created for the tokenId.
    event AuctionCanceled(
        uint256 indexed tokenId,
        address nftContractAddress,
        address Creator
    );

    // All of the details of an auction's close,
    // with an index created for the tokenId.
    event AuctionEnded(
        uint256 indexed tokenId,
        address nftContractAddress,
        address Creator,
        address winner,
        uint256 amount
    );

    // When the Creator recevies fees, emit the details including the amount,
    // with an index created for the tokenId.
    event CreatorFeePercentTransfer(
        uint256 indexed tokenId,
        address Creator,
        uint256 amount
    );

    // Emitted in the case that the contract is paused.
    event Paused(address account);
    // Emitted when the contract is unpaused.
    event Unpaused(address account);
    event Purchase(address indexed previousOwner, address indexed newOwner, uint256 price, uint nftID);
    event Minted(address indexed minter, uint256 price, string currencyType, uint nftID, string uri, bool status);
    event Burned(uint nftID);
    event PriceUpdate(address indexed owner, uint256 oldPrice, uint256 newPrice, uint nftID);
    event NftListStatus(address indexed owner, uint nftID, bool isListed);
    event Withdrawn(uint256 amount, address wallet);
    event TokensWithdrawn(uint256 amount, address wallet);
    event Received(address, uint);
    event Giveaway(address indexed sender, address indexed receiver, uint256 tokenId);

    // ============ Modifiers ============

    // Reverts if the sender is not admin, or admin
    // functionality has been turned off.
    modifier onlyAdminRecovery() {
        require(
            // The sender must be the admin address, and
            // adminRecovery must be set to true.
            adminRecoveryAddress == msg.sender && adminRecoveryEnabled(),
            "Caller does not have admin privileges"
        );
        _;
    }

    // Reverts if the sender is not the auction's Creator.
    modifier onlyCreator(uint256 tokenId) {
        require(
            auctions[tokenId].Creator == msg.sender,
            "Can only be called by auction Creator"
        );
        _;
    }

    // Reverts if the sender is not the auction's Creator or winner.
    modifier onlyCreatorOrWinner(uint256 tokenId) {
        require(
            auctions[tokenId].Creator == msg.sender || auctions[tokenId].bidder == msg.sender,
            "Can only be called by auction Creator"
        );
        _;
    }

    // Reverts if the contract is paused.
    modifier whenNotPaused() {
        require(!paused(), "Contract is paused");
        _;
    }

    // Reverts if the auction does not exist.
    modifier auctionExists(uint256 tokenId) {
        // The auction exists if the Creator is not null.
        require(!auctionCreatorIsNull(tokenId), "Auction doesn't exist");
        _;
    }

    // Reverts if the auction exists.
    modifier auctionNonExistant(uint256 tokenId) {
        // The auction does not exist if the Creator is null.
        require(auctionCreatorIsNull(tokenId), "Auction already exists");
        _;
    }

    // Reverts if the auction is expired.
    modifier auctionNotExpired(uint256 tokenId) {
        require(
            // Auction is not expired if there's never been a bid, or if the
            // current time is less than the time at which the auction ends.
            auctions[tokenId].firstBidTime == 0 ||
                block.timestamp < auctionEnds(tokenId),
            "Auction expired"
        );
        _;
    }

    // Reverts if the auction is not complete.
    // Auction is complete if there was a bid, and the time has run out.
    modifier auctionComplete(uint256 tokenId) {
        require(
            // Auction is complete if there has been a bid, and the current time
            // is greater than the auction's end time.
            auctions[tokenId].firstBidTime > 0 &&
                block.timestamp >= auctionEnds(tokenId),
            "Auction hasn't completed"
        );
        _;
    }

    // ============ Constructor ============

    constructor(
        address nftContract_,
        address WETHAddress_,
        address adminRecoveryAddress_,
        address USDCTokenAddress_,
        address USDTTokenAddress_
    ) {
        require(
            IERC165(nftContract_).supportsInterface(ERC721_INTERFACE_ID),
            "Contract at nftContract_ address does not support NFT interface"
        );
        // Initialize immutable memory.
        nftContract = nftContract_;
        WETHAddress = WETHAddress_;
        adminRecoveryAddress = adminRecoveryAddress_;
        tokenAddressMap["USDC"] = USDCTokenAddress_; // address(0x1e2FbB76c8dAf5a0a8F91388BAc09511F3d7AC62); // 0x1e2fbb76c8daf5a0a8f91388bac09511f3d7ac62
        tokenAddressMap["USDT"] = USDTTokenAddress_; // address(0x1e2FbB76c8dAf5a0a8F91388BAc09511F3d7AC62); // 0x1e2fbb76c8daf5a0a8f91388bac09511f3d7ac62
        // Initialize mutable memory.
        _paused = false;
        _adminRecoveryEnabled = true;
    }

    function openTrade(uint256 _id, uint256 _price, string memory paymentType)
    public
    {
        require(ownerMap[_id] == msg.sender, "sender is not owner");
        require(listedMap[_id] == false, "Already opened");
        require(_price >= price[_id], "Price is lower than the current price");
        Crypto528(nftContract).approve(address(this), _id);
        Crypto528(nftContract).transferFrom(msg.sender, address(this), _id);
        listedMap[_id] = true;
        price[_id] = _price;
        paymentTokenMap[_id] = paymentType;
    }

    function closeTrade(uint256 _id)
    external
    {
        require(ownerMap[_id] == msg.sender, "sender is not owner");
        require(listedMap[_id] == true, "Already colsed");
        Crypto528(nftContract).transferFrom(address(this), msg.sender, _id);
        listedMap[_id] = false;
        if(auctions[_id].Creator == msg.sender) {
            delete auctions[_id];
        }
    }
    function giveaway (
        address _to,
        uint256 _level,
        uint256 _tokenId,
        string memory paymentType,
        string memory _tokenUri) external onlyAdminRecovery {

        _tokenIds.increment();
        levelCounter[_level] = levelCounter[_level] + 1;
        require(levelCounter[_level] <= soldoutLimits[_level], "This Level is sold out");
        uint256 newTokenId = _tokenIds.current();
        require(newTokenId <= MAX_LIMIT, "Cannot mint over Max Limit!");
        paymentTokenMap[_tokenId] = paymentType;
        if (keccak256(abi.encodePacked((paymentType))) == keccak256(abi.encodePacked(("ETH")))) {
            price[_tokenId] = levelETHPrices[_level];
        } else {
            price[_tokenId] = levelPrices[_level];
        }
        levelMap[_tokenId] = _level;
        listedMap[_tokenId] = false;
        ownerMap[_tokenId] = _to;
        Crypto528(nftContract).mint(_tokenId, _to, _tokenUri);
        emit Minted(_to, price[_tokenId], paymentType, _tokenId, _tokenUri, false);
    }

    function mint(
        uint256 _level,
        uint256 _tokenId,
        string memory paymentType,
        string memory _tokenUri) external payable {

        // require(levelPrices[_level].exists, "Level does not exist.");

        _tokenIds.increment();

        levelCounter[_level] = levelCounter[_level] + 1;

        require(levelCounter[_level] <= soldoutLimits[_level], "This Level is sold out");

        uint256 newTokenId = _tokenIds.current();

        require(newTokenId <= MAX_LIMIT, "Cannot mint over Max Limit!");

        paymentTokenMap[_tokenId] = paymentType;
        levelMap[_tokenId] = _level;

        if (keccak256(abi.encodePacked((paymentType))) == keccak256(abi.encodePacked(("ETH")))) {
            price[_tokenId] = levelETHPrices[_level];
            require (msg.value >= price[_tokenId], "msg.value should be equal to the buyAmount");
            transferETHOrWETH(payable(adminRecoveryAddress), price[_tokenId]);
        } else {
            price[_tokenId] = levelPrices[_level];
            require (IERC20(tokenAddressMap[paymentType]).balanceOf(msg.sender) >= price[_tokenId], "token balance should be greater than the buyAmount");
            require (IERC20(tokenAddressMap[paymentType]).transferFrom(msg.sender, adminRecoveryAddress, price[_tokenId]));
        }

        listedMap[_tokenId] = false;
        ownerMap[_tokenId] = msg.sender;
        Crypto528(nftContract).mint(_tokenId, msg.sender, _tokenUri);
        emit Minted(msg.sender, price[_tokenId], paymentType, _tokenId, _tokenUri, false);
    }

    function buy(uint256 _id, uint256 _price, string memory paymentType) external payable {

        _validate(_id);
        require(price[_id]>=_price, "Error, price is not match");
        require(keccak256(abi.encodePacked((paymentType))) == keccak256(abi.encodePacked((paymentTokenMap[_id]))), "Error, Payment Type is not match");
        address _previousOwner = ownerMap[_id];

        // 5% commission cut
        // _owner.transfer(_owner, _sellerValue);
        if (keccak256(abi.encodePacked((paymentType))) == keccak256(abi.encodePacked(("ETH")))) {
            require (msg.value >= price[_id], "msg.value should be equal to the buyAmount");
            uint256 _commissionValue = price[_id].mul(marketFeeForETH).div(1000);
            uint256 _sellerValue = price[_id].sub(_commissionValue);
            transferETHOrWETH(payable(ownerMap[_id]), _sellerValue);
            transferETHOrWETH(payable(adminRecoveryAddress), _commissionValue);
        } else {
            require (IERC20(tokenAddressMap[paymentType]).balanceOf(msg.sender) >= price[_id], "token balance should be greater than the buyAmount");
            uint256 _commissionValue = price[_id].mul(marketFeeForToken).div(1000);
            uint256 _sellerValue = price[_id].sub(_commissionValue);
            require(IERC20(tokenAddressMap[paymentType]).transferFrom(msg.sender, ownerMap[_id], _sellerValue));
            require(IERC20(tokenAddressMap[paymentType]).transferFrom(msg.sender, adminRecoveryAddress, _commissionValue));
        }
        Crypto528(nftContract).transferFrom(address(this), msg.sender, _id);
        ownerMap[_id] = msg.sender;
        listedMap[_id] = false;
        emit Purchase(_previousOwner, msg.sender, price[_id], _id);
    }

    function _validate(uint256 _id) internal view {
        bool isItemListed = listedMap[_id];
        require(isItemListed, "Item not listed currently");
        require(msg.sender != Crypto528(nftContract).ownerOf(_id), "Can not buy what you own");
        // require(address(msg.sender).balance >= price[_id], "Error, the amount is lower");
    }

    function updatePrice(uint256 _tokenId, uint256 _price, string memory paymentType) public returns (bool) {
        uint oldPrice = price[_tokenId];
        require(msg.sender == ownerMap[_tokenId], "Error, you are not the owner");
        price[_tokenId] = _price;
        paymentTokenMap[_tokenId] = paymentType;

        emit PriceUpdate(msg.sender, oldPrice, _price, _tokenId);
        return true;
    }

    function updateListingStatus(uint256 _tokenId, bool shouldBeListed) public returns (bool) {
        require(msg.sender == Crypto528(nftContract).ownerOf(_tokenId), "Error, you are not the owner");
        listedMap[_tokenId] = shouldBeListed;
        emit NftListStatus(msg.sender, _tokenId, shouldBeListed);

        return true;
    }

    // ============ Create Auction ============

    function createAuction(
        uint256 tokenId,
        uint256 startDate,
        uint256 duration,
        uint256 reservePrice,
        string memory paymentType
    ) external nonReentrant whenNotPaused auctionNonExistant(tokenId) {
        // Check basic input requirements are reasonable.
        require(msg.sender != address(0));
        // Initialize the auction details, including null values.
        ownerMap[tokenId] = msg.sender;
        openTrade(tokenId, reservePrice, paymentType);

        // uint256 auctionStart = block.timestamp;

        auctions[tokenId] = Auction({
            duration: duration,
            reservePrice: reservePrice,
            paymentType: paymentType,
            CreatorFeePercent: 50,
            Creator: msg.sender,
            fundsRecipient: payable(adminRecoveryAddress),
            amount: 0,
            firstBidTime: startDate,
            bidder: payable(address(0))
        });

        // Transfer the NFT into this auction contract, from whoever owns it.

        // Emit an event describing the new auction.
        emit AuctionCreated(
            tokenId,
            startDate,
            duration,
            reservePrice,
            paymentType,
            msg.sender
        );
    }

    // ============ Create Bid ============

    function createBid(uint256 tokenId, string memory paymentType, uint256 amount)
        external
        payable
        nonReentrant
        whenNotPaused
        auctionExists(tokenId)
        auctionNotExpired(tokenId)
    {
        // Validate that the user's expected bid value matches the ETH deposit.
        require(amount > 0, "Amount must be greater than 0");

        require(keccak256(abi.encodePacked((paymentType))) == keccak256(abi.encodePacked((auctions[tokenId].paymentType))), "PaymentType is not mismatched");

        if (keccak256(abi.encodePacked((paymentType))) == keccak256(abi.encodePacked(("ETH")))) {
            require(amount == msg.value, "Amount doesn't equal msg.value");
        } else {
            require(amount >= IERC20(tokenAddressMap[paymentType]).balanceOf(msg.sender), "Insufficient token balance");
        }
        // Check if the current bid amount is 0.
        if (auctions[tokenId].amount == 0) {
            // If so, it is the first bid.
            // auctions[tokenId].firstBidTime = block.timestamp;
            // We only need to check if the bid matches reserve bid for the first bid,
            // since future checks will need to be higher than any previous bid.
            require(
                amount >= auctions[tokenId].reservePrice,
                "Must bid reservePrice or more"
            );
        } else {
            // Check that the new bid is sufficiently higher than the previous bid, by
            // the percentage defined as MIN_BID_INCREMENT_PERCENT.
            require(
                amount >=
                    auctions[tokenId].amount.add(
                        // Add 10% of the current bid to the current bid.
                        auctions[tokenId]
                            .amount
                            .mul(MIN_BID_INCREMENT_PERCENT)
                            .div(100)
                    ),
                "Must bid more than last bid by MIN_BID_INCREMENT_PERCENT amount"
            );


            // Refund the previous bidder.
            if (keccak256(abi.encodePacked((paymentType))) == keccak256(abi.encodePacked(("ETH")))) {
                transferETHOrWETH(
                    auctions[tokenId].bidder,
                    auctions[tokenId].amount
                );
            } else {
                require(IERC20(tokenAddressMap[paymentType]).transfer(auctions[tokenId].bidder, auctions[tokenId].amount));
            }

        }
        // Update the current auction.
        auctions[tokenId].amount = amount;
        auctions[tokenId].bidder = payable(msg.sender);
        // Compare the auction's end time with the current time plus the 15 minute extension,
        // to see whETHer we're near the auctions end and should extend the auction.
        if (auctionEnds(tokenId) < block.timestamp.add(TIME_BUFFER)) {
            // We add onto the duration whenever time increment is required, so
            // that the auctionEnds at the current time plus the buffer.
            auctions[tokenId].duration += block.timestamp.add(TIME_BUFFER).sub(
                auctionEnds(tokenId)
            );
        }
        // Emit the event that a bid has been made.
        emit AuctionBid(tokenId, nftContract, msg.sender, amount);
    }

    // ============ End Auction ============

    function endAuction(uint256 tokenId)
        external
        nonReentrant
        whenNotPaused
        auctionComplete(tokenId)
        onlyCreatorOrWinner(tokenId)
    {
        // Store relevant auction data in memory for the life of this function.
        address winner = auctions[tokenId].bidder;
        uint256 amount = auctions[tokenId].amount;
        address Creator = auctions[tokenId].Creator;
        string memory paymentType = auctions[tokenId].paymentType;
        // Remove all auction data for this token from storage.
        delete auctions[tokenId];
        // We don't use safeTransferFrom, to prevent reverts at this point,
        // which would break the auction.
        if(winner == address(0)) {
            Crypto528(nftContract).transferFrom(address(this), Creator, tokenId);
            ownerMap[tokenId] = Creator;
        } else {
            Crypto528(nftContract).transferFrom(address(this), winner, tokenId);
            if (keccak256(abi.encodePacked((paymentType))) == keccak256(abi.encodePacked(("ETH")))) {
                uint256 _commissionValue = amount.mul(marketFeeForETH).div(1000);
                transferETHOrWETH(payable(adminRecoveryAddress), _commissionValue);
                transferETHOrWETH(payable(Creator), amount.sub(_commissionValue));
            } else {
                uint256 _commissionValue = amount.mul(marketFeeForToken).div(1000);
                require(IERC20(tokenAddressMap[paymentType]).transfer(adminRecoveryAddress, _commissionValue));
                require(IERC20(tokenAddressMap[paymentType]).transfer(Creator, amount.sub(_commissionValue)));
            }

            ownerMap[tokenId] = winner;
        }
        listedMap[tokenId] = false;
        // Emit an event describing the end of the auction.
        emit AuctionEnded(
            tokenId,
            nftContract,
            Creator,
            winner,
            amount
        );
    }

    // ============ Cancel Auction ============

    function cancelAuction(uint256 tokenId)
        external
        nonReentrant
        auctionExists(tokenId)
        onlyCreator(tokenId)
    {
        // Check that there hasn't already been a bid for this NFT.
        require(
            uint256(auctions[tokenId].amount) == 0,
            "Auction already started"
        );
        // Pull the creator address before removing the auction.
        address Creator = auctions[tokenId].Creator;
        // Remove all data about the auction.
        delete auctions[tokenId];
        // Transfer the NFT back to the Creator.
        Crypto528(nftContract).transferFrom(address(this), Creator, tokenId);
        listedMap[tokenId] = false;
        ownerMap[tokenId] = Creator;
        // Emit an event describing that the auction has been canceled.
        emit AuctionCanceled(tokenId, nftContract, Creator);
    }

    // ============ Admin Functions ============

    // Irrevocably turns off admin recovery.
    function turnOffAdminRecovery() external onlyAdminRecovery {
        _adminRecoveryEnabled = false;
    }

    function pauseContract() external onlyAdminRecovery {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpauseContract() external onlyAdminRecovery {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    // Allows the admin to transfer any NFT from this contract
    // to the recovery address.
    function recoverNFT(uint256 tokenId) external onlyAdminRecovery {
        Crypto528(nftContract).transferFrom(
            // From the auction contract.
            address(this),
            // To the recovery account.
            adminRecoveryAddress,
            // For the specified token.
            tokenId
        );
    }

    // Allows the admin to transfer any ETH from this contract to the recovery address.
    function recoverETH(uint256 amount)
        external
        onlyAdminRecovery
        returns (bool success)
    {
        // Attempt an ETH transfer to the recovery account, and return true if it succeeds.
        success = attemptETHTransfer(payable(adminRecoveryAddress), amount);
    }

    // ============ Miscellaneous Public and External ============

    // Returns true if the contract is paused.
    function paused() public view returns (bool) {
        return _paused;
    }

    // Returns true if admin recovery is enabled.
    function adminRecoveryEnabled() public view returns (bool) {
        return _adminRecoveryEnabled;
    }

    // Returns the version of the deployed contract.
    function getVersion() external pure returns (uint256 version) {
        version = RESERVE_AUCTION_VERSION;
    }

    // ============ Private Functions ============

        // Will attempt to transfer ETH, but will transfer WETH instead if it fails.
    function transferETHOrWETH(address payable to, uint256 value) private {
        // Try to transfer ETH to the given recipient.
        if (!attemptETHTransfer(to, value)) {
            // If the transfer fails, wrap and send as WETH, so that
            // the auction is not impeded and the recipient still
            // can claim ETH via the WETH contract (similar to escrow).
            IWETH(WETHAddress).deposit{value: value}();
            IWETH(WETHAddress).transfer(to, value);
            // At this point, the recipient can unwrap WETH.
        }
    }

    // Sending ETH is not guaranteed complete, and the mETHod used here will return false if
    // it fails. For example, a contract can block ETH transfer, or might use
    // an excessive amount of gas, thereby griefing a new bidder.
    // We should limit the gas used in transfers, and handle failure cases.
    function attemptETHTransfer(address payable to, uint256 value)
        private
        returns (bool)
    {
        // Here increase the gas limit a reasonable amount above the default, and try
        // to send ETH to the recipient.
        // NOTE: This might allow the recipient to attempt a limited reentrancy attack.
        (bool success, ) = to.call{value: value, gas: 30000}("");
        return success;
    }

    // Returns true if the auction's Creator is set to the null address.
    function auctionCreatorIsNull(uint256 tokenId) private view returns (bool) {
        // The auction does not exist if the Creator is the null address,
        // since the NFT would not have been transferred in `createAuction`.
        return auctions[tokenId].Creator == address(0);
    }

    // Returns the timestamp at which an auction will finish.
    function auctionEnds(uint256 tokenId) private view returns (uint256) {
        // Derived by adding the auction's duration to the time of the first bid.
        // NOTE: duration can be extended conditionally after each new bid is added.
        return auctions[tokenId].firstBidTime.add(auctions[tokenId].duration);
    }

    /** ADMIN FUNCTION */

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
    function setTokenAddress(string memory _paymentToken, address _tokenAddress) public onlyOwner {
        tokenAddressMap[_paymentToken] = _tokenAddress;
    }

    function setMarketFeeForETH(uint256 _newMarketFeeForETH) external onlyOwner {
        require(_newMarketFeeForETH > 1, "Invalid MarketFee For ETH");
        marketFeeForETH = _newMarketFeeForETH;
    }

    function setMaxLimit(uint256 _maxLimit) external onlyOwner {
        require(_maxLimit > 528, "Should bigger than default");
        MAX_LIMIT = _maxLimit;
    }

    function setMarketFeeForToken(uint256 _newMarketFeeForToken) external onlyOwner {
        require(_newMarketFeeForToken > 1, "Invalid MarketFee For Token");
        marketFeeForToken = _newMarketFeeForToken;
    }
    function withdrawToken(string memory _tokenName, uint256 _amount) public onlyOwner {
        uint256 token_bal = IERC20(tokenAddressMap[_tokenName]).balanceOf(address(this)); //how much MST buyer has
        require(_amount <= token_bal, "Insufficient token balance to withdraw");
        require(IERC20(tokenAddressMap[_tokenName]).transfer(msg.sender, token_bal));
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}