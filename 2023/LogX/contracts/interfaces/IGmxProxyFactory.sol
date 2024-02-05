// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

interface IGmxProxyFactory {
    
    struct OpenPositionArgs {
        uint256 exchangeId;
        address collateralToken;
        address assetToken;
        bool isLong;
        address tokenIn;
        uint256 amountIn;
        uint256 minOut;
        uint256 sizeUsd;
        uint96 priceUsd;
        uint8 flags;
        bytes32 referralCode;
    }

    struct ClosePositionArgs {
        uint256 exchangeId;
        address collateralToken;
        address assetToken;
        bool isLong;
        uint256 collateralUsd;
        uint256 sizeUsd;
        uint96 priceUsd;
        uint8 flags;
        bytes32 referralCode;
    }


    event SetReferralCode(bytes32 referralCode);
    event SetMaintainer(address maintainer, bool enable);

    function initialize(address weth_) external;
    function weth() external view returns (address);
    function implementation() external view returns(address);
    function getImplementationAddress(uint256 exchangeId) external view returns(address);
    function getProxyExchangeId(address proxy) external view returns(uint256);
    function getTradingProxy(bytes32 proxyId) external view returns(address);
    function getExchangeConfig(uint256 ExchangeId) external view returns (uint256[] memory);
    function upgradeTo(uint256 exchangeId, address newImplementation_) external;
    function setExchangeConfig(uint256 ExchangeId, uint256[] memory values) external;
    function getConfigVersions(uint256 ExchangeId) external view returns (uint32 exchangeConfigVersion);
    function setMaintainer(address maintainer, bool enable) external;
    function createProxy(uint256 exchangeId, address collateralToken, address assetToken, bool isLong) external returns (address);
    function openPosition(OpenPositionArgs calldata args) external payable;
    function closePosition(ClosePositionArgs calldata args) external payable;
    function cancelOrders(uint256 exchangeId, address collateralToken, address assetToken, bool isLong, bytes32[] calldata keys) external;
    function getPendingOrderKeys(uint256 exchangeId, address collateralToken, address assetToken, bool isLong) external view  returns(bytes32[] memory);
    function withdraw(uint256 exchangeId, address account, address collateralToken, address assetToken, bool isLong) external;
}
