// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IMuxLiquidityPool {
    struct Asset {
        // slot
        // assets with the same symbol in different chains are the same asset. they shares the same muxToken. so debts of the same symbol
        // can be accumulated across chains (see Reader.AssetState.deduct). ex: ERC20(fBNB).symbol should be "BNB", so that BNBs of
        // different chains are the same.
        // since muxToken of all stable coins is the same and is calculated separately (see Reader.ChainState.stableDeduct), stable coin
        // symbol can be different (ex: "USDT", "USDT.e" and "fUSDT").
        bytes32 symbol;
        // slot
        address tokenAddress; // erc20.address
        uint8 id;
        uint8 decimals; // erc20.decimals
        uint56 flags; // a bitset of ASSET_*
        uint24 _flagsPadding;
        // slot
        uint32 initialMarginRate; // 1e5
        uint32 maintenanceMarginRate; // 1e5
        uint32 minProfitRate; // 1e5
        uint32 minProfitTime; // 1e0
        uint32 positionFeeRate; // 1e5
        // note: 96 bits remaining
        // slot
        address referenceOracle;
        uint32 referenceDeviation; // 1e5
        uint8 referenceOracleType;
        uint32 halfSpread; // 1e5
        // note: 24 bits remaining
        // slot
        uint96 credit;
        uint128 _reserved2;
        // slot
        uint96 collectedFee;
        uint32 liquidationFeeRate; // 1e5
        uint96 spotLiquidity;
        // note: 32 bits remaining
        // slot
        uint96 maxLongPositionSize;
        uint96 totalLongPosition;
        // note: 64 bits remaining
        // slot
        uint96 averageLongPrice;
        uint96 maxShortPositionSize;
        // note: 64 bits remaining
        // slot
        uint96 totalShortPosition;
        uint96 averageShortPrice;
        // note: 64 bits remaining
        // slot, less used
        address muxTokenAddress; // muxToken.address. all stable coins share the same muxTokenAddress
        uint32 spotWeight; // 1e0
        uint32 longFundingBaseRate8H; // 1e5
        uint32 longFundingLimitRate8H; // 1e5
        // slot
        uint128 longCumulativeFundingRate; // Σ_t fundingRate_t
        uint128 shortCumulativeFunding; // Σ_t fundingRate_t * indexPrice_t
    }

    function getAssetInfo(uint8 assetId) external view returns (Asset memory);

    function getAllAssetInfo() external view returns (Asset[] memory);

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
        );
}
