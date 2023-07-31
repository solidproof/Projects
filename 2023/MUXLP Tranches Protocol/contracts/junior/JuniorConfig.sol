// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../interfaces/mux/IMuxRewardRouter.sol";
import "../interfaces/IConfigurable.sol";
import "../libraries/LibTypeCast.sol";
import "./Type.sol";

/**
 * @title JuniorConfig
 * @notice JuniorConfig is designed to assist administrators in managing variables within the Mux Tranche Protocol.
 * However, it is not a mandatory component, as users can still directly use the setConfig interface and Key-Value (KV) approach to configure and customize the protocol settings. \
 * The JuniorConfig module provides an additional layer of convenience and flexibility for administrators to manage and update the protocol's variables.
 */
contract JuniorConfig {
    using LibTypeCast for bytes32;
    using LibTypeCast for uint256;
    using LibTypeCast for address;

    IConfigurable public juniorVault;

    modifier onlyAdmin() {
        require(juniorVault.hasRole(DEFAULT_ADMIN, msg.sender), "JuniorConfig::ONLY_ADMIN");
        _;
    }

    constructor(address configurable_) {
        require(configurable_ != address(0), "JuniorConfig::INVALID_ADDRESS");
        juniorVault = IConfigurable(configurable_);
    }

    function weth() public view virtual returns (address) {
        return juniorVault.getConfig(WETH_TOKEN).toAddress();
    }

    function mlp() public view virtual returns (address) {
        return juniorVault.getConfig(MLP_TOKEN).toAddress();
    }

    function smlp() public view virtual returns (address) {
        return juniorVault.getConfig(SMLP_TOKEN).toAddress();
    }

    function mux() public view virtual returns (address) {
        return juniorVault.getConfig(MUX_TOKEN).toAddress();
    }

    function mcb() public view virtual returns (address) {
        return juniorVault.getConfig(MCB_TOKEN).toAddress();
    }

    function muxRewardRouter() public view virtual returns (address) {
        return juniorVault.getConfig(MUX_REWARD_ROUTER).toAddress();
    }

    function muxLiquidityPool() public view virtual returns (address) {
        return juniorVault.getConfig(MUX_LIQUIDITY_POOL).toAddress();
    }

    function setMuxRewardRouter(address muxRewardRouter_) public virtual onlyAdmin {
        IMuxRewardRouter router = IMuxRewardRouter(muxRewardRouter_);
        juniorVault.setConfig(MUX_REWARD_ROUTER, muxRewardRouter_.toBytes32());
        juniorVault.setConfig(WETH_TOKEN, router.weth().toBytes32());
        juniorVault.setConfig(MLP_TOKEN, router.mlp().toBytes32());
        juniorVault.setConfig(SMLP_TOKEN, router.mlpMuxTracker().toBytes32());
        juniorVault.setConfig(MUX_TOKEN, router.mux().toBytes32());
        juniorVault.setConfig(MCB_TOKEN, router.mcb().toBytes32());
    }

    function setMuxLiquidityPool(address muxLiquidityPool_) public virtual onlyAdmin {
        juniorVault.setConfig(MUX_LIQUIDITY_POOL, muxLiquidityPool_.toBytes32());
    }
}
