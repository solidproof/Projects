// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "../aggregators/mux/Types.sol";

interface IMuxGetter {
    function getAssetInfo(uint8 assetId) external view returns (
        Asset memory
    );

    function getAllAssetInfo() external view returns (
        address[] memory tokenAddresses,
        uint64[] memory prices,
        uint32[] memory priceDecimals,
        uint32[] memory priceUpdateTimes,
        uint32[] memory collateralDecimals,
        uint32[] memory interestIndices,
        uint32[] memory lastInterestTimes,
        uint32[] memory fundingIntervals,
        uint96[] memory minTradeSizes,
        uint96[] memory maxTradeSizes,
        uint96[] memory maxLeverages,
        uint96[] memory impactCostFactors,
        uint96[] memory fundingRateCoefficients,
        uint96[] memory priceDeviationLimits
    );

    function getAssetAddress(uint8 assetId) external view returns (address);

    function getLiquidityPoolStorage() external view returns (
        uint32[8] memory u32s,
        uint96[2] memory u96s
    );

    function getSubAccount(
        bytes32 subAccountId
    ) external view returns (uint96 collateral, uint96 size, uint32 lastIncreasedTime, uint96 entryPrice, uint128 entryFunding);
}
