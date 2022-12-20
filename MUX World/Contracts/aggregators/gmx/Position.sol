// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "../../interfaces/ILiquidityPool.sol";
import "../../interfaces/IProxyFactory.sol";

import "./libs/LibGmx.sol";
import "./libs/LibUtils.sol";
import "./Storage.sol";
import "./Debt.sol";

contract Position is Storage, Debt {
    using LibUtils for uint256;
    using MathUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    uint256 internal constant GMX_DECIMAL_MULTIPLIER = 1e12; // 30 - 18
    uint256 internal constant MAX_PENDING_ORDERS = 64;

    event AddPendingOrder(
        LibGmx.OrderCategory category,
        LibGmx.OrderReceiver receiver,
        uint256 index,
        uint256 borrow,
        uint256 timestamp
    );
    event RemovePendingOrder(bytes32 key);
    event CancelOrder(bytes32 key, bool success);

    event OpenPosition(address collateralToken, address indexToken, bool isLong, OpenPositionContext context);
    event ClosePosition(address collateralToken, address indexToken, bool isLong, ClosePositionContext context);
    event LiquidatePosition(
        address collateralToken,
        address indexToken,
        bool isLong,
        uint256 liquidationPrice,
        uint256 estimateliquidationFee,
        IGmxVault.Position position
    );

    function _hasPendingOrder(bytes32 key) internal view returns (bool) {
        return _pendingOrders.contains(key);
    }

    function _getPendingOrders() internal view returns (bytes32[] memory) {
        return _pendingOrders.values();
    }

    function _isIncreasingOrder(bytes32 key) internal pure returns (bool) {
        LibGmx.OrderReceiver receiver = LibGmx.OrderReceiver(uint8(bytes1(key << 8)));
        return receiver == LibGmx.OrderReceiver.PR_INC || receiver == LibGmx.OrderReceiver.OB_INC;
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
                _projectConfigs,
                _account.indexToken,
                position.sizeUsd,
                position.averagePrice,
                _account.isLong,
                priceUsd,
                position.lastIncreasedTime
            );
            gmxFundingFeeUsd = IGmxVault(_projectConfigs.vault).getFundingFee(
                _account.collateralToken,
                position.sizeUsd,
                position.entryFundingRate
            );
        }
        (uint256 muxFundingFee, ) = _getMuxFundingFee();
        uint256 inflightBorrow = _calcInflightBorrow(); // collateral
        int256 value = int256(position.collateralUsd) +
            (hasProfit ? int256(gmxPnlUsd) : -int256(gmxPnlUsd)) -
            int256(gmxFundingFeeUsd);
        int256 effectiveDebt = (int256(_account.cumulativeDebt + _account.cumulativeFee + muxFundingFee) -
            int256(inflightBorrow + deltaCollateral));
        if (_account.isLong) {
            value -= (effectiveDebt * int256(position.averagePrice)) / int256(10**_account.collateralDecimals); // 1e30
        } else {
            uint256 tokenPrice = LibGmx.getOraclePrice(_projectConfigs, _account.collateralToken, false); // 1e30
            value -= (effectiveDebt * int256(tokenPrice)) / int256(10**_account.collateralDecimals); // 1e30
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
        uint256 liquidationFeeUsd = IGmxVault(_projectConfigs.vault).liquidationFeeUsd();
        return accountValue >= (position.sizeUsd + deltaSizeUsd).rate(threshold).max(liquidationFeeUsd);
    }

    function _getGmxPosition() internal view returns (IGmxVault.Position memory) {
        return IGmxVault(_projectConfigs.vault).positions(_gmxPositionKey);
    }

    function _openPosition(OpenPositionContext memory context) internal {
        require(_pendingOrders.length() <= MAX_PENDING_ORDERS, "TooManyPendingOrders");
        IGmxVault.Position memory position = _getGmxPosition();
        require(
            _isMarginSafe(
                position,
                context.amountIn,
                context.sizeUsd,
                LibGmx.getOraclePrice(_projectConfigs, _account.indexToken, !_account.isLong),
                _assetConfigs.initialMarginRate
            ),
            "ImMarginUnsafe"
        );
        address[] memory path = new address[](1);
        path[0] = _account.collateralToken;
        if (context.isMarket) {
            IGmxPositionRouter(_projectConfigs.positionRouter).createIncreasePosition{ value: context.executionFee }(
                path,
                _account.indexToken,
                context.amountIn,
                0,
                context.sizeUsd,
                _account.isLong,
                _account.isLong ? type(uint256).max : 0,
                context.executionFee,
                _projectConfigs.referralCode,
                address(0)
            );
            context.gmxOrderIndex = _addPendingOrder(
                LibGmx.OrderCategory.OPEN,
                LibGmx.OrderReceiver.PR_INC,
                context.borrow
            );
        } else {
            IGmxOrderBook(_projectConfigs.orderBook).createIncreaseOrder{ value: context.executionFee }(
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
            context.gmxOrderIndex = _addPendingOrder(
                LibGmx.OrderCategory.OPEN,
                LibGmx.OrderReceiver.OB_INC,
                context.borrow
            );
        }
        emit OpenPosition(_account.collateralToken, _account.indexToken, _account.isLong, context);
    }

    function _closePosition(ClosePositionContext memory context) internal {
        require(_pendingOrders.length() <= MAX_PENDING_ORDERS * 2, "TooManyPendingOrders");

        IGmxVault.Position memory position = _getGmxPosition();
        require(
            _isMarginSafe(
                position,
                0,
                0,
                LibGmx.getOraclePrice(_projectConfigs, _account.indexToken, !_account.isLong),
                _assetConfigs.maintenanceMarginRate
            ),
            "MmMarginUnsafe"
        );

        uint256 executionFee = msg.value;
        address[] memory path = new address[](1);
        path[0] = _account.collateralToken;
        if (context.isMarket) {
            context.priceUsd = _account.isLong ? 0 : type(uint256).max;
            IGmxPositionRouter(_projectConfigs.positionRouter).createDecreasePosition{ value: executionFee }(
                path, // no swap for collateral
                _account.indexToken,
                context.collateralUsd,
                context.sizeUsd,
                _account.isLong, // no swap for collateral
                address(this),
                context.priceUsd,
                0,
                msg.value,
                false,
                address(0)
            );
            context.gmxOrderIndex = _addPendingOrder(LibGmx.OrderCategory.CLOSE, LibGmx.OrderReceiver.PR_DEC, 0);
        } else {
            uint256 oralcePrice = LibGmx.getOraclePrice(_projectConfigs, _account.indexToken, !_account.isLong);
            uint256 priceUsd = context.priceUsd;
            IGmxOrderBook(_projectConfigs.orderBook).createDecreaseOrder{ value: executionFee }(
                _account.indexToken,
                context.sizeUsd,
                _account.collateralToken,
                context.collateralUsd,
                _account.isLong,
                priceUsd,
                priceUsd >= oralcePrice
            );
            context.gmxOrderIndex = _addPendingOrder(LibGmx.OrderCategory.CLOSE, LibGmx.OrderReceiver.OB_DEC, 0);
        }
        emit ClosePosition(_account.collateralToken, _account.indexToken, _account.isLong, context);
    }

    function _liquidatePosition(IGmxVault.Position memory position, uint256 liquidationPrice) internal {
        require(
            !_isMarginSafe(position, 0, 0, liquidationPrice * 1e12, _assetConfigs.maintenanceMarginRate),
            "MmMarginSafe"
        );
        uint256 executionFee = msg.value;
        // cancel all orders inflight
        bytes32[] memory pendingKeys = _pendingOrders.values();
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            LibGmx.cancelOrder(_projectConfigs, pendingKeys[i]);
        }
        // place market liquidate order
        uint256 markPrice = _account.isLong ? 0 : type(uint256).max;
        address[] memory path = new address[](1);
        path[0] = _account.collateralToken;
        IGmxPositionRouter(_projectConfigs.positionRouter).createDecreasePosition{ value: executionFee }(
            path,
            _account.indexToken,
            0,
            position.sizeUsd,
            _account.isLong,
            address(this),
            markPrice,
            0,
            executionFee,
            false,
            address(0)
        );
        _addPendingOrder(LibGmx.OrderCategory.LIQUIDATE, LibGmx.OrderReceiver.PR_INC, 0);
        emit LiquidatePosition(
            _account.collateralToken,
            _account.indexToken,
            _account.isLong,
            liquidationPrice,
            _account.liquidationFee,
            position
        );
    }

    function _cancelOrder(bytes32 key) internal returns (bool success) {
        require(_hasPendingOrder(key), "KeyNotExists");
        success = LibGmx.cancelOrder(_projectConfigs, key);
        _removePendingOrder(key);
        emit CancelOrder(key, success);
    }

    function _removePendingOrder(bytes32 key) internal {
        _pendingOrders.remove(key);
        emit RemovePendingOrder(key);
    }

    function _addPendingOrder(
        LibGmx.OrderCategory category,
        LibGmx.OrderReceiver receiver,
        uint256 borrow
    ) internal returns (uint256 index) {
        index = LibGmx.getOrderIndex(_projectConfigs, receiver);
        require(
            _pendingOrders.add(LibGmx.encodeOrderHistoryKey(category, receiver, index, borrow, block.timestamp)),
            "AddFailed"
        );
        emit AddPendingOrder(category, receiver, index, borrow, block.timestamp);
    }

    function _calcInflightBorrow() internal view returns (uint256 inflightBorrow) {
        bytes32[] memory pendingKeys = _pendingOrders.values();
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            bytes32 key = pendingKeys[i];
            if (_hasPendingOrder(key) && _isIncreasingOrder(key)) {
                (bool isFilled, LibGmx.OrderHistory memory history) = LibGmx.getOrder(_projectConfigs, key);
                if (!isFilled) {
                    inflightBorrow += history.borrow;
                }
            }
        }
    }
}
