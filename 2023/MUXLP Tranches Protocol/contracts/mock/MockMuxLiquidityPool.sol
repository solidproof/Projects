// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../interfaces/mux/IMuxLiquidityPool.sol";

contract MockMuxLiquidityPool {
    mapping(uint8 => IMuxLiquidityPool.Asset) assets;
    uint8 public assetCount;
    uint96 public upperBound;
    uint96 public lowerBound;

    function addAsset(address token) external {
        assets[assetCount].tokenAddress = token;
        assetCount++;
    }

    function setBound(uint96 lowerBound_, uint96 upperBound_) external {
        lowerBound = lowerBound_;
        upperBound = upperBound_;
    }

    function getAssetInfo(
        uint8 assetId
    ) external view returns (IMuxLiquidityPool.Asset memory asset_) {
        asset_ = assets[assetId];
    }

    function getAllAssetInfo() external view returns (IMuxLiquidityPool.Asset[] memory assets_) {
        assets_ = new IMuxLiquidityPool.Asset[](assetCount);
        for (uint8 i = 0; i < assetCount; i++) {
            assets_[i] = assets[i];
        }
    }

    function getLiquidityPoolStorage()
        external
        view
        returns (
            // [0] shortFundingBaseRate8H
            // [1] shortFundingLimitRate8H
            // [2] lastFundingTime
            // [3] fundingInterval
            // [4] liquidityBaseFeeRate
            // [5] liquidityDynamicFeeRate
            // [6] sequence. note: will be 0 after 0xffffffff
            // [7] strictStableDeviation
            uint32[8] memory u32s,
            // [0] mlpPriceLowerBound
            // [1] mlpPriceUpperBound
            uint96[2] memory u96s
        )
    {
        u96s[0] = lowerBound;
        u96s[1] = upperBound;
    }
}
