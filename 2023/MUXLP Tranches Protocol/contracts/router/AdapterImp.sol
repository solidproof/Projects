// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "../libraries/LibAsset.sol";
import "../libraries/LibReferenceOracle.sol";

import "../interfaces/mux/IMuxLiquidityPool.sol";
import "../interfaces/mux/IMuxOrderBook.sol";
import "../interfaces/mux/IMuxRewardRouter.sol";
import "../interfaces/mux/IMuxVester.sol";

import "./UtilsImp.sol";
import "./Type.sol";

library AdapterImp {
    using UtilsImp for RouterStateStore;
    using LibAsset for IMuxLiquidityPool.Asset;
    using LibTypeCast for uint256;
    using LibConfigSet for LibConfigSet.ConfigSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function retrieveMuxAssetId(
        RouterStateStore storage store,
        address token
    ) public returns (uint8) {
        require(token != address(0), "AdapterImp::INVALID_TOKEN");
        uint8 assetId = store.idLookupTable[token];
        if (assetId == 0) {
            updateMuxAssetId(store);
            assetId = store.idLookupTable[token];
        }
        require(assetId != 0, "AdapterImp::INVALID_ASSET");
        return assetId - 1;
    }

    function updateMuxAssetId(RouterStateStore storage store) public {
        IMuxLiquidityPool liquidityPool = IMuxLiquidityPool(
            store.config.mustGetAddress(MUX_LIQUIDITY_POOL)
        );
        require(address(liquidityPool) != address(0), "AdapterImp::INVALID_POOL");
        IMuxLiquidityPool.Asset[] memory assets = liquidityPool.getAllAssetInfo();
        for (uint256 i = 0; i < assets.length; i++) {
            store.idLookupTable[assets[i].tokenAddress] = assets[i].id + 1;
        }
    }

    function cancelOrder(
        RouterStateStore storage store,
        uint64 orderId
    ) internal returns (bool success) {
        IMuxOrderBook muxOrderBook = IMuxOrderBook(store.config.mustGetAddress(MUX_ORDER_BOOK));
        try muxOrderBook.cancelOrder(orderId) {
            success = true;
        } catch {
            success = false;
        }
    }

    function placeAddOrder(
        RouterStateStore storage store,
        uint256 usdAmount
    ) internal returns (uint64 orderId) {
        IMuxOrderBook muxOrderBook = IMuxOrderBook(store.config.mustGetAddress(MUX_ORDER_BOOK));
        orderId = muxOrderBook.nextOrderId();
        IERC20Upgradeable(store.seniorVault.depositToken()).approve(
            address(muxOrderBook),
            usdAmount
        );
        muxOrderBook.placeLiquidityOrder(
            retrieveMuxAssetId(store, store.seniorVault.depositToken()),
            uint96(usdAmount),
            true
        );
    }

    function placeRemoveOrder(
        RouterStateStore storage store,
        uint256 amount
    ) internal returns (uint64 orderId) {
        IMuxOrderBook muxOrderBook = IMuxOrderBook(store.config.mustGetAddress(MUX_ORDER_BOOK));
        orderId = muxOrderBook.nextOrderId();
        IERC20Upgradeable(store.juniorVault.depositToken()).approve(address(muxOrderBook), amount);
        muxOrderBook.placeLiquidityOrder(
            retrieveMuxAssetId(store, store.seniorVault.depositToken()),
            uint96(amount),
            false
        );
    }

    // mlp => usd, calc mlp
    function estimateMaxIn(
        RouterStateStore storage store,
        uint256 minSeniorOut
    ) internal view returns (uint256 maxJuniorIn) {
        // estimated mlp = out * tokenPrice / mlpPrice / (1 - feeRate)
        // feeRate = dynamic + base
        IMuxLiquidityPool muxLiquidityPool = IMuxLiquidityPool(
            store.config.mustGetAddress(MUX_LIQUIDITY_POOL)
        );
        (uint32[8] memory u32s, uint96[2] memory bounds) = muxLiquidityPool
            .getLiquidityPoolStorage();
        uint256 maxFeeRate = u32s[4] + u32s[5];
        uint256 minPrice = bounds[0];
        minSeniorOut = store.toJuniorUnit(minSeniorOut);
        maxJuniorIn = (((minSeniorOut * ONE) / minPrice) * 1e5) / (1e5 - maxFeeRate);
    }

    struct LiquidityPoolConfig {
        uint32 strictStableDeviation;
        uint32 liquidityBaseFeeRate;
        uint32 liquidityDynamicFeeRate;
    }

    function getLiquidityPoolConfig(
        IMuxLiquidityPool muxLiquidityPool
    ) internal view returns (LiquidityPoolConfig memory config) {
        (uint32[8] memory u32s, ) = muxLiquidityPool.getLiquidityPoolStorage();
        config.strictStableDeviation = u32s[7];
        config.liquidityBaseFeeRate = u32s[4];
        config.liquidityDynamicFeeRate = u32s[5];
    }

    function estimateExactOut(
        RouterStateStore storage store,
        uint8 seniorAssetId,
        uint256 juniorAmount,
        uint96 seniorPrice,
        uint96 juniorPrice,
        uint96 currentSeniorValue,
        uint96 targetSeniorValue
    ) internal view returns (uint256 outAmount) {
        IMuxLiquidityPool muxLiquidityPool = IMuxLiquidityPool(
            store.config.mustGetAddress(MUX_LIQUIDITY_POOL)
        );
        IMuxLiquidityPool.Asset memory seniorAsset = muxLiquidityPool.getAssetInfo(seniorAssetId);
        LiquidityPoolConfig memory config = getLiquidityPoolConfig(muxLiquidityPool);
        require(seniorAsset.isEnabled(), "AdapterImp::DISABLED_ASSET"); // the token is temporarily not ENAbled
        require(seniorAsset.canAddRemoveLiquidity(), "AdapterImp::FORBIDDEN_ASSET"); // the Token cannot be Used to add Liquidity
        seniorPrice = LibReferenceOracle.checkPriceWithSpread(
            seniorAsset,
            seniorPrice,
            config.strictStableDeviation,
            SpreadType.Ask
        );
        // token amount
        uint96 wadAmount = ((uint256(juniorAmount) * uint256(juniorPrice)) / uint256(seniorPrice))
            .toUint96();
        // fee
        uint32 mlpFeeRate = _getLiquidityFeeRate(
            currentSeniorValue,
            targetSeniorValue,
            true,
            ((uint256(wadAmount) * seniorPrice) / 1e18).toUint96(),
            config.liquidityBaseFeeRate,
            config.liquidityDynamicFeeRate
        );
        wadAmount -= ((uint256(wadAmount) * mlpFeeRate) / 1e5).toUint96(); // -fee
        outAmount = seniorAsset.toRaw(wadAmount);
    }

    function estimateMlpExactOut(
        RouterStateStore storage store,
        uint8 seniorAssetId,
        uint256 seniorAmount,
        uint96 seniorPrice,
        uint96 juniorPrice,
        uint96 currentSeniorValue,
        uint96 targetSeniorValue
    ) internal view returns (uint256 outAmount) {
        IMuxLiquidityPool muxLiquidityPool = IMuxLiquidityPool(
            store.config.mustGetAddress(MUX_LIQUIDITY_POOL)
        );
        IMuxLiquidityPool.Asset memory seniorAsset = muxLiquidityPool.getAssetInfo(seniorAssetId);
        LiquidityPoolConfig memory config = getLiquidityPoolConfig(muxLiquidityPool);
        require(seniorAsset.isEnabled(), "AdapterImp::DISABLED_ASSET"); // the token is temporarily not ENAbled
        require(seniorAsset.canAddRemoveLiquidity(), "AdapterImp::FORBIDDEN_ASSET"); // the Token cannot be Used to add Liquidity
        seniorPrice = LibReferenceOracle.checkPriceWithSpread(
            seniorAsset,
            seniorPrice,
            config.strictStableDeviation,
            SpreadType.Bid
        );
        // token amount
        uint96 wadAmount = seniorAsset.toWad(seniorAmount).toUint96();
        // fee
        uint32 mlpFeeRate = _getLiquidityFeeRate(
            currentSeniorValue,
            targetSeniorValue,
            true,
            ((uint256(wadAmount) * seniorPrice) / 1e18).toUint96(),
            config.liquidityBaseFeeRate,
            config.liquidityDynamicFeeRate
        );
        wadAmount -= ((uint256(wadAmount) * mlpFeeRate) / 1e5).toUint96(); // -fee
        outAmount = ((uint256(wadAmount) * uint256(seniorPrice)) / uint256(juniorPrice)).toUint96();
    }

    function _getLiquidityFeeRate(
        uint96 currentAssetValue,
        uint96 targetAssetValue,
        bool isAdd,
        uint96 deltaValue,
        uint32 baseFeeRate, // 1e5
        uint32 dynamicFeeRate // 1e5
    ) internal pure returns (uint32) {
        uint96 newAssetValue;
        if (isAdd) {
            newAssetValue = currentAssetValue + deltaValue;
        } else {
            require(currentAssetValue >= deltaValue, "AdapterImp::INSUFFICIENT_LIQUIDITY");
            newAssetValue = currentAssetValue - deltaValue;
        }
        // | x - target |
        uint96 oldDiff = currentAssetValue > targetAssetValue
            ? currentAssetValue - targetAssetValue
            : targetAssetValue - currentAssetValue;
        uint96 newDiff = newAssetValue > targetAssetValue
            ? newAssetValue - targetAssetValue
            : targetAssetValue - newAssetValue;
        if (targetAssetValue == 0) {
            // avoid division by 0
            return baseFeeRate;
        } else if (newDiff < oldDiff) {
            // improves
            uint32 rebate = ((uint256(dynamicFeeRate) * uint256(oldDiff)) /
                uint256(targetAssetValue)).toUint32();
            return baseFeeRate > rebate ? baseFeeRate - rebate : 0;
        } else {
            // worsen
            uint96 avgDiff = (oldDiff + newDiff) / 2;
            avgDiff = uint96(MathUpgradeable.min(avgDiff, targetAssetValue));
            uint32 dynamic = ((uint256(dynamicFeeRate) * uint256(avgDiff)) /
                uint256(targetAssetValue)).toUint32();
            return baseFeeRate + dynamic;
        }
    }
}
