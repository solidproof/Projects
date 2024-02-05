// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/structs/EnumerableSetUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/math/SafeMathUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";

import "../lib/LibUtils.sol";
import "./lib/LibGmx.sol";
import "./Storage.sol";

contract Position  is Storage{
    using LibUtils for uint256;
    using MathUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.Bytes32ToBytes32Map;

    uint256 internal constant GMX_DECIMAL_MULTIPLIER = 1e12; // 30 - 18
    uint256 internal constant MAX_PENDING_ORDERS = 64;

    event AddPendingOrder(
        LibGmx.OrderCategory category,
        LibGmx.OrderReceiver receiver,
        uint256 index,
        uint256 timestamp
    );
    event RemovePendingOrder(bytes32 key);
    event CancelOrder(bytes32 key, bool success);

    event OpenPosition(address collateralToken, address indexToken, bool isLong, OpenPositionContext context);
    event ClosePosition(address collateralToken, address indexToken, bool isLong, ClosePositionContext context);

    function _hasPendingOrder(bytes32 key) internal view returns (bool) {
        return _pendingOrders.contains(key);
    }

    function _getPendingOrders() internal view returns (bytes32[] memory) {
        return _pendingOrders.values();
    }

    function _removePendingOrder(bytes32 key) internal {
        _pendingOrders.remove(key);
        emit RemovePendingOrder(key);
    }

    function _getGmxPosition() internal view returns (IGmxVault.Position memory) {
        return IGmxVault(_exchangeConfigs.vault).positions(_gmxPositionKey);
    }

    function _addPendingOrder(
        LibGmx.OrderCategory category,
        LibGmx.OrderReceiver receiver
    ) internal returns (uint256 index, bytes32 orderKey) {
        index = LibGmx.getOrderIndex(_exchangeConfigs, receiver);
        orderKey = LibGmx.encodeOrderHistoryKey(category, receiver, index, block.timestamp);
        require(_pendingOrders.add(orderKey), "AddFailed");
        emit AddPendingOrder(category, receiver, index, block.timestamp);
    }

    function _getMarginValue(
        IGmxVault.Position memory position,
        uint256 deltaCollateral,
        uint256 priceUsd
    ) internal view returns (uint256 accountValue, bool isNegative) {
        bool hasProfit = false;
        uint256 gmxPnlUsd = 0;
        uint256 gmxFundingFeeUsd = 0;
        // 1. gmx pnl and funding, 1e30
        if (position.sizeUsd != 0) {
            (hasProfit, gmxPnlUsd) = LibGmx.getPnl(
                _exchangeConfigs,
                _account.indexToken,
                position.sizeUsd,
                position.averagePrice,
                _account.isLong,
                priceUsd,
                position.lastIncreasedTime
            );
            gmxFundingFeeUsd = IGmxVault(_exchangeConfigs.vault).getFundingFee(
                _account.collateralToken,
                position.sizeUsd,
                position.entryFundingRate
            );
        }
        //ToDo - need to double check the below formulae to make sure they are solid
        int256 value = int256(position.collateralUsd) +
            (hasProfit ? int256(gmxPnlUsd) : -int256(gmxPnlUsd)) -
            int256(gmxFundingFeeUsd);
        if (_account.isLong) {
            value += (int256(deltaCollateral) * int256(position.averagePrice)) / int256(10**_account.collateralDecimals); // 1e30
        } else {
            uint256 tokenPrice = LibGmx.getOraclePrice(_exchangeConfigs, _account.collateralToken, false); // 1e30
            value += (int256(deltaCollateral) * int256(tokenPrice)) / int256(10**_account.collateralDecimals); // 1e30
        }
        if (value > 0) {
            accountValue = uint256(value);
            isNegative = false;
        } else {
            accountValue = uint256(-value);
            isNegative = true;
        }
    }

    function _isMarginSafe(
        IGmxVault.Position memory position,
        uint256 deltaCollateralUsd,
        uint256 deltaSizeUsd,
        uint256 priceUsd,
        uint32 threshold
    ) internal view returns (bool) {
        if (position.sizeUsd == 0) {
            return true;
        }
        (uint256 accountValue, bool isNegative) = _getMarginValue(position, deltaCollateralUsd, priceUsd); // 1e30
        if (isNegative) {
            return false;
        }
        uint256 liquidationFeeUsd = IGmxVault(_exchangeConfigs.vault).liquidationFeeUsd();
        return accountValue >= (position.sizeUsd + deltaSizeUsd).rate(threshold).max(liquidationFeeUsd);
    }

    function _openPosition(OpenPositionContext memory context) internal returns(bytes32 orderKey){
        require(_pendingOrders.length() <= MAX_PENDING_ORDERS, "TooManyPendingOrders");
        IGmxVault.Position memory position = _getGmxPosition();
        require(
            _isMarginSafe(
                position,
                context.amountIn,
                context.sizeUsd,
                LibGmx.getOraclePrice(_exchangeConfigs, _account.indexToken, !_account.isLong),
                _exchangeConfigs.initialMarginRate
            ),
            "ImMarginUnsafe"
        );
        address[] memory path = new address[](1);
        path[0] = _account.collateralToken;
        if (context.isMarket) {
            context.executionFee = LibGmx.getPrExecutionFee(_exchangeConfigs);
            IGmxPositionRouter(_exchangeConfigs.positionRouter).createIncreasePosition{ value: context.executionFee }(
                path,
                _account.indexToken,
                context.amountIn,
                0,
                context.sizeUsd,
                _account.isLong,
                _account.isLong ? type(uint256).max : 0,
                context.executionFee,
                _exchangeConfigs.referralCode,
                address(0)
            );
            (context.gmxOrderIndex, orderKey) = _addPendingOrder(
                LibGmx.OrderCategory.OPEN,
                LibGmx.OrderReceiver.PR_INC
            );
        } else {
            context.executionFee = LibGmx.getObExecutionFee(_exchangeConfigs);
            IGmxOrderBook(_exchangeConfigs.orderBook).createIncreaseOrder{ value: context.executionFee }(
                path,
                context.amountIn,
                _account.indexToken,
                0,
                context.sizeUsd,
                _account.collateralToken,
                _account.isLong,
                context.priceUsd,
                !_account.isLong,
                context.executionFee,
                false
            );
            (context.gmxOrderIndex, orderKey) = _addPendingOrder(
                LibGmx.OrderCategory.OPEN,
                LibGmx.OrderReceiver.OB_INC
            );
        }
        emit OpenPosition(_account.collateralToken, _account.indexToken, _account.isLong, context);
    }

    function _closePosition(ClosePositionContext memory context) internal returns(bytes32 orderKey){
        require(_pendingOrders.length() <= MAX_PENDING_ORDERS * 2, "TooManyPendingOrders");

        IGmxVault.Position memory position = _getGmxPosition();
        require(
            _isMarginSafe(
                position,
                0,
                0,
                LibGmx.getOraclePrice(_exchangeConfigs, _account.indexToken, !_account.isLong),
                _exchangeConfigs.maintenanceMarginRate
            ),
            "MmMarginUnsafe"
        );

        address[] memory path = new address[](1);
        path[0] = _account.collateralToken;
        if (context.isMarket) {
            context.executionFee = LibGmx.getPrExecutionFee(_exchangeConfigs);
            context.priceUsd = _account.isLong ? 0 : type(uint256).max;
            IGmxPositionRouter(_exchangeConfigs.positionRouter).createDecreasePosition{ value: context.executionFee }(
                path, // no swap for collateral
                _account.indexToken,
                context.collateralUsd,
                context.sizeUsd,
                _account.isLong, // no swap for collateral
                address(this),
                context.priceUsd,
                0,
                context.executionFee,
                false,
                address(0)
            );
            (context.gmxOrderIndex, orderKey) = _addPendingOrder(LibGmx.OrderCategory.CLOSE, LibGmx.OrderReceiver.PR_DEC);
        } else {
            context.executionFee = LibGmx.getObExecutionFee(_exchangeConfigs);
            uint256 oralcePrice = LibGmx.getOraclePrice(_exchangeConfigs, _account.indexToken, !_account.isLong);
            uint256 priceUsd = context.priceUsd;
            IGmxOrderBook(_exchangeConfigs.orderBook).createDecreaseOrder{ value: context.executionFee }(
                _account.indexToken,
                context.sizeUsd,
                _account.collateralToken,
                context.collateralUsd,
                _account.isLong,
                priceUsd,
                priceUsd >= oralcePrice
            );
            (context.gmxOrderIndex, orderKey) = _addPendingOrder(LibGmx.OrderCategory.CLOSE, LibGmx.OrderReceiver.OB_DEC);
        }
        emit ClosePosition(_account.collateralToken, _account.indexToken, _account.isLong, context);
    }

    function _cancelOrder(bytes32 key) internal returns (bool success) {
        require(_hasPendingOrder(key), "KeyNotExists");
        success = LibGmx.cancelOrder(_exchangeConfigs, key);
        require(success, 'Cancel Order Failed');
        _removePendingOrder(key);
        emit CancelOrder(key, success);
    }

    function _cancelTpslOrders(bytes32 orderKey) internal returns (bool success) {
        (bool exists, bytes32 tpslIndex) = _openTpslOrderIndexes.tryGet(orderKey);
        if (!exists) {
            success = true;
        } else {
            (bytes32 tpOrderKey, bytes32 slOrderKey) = LibGmx.decodeTpslIndex(orderKey, tpslIndex);
            if (_cancelOrder(tpOrderKey) && _cancelOrder(slOrderKey)) {
                _openTpslOrderIndexes.remove(orderKey);
                success = true;
            }
        }
    }
}