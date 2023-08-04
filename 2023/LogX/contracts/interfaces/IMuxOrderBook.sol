// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../aggregators/mux/Types.sol";

interface IMuxOrderBook {

    enum OrderType {
        None, // 0
        PositionOrder, // 1
        LiquidityOrder, // 2
        WithdrawalOrder, // 3
        RebalanceOrder // 4
    }

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
    event CancelOrder(uint64 orderId, OrderType orderType, bytes32[3] orderData);

    function getOrderCount() external view returns (uint256);
    function getOrder(uint64 orderId) external view returns (bytes32[3] memory, bool);
    function getOrders(
        uint256 begin,
        uint256 end
    ) external view returns (bytes32[3][] memory orderArray, uint256 totalCount);
    function placePositionOrder2(
        bytes32 subAccountId,
        uint96 collateralAmount, // erc20.decimals
        uint96 size, // 1e18
        uint96 price, // 1e18
        uint8 profitTokenId,
        uint8 flags,
        uint32 deadline, // 1e0
        bytes32 referralCode
    ) external payable;
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
    ) external payable;
    function placeLiquidityOrder(
        uint8 assetId,
        uint96 rawAmount, // erc20.decimals
        bool isAdding
    ) external payable;
    function placeWithdrawalOrder(
        bytes32 subAccountId,
        uint96 rawAmount, // erc20.decimals
        uint8 profitTokenId,
        bool isProfit
    ) external;
    function cancelOrder(uint64 orderId) external;
    function withdrawAllCollateral(bytes32 subAccountId) external;
    function depositCollateral(bytes32 subAccountId, uint256 collateralAmount) external payable;
    function redeemMuxToken(uint8 tokenId, uint96 muxTokenAmount) external;

}