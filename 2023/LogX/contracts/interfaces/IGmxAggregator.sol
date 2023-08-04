// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../aggregators/gmx/Types.sol";
import "../aggregators/gmx/lib/LibGmx.sol";

interface IGmxAggregator {
    function initialize(
        uint256 projectId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) external;

    function accountState() external returns(AccountState memory);

    function getPositionKey() external view returns(bytes32);

    function getOrder(bytes32 orderKey) external view returns(bool isFilled, LibGmx.OrderHistory memory history);

    function openPosition(
        address swapInToken,
        uint256 swapInAmount, // tokenIn.decimals
        uint256 minSwapOut, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint96 tpPriceUsd,
        uint96 slPriceUsd,
        uint8 flags // MARKET, TRIGGER
    ) external payable;

    function closePosition(
        uint256 collateralUsd, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint96 tpPriceUsd, // 1e18
        uint96 slPriceUsd, // 1e18
        uint8 flags // MARKET, TRIGGER
    ) external payable;

    function updateOrder(
        bytes32 orderKey,
        uint256 collateralDelta,
        uint256 sizeDelta,
        uint256 triggerPrice,
        bool triggerAboveThreshold
    ) external;

    function withdraw() external;

    function cancelOrders(bytes32[] calldata keys) external;

    function cancelTimeoutOrders(bytes32[] calldata keys) external;

    function getPendingOrderKeys() external view returns (bytes32[] memory);
}