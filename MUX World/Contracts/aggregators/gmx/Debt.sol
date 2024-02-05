// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../../interfaces/ILiquidityPool.sol";
import "../../interfaces/IProxyFactory.sol";

import "./libs/LibGmx.sol";
import "./libs/LibUtils.sol";
import "./Storage.sol";

contract Debt is Storage {
    using LibUtils for uint256;
    using MathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event SetBoostRate(uint256 previousRate, uint256 newRate);
    event SetLiquidityPool(address previousLiquidityPool, address newLiquidityPool);
    event BorrowAsset(
        uint256 amount,
        uint256 boostFee,
        uint256 cumulativeDebt,
        uint256 cumulativeFee,
        uint256 debtEntryFunding
    );
    event RepayAsset(
        uint256 amount,
        uint256 paidDebt,
        uint256 paidFee,
        uint256 boostFee,
        uint256 badDebt,
        uint256 cumulativeDebt,
        uint256 cumulativeFee,
        uint256 debtEntryFunding
    );

    // virtual methods
    function _borrowFromPool(uint256 amount, uint256 fee) internal returns (uint256 amountOut) {
        amountOut = IProxyFactory(_factory).borrowAsset(PROJECT_ID, _account.collateralToken, amount, fee);
    }

    function _repayToPool(
        uint256 amount,
        uint256 fee,
        uint256 badDebt
    ) internal {
        IERC20Upgradeable(_account.collateralToken).safeTransfer(_liquidityPool, amount + fee);
        IProxyFactory(_factory).repayAsset(PROJECT_ID, _account.collateralToken, amount, fee, badDebt);
    }

    // implementations
    function _getMuxFundingFee() internal view returns (uint256 fundingFee, uint256 newFunding) {
        if (_account.isLong) {
            uint8 assetId = IProxyFactory(_factory).getAssetId(PROJECT_ID, _account.collateralToken);
            if (assetId == VIRTUAL_ASSET_ID) {
                fundingFee = 0;
                newFunding = 0;
            } else {
                ILiquidityPool.Asset memory asset = ILiquidityPool(_liquidityPool).getAssetInfo(assetId);
                newFunding = asset.longCumulativeFundingRate; // 1e18
                fundingFee = ((newFunding - _account.debtEntryFunding) * _account.cumulativeDebt) / 1e18; // collateral.decimal
            }
        } else {
            ILiquidityPool.Asset memory asset = ILiquidityPool(_liquidityPool).getAssetInfo(
                _projectConfigs.fundingAssetId
            );
            newFunding = asset.shortCumulativeFunding;
            address token = ILiquidityPool(_liquidityPool).getAssetAddress(_projectConfigs.fundingAssetId);
            fundingFee =
                (((newFunding - _account.debtEntryFunding) * _account.cumulativeDebt) * 1e12) /
                LibGmx.getOraclePrice(_projectConfigs, token, false); // collateral.decimal
        }
    }

    function _updateMuxFundingFee() internal returns (uint256) {
        (uint256 fundingFee, uint256 newFunding) = _getMuxFundingFee();
        _account.cumulativeFee += fundingFee;
        _account.debtEntryFunding = newFunding;
        return fundingFee;
    }

    function _borrowCollateral(uint256 toBorrow) internal returns (uint256 borrowed, uint256 paidFee) {
        _updateMuxFundingFee();
        uint256 boostFee = toBorrow.rate(_assetConfigs.boostFeeRate);
        borrowed = toBorrow - boostFee;
        paidFee = boostFee;
        _borrowFromPool(toBorrow, boostFee);
        _account.cumulativeDebt += toBorrow;
        emit BorrowAsset(
            toBorrow,
            boostFee,
            _account.cumulativeDebt,
            _account.cumulativeFee,
            _account.debtEntryFunding
        );
    }

    function _partialRepayCollateral(uint256 borrow, uint256 balance)
        internal
        returns (
            uint256 toUser,
            uint256 toRepay,
            uint256 fee
        )
    {
        _updateMuxFundingFee();

        toUser = balance;
        toRepay = _account.cumulativeDebt.min(borrow);
        require(balance >= toRepay, "InsufficientBalance");
        fee = toRepay.rate(_assetConfigs.boostFeeRate);
        _account.cumulativeDebt -= toRepay;
        toUser -= toRepay;
        if (toUser >= fee) {
            toUser -= fee;
        } else {
            _account.cumulativeFee += fee;
        }
        _repayToPool(toRepay, fee, 0);
        emit RepayAsset(
            balance,
            toRepay,
            fee,
            fee,
            0,
            _account.cumulativeDebt,
            _account.cumulativeFee,
            _account.debtEntryFunding
        );
    }

    function _repayCollateral(uint256 balance, uint256 inflightBorrow)
        internal
        returns (
            uint256 remain,
            uint256 toRepay,
            uint256 fee
        )
    {
        _updateMuxFundingFee();
        toRepay = _account.cumulativeDebt - inflightBorrow;
        uint256 boostFee = toRepay.rate(_assetConfigs.boostFeeRate);
        fee = boostFee + _account.cumulativeFee;
        remain = balance;
        // 1. pay the debt, missing part will be turned into bad debt
        toRepay = toRepay.min(remain);
        remain -= toRepay;
        // 2. pay the fee, if possible
        fee = fee.min(remain);
        remain -= fee;
        uint256 badDebt = _account.cumulativeDebt - inflightBorrow - toRepay;
        // cumulativeDebt - inflightBorrow = paidDebt - badDebt
        _account.cumulativeDebt = inflightBorrow;
        _account.cumulativeFee = 0;
        _repayToPool(toRepay, fee, badDebt);

        emit RepayAsset(
            balance,
            toRepay,
            fee,
            boostFee,
            badDebt,
            _account.cumulativeDebt,
            _account.cumulativeFee,
            _account.debtEntryFunding
        );
    }
}
