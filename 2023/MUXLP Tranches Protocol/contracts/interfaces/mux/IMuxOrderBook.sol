// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IMuxOrderBook {
    event CallbackError(string reason);

    function nextOrderId() external view returns (uint64);

    /**
     * @notice Liquidity Order can be filled after this time in seconds.
     */
    function liquidityLockPeriod() external view returns (uint32);

    /**
     * @notice Cancel an Order by orderId.
     */
    function cancelOrder(uint64 orderId) external;

    /**
     * @notice Add/remove liquidity. called by Liquidity Provider.
     *
     *         Can be filled after liquidityLockPeriod seconds.
     * @param  assetId   asset.id that added/removed to.
     * @param  rawAmount asset token amount. decimals = erc20.decimals.
     * @param  isAdding  true for add liquidity, false for remove liquidity.
     */
    function placeLiquidityOrder(
        uint8 assetId,
        uint96 rawAmount, // erc20.decimals
        bool isAdding
    ) external payable;

    function setCallbackWhitelist(address caller, bool enable) external;

    function fillLiquidityOrder(
        uint64 orderId,
        uint96 assetPrice,
        uint96 mlpPrice,
        uint96 currentAssetValue,
        uint96 targetAssetValue
    ) external;
}
