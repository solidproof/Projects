// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";
import "../../interfaces/IMuxGetter.sol";
import "./lib/LibMux.sol";
import "../lib/LibMath.sol";

import "./Storage.sol";
import "./Types.sol";

contract Position is Storage{
    using MathUpgradeable for uint256;
    using LibMath for uint256;

    uint256 internal constant MAX_PENDING_ORDERS = 64;

    event AddPendingOrder(
        LibMux.OrderCategory category,
        uint256 index,
        uint256 timestamp
    );
    event RemovePendingOrder(uint64 orderId);
    event CancelOrder(uint64 orderId, bool success);

    event OpenPosition(uint8 collateralId, uint8 indexId, bool isLong, PositionContext context);
    event ClosePosition(uint8 collateralId, uint8 indexId, bool isLong, PositionContext context);

    function _hasPendingOrder(uint64 key) internal view returns (bool) {
        return _pendingOrdersContains(key);
    }

    function _getPendingOrders() internal view returns (uint64[] memory) {
        return _pendingOrders;
    }

    function _removePendingOrder(uint64 key) internal {
        _pendingOrdersRemove(key);
        emit RemovePendingOrder(key);
    }

    function _addPendingOrder(
        LibMux.OrderCategory category,
        uint256 startOrderCount,
        uint256 endOrderCount,
        bytes32 subAccountId
    ) internal{
        (bytes32[3][] memory orderArray, ) = IMuxOrderBook(_exchangeConfigs.orderBook).getOrders(startOrderCount, endOrderCount);
        uint256 totalCount = endOrderCount - startOrderCount;
        for (uint256 i = 0; i < totalCount; i++) {
            PositionOrder memory order = LibMux.decodePositionOrder(orderArray[i]);
            if(order.subAccountId == subAccountId) {
                require(
                    _pendingOrdersAdd(order.id),
                    "AddFailed"
                );
                emit AddPendingOrder(category, i, block.timestamp);
            }
        }
    }

    function _isMarginSafe(SubAccount memory subAccount, uint96 collateralPrice, uint96 assetPrice, bool isLong, uint96 collateralDelta, uint96 sizeDelta, bool isOpen) internal view returns(bool){
        //for closing a position, we dont have to consider the delta in size and collateral, we just want to make sure the current position margin is safe.
        collateralDelta = isOpen ? collateralDelta : 0;
        sizeDelta = isOpen ? sizeDelta : 0;

        if(subAccount.size == 0){
            return true;
        }
        Margin memory margin;
        margin.asset = IMuxGetter(_exchangeConfigs.liquidityPool).getAssetInfo(_account.indexId);
        bool hasProfit;
        if (subAccount.size != 0) {
            (hasProfit, margin.muxPnlUsd) = LibMux._positionPnlUsd(margin.asset, subAccount, isLong, assetPrice); 
            margin.muxFundingFeeUsd = LibMux._getFundingFeeUsd(subAccount, margin.asset, isLong, assetPrice);
        }

        //We dont have to add sizeDelta to liquidation fees since we are only concerned about the current position liquidating
        margin.liquidationFeeUsd = LibMux._getLiquidationFeeUsd(margin.asset, subAccount.size, assetPrice);

        //Minimum threshold the position has to maintain
        uint32 threshold = isOpen ? margin.asset.initialMarginRate : margin.asset.maintenanceMarginRate;
        margin.thresholdUsd = ((uint256(subAccount.size) + uint256(sizeDelta)) * uint256(assetPrice) * uint256(threshold)) / 1e18 / 1e5;

        //Collateral left in the position
        uint256 collateralUsd = ((uint256(subAccount.collateral) + uint256(collateralDelta)) * collateralPrice) / uint256(10**_account.collateralDecimals);
        
        return ((hasProfit ? collateralUsd + margin.muxPnlUsd - margin.muxFundingFeeUsd : collateralUsd - margin.muxPnlUsd - margin.muxFundingFeeUsd) >= margin.thresholdUsd.max(margin.liquidationFeeUsd));
    }

    function _placePositionOrder(PositionContext memory context) internal{
        require(_pendingOrders.length <= MAX_PENDING_ORDERS, "TooManyPendingOrders");

        SubAccount memory subAccount;
        (subAccount.collateral, subAccount.size, subAccount.lastIncreasedTime, subAccount.entryPrice, subAccount.entryFunding) = IMuxGetter(_exchangeConfigs.liquidityPool).getSubAccount(context.subAccountId);

        bool isOpen = ((context.flags & POSITION_OPEN) != 0) ? true : false;

        require(
            _isMarginSafe(
                subAccount,
                context.collateralPrice,
                context.assetPrice,
                context.isLong,
                context.collateralAmount,
                context.size,
                isOpen
            ),
            "ImMarginUnsafe"
        );

        uint256 startOrderCount = IMuxOrderBook(_exchangeConfigs.orderBook).getOrderCount();
        IMuxOrderBook(_exchangeConfigs.orderBook).placePositionOrder3{ value: msg.value }(context.subAccountId, context.collateralAmount, context.size, context.price, context.profitTokenId ,context.flags, context.deadline, _exchangeConfigs.referralCode, context.extra);
        uint256 endOrderCount = IMuxOrderBook(_exchangeConfigs.orderBook).getOrderCount();

        require(endOrderCount > startOrderCount, "Order not recorded on MUX");

        if(isOpen){
            _addPendingOrder(LibMux.OrderCategory.OPEN, startOrderCount, endOrderCount, context.subAccountId);
            emit OpenPosition(_account.collateralId, _account.indexId, context.isLong, context);
        }else{
            _addPendingOrder(LibMux.OrderCategory.CLOSE, startOrderCount, endOrderCount, context.subAccountId);
            emit ClosePosition(_account.collateralId, _account.indexId, context.isLong, context);
        }
    }

    function _cancelOrder(uint64 orderId) internal returns(bool success){
        require(_hasPendingOrder(orderId), "KeyNotExists");
        success = LibMux.cancelOrderFromOrderBook(_exchangeConfigs.orderBook, orderId);
        require(success, 'Cancel Order Failed');
        _removePendingOrder(orderId);
        emit CancelOrder(orderId, success);
    }

    // ======================== Utility methods ========================
    
    function _pendingOrdersContains(uint64 value) internal view returns(bool){
        for(uint i = 0; i < _pendingOrders.length; i++) {
            if (_pendingOrders[i] == value) {
                return true;
            }
        }
        return false;
    }

    function _pendingOrdersAdd(uint64 value) internal returns(bool){
        uint initialLength = _pendingOrders.length;
        _pendingOrders.push(value);
        if (_pendingOrders.length == initialLength + 1) {
            return true;
        } else {
            return false;
        }
    }

    function _pendingOrdersRemove(uint64 value) internal {
        uint i = 0;
        bool found = false;
        for (; i < _pendingOrders.length; i++) {
            if (_pendingOrders[i] == value) {
                found = true;
                break;
            }
        }

        if (found) {
            // Set the i-th element to the last element
            _pendingOrders[i] = _pendingOrders[_pendingOrders.length - 1];
            // Remove the last element
            _pendingOrders.pop();
        }
    }

}