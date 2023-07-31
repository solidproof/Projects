// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IMuxLiquidityCallback {
    struct LiquidityOrder {
        uint64 id;
        address account;
        uint96 rawAmount; // erc20.decimals
        uint8 assetId;
        bool isAdding;
        uint32 placeOrderTime; // 1e0
    }

    function beforeFillLiquidityOrder(
        LiquidityOrder calldata order, // the order to be filled
        uint96 assetPrice, // the price of asset used in add / remove liquidity
        uint96 mlpPrice, // the price of mlp
        uint96 currentAssetValue, // the param used to calculate fee for liquidity
        uint96 targetAssetValue // the param used to calculate fee for liquidity
    ) external returns (bool);

    function afterFillLiquidityOrder(
        LiquidityOrder calldata order, // the order to be filled
        uint256 outAmount, // the output amount of the order (that is: mlp output amount for adding and asset output amount for removing)
        uint96 assetPrice, // the price of asset used in add / remove liquidity
        uint96 mlpPrice, // the price of mlp
        uint96 currentAssetValue, // the param used to calculate fee for liquidity
        uint96 targetAssetValue // the param used to calculate fee for liquidity
    ) external;

    function afterCancelLiquidityOrder(LiquidityOrder calldata order) external; // the order to be filled
}
