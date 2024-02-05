// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/structs/EnumerableSetUpgradeable.sol";

import "../../interfaces/IGmxProxyFactory.sol";

import "../lib/LibUtils.sol";
import "./Storage.sol";
import "./Position.sol";

contract Config is Storage, Position{
    using LibUtils for bytes32;
    using LibUtils for address;
    using LibUtils for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    function _updateConfigs() internal virtual{
        (uint32 latestexchangeVersion) = IGmxProxyFactory(_factory).getConfigVersions(
            EXCHANGE_ID
        );
        if (_localexchangeVersion < latestexchangeVersion) {
            _updateExchangeConfigs();
            _localexchangeVersion = latestexchangeVersion;
        }
    }

    function _updateExchangeConfigs() internal {
        uint256[] memory values = IGmxProxyFactory(_factory).getExchangeConfig(EXCHANGE_ID);
        require(values.length >= uint256(ExchangeConfigIds.END), "MissingConfigs");

        address newPositionRouter = values[uint256(ExchangeConfigIds.POSITION_ROUTER)].toAddress();
        address newOrderBook = values[uint256(ExchangeConfigIds.ORDER_BOOK)].toAddress();
        //ToDo - is cancelling orders when we change positionRouter and orderBook really necessary?
        _onGmxAddressUpdated(
            _exchangeConfigs.positionRouter,
            _exchangeConfigs.orderBook,
            newPositionRouter,
            newOrderBook
        );
        _exchangeConfigs.vault = values[uint256(ExchangeConfigIds.VAULT)].toAddress();
        _exchangeConfigs.positionRouter = newPositionRouter;
        _exchangeConfigs.orderBook = newOrderBook;
        _exchangeConfigs.router = values[uint256(ExchangeConfigIds.ROUTER)].toAddress();
        _exchangeConfigs.referralCode = bytes32(values[uint256(ExchangeConfigIds.REFERRAL_CODE)]);
        _exchangeConfigs.marketOrderTimeoutSeconds = values[uint256(ExchangeConfigIds.MARKET_ORDER_TIMEOUT_SECONDS)]
            .toU32();
        _exchangeConfigs.limitOrderTimeoutSeconds = values[uint256(ExchangeConfigIds.LIMIT_ORDER_TIMEOUT_SECONDS)]
            .toU32();
        _exchangeConfigs.initialMarginRate = values[uint256(ExchangeConfigIds.INITIAL_MARGIN_RATE)]
            .toU32();
        _exchangeConfigs.maintenanceMarginRate = values[uint256(ExchangeConfigIds.MAINTENANCE_MARGIN_RATE)]
            .toU32();
    }

    function _onGmxAddressUpdated(
        address previousPositionRouter,
        address previousOrderBook,
        address newPostitionRouter,
        address newOrderBook
    ) internal virtual {
        bool cancelPositionRouter = previousPositionRouter != newPostitionRouter;
        bool cancelOrderBook = previousOrderBook != newOrderBook;
        bytes32[] memory pendingKeys = _pendingOrders.values();
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            bytes32 key = pendingKeys[i];
            if (cancelPositionRouter) {
                LibGmx.cancelOrderFromPositionRouter(previousPositionRouter, key);
                _removePendingOrder(key);
            }
            if (cancelOrderBook) {
                LibGmx.cancelOrderFromOrderBook(previousOrderBook, key);
                _removePendingOrder(key);
            }
        }
    }
}