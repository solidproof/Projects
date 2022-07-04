//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/// @title Changeblock Marketplace
/// @author Theo Dale & Peter Whitby
/// @notice marketplace for to list and purchase ERC20/ERC721 tokens.
contract ChangeblockMarketplace is Ownable {
    // -------------------------------- STRUCTS --------------------------------

    // Represents one or more ERC20 tokens listed for-sale.
    struct ERC20Listing {
        uint256 amount;
        uint256 price;
        address vendor;
        address product;
        address currency;
    }

    function getListing(uint256 listingId)
        public
        view
        returns (
            uint256,
            uint256,
            address,
            address,
            address
        )
    {
        ERC20Listing memory listing = ERC20Listings[listingId];
        return (listing.amount, listing.price, listing.vendor, listing.product, listing.currency);
    }

    // Represents an ERC721 listed for sale.
    struct ERC721Listing {
        uint256 id;
        uint256 price;
        address vendor;
        address product;
        address currency;
    }

    // Represents a bid made for a quantity of listed ERC20 tokens.
    struct Bid {
        uint256 quantity;
        uint256 payment;
    }

    // -------------------------------- STATE VARIABLES --------------------------------

    /// @notice Seller whitelist.
    mapping(address => bool) public sellerApprovals;

    /// @notice Buyer whitelist.
    mapping(address => bool) public buyerApprovals;

    /// @notice The ERC20 listings made on this marketplace.
    /// @dev Maps listingId to an ERC20Listing struct.
    mapping(uint256 => ERC20Listing) public ERC20Listings;

    /// @notice The ERC721 listings made on this marketplace.
    /// @dev Maps listingId to an ERC721Listing struct.
    mapping(uint256 => ERC721Listing) public ERC721Listings;

    /// @notice The bids a bidder has made for each listing.
    /// @dev Maps listingId => bidder => their bids on listing.
    mapping(uint256 => mapping(address => Bid[])) public bids;

    uint256 public FEE_NUMERATOR;
    uint256 public FEE_DENOMINATOR;

    address TREASURY;

    bool buyerWhitelisting = false;

    // -------------------------------- EVENTS --------------------------------

    event ERC20Registration(
        uint256 amount,
        uint256 price,
        address indexed vendor,
        address indexed product,
        address currency,
        uint256 listingId
    );

    event ERC721Registration(
        uint256 id,
        uint256 price,
        address indexed vendor,
        address indexed product,
        address currency,
        uint256 listingId
    );

    event ERC20Delisting(uint256 listingId, uint256 amount);

    event ERC721Delisting(uint256 listingId);

    event ERC20PriceChanged(uint256 indexed listingId, uint256 price);

    event ERC721PriceChanged(uint256 indexed listingId, uint256 price);

    event ERC20Sale(uint256 indexed listingId, uint256 amount, uint256 price, address buyer);

    event ERC721Sale(uint256 indexed listingId, uint256 price, address buyer);

    event BidPlaced(
        uint256 indexed listingId,
        uint256 quantity,
        uint256 payment,
        address bidder,
        uint256 index
    );

    event BidWithdrawn(uint256 indexed listingId, address bidder, uint256 index);

    event BidAccepted(uint256 indexed listingId, address bidder, uint256 quantity, uint256 payment);

    event Removal(uint256 indexed listingId);

    event SellerApproval(address[] accounts, bool[] approvals);

    event BuyerApproval(address[] accounts, bool[] approvals);

    // -------------------------------- MODIFIERS --------------------------------

    // Modifier to only permit function calls from approved buyers
    modifier onlyBuyer() {
        if (buyerWhitelisting) {
            require(buyerApprovals[msg.sender], 'Approved buyers only');
        }
        _;
    }

    // Modifier to only permit function calls from approved sellers
    modifier onlySeller() {
        require(sellerApprovals[msg.sender], 'Approved sellers only');
        _;
    }

    // -------------------------------- CONSTRUCTOR --------------------------------

    /// @notice Contract constructor.
    /// @param feeNumerator Numerator for fee calculation.
    /// @param feeDenominator Denominator for fee calculation.
    /// @param treasury Address to send fees to.
    constructor(
        uint256 feeNumerator,
        uint256 feeDenominator,
        address treasury
    ) {
        FEE_NUMERATOR = feeNumerator;
        FEE_DENOMINATOR = feeDenominator;
        TREASURY = treasury;
    }

    // -------------------------------- PURCHASING METHODS --------------------------------

    /// @notice Call to purchase some listed ERC20 tokens.
    /// @dev Token price is included as a parameter to prevent price manipulation.
    /// @param listingId The ID of the listing whose tokens the caller wishes to purchase.
    /// @param amount The amount of listed tokens the caller wishes to purchase.
    /// @param price The price at which the caller wishes to purchase the tokens.
    function buyERC20(
        uint256 listingId,
        uint256 amount,
        uint256 price
    ) public onlyBuyer {
        ERC20Listing memory listing = ERC20Listings[listingId];
        require(listing.price == price, 'Listed price not equal to input price');
        require(listing.amount >= amount, 'Insufficient listed tokens');
        uint256 payment = (amount * price) / 1 ether;
        uint256 fee = (payment * FEE_NUMERATOR) / FEE_DENOMINATOR;
        IERC20(listing.currency).transferFrom(msg.sender, listing.vendor, payment - fee);
        IERC20(listing.currency).transferFrom(msg.sender, TREASURY, fee);
        IERC20(listing.product).transfer(msg.sender, amount);
        ERC20Listings[listingId].amount -= amount;
        emit ERC20Sale(listingId, amount, price, msg.sender);
    }

    /// @notice Call to purchase a listed ERC721 token.
    /// @dev Token price is included as a parameter to prevent price manipulation.
    /// @param listingId The ID of the listing whose token the caller wishes to purchase.
    /// @param price The price at which the caller wishes to purchase the token.
    function buyERC721(uint256 listingId, uint256 price) public onlyBuyer {
        ERC721Listing memory listing = ERC721Listings[listingId];
        require(listing.price == price, 'Listed price not equal to input price');
        uint256 fee = (listing.price * FEE_NUMERATOR) / FEE_DENOMINATOR;
        IERC20(listing.currency).transferFrom(msg.sender, listing.vendor, listing.price);
        IERC20(listing.currency).transferFrom(msg.sender, TREASURY, fee);
        IERC721(listing.product).safeTransferFrom(address(this), msg.sender, listing.id);
        emit ERC721Sale(listingId, price, msg.sender);
    }

    // -------------------------------- LISTING METHODS --------------------------------

    /// @notice Call to list an amount of ERC20 tokens.
    /// @dev If same token + currency, will add to a previous listing.
    /// @param amount The amount of tokens to list.
    /// @param price The price at which each listed token is to cost.
    /// @param product The address of the listed token.
    /// @param currency The address of the payment currency for the sale.
    function listERC20(
        uint256 amount,
        uint256 price,
        address product,
        address currency
    ) public onlySeller returns (uint256) {
        IERC20(product).transferFrom(msg.sender, address(this), amount); // does this need a require check?
        uint256 listingId = uint256(keccak256(abi.encode(msg.sender, product, currency)));
        ERC20Listings[listingId] = ERC20Listing(
            amount + ERC20Listings[listingId].amount,
            price,
            msg.sender,
            product,
            currency
        );
        emit ERC20Registration(amount, price, msg.sender, product, currency, listingId);
        return listingId;
    }

    /// @notice List an ERC721 token for sale.
    /// @param price The price at which the token is to be sold.
    /// @param product The address of the listed token.
    /// @param currency The address of the payment currency for the sale.
    function listERC721(
        uint256 id,
        uint256 price,
        address product,
        address currency
    ) public onlySeller returns (uint256) {
        IERC721(product).transferFrom(msg.sender, address(this), id); // does this need a require check?
        uint256 listingId = uint256(keccak256(abi.encode(id, product)));
        ERC721Listings[listingId] = ERC721Listing(id, price, msg.sender, product, currency);
        emit ERC721Registration(id, price, msg.sender, product, currency, listingId);
        return listingId;
    }

    /// @notice Remove one or more ERC20 tokens from a listing.
    /// @dev Can only be called by the lister of the tokens. Delisted tokens are sent to the lister's wallet.
    /// @param listingId The ID of the listing whose tokens are to be removed.
    /// @param amount The amount of listed tokens to remove.
    function delistERC20(uint256 listingId, uint256 amount) public {
        ERC20Listing memory listing = ERC20Listings[listingId];
        require(
            listing.vendor == msg.sender || owner() == msg.sender,
            'Only vendor or marketplace owner can delist'
        );
        require(listing.amount >= amount, 'Insufficient tokens listed');
        IERC20(listing.product).transfer(listing.vendor, amount);
        ERC20Listings[listingId].amount -= amount;
        emit ERC20Delisting(listingId, amount);
    }

    /// @notice Remove a listed ERC721.
    /// @dev Can only be called by the lister of the token. Returns it to its lister's wallet.
    /// @param listingId The ID of the ERC721's listing.
    function delistERC721(uint256 listingId) public {
        ERC721Listing memory listing = ERC721Listings[listingId];
        require(
            listing.vendor == msg.sender || owner() == msg.sender,
            'Only vendor or marketplace owner can delist'
        );
        IERC721(listing.product).safeTransferFrom(address(this), listing.vendor, listing.id);
        emit ERC721Delisting(listingId);
    }

    /// @notice Called by a vendor to change the price of listed ERC20s
    function updateERC20Price(uint256 listingId, uint256 price) external {
        require(msg.sender == ERC20Listings[listingId].vendor, 'Only vendor can update price');
        ERC20Listings[listingId].price = price;
        emit ERC20PriceChanged(listingId, price);
    }

    /// @notice Called by a vendor to change the price of a listed ERC721
    function updateERC721Price(uint256 listingId, uint256 price) external {
        require(msg.sender == ERC721Listings[listingId].vendor, 'Only vendor can update price');
        ERC721Listings[listingId].price = price;
        emit ERC721PriceChanged(listingId, price);
    }

    // -------------------------------- BIDDING METHODS --------------------------------

    /// @notice Bid an amount (payment) of a listing's currency for an amount (quantity) of its tokens.
    /// @dev Requires ERC20 approval for payment escrow.
    /// @param listingId The ID of the listing whose tokens are being bid for.
    /// @param quantity The amount of tokens being bid for - e.g. a bid for 1000 CBTs.
    /// @param payment The total size of the bid being made - e.g. a bid of 550 USDC.
    function bid(
        uint256 listingId,
        uint256 quantity,
        uint256 payment
    ) public onlyBuyer {
        IERC20(ERC20Listings[listingId].currency).transferFrom(msg.sender, address(this), payment);
        emit BidPlaced(
            listingId,
            quantity,
            payment,
            msg.sender,
            bids[listingId][msg.sender].length
        );
        bids[listingId][msg.sender].push(Bid(quantity, payment));
    }

    /// @notice Called by bidder to withdraw their bid and claim bidded funds.
    /// @dev Deletes bid at index in bids[listingId][msg.sender].
    /// @param listingId The ID of the listing to which the bid has been made.
    /// @param index The index of the bid in bids[listingId][msg.sender].
    function withdrawBid(uint256 listingId, uint256 index) public {
        IERC20(ERC20Listings[listingId].currency).transfer(
            msg.sender,
            bids[listingId][msg.sender][index].payment
        );
        _removeBid(listingId, msg.sender, index);
        emit BidWithdrawn(listingId, msg.sender, index);
    }

    /// @notice Called by vendor to accept a bid on their listing.
    /// @dev Takes input quantity/payment to prevent those parameters being altered by the bidder after transaction submission.
    /// @param listingId The ID of the listing to which the bid has been made.
    /// @param bidder The address of the bid maker.
    /// @param index The index of the bid in bids[listingId][msg.sender].
    /// @param quantity The accepted number of tokens to be sold.
    /// @param payment The accepted payment for the sold tokens.
    function acceptBid(
        uint256 listingId,
        address bidder,
        uint256 index,
        uint256 quantity,
        uint256 payment
    ) public {
        require(msg.sender == ERC20Listings[listingId].vendor, 'Only vendor can accept bid');
        require(
            ERC20Listings[listingId].amount >= quantity,
            'Insufficient tokens listed to fulfill bid'
        );
        Bid memory bid_ = bids[listingId][bidder][index];
        require(
            bid_.quantity == quantity && bid_.payment == payment,
            'Bid at input index does not have input quantity and price'
        );
        uint256 fee = (payment * FEE_NUMERATOR) / FEE_DENOMINATOR;
        IERC20 currency = IERC20(ERC20Listings[listingId].currency);
        currency.transfer(msg.sender, payment - fee);
        currency.transfer(TREASURY, fee);
        IERC20(ERC20Listings[listingId].product).transfer(bidder, quantity);
        ERC20Listings[listingId].amount -= quantity;
        _removeBid(listingId, bidder, index);
        emit BidAccepted(listingId, bidder, quantity, payment);
    }

    // -------------------------------- ADMIN METHODS --------------------------------
    /// @notice function to approve account(s) to allow them to create listings on the platform
    /// @dev default is of course unapproved (false)
    /// @param targets array of accounts to approve/retract approval
    /// @param approvals array of bools, true means approved to make listings, false means unapproved
    function setSellers(address[] calldata targets, bool[] calldata approvals) public onlyOwner {
        for (uint256 i = 0; i < targets.length; i++) {
            sellerApprovals[targets[i]] = approvals[i];
        }
        emit SellerApproval(targets, approvals);
    }

    /// @notice function to allow buyer(s) to make purchases, see setSellers
    /// @dev note that until buyer whitelisting has been enabled using setBuyerWhitelisting, this function will have no effect on users
    function setBuyers(address[] calldata targets, bool[] calldata approvals) public onlyOwner {
        for (uint256 i = 0; i < targets.length; i++) {
            buyerApprovals[targets[i]] = approvals[i];
        }
        emit BuyerApproval(targets, approvals);
    }

    function setFeeNumerator(uint256 feeNumerator) external onlyOwner {
        FEE_NUMERATOR = feeNumerator;
    }

    function setFeeDenominator(uint256 feeDenominator) external onlyOwner {
        FEE_DENOMINATOR = feeDenominator;
    }

    function setBuyerWhitelisting(bool whitelisting) external onlyOwner {
        buyerWhitelisting = whitelisting;
    }

    // -------------------------------- INTERNAL METHODS --------------------------------

    // Removes bid at bids[listingId][bidder]
    /// @dev does not conserve Bid[] order
    function _removeBid(
        uint256 listingId,
        address bidder,
        uint256 index
    ) internal {
        bids[listingId][bidder][index] = bids[listingId][bidder][
            bids[listingId][bidder].length - 1
        ];
        bids[listingId][bidder].pop();
    }
}
