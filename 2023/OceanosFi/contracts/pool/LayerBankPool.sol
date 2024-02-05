// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./base/YieldAdapterIssuedPool.sol";

import "../interfaces/ILToken.sol";
import "../interfaces/IPriceCalculator.sol";
import "../interfaces/ILayerBankCore.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract LayerBankPool is Initializable, YieldAdapterIssuedPool {
    uint256 public totalCollateralStored;

    ILToken public lToken;
    ILayerBankCore public layerBankCore;
    IRebateDistributor public rebateDistributor;
    IERC20 public rewardToken;

    function initialize(
        IController _controller,
        IOcUSD _ocUsd,
        IERC20 _collateral,
        ILToken _lToken,
        ILayerBankCore _layerBankCore
    ) external initializer {
        _initialize(_ocUsd, _collateral, _controller);
        lToken = _lToken;
        layerBankCore = _layerBankCore;
        rebateDistributor = IRebateDistributor(
            layerBankCore.rebateDistributor()
        );
        rewardToken = IERC20(rebateDistributor.lab());
    }

    function totalCollateralAmount() public view override returns (uint256) {
        return totalUnderlyingAmount();
    }

    function totalUnderlyingAmount() public view returns (uint256) {
        return lToken.underlyingBalanceOf(address(this));
    }

    function totalLTokenAmount() public view returns (uint256) {
        return lToken.balanceOf(address(this));
    }

    function getAssetPrice() public view override returns (uint256) {
        return
            IPriceCalculator(controller.getPriceCalculator()).priceOf(
                address(collateralAsset)
            );
    }

    function _depositToYieldPool(uint256 amount) internal override {
        if (address(collateralAsset) == address(0)) {
            layerBankCore.supply{value: amount}(address(lToken), amount);
        } else {
            collateralAsset.approve(address(layerBankCore), amount);
            layerBankCore.supply(address(lToken), amount);
        }
    }

    function _withdrawFromYieldPool(uint256 amount) internal override {
        layerBankCore.redeemUnderlying(address(lToken), amount);
    }

    function _safeTransferIn(
        address from,
        uint256 amount
    ) internal override returns (bool) {
        super._safeTransferIn(from, amount);

        _depositToYieldPool(amount);

        totalCollateralStored += amount;

        return true;
    }

    function _safeTransferOut(
        address to,
        uint256 amount
    ) internal override returns (bool) {
        _withdrawFromYieldPool(amount);

        totalCollateralStored -= amount;

        return super._safeTransferOut(to, amount);
    }

    // handle external reward

    function processYield() public override {
        _claimYield();

        uint256 rewardAmount = rewardToken.balanceOf(address(this));

        rewardToken.transfer(address(controller), rewardAmount);
        controller.notifyYieldReward(address(rewardToken), rewardAmount);
    }

    function _claimYield() internal override {
        layerBankCore.compoundLab();
        rebateDistributor.claimRebates();
    }

    function claimReserve() external {
        address receiver = controller.getSavingPool();
        if (receiver == address(0)) return;

        uint256 totalCollateralCurrent = totalCollateralAmount();
        if (totalCollateralCurrent >= totalCollateralStored) {
            uint256 toSend = totalCollateralCurrent - totalCollateralStored;

            _withdrawFromYieldPool(toSend);

            super._safeTransferOut(receiver, toSend);
        }
    }

    uint256[50] private __gap;
}
