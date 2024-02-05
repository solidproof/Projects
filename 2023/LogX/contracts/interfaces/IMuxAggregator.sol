// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../aggregators/mux/Types.sol";

interface IMuxAggregator {

    function initialize(
        uint256 exchangeId,
        address account,
        address collateralToken,
        uint8 collateralId,
        uint8 assetId,
        bool isLong
    ) external;

    function accountState() external returns(AccountState memory);

    function getSubAccountId() external view returns(bytes32);

    function placePositionOrder(
        uint96 collateralAmount, // tokenIn.decimals
        uint96 size, // 1e18
        uint96 price, // 1e18
        uint8 flags, // MARKET, TRIGGER
        uint96 assetPrice, // 1e18
        uint96 collateralPrice, // 1e18
        uint32 deadline,
        bool isLong,
        uint8 profitTokenId,
        address profitTokenAddress,
        PositionOrderExtra memory extra
    ) external payable;
    
    function withdraw() external;

    function cancelOrders(uint64[] calldata keys) external;

    function getPendingOrderKeys() external view returns (uint64[] memory);
}