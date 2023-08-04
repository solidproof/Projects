// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import "../../lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";

import "../../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/IMuxAggregator.sol";

import "./MuxStorage.sol";
import "./MuxProxyBeacon.sol";
import "./MuxProxyConfig.sol";

contract MuxProxyFactory is MuxStorage, MuxProxyBeacon, MuxProxyConfig, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct PositionArgs {
        uint256 exchangeId;
        address collateralToken;
        uint8 collateralId;
        uint8 assetId;
        uint8 profitTokenId;
        address profitTokenAddress;
        bool isLong;
        uint96 collateralAmount; // tokenIn.decimals
        uint96 size; // 1e18
        uint96 price; // 1e18
        uint96 collateralPrice;
        uint96 assetPrice;
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
        uint32 deadline;
    }

    event SetReferralCode(bytes32 referralCode);
    event SetMaintainer(address maintainer, bool enable);

    function initialize(address weth_) external initializer {
        __Ownable_init();
        _weth = weth_;
    }

    function weth() external view returns (address) {
        return _weth;
    }

    // ======================== getter methods ========================

    function getImplementationAddress(uint256 exchangeId) external view returns(address){
        return _implementations[exchangeId];
    }

    function getProxyExchangeId(address proxy) external view returns(uint256){
        return _proxyExchangeIds[proxy];
    }

    function getTradingProxy(bytes32 proxyId) external view returns(address){
        return _tradingProxies[proxyId];
    }

    function getProxiesOf(address account) public view returns (address[] memory) {
        return _ownedProxies[account];
    }

    function getExchangeConfig(uint256 ExchangeId) external view returns (uint256[] memory) {
        return _exchangeConfigs[ExchangeId].values;
    }

    function getMainatinerStatus(address maintainer) external view returns(bool){
        return _maintainers[maintainer];
    }

    function getConfigVersions(uint256 ExchangeId)
        external
        view
        returns (uint32 ExchangeConfigVersion)
    {
        return _getLatestVersions(ExchangeId);
    }

    // ======================== methods for contract management ========================
    function upgradeTo(uint256 exchangeId, address newImplementation_) external onlyOwner {
        _upgradeTo(exchangeId, newImplementation_);
    }

    function setExchangeConfig(uint256 ExchangeId, uint256[] memory values) external {
        require(_maintainers[msg.sender] || msg.sender == owner(), "OnlyMaintainerOrAbove");
        _setExchangeConfig(ExchangeId, values);
    }

    function setMaintainer(address maintainer, bool enable) external onlyOwner {
        _maintainers[maintainer] = enable;
        emit SetMaintainer(maintainer, enable);
    }

    // ======================== methods called by user ========================
    function createProxy(
        uint256 exchangeId,
        address collateralToken,
        uint8 collateralId,
        uint8 assetId,
        bool isLong
    ) public returns (address) {
        return
            _createBeaconProxy(
                exchangeId,
                msg.sender,
                collateralToken,
                assetId,
                collateralId,
                isLong
            );
    }

    function openPosition(PositionArgs calldata args, PositionOrderExtra calldata extra) external payable {
        bytes32 proxyId = _makeProxyId(args.exchangeId, msg.sender, args.collateralToken, args.collateralId, args.assetId, args.isLong);
        address proxy = _tradingProxies[proxyId];
        if (proxy == address(0)) {
            proxy = createProxy(args.exchangeId, args.collateralToken, args.collateralId, args.assetId, args.isLong);
        }
        if (args.collateralToken != _weth) {
            IERC20Upgradeable(args.collateralToken).safeTransferFrom(msg.sender, proxy, args.collateralAmount);
        } else {
            require(msg.value >= args.collateralAmount, "InsufficientAmountIn");
        }

        IMuxAggregator(proxy).placePositionOrder{ value: msg.value }(
            args.collateralAmount,
            args.size,
            args.price,
            args.flags,
            args.assetPrice,
            args.collateralPrice,
            args.deadline,
            args.isLong,
            args.profitTokenId,
            args.profitTokenAddress,
            extra
        );
    }

    function closePosition(PositionArgs calldata args, PositionOrderExtra calldata extra) external payable {
        address proxy = _mustGetProxy(args.exchangeId, msg.sender, args.collateralToken, args.collateralId, args.assetId, args.isLong);

        IMuxAggregator(proxy).placePositionOrder{ value: msg.value }(
            args.collateralAmount,
            args.size,
            args.price,
            args.flags,
            args.assetPrice,
            args.collateralPrice,
            args.deadline,
            args.isLong,
            args.profitTokenId,
            args.profitTokenAddress,
            extra
        );
    }

    function cancelOrders(
        uint256 exchangeId,
        address collateralToken,
        uint8 collateralId,
        uint8 assetId,
        bool isLong,
        uint64[] calldata keys
    ) external {
        IMuxAggregator(_mustGetProxy(exchangeId, msg.sender, collateralToken, collateralId, assetId, isLong)).cancelOrders(keys);
    }

    function getPendingOrderKeys(uint256 exchangeId, address collateralToken, uint8 collateralId, uint8 assetId, bool isLong) external view returns(uint64[] memory){
        return IMuxAggregator(_mustGetProxy(exchangeId, msg.sender, collateralToken, collateralId, assetId, isLong)).getPendingOrderKeys();
    }

    function withdraw(
        uint256 exchangeId,
        address account,
        address collateralToken,
        uint8 collateralId,
        uint8 assetId,
        bool isLong
    ) external {
        require(_maintainers[msg.sender] || msg.sender == owner(), "OnlyMaintainerOrAbove");
        IMuxAggregator(_mustGetProxy(exchangeId, account, collateralToken, collateralId, assetId, isLong)).withdraw();
    }

    function removeProxy(bytes32 proxyId, address userAddress) external onlyOwner {
        // Fetch the proxy address from _tradingProxies
        address proxyAddress = _tradingProxies[proxyId];

        // Delete the entry in _tradingProxies
        delete _tradingProxies[proxyId];

        // Delete the entry in _proxyExchangeIds
        delete _proxyExchangeIds[proxyAddress];

        // Remove the proxyAddress from the _ownedProxies array for the userAddress
        address[] storage ownedProxies = _ownedProxies[userAddress];
        for (uint i = 0; i < ownedProxies.length; i++) {
            if (ownedProxies[i] == proxyAddress) {
                // We found the proxyAddress, now we need to remove it
                ownedProxies[i] = ownedProxies[ownedProxies.length - 1];
                ownedProxies.pop();
                break;
            }
        }
    }

    // ======================== Utility methods ========================
    function _mustGetProxy(
        uint256 exchangeId,
        address account,
        address collateralToken,
        uint8 collateralId,
        uint8 assetId,
        bool isLong
    ) internal view returns (address proxy) {
        bytes32 proxyId = _makeProxyId(exchangeId, account, collateralToken, collateralId, assetId, isLong);
        proxy = _tradingProxies[proxyId];
        require(proxy != address(0), "ProxyNotExist");
    }
}