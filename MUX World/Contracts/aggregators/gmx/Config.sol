// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "../../interfaces/IProxyFactory.sol";

import "./libs/LibGmx.sol";
import "./libs/LibUtils.sol";
import "./Storage.sol";
import "./Debt.sol";
import "./Position.sol";

contract Config is Storage, Debt, Position {
    using LibUtils for bytes32;
    using LibUtils for address;
    using LibUtils for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    function _updateConfigs() internal virtual {
        address token = _account.indexToken;
        (uint32 latestProjectVersion, uint32 latestAssetVersion) = IProxyFactory(_factory).getConfigVersions(
            PROJECT_ID,
            token
        );
        if (_localProjectVersion < latestProjectVersion) {
            _updateProjectConfigs();
            _localProjectVersion = latestProjectVersion;
        }
        // pull configs from factory
        if (_localAssetVersions[token] < latestAssetVersion) {
            _updateAssetConfigs();
            _localAssetVersions[token] = latestAssetVersion;
        }
        _patch();
    }

    function _updateProjectConfigs() internal {
        uint256[] memory values = IProxyFactory(_factory).getProjectConfig(PROJECT_ID);
        require(values.length >= uint256(ProjectConfigIds.END), "MissingConfigs");

        address newPositionRouter = values[uint256(ProjectConfigIds.POSITION_ROUTER)].toAddress();
        address newOrderBook = values[uint256(ProjectConfigIds.ORDER_BOOK)].toAddress();
        _onGmxAddressUpdated(
            _projectConfigs.positionRouter,
            _projectConfigs.orderBook,
            newPositionRouter,
            newOrderBook
        );
        _projectConfigs.vault = values[uint256(ProjectConfigIds.VAULT)].toAddress();
        _projectConfigs.positionRouter = newPositionRouter;
        _projectConfigs.orderBook = newOrderBook;
        _projectConfigs.router = values[uint256(ProjectConfigIds.ROUTER)].toAddress();
        _projectConfigs.referralCode = bytes32(values[uint256(ProjectConfigIds.REFERRAL_CODE)]);
        _projectConfigs.marketOrderTimeoutSeconds = values[uint256(ProjectConfigIds.MARKET_ORDER_TIMEOUT_SECONDS)]
            .toU32();
        _projectConfigs.limitOrderTimeoutSeconds = values[uint256(ProjectConfigIds.LIMIT_ORDER_TIMEOUT_SECONDS)]
            .toU32();
        _projectConfigs.fundingAssetId = values[uint256(ProjectConfigIds.FUNDING_ASSET_ID)].toU8();
    }

    function _onGmxAddressUpdated(
        address previousPositionRouter,
        address prevousOrderBook,
        address newPostitionRouter,
        address newOrderBook
    ) internal virtual {
        bool cancelPositionRouter = previousPositionRouter != newPostitionRouter;
        bool cancelOrderBook = prevousOrderBook != newOrderBook;
        bytes32[] memory pendingKeys = _pendingOrders.values();
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            bytes32 key = pendingKeys[i];
            if (cancelPositionRouter) {
                LibGmx.cancelOrderFromPositionRouter(previousPositionRouter, key);
                _removePendingOrder(key);
            }
            if (cancelOrderBook) {
                LibGmx.cancelOrderFromOrderBook(newPostitionRouter, key);
                _removePendingOrder(key);
            }
        }
    }

    function _updateAssetConfigs() internal {
        uint256[] memory values = IProxyFactory(_factory).getProjectAssetConfig(PROJECT_ID, _account.collateralToken);
        require(values.length >= uint256(TokenConfigIds.END), "MissingConfigs");
        _assetConfigs.boostFeeRate = values[uint256(TokenConfigIds.BOOST_FEE_RATE)].toU32();
        _assetConfigs.initialMarginRate = values[uint256(TokenConfigIds.INITIAL_MARGIN_RATE)].toU32();
        _assetConfigs.maintenanceMarginRate = values[uint256(TokenConfigIds.MAINTENANCE_MARGIN_RATE)].toU32();
        _assetConfigs.liquidationFeeRate = values[uint256(TokenConfigIds.LIQUIDATION_FEE_RATE)].toU32();
        _assetConfigs.referrenceOracle = values[uint256(TokenConfigIds.REFERRENCE_ORACLE)].toAddress();
        _assetConfigs.referenceDeviation = values[uint256(TokenConfigIds.REFERRENCE_ORACLE_DEVIATION)].toU32();
    }

    // path  TODO: remove me when deploy
    function _patch() internal {
        if (_account.collateralDecimals == 0) {
            _account.collateralDecimals = IERC20MetadataUpgradeable(_account.collateralToken).decimals();
        }
    }
}
