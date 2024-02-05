// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

enum ProjectConfigIds {
    VAULT,
    POSITION_ROUTER,
    ORDER_BOOK,
    ROUTER,
    REFERRAL_CODE,
    MARKET_ORDER_TIMEOUT_SECONDS,
    LIMIT_ORDER_TIMEOUT_SECONDS,
    FUNDING_ASSET_ID,
    END
}

enum TokenConfigIds {
    BOOST_FEE_RATE,
    INITIAL_MARGIN_RATE,
    MAINTENANCE_MARGIN_RATE,
    LIQUIDATION_FEE_RATE,
    REFERRENCE_ORACLE,
    REFERRENCE_ORACLE_DEVIATION,
    END
}

struct ProjectConfigs {
    address vault;
    address positionRouter;
    address orderBook;
    address router;
    bytes32 referralCode;
    // ========================
    uint32 marketOrderTimeoutSeconds;
    uint32 limitOrderTimeoutSeconds;
    uint8 fundingAssetId;
    bytes32[19] reserved;
}

struct TokenConfigs {
    address referrenceOracle;
    // --------------------------
    uint32 referenceDeviation;
    uint32 boostFeeRate;
    uint32 initialMarginRate;
    uint32 maintenanceMarginRate;
    uint32 liquidationFeeRate;
    // --------------------------
    bytes32[20] reserved;
}

struct AccountState {
    address account;
    uint256 cumulativeDebt;
    uint256 cumulativeFee;
    uint256 debtEntryFunding;
    address collateralToken;
    // --------------------------
    address indexToken; // 160
    uint8 deprecated0; // 8
    bool isLong; // 8
    uint8 collateralDecimals;
    // reserve 80
    // --------------------------
    uint256 liquidationFee;
    bool isLiquidating;
    bytes32[18] reserved;
}

struct OpenPositionContext {
    // parameters
    uint256 amountIn;
    uint256 sizeUsd;
    uint256 priceUsd;
    bool isMarket;
    // calculated
    uint256 fee;
    uint256 borrow;
    uint256 amountOut;
    uint256 gmxOrderIndex;
    uint256 executionFee;
}

struct ClosePositionContext {
    uint256 collateralUsd;
    uint256 sizeUsd;
    uint256 priceUsd;
    bool isMarket;
    uint256 gmxOrderIndex;
}
