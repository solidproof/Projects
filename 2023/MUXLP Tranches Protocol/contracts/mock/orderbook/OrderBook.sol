// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../libraries/LibSubAccount.sol";
import "../libraries/LibMath.sol";
import "../libraries/LibOrderBook.sol";
import "../interfaces/ILiquidityCallback.sol";
import "./Types.sol";
import "./Admin.sol";

contract OrderBook is Storage, Admin, ReentrancyGuardUpgradeable {
    using LibSubAccount for bytes32;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using LibOrder for LibOrder.OrderList;
    using LibOrder for bytes32[3];
    using LibOrder for PositionOrder;
    using LibOrder for LiquidityOrder;
    using LibOrder for WithdrawalOrder;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    // do not forget to update LibOrderBook if this line updates
    event NewPositionOrder(
        bytes32 indexed subAccountId,
        uint64 indexed orderId,
        uint96 collateral, // erc20.decimals
        uint96 size, // 1e18
        uint96 price, // 1e18
        uint8 profitTokenId,
        uint8 flags,
        uint32 deadline // 1e0. 0 if market order. > 0 if limit order
    );
    // do not forget to update LibOrderBook if this line updates
    event NewLiquidityOrder(
        address indexed account,
        uint64 indexed orderId,
        uint8 assetId,
        uint96 rawAmount, // erc20.decimals
        bool isAdding
    );
    event NewWithdrawalOrder(
        bytes32 indexed subAccountId,
        uint64 indexed orderId,
        uint96 rawAmount, // erc20.decimals
        uint8 profitTokenId,
        bool isProfit
    );
    event NewRebalanceOrder(
        address indexed rebalancer,
        uint64 indexed orderId,
        uint8 tokenId0,
        uint8 tokenId1,
        uint96 rawAmount0,
        uint96 maxRawAmount1,
        bytes32 userData
    );
    event FillOrder(uint64 orderId, OrderType orderType, bytes32[3] orderData);
    // do not forget to update LibOrderBook if this line updates
    event CancelOrder(uint64 orderId, OrderType orderType, bytes32[3] orderData);
    // do not forget to update LibOrderBook if this line updates
    event NewPositionOrderExtra(
        bytes32 indexed subAccountId,
        uint64 indexed orderId,
        uint96 collateral, // erc20.decimals
        uint96 size, // 1e18
        uint96 price, // 1e18
        uint8 profitTokenId,
        uint8 flags,
        uint32 deadline, // 1e0. 0 if market order. > 0 if limit order
        PositionOrderExtra extra
    );

    function initialize(
        address pool,
        address mlp,
        address weth,
        address nativeUnwrapper
    ) external initializer {
        __SafeOwnable_init();

        _storage.pool = ILiquidityPool(pool);
        _storage.mlp = IERC20Upgradeable(mlp);
        _storage.weth = IWETH(weth);
        _storage.nativeUnwrapper = INativeUnwrapper(nativeUnwrapper);
        _storage.maintainer = owner();
    }

    function getOrderCount() external view returns (uint256) {
        return _storage.orders.length();
    }

    /**
     * @notice Get an Order by orderId.
     */
    function getOrder(uint64 orderId) external view returns (bytes32[3] memory, bool) {
        return (_storage.orders.get(orderId), _storage.orders.contains(orderId));
    }

    function getOrders(
        uint256 begin,
        uint256 end
    ) external view returns (bytes32[3][] memory orderArray, uint256 totalCount) {
        totalCount = _storage.orders.length();
        if (begin >= end || begin >= totalCount) {
            return (orderArray, totalCount);
        }
        end = end <= totalCount ? end : totalCount;
        uint256 size = end - begin;
        orderArray = new bytes32[3][](size);
        for (uint256 i = 0; i < size; i++) {
            orderArray[i] = _storage.orders.at(i + begin);
        }
    }

    // A deprecated interface that will be removed in the next release.
    function placePositionOrder2(
        bytes32 subAccountId,
        uint96 collateralAmount, // erc20.decimals
        uint96 size, // 1e18
        uint96 price, // 1e18
        uint8 profitTokenId,
        uint8 flags,
        uint32 deadline, // 1e0
        bytes32 referralCode
    ) public payable nonReentrant {
        PositionOrderExtra memory extra;
        placePositionOrder3(
            subAccountId,
            collateralAmount,
            size,
            price,
            profitTokenId,
            flags,
            deadline,
            referralCode,
            extra
        );
    }

    /**
     * @notice Open/close position. called by Trader.
     *
     *         Market order will expire after marketOrderTimeout seconds.
     *         Limit/Trigger order will expire after deadline.
     * @param  subAccountId       sub account id. see LibSubAccount.decodeSubAccountId.
     * @param  collateralAmount   deposit collateral before open; or withdraw collateral after close. decimals = erc20.decimals.
     * @param  size               position size. decimals = 18.
     * @param  price              limit price. decimals = 18.
     * @param  profitTokenId      specify the profitable asset.id when closing a position and making a profit.
     *                            take no effect when opening a position or loss.
     * @param  flags              a bitset of LibOrder.POSITION_*.
     *                            POSITION_OPEN                     this flag means openPosition; otherwise closePosition
     *                            POSITION_MARKET_ORDER             this flag means ignore limitPrice
     *                            POSITION_WITHDRAW_ALL_IF_EMPTY    this flag means auto withdraw all collateral if position.size == 0
     *                            POSITION_TRIGGER_ORDER            this flag means this is a trigger order (ex: stop-loss order). otherwise this is a limit order (ex: take-profit order)
     *                            POSITION_TPSL_STRATEGY            for open-position-order, this flag auto place take-profit and stop-loss orders when open-position-order fills.
     *                                                              for close-position-order, this flag means ignore limitPrice and profitTokenId, and use extra.tpPrice, extra.slPrice, extra.tpslProfitTokenId instead.
     * @param  deadline           a unix timestamp after which the limit/trigger order MUST NOT be filled. fill 0 for market order.
     * @param  referralCode       set referral code of the trading account.
     * @param  extra              more strategy like tp/sl.
     */
    function placePositionOrder3(
        bytes32 subAccountId,
        uint96 collateralAmount, // erc20.decimals
        uint96 size, // 1e18
        uint96 price, // 1e18
        uint8 profitTokenId,
        uint8 flags,
        uint32 deadline, // 1e0
        bytes32 referralCode,
        PositionOrderExtra memory extra
    ) public payable nonReentrant {
        address msgSender = _msgSender();
        address accountOwner = subAccountId.getSubAccountOwner();
        if (_storage.aggregators[msgSender]) {
            // we trust aggregator
        } else {
            // otherwise only account owner can place order
            require(accountOwner == msgSender, "SND"); // SeNDer is not authorized
        }
        if (referralCode != bytes32(0) && _storage.referralManager != address(0)) {
            // IReferralManager(_storage.referralManager).setReferrerCodeFor(
            //     accountOwner,
            //     referralCode
            // );
        }
        LibOrderBook.placePositionOrder(
            _storage,
            _blockTimestamp(),
            subAccountId,
            collateralAmount,
            size,
            price,
            profitTokenId,
            flags,
            deadline,
            extra
        );
    }

    /**
     * @dev    Update a position-order. called by Trader.
     *
     *         Internally this function will cancel the old order and place a new order.
     * @param  orderId            order id.
     * @param  collateralAmount   only available for a close-position-order. withdraw collateral after close. decimals = erc20.decimals.
     * @param  size               position size. decimals = 18.
     * @param  price              limit price. decimals = 18.
     * @param  deadline           a unix timestamp after which the limit/trigger order MUST NOT be filled. fill 0 for market order.
     * @param  extra              more strategy like tp/sl.
     */
    function updatePositionOrder(
        uint64 orderId,
        uint96 collateralAmount, // erc20.decimals
        uint96 size, // 1e18
        uint96 price, // 1e18
        uint32 deadline, // 1e0
        PositionOrderExtra memory extra
    ) external whenPositionOrderEnabled nonReentrant {
        LibOrderBook.updatePositionOrder(
            _storage,
            _msgSender(),
            _blockTimestamp(),
            orderId,
            collateralAmount, // erc20.decimals
            size, // 1e18
            price, // 1e18
            deadline, // 1e0
            extra
        );
    }

    /**
     * @notice Add/remove liquidity. called by Liquidity Provider.
     *
     *         Can be filled after liquidityLockPeriod seconds.
     * @param  assetId   asset.id that added/removed to.
     * @param  rawAmount asset token amount. decimals = erc20.decimals.
     * @param  isAdding  true for add liquidity, false for remove liquidity.
     */
    function placeLiquidityOrder(
        uint8 assetId,
        uint96 rawAmount, // erc20.decimals
        bool isAdding
    ) external payable nonReentrant {
        address account = _msgSender();
        LibOrderBook.placeLiquidityOrder(
            _storage,
            _blockTimestamp(),
            account,
            assetId,
            rawAmount,
            isAdding
        );
    }

    /**
     * @notice Withdraw collateral/profit. called by Trader.
     *
     *         This order will expire after marketOrderTimeout seconds.
     * @param  subAccountId       sub account id. see LibSubAccount.decodeSubAccountId.
     * @param  rawAmount          collateral or profit asset amount. decimals = erc20.decimals.
     * @param  profitTokenId      specify the profitable asset.id.
     * @param  isProfit           true for withdraw profit. false for withdraw collateral.
     */
    function placeWithdrawalOrder(
        bytes32 subAccountId,
        uint96 rawAmount, // erc20.decimals
        uint8 profitTokenId,
        bool isProfit
    ) external nonReentrant {
        address trader = subAccountId.getSubAccountOwner();
        require(trader == _msgSender(), "SND"); // SeNDer is not authorized
        require(rawAmount != 0, "A=0"); // Amount Is Zero

        uint64 orderId = _storage.nextOrderId++;
        bytes32[3] memory data = LibOrder.encodeWithdrawalOrder(
            orderId,
            subAccountId,
            rawAmount,
            profitTokenId,
            isProfit,
            _blockTimestamp()
        );
        _storage.orders.add(orderId, data);

        emit NewWithdrawalOrder(subAccountId, orderId, rawAmount, profitTokenId, isProfit);
    }

    /**
     * @notice Rebalance pool liquidity. Swap token 0 for token 1.
     *
     *         msg.sender must implement IMuxRebalancerCallback.
     * @param  tokenId0      asset.id to be swapped out of the pool.
     * @param  tokenId1      asset.id to be swapped into the pool.
     * @param  rawAmount0    token 0 amount. decimals = erc20.decimals.
     * @param  maxRawAmount1 max token 1 that rebalancer is willing to pay. decimals = erc20.decimals.
     * @param  userData      any user defined data.
     */
    function placeRebalanceOrder(
        uint8 tokenId0,
        uint8 tokenId1,
        uint96 rawAmount0, // erc20.decimals
        uint96 maxRawAmount1, // erc20.decimals
        bytes32 userData
    ) external onlyRebalancer nonReentrant {
        require(rawAmount0 != 0, "A=0"); // Amount Is Zero
        address rebalancer = _msgSender();
        uint64 orderId = _storage.nextOrderId++;
        bytes32[3] memory data = LibOrder.encodeRebalanceOrder(
            orderId,
            rebalancer,
            tokenId0,
            tokenId1,
            rawAmount0,
            maxRawAmount1,
            userData
        );
        _storage.orders.add(orderId, data);
        emit NewRebalanceOrder(
            rebalancer,
            orderId,
            tokenId0,
            tokenId1,
            rawAmount0,
            maxRawAmount1,
            userData
        );
    }

    /**
     * @dev   Open/close a position. called by Broker.
     *
     * @param orderId           order id.
     * @param collateralPrice   collateral price. decimals = 18.
     * @param assetPrice        asset price. decimals = 18.
     * @param profitAssetPrice  profit asset price. decimals = 18.
     */
    function fillPositionOrder(
        uint64 orderId,
        uint96 collateralPrice,
        uint96 assetPrice,
        uint96 profitAssetPrice // only used when !isLong
    ) external onlyBroker whenPositionOrderEnabled nonReentrant {
        require(_storage.orders.contains(orderId), "OID"); // can not find this OrderID
        bytes32[3] memory orderData = _storage.orders.get(orderId);
        _storage.orders.remove(orderId);
        OrderType orderType = LibOrder.getOrderType(orderData);
        require(orderType == OrderType.PositionOrder, "TYP"); // order TYPe mismatch

        PositionOrder memory order = orderData.decodePositionOrder();
        require(_blockTimestamp() <= _positionOrderDeadline(order), "EXP"); // EXPired
        uint96 tradingPrice;
        if (order.isOpenPosition()) {
            tradingPrice = LibOrderBook.fillOpenPositionOrder(
                _storage,
                _blockTimestamp(),
                orderId,
                collateralPrice,
                assetPrice,
                order
            );
        } else {
            tradingPrice = LibOrderBook.fillClosePositionOrder(
                _storage,
                orderId,
                collateralPrice,
                assetPrice,
                profitAssetPrice,
                order
            );
        }
        // price check
        if (!order.isMarketOrder() && tradingPrice > 0) {
            // open,long      0,0   0,1   1,1   1,0
            // limitOrder     <=    >=    <=    >=
            // triggerOrder   >=    <=    >=    <=
            bool isLess = (order.subAccountId.isLong() == order.isOpenPosition());
            if (order.isTriggerOrder()) {
                isLess = !isLess;
            }
            if (isLess) {
                require(tradingPrice <= order.price, "LMT"); // LiMiTed by limitPrice
            } else {
                require(tradingPrice >= order.price, "LMT"); // LiMiTed by limitPrice
            }
        }

        emit FillOrder(orderId, orderType, orderData);
    }

    /**
     * @dev   Add/remove liquidity. called by Broker.
     *
     *        Check _getLiquidityFeeRate in Liquidity.sol on how to calculate liquidity fee.
     * @param orderId           order id.
     * @param assetPrice        token price that added/removed to. decimals = 18.
     * @param mlpPrice          mlp price. decimals = 18.
     * @param currentAssetValue liquidity USD value of a single asset in all chains (even if tokenId is a stable asset). decimals = 18.
     * @param targetAssetValue  weight / Σ weight * total liquidity USD value in all chains. decimals = 18.
     */
    function fillLiquidityOrder(
        uint64 orderId,
        uint96 assetPrice,
        uint96 mlpPrice,
        uint96 currentAssetValue,
        uint96 targetAssetValue
    ) external onlyBroker whenLiquidityOrderEnabled nonReentrant {
        require(_storage.orders.contains(orderId), "OID"); // can not find this OrderID
        bytes32[3] memory orderData = _storage.orders.get(orderId);
        _storage.orders.remove(orderId);
        LiquidityOrder memory order = LibOrder.decodeLiquidityOrder(orderData);
        if (_storage.callbackWhitelist[order.account]) {
            bool isValid;
            try
                ILiquidityCallback(order.account).beforeFillLiquidityOrder{
                    gas: _callbackGasLimit()
                }(order, assetPrice, mlpPrice, currentAssetValue, targetAssetValue)
            returns (bool _isValid) {
                isValid = _isValid;
            } catch {
                isValid = false;
            }
            if (!isValid) {
                _cancelLiquidityOrder(order);
                emit CancelOrder(orderId, LibOrder.getOrderType(orderData), orderData);
                return;
            }
        }
        OrderType orderType = LibOrder.getOrderType(orderData);
        require(orderType == OrderType.LiquidityOrder, "TYP"); // order TYPe mismatch
        uint256 mlpAmount = LibOrderBook.fillLiquidityOrder(
            _storage,
            _blockTimestamp(),
            assetPrice,
            mlpPrice,
            currentAssetValue,
            targetAssetValue,
            orderData
        );
        if (_storage.callbackWhitelist[order.account]) {
            try
                ILiquidityCallback(order.account).afterFillLiquidityOrder{gas: _callbackGasLimit()}(
                    order,
                    mlpAmount,
                    assetPrice,
                    mlpPrice,
                    currentAssetValue,
                    targetAssetValue
                )
            {} catch {}
        }
        emit FillOrder(orderId, orderType, orderData);
    }

    /**
     * @dev   Withdraw collateral/profit. called by Broker.
     *
     * @param orderId           order id.
     * @param collateralPrice   collateral price. decimals = 18.
     * @param assetPrice        asset price. decimals = 18.
     * @param profitAssetPrice  profit asset price. decimals = 18.
     */
    function fillWithdrawalOrder(
        uint64 orderId,
        uint96 collateralPrice,
        uint96 assetPrice,
        uint96 profitAssetPrice // only used when !isLong
    ) external onlyBroker nonReentrant {
        require(_storage.orders.contains(orderId), "OID"); // can not find this OrderID
        bytes32[3] memory orderData = _storage.orders.get(orderId);
        _storage.orders.remove(orderId);
        OrderType orderType = LibOrder.getOrderType(orderData);
        require(orderType == OrderType.WithdrawalOrder, "TYP"); // order TYPe mismatch

        WithdrawalOrder memory order = orderData.decodeWithdrawalOrder();
        require(_blockTimestamp() <= order.placeOrderTime + _storage.marketOrderTimeout, "EXP"); // EXPired
        if (order.isProfit) {
            _storage.pool.withdrawProfit(
                order.subAccountId,
                order.rawAmount,
                order.profitTokenId,
                collateralPrice,
                assetPrice,
                profitAssetPrice
            );
        } else {
            _storage.pool.withdrawCollateral(
                order.subAccountId,
                order.rawAmount,
                collateralPrice,
                assetPrice
            );
        }

        emit FillOrder(orderId, orderType, orderData);
    }

    /**
     * @dev   Rebalance. called by Broker.
     *
     * @param orderId  order id.
     * @param price0   price of token 0. decimals = 18.
     * @param price1   price of token 1. decimals = 18.
     */
    function fillRebalanceOrder(
        uint64 orderId,
        uint96 price0,
        uint96 price1
    ) external onlyBroker whenLiquidityOrderEnabled nonReentrant {
        require(_storage.orders.contains(orderId), "OID"); // can not find this OrderID
        bytes32[3] memory orderData = _storage.orders.get(orderId);
        _storage.orders.remove(orderId);
        OrderType orderType = LibOrder.getOrderType(orderData);
        require(orderType == OrderType.RebalanceOrder, "TYP"); // order TYPe mismatch

        RebalanceOrder memory order = orderData.decodeRebalanceOrder();
        _storage.pool.rebalance(
            order.rebalancer,
            order.tokenId0,
            order.tokenId1,
            order.rawAmount0,
            order.maxRawAmount1,
            order.userData,
            price0,
            price1
        );

        emit FillOrder(orderId, orderType, orderData);
    }

    /**
     * @notice Cancel an Order by orderId.
     */
    function cancelOrder(uint64 orderId) external nonReentrant {
        require(_storage.orders.contains(orderId), "OID"); // can not find this OrderID
        bytes32[3] memory orderData = _storage.orders.get(orderId);
        _storage.orders.remove(orderId);
        address account = orderData.getOrderOwner();
        OrderType orderType = LibOrder.getOrderType(orderData);
        if (orderType == OrderType.PositionOrder) {
            PositionOrder memory order = orderData.decodePositionOrder();
            if (_storage.brokers[_msgSender()]) {
                require(_blockTimestamp() > _positionOrderDeadline(order), "EXP"); // not EXPired yet
            } else {
                require(_msgSender() == account, "SND"); // SeNDer is not authorized
            }
            if (order.isOpenPosition() && order.collateral > 0) {
                address collateralAddress = _storage.pool.getAssetAddress(
                    order.subAccountId.getSubAccountCollateralId()
                );
                LibOrderBook._transferOut(_storage, collateralAddress, account, order.collateral);
            }
            // tp/sl strategy
            delete _storage.positionOrderExtras[orderId];
            _storage.activatedTpslOrders[order.subAccountId].remove(uint256(orderId));
        } else if (orderType == OrderType.LiquidityOrder) {
            require(_msgSender() == account, "SND"); // SeNDer is not authorized
            LiquidityOrder memory order = orderData.decodeLiquidityOrder();
            _cancelLiquidityOrder(order);
        } else if (orderType == OrderType.WithdrawalOrder) {
            if (_storage.brokers[_msgSender()]) {
                WithdrawalOrder memory order = orderData.decodeWithdrawalOrder();
                uint256 deadline = order.placeOrderTime + _storage.marketOrderTimeout;
                require(_blockTimestamp() > deadline, "EXP"); // not EXPired yet
            } else {
                require(_msgSender() == account, "SND"); // SeNDer is not authorized
            }
        } else if (orderType == OrderType.RebalanceOrder) {
            require(_msgSender() == account, "SND"); // SeNDer is not authorized
        } else {
            revert();
        }
        emit CancelOrder(orderId, LibOrder.getOrderType(orderData), orderData);
    }

    function _cancelLiquidityOrder(LiquidityOrder memory order) internal {
        if (order.isAdding) {
            address collateralAddress = _storage.pool.getAssetAddress(order.assetId);
            LibOrderBook._transferOut(_storage, collateralAddress, order.account, order.rawAmount);
        } else {
            _storage.mlp.safeTransfer(order.account, order.rawAmount);
        }
        if (_storage.callbackWhitelist[order.account]) {
            try
                ILiquidityCallback(order.account).afterCancelLiquidityOrder{
                    gas: _callbackGasLimit()
                }(order)
            {} catch {}
        }
    }

    /**
     * @notice Trader can withdraw all collateral only when position = 0.
     */
    function withdrawAllCollateral(bytes32 subAccountId) external {
        require(subAccountId.getSubAccountOwner() == _msgSender(), "SND"); // SeNDer is not authorized
        _storage.pool.withdrawAllCollateral(subAccountId);
    }

    /**
     * @notice Broker can update funding each [fundingInterval] seconds by specifying utilizations.
     *
     *         Check _getFundingRate in Liquidity.sol on how to calculate funding rate.
     * @param  stableUtilization    Stable coin utilization in all chains. decimals = 5.
     * @param  unstableTokenIds     All unstable Asset id(s) MUST be passed in order. ex: 1, 2, 5, 6, ...
     * @param  unstableUtilizations Unstable Asset utilizations in all chains decimals = 5.
     * @param  unstablePrices       Unstable Asset prices decimals = 18.
     */
    function updateFundingState(
        uint32 stableUtilization, // 1e5
        uint8[] calldata unstableTokenIds,
        uint32[] calldata unstableUtilizations, // 1e5
        uint96[] calldata unstablePrices // 1e18
    ) external onlyBroker {
        _storage.pool.updateFundingState(
            stableUtilization,
            unstableTokenIds,
            unstableUtilizations,
            unstablePrices
        );
    }

    /**
     * @notice Deposit collateral into a subAccount.
     *
     * @param  subAccountId       sub account id. see LibSubAccount.decodeSubAccountId.
     * @param  collateralAmount   collateral amount. decimals = erc20.decimals.
     */
    function depositCollateral(bytes32 subAccountId, uint256 collateralAmount) external payable {
        LibSubAccount.DecodedSubAccountId memory account = subAccountId.decodeSubAccountId();
        require(account.account == _msgSender(), "SND"); // SeNDer is not authorized
        require(collateralAmount != 0, "C=0"); // Collateral Is Zero
        address collateralAddress = _storage.pool.getAssetAddress(account.collateralId);
        LibOrderBook._transferIn(
            _storage,
            _msgSender(),
            collateralAddress,
            address(_storage.pool),
            collateralAmount
        );
        _storage.pool.depositCollateral(subAccountId, collateralAmount);
    }

    function liquidate(
        bytes32 subAccountId,
        uint8 profitAssetId, // only used when !isLong
        uint96 collateralPrice,
        uint96 assetPrice,
        uint96 profitAssetPrice // only used when !isLong
    ) external onlyBroker {
        _storage.pool.liquidate(
            subAccountId,
            profitAssetId,
            collateralPrice,
            assetPrice,
            profitAssetPrice
        );
        // auto withdraw
        (uint96 collateral, , , , ) = _storage.pool.getSubAccount(subAccountId);
        if (collateral > 0) {
            _storage.pool.withdrawAllCollateral(subAccountId);
        }
        // cancel activated tp/sl orders
        LibOrderBook.cancelActivatedTpslOrders(_storage, subAccountId);
    }

    function redeemMuxToken(uint8 tokenId, uint96 muxTokenAmount) external {
        address trader = _msgSender();
        LibOrderBook.redeemMuxToken(_storage, trader, tokenId, muxTokenAmount);
    }

    /**
     * @dev Broker can withdraw brokerGasRebate.
     */
    function claimBrokerGasRebate() external onlyBroker returns (uint256 rawAmount) {
        return _storage.pool.claimBrokerGasRebate(msg.sender);
    }

    function _callbackGasLimit() internal view returns (uint256) {
        return _storage.callbackGasLimit == 0 ? gasleft() : _storage.callbackGasLimit;
    }

    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp);
    }

    function _positionOrderDeadline(PositionOrder memory order) internal view returns (uint32) {
        if (order.isMarketOrder()) {
            return order.placeOrderTime + _storage.marketOrderTimeout;
        } else {
            return
                order.placeOrderTime +
                LibMath.min32(uint32(order.expire10s) * 10, _storage.maxLimitOrderTimeout);
        }
    }
}
