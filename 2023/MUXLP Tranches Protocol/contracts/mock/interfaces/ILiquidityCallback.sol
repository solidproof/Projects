// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../orderbook/Types.sol";

interface ILiquidityCallback {
    function beforeFillLiquidityOrder(
        LiquidityOrder calldata order,
        uint96 assetPrice,
        uint96 mlpPrice,
        uint96 currentAssetValue,
        uint96 targetAssetValue
    ) external returns (bool);

    function afterFillLiquidityOrder(
        LiquidityOrder calldata order,
        uint256 outAmount,
        uint96 assetPrice,
        uint96 mlpPrice,
        uint96 currentAssetValue,
        uint96 targetAssetValue
    ) external;

    function afterCancelLiquidityOrder(LiquidityOrder calldata order) external;
}
