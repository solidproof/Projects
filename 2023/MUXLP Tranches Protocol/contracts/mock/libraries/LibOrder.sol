// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../orderbook/Types.sol";
import "./LibSubAccount.sol";

library LibOrder {
    // position order flags
    uint8 constant POSITION_OPEN = 0x80; // this flag means openPosition; otherwise closePosition
    uint8 constant POSITION_MARKET_ORDER = 0x40; // this flag means ignore limitPrice
    uint8 constant POSITION_WITHDRAW_ALL_IF_EMPTY = 0x20; // this flag means auto withdraw all collateral if position.size == 0
    uint8 constant POSITION_TRIGGER_ORDER = 0x10; // this flag means this is a trigger order (ex: stop-loss order). otherwise this is a limit order (ex: take-profit order)
    uint8 constant POSITION_TPSL_STRATEGY = 0x08; // for open-position-order, this flag auto place take-profit and stop-loss orders when open-position-order fills.
    //                                               for close-position-order, this flag means ignore limitPrice and profitTokenId, and use extra.tpPrice, extra.slPrice, extra.tpslProfitTokenId instead.

    // order data[1] SHOULD reserve lower 64bits for enumIndex
    bytes32 constant ENUM_INDEX_BITS = bytes32(uint256(0xffffffffffffffff));

    struct OrderList {
        uint64[] _orderIds;
        mapping(uint64 => bytes32[3]) _orders;
    }

    function add(OrderList storage list, uint64 orderId, bytes32[3] memory order) internal {
        require(!contains(list, orderId), "DUP"); // already seen this orderId
        list._orderIds.push(orderId);
        // The value is stored at length-1, but we add 1 to all indexes
        // and use 0 as a sentinel value
        uint256 enumIndex = list._orderIds.length;
        require(enumIndex <= type(uint64).max, "O64"); // Overflow uint64
        // order data[1] SHOULD reserve lower 64bits for enumIndex
        require((order[1] & ENUM_INDEX_BITS) == 0, "O1F"); // bad Order[1] Field
        order[1] = bytes32(uint256(order[1]) | uint256(enumIndex));
        list._orders[orderId] = order;
    }

    function remove(OrderList storage list, uint64 orderId) internal {
        bytes32[3] storage orderToRemove = list._orders[orderId];
        uint64 enumIndexToRemove = uint64(uint256(orderToRemove[1]));
        require(enumIndexToRemove != 0, "OID"); // orderId is not found
        // swap and pop
        uint256 indexToRemove = enumIndexToRemove - 1;
        uint256 lastIndex = list._orderIds.length - 1;
        if (lastIndex != indexToRemove) {
            uint64 lastOrderId = list._orderIds[lastIndex];
            // move the last orderId
            list._orderIds[indexToRemove] = lastOrderId;
            // replace enumIndex
            bytes32[3] storage lastOrder = list._orders[lastOrderId];
            lastOrder[1] =
                (lastOrder[1] & (~ENUM_INDEX_BITS)) |
                bytes32(uint256(enumIndexToRemove));
        }
        list._orderIds.pop();
        delete list._orders[orderId];
    }

    function contains(OrderList storage list, uint64 orderId) internal view returns (bool) {
        bytes32[3] storage order = list._orders[orderId];
        // order data[1] always contains enumIndex
        return order[1] != bytes32(0);
    }

    function length(OrderList storage list) internal view returns (uint256) {
        return list._orderIds.length;
    }

    function at(
        OrderList storage list,
        uint256 index
    ) internal view returns (bytes32[3] memory order) {
        require(index < list._orderIds.length, "IDX"); // InDex overflow
        uint64 orderId = list._orderIds[index];
        order = list._orders[orderId];
    }

    function get(OrderList storage list, uint64 orderId) internal view returns (bytes32[3] memory) {
        return list._orders[orderId];
    }

    function getOrderType(bytes32[3] memory orderData) internal pure returns (OrderType) {
        return OrderType(uint8(uint256(orderData[0])));
    }

    function getOrderOwner(bytes32[3] memory orderData) internal pure returns (address) {
        return address(bytes20(orderData[0]));
    }

    // check Types.PositionOrder for schema
    function encodePositionOrder(
        uint64 orderId,
        bytes32 subAccountId,
        uint96 collateral, // erc20.decimals
        uint96 size, // 1e18
        uint96 price, // 1e18
        uint8 profitTokenId,
        uint8 flags,
        uint32 placeOrderTime,
        uint24 expire10s
    ) internal pure returns (bytes32[3] memory data) {
        require((subAccountId & LibSubAccount.SUB_ACCOUNT_ID_FORBIDDEN_BITS) == 0, "AID"); // bad subAccount ID
        data[0] =
            subAccountId |
            bytes32(uint256(orderId) << 8) |
            bytes32(uint256(OrderType.PositionOrder));
        data[1] = bytes32(
            (uint256(size) << 160) |
                (uint256(profitTokenId) << 152) |
                (uint256(flags) << 144) |
                (uint256(expire10s) << 96) |
                (uint256(placeOrderTime) << 64)
        );
        data[2] = bytes32((uint256(price) << 160) | (uint256(collateral) << 64));
    }

    // check Types.PositionOrder for schema
    function decodePositionOrder(
        bytes32[3] memory data
    ) internal pure returns (PositionOrder memory order) {
        order.id = uint64(bytes8(data[0] << 184));
        order.subAccountId = bytes32(bytes23(data[0]));
        order.collateral = uint96(bytes12(data[2] << 96));
        order.size = uint96(bytes12(data[1]));
        order.flags = uint8(bytes1(data[1] << 104));
        order.price = uint96(bytes12(data[2]));
        order.profitTokenId = uint8(bytes1(data[1] << 96));
        order.expire10s = uint24(bytes3(data[1] << 136));
        order.placeOrderTime = uint32(bytes4(data[1] << 160));
    }

    // check Types.LiquidityOrder for schema
    function encodeLiquidityOrder(
        uint64 orderId,
        address account,
        uint8 assetId,
        uint96 rawAmount, // erc20.decimals
        bool isAdding,
        uint32 placeOrderTime
    ) internal pure returns (bytes32[3] memory data) {
        uint8 flags = isAdding ? 1 : 0;
        data[0] = bytes32(
            (uint256(uint160(account)) << 96) |
                (uint256(orderId) << 8) |
                uint256(OrderType.LiquidityOrder)
        );
        data[1] = bytes32(
            (uint256(rawAmount) << 160) |
                (uint256(assetId) << 152) |
                (uint256(flags) << 144) |
                (uint256(placeOrderTime) << 64)
        );
    }

    // check Types.LiquidityOrder for schema
    function decodeLiquidityOrder(
        bytes32[3] memory data
    ) internal pure returns (LiquidityOrder memory order) {
        order.id = uint64(bytes8(data[0] << 184));
        order.account = address(bytes20(data[0]));
        order.rawAmount = uint96(bytes12(data[1]));
        order.assetId = uint8(bytes1(data[1] << 96));
        uint8 flags = uint8(bytes1(data[1] << 104));
        order.isAdding = flags > 0;
        order.placeOrderTime = uint32(bytes4(data[1] << 160));
    }

    // check Types.WithdrawalOrder for schema
    function encodeWithdrawalOrder(
        uint64 orderId,
        bytes32 subAccountId,
        uint96 rawAmount, // erc20.decimals
        uint8 profitTokenId,
        bool isProfit,
        uint32 placeOrderTime
    ) internal pure returns (bytes32[3] memory data) {
        require((subAccountId & LibSubAccount.SUB_ACCOUNT_ID_FORBIDDEN_BITS) == 0, "AID"); // bad subAccount ID
        uint8 flags = isProfit ? 1 : 0;
        data[0] =
            subAccountId |
            bytes32(uint256(orderId) << 8) |
            bytes32(uint256(OrderType.WithdrawalOrder));
        data[1] = bytes32(
            (uint256(rawAmount) << 160) |
                (uint256(profitTokenId) << 152) |
                (uint256(flags) << 144) |
                (uint256(placeOrderTime) << 64)
        );
    }

    // check Types.WithdrawalOrder for schema
    function decodeWithdrawalOrder(
        bytes32[3] memory data
    ) internal pure returns (WithdrawalOrder memory order) {
        order.subAccountId = bytes32(bytes23(data[0]));
        order.rawAmount = uint96(bytes12(data[1]));
        order.profitTokenId = uint8(bytes1(data[1] << 96));
        uint8 flags = uint8(bytes1(data[1] << 104));
        order.isProfit = flags > 0;
        order.placeOrderTime = uint32(bytes4(data[1] << 160));
    }

    // check Types.RebalanceOrder for schema
    function encodeRebalanceOrder(
        uint64 orderId,
        address rebalancer,
        uint8 tokenId0,
        uint8 tokenId1,
        uint96 rawAmount0, // erc20.decimals
        uint96 maxRawAmount1, // erc20.decimals
        bytes32 userData
    ) internal pure returns (bytes32[3] memory data) {
        data[0] = bytes32(
            (uint256(uint160(rebalancer)) << 96) |
                (uint256(tokenId0) << 88) |
                (uint256(tokenId1) << 80) |
                (uint256(orderId) << 8) |
                uint256(OrderType.RebalanceOrder)
        );
        data[1] = bytes32((uint256(rawAmount0) << 160) | (uint256(maxRawAmount1) << 64));
        data[2] = userData;
    }

    // check Types.RebalanceOrder for schema
    function decodeRebalanceOrder(
        bytes32[3] memory data
    ) internal pure returns (RebalanceOrder memory order) {
        order.rebalancer = address(bytes20(data[0]));
        order.tokenId0 = uint8(bytes1(data[0] << 160));
        order.tokenId1 = uint8(bytes1(data[0] << 168));
        order.rawAmount0 = uint96(bytes12(data[1]));
        order.maxRawAmount1 = uint96(bytes12(data[1] << 96));
        order.userData = data[2];
    }

    function isOpenPosition(PositionOrder memory order) internal pure returns (bool) {
        return (order.flags & POSITION_OPEN) != 0;
    }

    function isMarketOrder(PositionOrder memory order) internal pure returns (bool) {
        return (order.flags & POSITION_MARKET_ORDER) != 0;
    }

    function isWithdrawIfEmpty(PositionOrder memory order) internal pure returns (bool) {
        return (order.flags & POSITION_WITHDRAW_ALL_IF_EMPTY) != 0;
    }

    function isTriggerOrder(PositionOrder memory order) internal pure returns (bool) {
        return (order.flags & POSITION_TRIGGER_ORDER) != 0;
    }

    function isTpslStrategy(PositionOrder memory order) internal pure returns (bool) {
        return (order.flags & POSITION_TPSL_STRATEGY) != 0;
    }
}
