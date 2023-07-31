// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IConfigurable.sol";
import "../libraries/LibTypeCast.sol";
import "./Type.sol";

/**
 * @title RouterConfig
 * @notice RouterConfig is designed to assist administrators in managing variables within the Mux Tranche Protocol.
 * However, it is not a mandatory component, as users can still directly use the setConfig interface and Key-Value (KV) approach to configure and customize the protocol settings. \
 * The RouterConfig module provides an additional layer of convenience and flexibility for administrators to manage and update the protocol's variables.
 */
contract RouterConfig {
    using LibTypeCast for bytes32;
    using LibTypeCast for uint256;
    using LibTypeCast for address;

    IConfigurable public router;

    modifier onlyAdmin() {
        require(router.hasRole(DEFAULT_ADMIN, msg.sender), "RouterConfig::ONLY_ADMIN");
        _;
    }

    constructor(address configurable_) {
        require(configurable_ != address(0), "RouterConfig::INVALID_ADDRESS");
        router = IConfigurable(configurable_);
    }

    function muxRewardRouter() public view virtual returns (address) {
        return router.getConfig(MUX_REWARD_ROUTER).toAddress();
    }

    function muxLiquidityPool() public view virtual returns (address) {
        return router.getConfig(MUX_LIQUIDITY_POOL).toAddress();
    }

    function muxOrderBook() public view virtual returns (address) {
        return router.getConfig(MUX_ORDER_BOOK).toAddress();
    }

    function targetLeverage() public view virtual returns (uint256) {
        return router.getConfig(TARGET_LEVERAGE).toUint256();
    }

    function rebalanceThreshold() public view virtual returns (uint256) {
        return router.getConfig(REBALANCE_THRESHOLD).toUint256();
    }

    function liquidationLeverage() public view virtual returns (uint256) {
        return router.getConfig(LIQUIDATION_LEVERAGE).toUint256();
    }

    function setMuxRewardRouter(address muxRewardRouter_) public virtual onlyAdmin {
        require(muxRewardRouter_ != address(0), "RouterConfig::INVALID_MUX_REWARD_ROUTER");
        router.setConfig(MUX_REWARD_ROUTER, muxRewardRouter_.toBytes32());
    }

    function setMuxLiquidityPool(address muxLiquidityPool_) public virtual onlyAdmin {
        require(muxLiquidityPool_ != address(0), "RouterConfig::INVALID_MUX_LIQUIDITY_POOL");
        router.setConfig(MUX_LIQUIDITY_POOL, muxLiquidityPool_.toBytes32());
    }

    function setMuxOrderBook(address muxOrderBook_) public virtual onlyAdmin {
        require(muxOrderBook_ != address(0), "RouterConfig::INVALID_MUX_ORDER_BOOK");
        router.setConfig(MUX_ORDER_BOOK, muxOrderBook_.toBytes32());
    }

    function setTargetLeverage(uint256 targetLeverage_) public virtual onlyAdmin {
        require(targetLeverage_ > ONE, "RouterConfig::INVALID_LEVERAGE");
        router.setConfig(TARGET_LEVERAGE, targetLeverage_.toBytes32());
    }

    function setRebalanceThreshold(uint256 rebalanceThreshold_) public virtual {
        require(rebalanceThreshold_ < ONE, "RouterConfig::INVALID_THRESHOLD");
        router.setConfig(REBALANCE_THRESHOLD, rebalanceThreshold_.toBytes32());
    }

    function setLiquidationLeverage(uint256 liquidationLeverage_) public virtual onlyAdmin {
        require(liquidationLeverage_ > targetLeverage(), "RouterConfig::INVALID_LEVERAGE");
        router.setConfig(LIQUIDATION_LEVERAGE, liquidationLeverage_.toBytes32());
    }
}
