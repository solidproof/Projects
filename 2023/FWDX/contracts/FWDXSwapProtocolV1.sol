// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./TransferHelper.sol";

interface IERC20Extended is IERC20Upgradeable {
    function decimals() external view returns (uint8);
}

contract FWDXSwapProtocolV1 is
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // Define your state variables, structures and events here...

    function initialize(address payable _treasury) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        require(
            _treasury != address(0),
            "Initiate:: _treasury can not be zero address"
        );
        treasury = _treasury;
        networkId = getChainID();
        marketFee = 25;
        stableCoinMarketFee = 5;
    }

    ////////////////////////////////////////////////////////////////
    // constants //
    ////////////////////////////////////////////////////////////////

    // max platform fee
    uint256 public constant maxFee = 10000;

    ////////////////////////////////////////////////////////////////
    // variables //
    ////////////////////////////////////////////////////////////////

    // platform fee - 0.25 %
    uint256 public marketFee;

    // platform fee - 0.05 %
    uint256 public stableCoinMarketFee;

    // Total Markets count
    uint256 public totalMarkets;

    // treasury address
    address payable public treasury;

    // network Id
    uint256 public networkId;

    // version
    uint256 public version;

    ////////////////////////////////////////////////////////////////
    // structs //
    ////////////////////////////////////////////////////////////////

    // Market Info
    struct Market {
        address _maker;
        address _swapInToken;
        address _swapOutToken;
        bool _partialOrderAllowed;
        uint256 _swapInAmount;
        uint256 _swapOutAmount;
        uint256 _openTill;
    }

    ////////////////////////////////////////////////////////////////
    // mappings //
    ////////////////////////////////////////////////////////////////

    // Mapping of MarketId & Markets Struct
    mapping(bytes32 => Market) markets;

    // Market Status : 1-opened, 2-completed, 3-cancelled, 4-filled
    mapping(bytes32 => uint256) internal marketStatus;

    // Mapping of Maker Claimed & Status
    mapping(bytes32 => bool) internal isMakerClaimed;

    // Mapping of MarketId & Total Filled Amount
    mapping(bytes32 => uint256) internal totalFilledAmount;

    // Mapping of MarketId & Total User Share Amount from SwapInTokens
    mapping(bytes32 => uint256) internal totalSwapShareAmount;

    // Mapping of MarketId & Market Fee Amount
    mapping(bytes32 => uint256) internal marketFeeAmount;

    // Mapping of MarketId & Mapping of UserWallet & User Filled Orders
    mapping(bytes32 => mapping(address => uint256)) internal userOrders;

    // Mapping of MarketId & Mapping of User Wallet & User Share
    mapping(bytes32 => mapping(address => uint256)) internal userShare;

    // Mapping of Stablecoins & Status
    mapping(address => bool) internal stableCoin;

    ////////////////////////////////////////////////////////////////
    // events //
    ////////////////////////////////////////////////////////////////

    // Triggers on updating allowed ERC20
    event UpdateStableCoinStatus(address _erc20, bool _isStable);

    // Triggers on updating platform fee
    event PlatformFeeUpdated(uint256 _oldFee, uint256 _newFee, bool _isStable);

    // Triggers on updating treasury
    event TreasuryUpdated(address oldBeneficiary, address newBeneficiary);

    // Market Created
    event MarketCreated(
        bytes32 marketId,
        address maker,
        address swapIn,
        address swapOut,
        bool isPartialAllowed,
        uint256 swapInAmount,
        uint256 swapOutAmount,
        uint256 validUntil,
        uint256 networkId
    );

    // Market Filling by Takers
    event MarketFilling(
        bytes32 marketId,
        address taker,
        address fillingToken,
        uint256 fillInAmount,
        uint256 marketStatus,
        uint256 networkId
    );

    // Taker Claimed Event
    event MarketClaimedByTaker(
        bytes32 marketId,
        address taker,
        address token,
        uint256 amount,
        uint256 marketStatus,
        uint256 networkId
    );

    // Maker Claimed Event
    event MarketClaimedByMaker(
        bytes32 marketId,
        address maker,
        address token,
        uint256 amount,
        uint256 marketStatus,
        uint256 networkId
    );

    // Maker Claimed Event
    event MarketCancelledByMaker(
        bytes32 marketId,
        address maker,
        address token,
        uint256 amount,
        uint256 marketStatus,
        uint256 networkId
    );

    // Claim cancelled market funds by Taker
    event ClaimedCancelledMarketByTaker(
        bytes32 marketId,
        address taker,
        address token,
        uint256 amount,
        uint256 marketStatus,
        uint256 networkId
    );

    ////////////////////////////////////////////////////////////////
    // modifiers //
    ////////////////////////////////////////////////////////////////

    modifier nonZero(uint256 _amount) {
        require(_amount > 0, "NonZero:: amount can not be zero");
        _;
    }

    ////////////////////////////////////////////////////////////////
    // external / public functions //
    ////////////////////////////////////////////////////////////////

    // Create Market - anyone can create for any amount
    // NOTE: While passing swapInAmount, user should send the amount, however user pay amount + fee.
    function createMarket(
        address _swapInToken,
        address _swapOutToken,
        uint256 _swapInAmount,
        uint256 _swapOutAmount,
        uint256 _openTill,
        bool _isPartialFillAllowed
    ) external nonReentrant {
        require(_swapInAmount > 0, "CreateMarket:: Invalid SwapInAmount");
        require(_swapOutAmount > 0, "CreateMarket:: Invalid SwapOutAmount");
        bytes32 _marketId = keccak256(abi.encodePacked(totalMarkets));
        require(
            _openTill > block.timestamp,
            "CreateMarket:: Invalid Timestamp"
        );
        markets[_marketId] = Market(
            msg.sender,
            _swapInToken,
            _swapOutToken,
            _isPartialFillAllowed,
            _swapInAmount,
            _swapOutAmount,
            _openTill
        );
        safeCreateMarket(
            _marketId,
            _swapInToken,
            _swapInAmount,
            isStableCoinSwap(_swapInToken, _swapOutToken)
        );
        emit MarketCreated(
            _marketId,
            msg.sender,
            _swapInToken,
            _swapOutToken,
            _isPartialFillAllowed,
            _swapInAmount,
            _swapOutAmount,
            _openTill,
            networkId
        );
        marketStatus[_marketId] = 1;
        totalMarkets += 1;
    }

    function fillMarket(
        bytes32 marketId,
        uint256 amount
    ) external nonReentrant nonZero(amount) {
        require(marketStatus[marketId] == 1, "FillOrder:: Invalid Order");
        require(
            block.timestamp <= uint256(markets[marketId]._openTill),
            "FillOrder:: Market Expired"
        );
        require(
            amount <= getLeftTokensToFill(marketId),
            "FillOrder:: Limit Reached"
        );

        // Check if partial orders are allowed
        if (!markets[marketId]._partialOrderAllowed) {
            // If partial orders are not allowed, the fill amount must match the swapOutAmount
            require(
                amount == markets[marketId]._swapOutAmount,
                "FillOrder:: Partial fill not allowed for this Market"
            );
        } else {
            // If partial orders are allowed, check if the amount is within the limit
            require(
                amount <= getLeftTokensToFill(marketId),
                "FillOrder:: Limit Reached"
            );
        }

        // transfer platform fee
        if (totalFilledAmount[marketId] == 0) {
            safeTransfer(
                markets[marketId]._swapInToken,
                marketFeeAmount[marketId],
                treasury
            );
        }
        totalFilledAmount[marketId] += amount;

        safeFillMarket(
            markets[marketId]._swapOutToken,
            amount,
            isStableCoinSwap(
                markets[marketId]._swapInToken,
                markets[marketId]._swapOutToken
            )
        );

        userOrders[marketId][msg.sender] += amount;

        userShare[marketId][msg.sender] += updateUserShare(
            marketId,
            amount,
            IERC20Extended(markets[marketId]._swapOutToken).decimals()
        );

        if (getLeftTokensToFill(marketId) == 0) {
            marketStatus[marketId] = 4;
        }

        emit MarketFilling(
            marketId,
            msg.sender,
            markets[marketId]._swapOutToken,
            amount,
            marketStatus[marketId],
            networkId
        );
    }

    // Maker can cancel market if no one takes it
    function cancelMarketByMaker(bytes32 marketId) external nonReentrant {
        require(
            msg.sender == markets[marketId]._maker,
            "CancelMarketByMaker:: Unauthorised"
        );
        require(
            marketStatus[marketId] == 1,
            "CancelMarketByMaker:: Is Market Open?"
        );
        if (
            totalFilledAmount[marketId] == 0 ||
            uint256(markets[marketId]._openTill) > block.timestamp
        ) {
            uint256 eligibleTokens = markets[marketId]._swapInAmount;
            safeTransfer(
                markets[marketId]._swapInToken,
                eligibleTokens,
                msg.sender
            );
            safeTransfer(
                markets[marketId]._swapInToken,
                marketFeeAmount[marketId],
                msg.sender
            );
            marketStatus[marketId] = 3;
            isMakerClaimed[marketId] = true;
            emit MarketCancelledByMaker(
                marketId,
                msg.sender,
                markets[marketId]._swapInToken,
                eligibleTokens,
                marketStatus[marketId],
                networkId
            );
        } else {
            revert("Market Partially Filled or Market Expired");
        }
    }

    function claimMarketByTaker(bytes32 _marketId) external nonReentrant {
        require(
            marketStatus[_marketId] == 4 || marketStatus[_marketId] == 2,
            "ClaimMarketByTaker:: Market not filled"
        );
        require(
            userShare[_marketId][msg.sender] > 0,
            "ClaimMarketByTaker:: Already claimed or Havent filled market"
        );
        uint256 eligibleTokens = userShare[_marketId][msg.sender];
        safeTransfer(
            markets[_marketId]._swapInToken,
            eligibleTokens,
            msg.sender
        );
        emit MarketClaimedByTaker(
            _marketId,
            msg.sender,
            markets[_marketId]._swapInToken,
            eligibleTokens,
            marketStatus[_marketId],
            networkId
        );
        userShare[_marketId][msg.sender] = 0;
        userOrders[_marketId][msg.sender] = 0;
    }

    // Maker trying to claim
    function claimMarketByMaker(bytes32 _marketId) external nonReentrant {
        uint256 _amount = 0;
        require(
            msg.sender == markets[_marketId]._maker,
            "ClaimMarketByMaker:: Unauthorised"
        );
        require(
            isMakerClaimed[_marketId] == false,
            "ClaimMarketByMaker:: Already claimed"
        );

        if (markets[_marketId]._partialOrderAllowed) {
            // If market partially filled, maker get the totalFilledAmount & Left over amount of SwapIn Token
            _amount = totalFilledAmount[_marketId];
            uint256 balanceInPartial = markets[_marketId]._swapInAmount -
                totalSwapShareAmount[_marketId];
            if (balanceInPartial > 0) {
                safeTransfer(
                    markets[_marketId]._swapInToken,
                    balanceInPartial,
                    msg.sender
                );
            }
        } else {
            require(
                marketStatus[_marketId] == 4,
                "ClaimMarketByMaker:: Market not filled"
            );
            _amount = markets[_marketId]._swapOutAmount;
        }
        uint256 eligibleTokens = _amount;
        safeTransfer(
            markets[_marketId]._swapOutToken,
            eligibleTokens,
            msg.sender
        );
        isMakerClaimed[_marketId] = true;
        marketStatus[_marketId] = 2;
        emit MarketClaimedByMaker(
            _marketId,
            msg.sender,
            markets[_marketId]._swapOutToken,
            eligibleTokens,
            marketStatus[_marketId],
            networkId
        );
    }

    ////////////////////////////////////////////////////////////////
    // internal functions //
    ////////////////////////////////////////////////////////////////

    function safeFillMarket(
        address token,
        uint256 amount,
        bool isStable
    ) internal {
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            treasury,
            calculateFee(amount, isStable)
        );
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amount
        );
    }

    function safeCreateMarket(
        bytes32 marketId,
        address token,
        uint256 amount,
        bool isStable
    ) internal {
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amount + calculateFee(amount, isStable)
        );
        marketFeeAmount[marketId] = calculateFee(amount, isStable);
    }

    function safeTransfer(address token, uint256 amount, address to) internal {
        TransferHelper.safeTransfer(token, to, amount);
    }

    function updateUserShare(
        bytes32 marketId,
        uint256 myShare,
        uint8 decimals
    ) internal returns (uint256) {
        uint256 homePool = uint256(markets[marketId]._swapInAmount);
        uint256 foreignPool = uint256(markets[marketId]._swapOutAmount);
        uint256 myShareInForeignPool = (myShare * 100 * (10 ** decimals)) /
            foreignPool;
        uint256 myShareInHomePool = (homePool * myShareInForeignPool) /
            (100 * (10 ** decimals));
        totalSwapShareAmount[marketId] += myShareInHomePool;
        return myShareInHomePool;
    }

    function getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    ////////////////////////////////////////////////////////////////
    // view functions //
    ////////////////////////////////////////////////////////////////

    // Get no.of tokens that is needed to fill the market
    function getLeftTokensToFill(
        bytes32 marketId
    ) public view returns (uint256) {
        return
            uint256(markets[marketId]._swapOutAmount) -
            totalFilledAmount[marketId];
    }

    // Get no.of tokens that user get when he/she partially close the market
    function getPartialFillLeftOverAmount(
        bytes32 marketId
    ) public view returns (uint256) {
        return totalSwapShareAmount[marketId];
    }

    // Get market base info by Market Id
    function getMarketPairBase(
        bytes32 _marketId
    ) external view returns (bytes32, address, uint256, bool, uint256) {
        return (
            _marketId,
            markets[_marketId]._maker,
            markets[_marketId]._openTill,
            markets[_marketId]._partialOrderAllowed,
            marketStatus[_marketId]
        );
    }

    // Get market base info by Market Id
    function getMarketPairInfo(
        bytes32 _marketId
    ) external view returns (bytes32, address, address, uint256, uint256) {
        return (
            _marketId,
            markets[_marketId]._swapInToken,
            markets[_marketId]._swapOutToken,
            markets[_marketId]._swapInAmount,
            markets[_marketId]._swapOutAmount
        );
    }

    // Check if a user placed or in a market or not
    function userFilledOrderAmount(
        bytes32 _marketId,
        address _user
    ) external view returns (uint256) {
        return userOrders[_marketId][_user];
    }

    // Check if a ERC20 is stablecoin or not
    function isStableCoin(address _erc20Token) public view returns (bool) {
        return stableCoin[_erc20Token];
    }

    function getUserShareInAMarketIn(
        bytes32 _marketId,
        address _wallet
    ) public view returns (uint256) {
        return userShare[_marketId][_wallet];
    }

    function getUserShareInAMarketOut(
        bytes32 _marketId,
        address _wallet
    ) public view returns (uint256) {
        return userOrders[_marketId][_wallet];
    }

    function currentFilledOfMarket(
        bytes32 _marketId
    ) public view returns (uint256) {
        return totalFilledAmount[_marketId];
    }

    function getCurrentMarketStatus(
        bytes32 _marketId
    ) public view returns (uint256) {
        return marketStatus[_marketId];
    }

    function getMarketClaimStatusByMaker(
        bytes32 _marketId
    ) public view returns (bool) {
        return isMakerClaimed[_marketId];
    }

    function getMarketStatus(bytes32 marketId) public view returns (uint256) {
        if (uint256(markets[marketId]._openTill) < block.timestamp) {
            return 3;
        } else {
            return marketStatus[marketId];
        }
    }

    function getUserShare(
        address caller,
        bytes32 marketId,
        uint256 myShare
    ) external view returns (uint256) {
        uint256 homePool = uint256(markets[marketId]._swapInAmount);
        uint256 foreginPool = uint256(markets[marketId]._swapOutAmount);
        uint256 decimals = IERC20Extended(markets[marketId]._swapOutToken)
            .decimals();
        uint256 myShareInForeignPool = (myShare * 100 * (10 ** decimals)) /
            foreginPool;
        uint256 myShareInHomePool = (homePool * myShareInForeignPool) /
            (100 * (10 ** decimals));
        return userShare[marketId][caller] + myShareInHomePool;
    }

    function calculateTokensToPay(
        uint256 amount,
        bool isStable
    ) public view returns (uint256) {
        if (isStable) {
            return amount + ((amount * stableCoinMarketFee) / maxFee);
        } else {
            return amount + ((amount * marketFee) / maxFee);
        }
    }

    function calculateFee(
        uint256 amount,
        bool isStable
    ) public view returns (uint256) {
        if (isStable) {
            return (amount * stableCoinMarketFee) / maxFee;
        } else {
            return (amount * marketFee) / maxFee;
        }
    }

    function isStableCoinSwap(
        address _swapInToken,
        address _swapOutToken
    ) public view returns (bool) {
        return stableCoin[_swapInToken] && stableCoin[_swapOutToken];
    }

    ////////////////////////////////////////////////////////////////
    // Admin functions //
    ////////////////////////////////////////////////////////////////

    // Update Treasury
    function updateTreasury(address payable _newTreasury) external onlyOwner {
        require(
            _newTreasury != address(0),
            "updateTreasury:: New Treasury can not be Zero Address"
        );
        emit TreasuryUpdated(treasury, _newTreasury);
        treasury = _newTreasury;
    }

    // Update Market fee
    function updateMarketFee(uint256 _newMarketFee) external onlyOwner {
        require(
            _newMarketFee <= 10000,
            "UpdateMarketFee:: Basis points cannot exceed 10000"
        );
        emit PlatformFeeUpdated(marketFee, _newMarketFee, false);
        marketFee = _newMarketFee;
    }

    // Update StableCoin Market fee
    function updateStableCoinMarketFee(
        uint256 _newStableCoinMarketFee
    ) external onlyOwner {
        require(
            _newStableCoinMarketFee <= 10000,
            "UpdateStableCoinMarketFee:: Basis points cannot exceed 10000"
        );
        emit PlatformFeeUpdated(
            stableCoinMarketFee,
            _newStableCoinMarketFee,
            true
        );
        stableCoinMarketFee = _newStableCoinMarketFee;
    }

    // Update a token as Stablecoin
    function updateStableCoinStatus(
        address _erc20Token,
        bool _isStableCoin
    ) public onlyOwner {
        require(
            _erc20Token != address(0),
            "UpdateStableCoinStatus:: Invalid _erc20Token"
        );
        stableCoin[_erc20Token] = _isStableCoin;
        emit UpdateStableCoinStatus(_erc20Token, _isStableCoin);
    }

    // Bulk update a token as Stablecoin
    function bulkUpdateStableCoinStatus(
        address[] calldata _erc20Tokens,
        bool[] calldata _isStableCoins
    ) public onlyOwner {
        require(
            _erc20Tokens.length == _isStableCoins.length,
            "BulkUpdateERC20Status:: Invalid Length"
        );
        for (uint8 i = 0; i < _erc20Tokens.length; i++) {
            updateStableCoinStatus(_erc20Tokens[i], _isStableCoins[i]);
        }
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {
        version++;
    }
}
