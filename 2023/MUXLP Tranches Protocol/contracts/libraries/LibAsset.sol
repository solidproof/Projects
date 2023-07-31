// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "../interfaces/mux/IMuxLiquidityPool.sol";

library LibAsset {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    uint56 constant ASSET_IS_STABLE = 0x00000000000001; // is a usdt, usdc, ...
    uint56 constant ASSET_CAN_ADD_REMOVE_LIQUIDITY = 0x00000000000002; // can call addLiquidity and removeLiquidity with this token
    uint56 constant ASSET_IS_TRADABLE = 0x00000000000100; // allowed to be assetId
    uint56 constant ASSET_IS_OPENABLE = 0x00000000010000; // can open position
    uint56 constant ASSET_IS_SHORTABLE = 0x00000001000000; // allow shorting this asset
    uint56 constant ASSET_USE_STABLE_TOKEN_FOR_PROFIT = 0x00000100000000; // take profit will get stable coin
    uint56 constant ASSET_IS_ENABLED = 0x00010000000000; // allowed to be assetId and collateralId
    uint56 constant ASSET_IS_STRICT_STABLE = 0x01000000000000; // assetPrice is always 1 unless volatility exceeds strictStableDeviation

    function toWad(
        IMuxLiquidityPool.Asset memory token,
        uint256 rawAmount
    ) internal pure returns (uint256) {
        return (rawAmount * (10 ** (18 - token.decimals)));
    }

    function toRaw(
        IMuxLiquidityPool.Asset memory token,
        uint96 wadAmount
    ) internal pure returns (uint256) {
        return uint256(wadAmount) / 10 ** (18 - token.decimals);
    }

    // is a usdt, usdc, ...
    function isStable(IMuxLiquidityPool.Asset memory asset) internal pure returns (bool) {
        return (asset.flags & ASSET_IS_STABLE) != 0;
    }

    // can call addLiquidity and removeLiquidity with this token
    function canAddRemoveLiquidity(
        IMuxLiquidityPool.Asset memory asset
    ) internal pure returns (bool) {
        return (asset.flags & ASSET_CAN_ADD_REMOVE_LIQUIDITY) != 0;
    }

    // allowed to be assetId
    function isTradable(IMuxLiquidityPool.Asset memory asset) internal pure returns (bool) {
        return (asset.flags & ASSET_IS_TRADABLE) != 0;
    }

    // can open position
    function isOpenable(IMuxLiquidityPool.Asset memory asset) internal pure returns (bool) {
        return (asset.flags & ASSET_IS_OPENABLE) != 0;
    }

    // allow shorting this asset
    function isShortable(IMuxLiquidityPool.Asset memory asset) internal pure returns (bool) {
        return (asset.flags & ASSET_IS_SHORTABLE) != 0;
    }

    // take profit will get stable coin
    function useStableTokenForProfit(
        IMuxLiquidityPool.Asset memory asset
    ) internal pure returns (bool) {
        return (asset.flags & ASSET_USE_STABLE_TOKEN_FOR_PROFIT) != 0;
    }

    // allowed to be assetId and collateralId
    function isEnabled(IMuxLiquidityPool.Asset memory asset) internal pure returns (bool) {
        return (asset.flags & ASSET_IS_ENABLED) != 0;
    }

    // assetPrice is always 1 unless volatility exceeds strictStableDeviation
    function isStrictStable(IMuxLiquidityPool.Asset memory asset) internal pure returns (bool) {
        return (asset.flags & ASSET_IS_STRICT_STABLE) != 0;
    }
}
