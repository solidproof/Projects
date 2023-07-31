// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/mux/IMuxRewardRouter.sol";
import "../interfaces/mux/IMuxVester.sol";
import "../libraries/LibConfigSet.sol";
import "./Type.sol";

library StakeHelperImp {
    using LibConfigSet for LibConfigSet.ConfigSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event CollectRewards(uint256 wethAmount, uint256 mcbAmount);

    function pendingRewards(
        JuniorStateStore storage store
    ) internal returns (uint256 wethAmount, uint256 mcbAmount) {
        IMuxRewardRouter muxRewardRouter = IMuxRewardRouter(
            store.config.mustGetAddress(MUX_REWARD_ROUTER)
        );
        (wethAmount, , , , mcbAmount) = muxRewardRouter.claimableRewards(address(this));
    }

    function collectRewards(JuniorStateStore storage store, address receiver) internal {
        require(receiver != address(0), "StakeHelperImp::INVALID_RECEIVER");
        IMuxRewardRouter muxRewardRouter = IMuxRewardRouter(
            store.config.mustGetAddress(MUX_REWARD_ROUTER)
        );
        IERC20Upgradeable mcbToken = IERC20Upgradeable(store.config.mustGetAddress(MCB_TOKEN));
        IERC20Upgradeable wethToken = IERC20Upgradeable(store.config.mustGetAddress(WETH_TOKEN));
        address vester = muxRewardRouter.mlpVester();
        require(vester != address(0), "StakeHelperImp::INVALID_VESTER");
        (uint256 wethAmount, , , , uint256 mcbAmount) = muxRewardRouter.claimableRewards(
            address(this)
        );
        muxRewardRouter.claimAll();
        if (wethAmount > 0) {
            wethToken.safeTransfer(receiver, wethAmount);
        }
        if (mcbAmount > 0) {
            mcbToken.safeTransfer(receiver, mcbAmount);
        }
        emit CollectRewards(wethAmount, mcbAmount);
    }

    function stake(JuniorStateStore storage store, uint256 amount) internal {
        // stake
        if (amount > 0) {
            IMuxRewardRouter muxRewardRouter = IMuxRewardRouter(
                store.config.mustGetAddress(MUX_REWARD_ROUTER)
            );
            IERC20Upgradeable mlpToken = IERC20Upgradeable(store.config.mustGetAddress(MLP_TOKEN));
            address mlpFeeTracker = muxRewardRouter.mlpFeeTracker();
            mlpToken.approve(address(mlpFeeTracker), amount);
            muxRewardRouter.stakeMlp(amount);
        }
    }

    function unstake(JuniorStateStore storage store, uint256 amount) internal {
        if (amount > 0) {
            IMuxRewardRouter muxRewardRouter = IMuxRewardRouter(
                store.config.mustGetAddress(MUX_REWARD_ROUTER)
            );
            IERC20Upgradeable sMlpToken = IERC20Upgradeable(
                store.config.mustGetAddress(SMLP_TOKEN)
            );
            // vest => smlp
            if (muxRewardRouter.reservedMlpAmount(address(this)) > 0) {
                muxRewardRouter.withdrawFromMlpVester();
            }
            // smlp => mlp
            sMlpToken.approve(muxRewardRouter.mlpFeeTracker(), amount);
            muxRewardRouter.unstakeMlp(amount);
        }
    }

    event AdjustVesting(
        uint256 vestedMlpAmount,
        uint256 vestedMuxAmount,
        uint256 requiredMlpAmount,
        uint256 totalMlpAmount,
        uint256 toVestMuxAmount
    );

    function adjustVesting(JuniorStateStore storage store) internal {
        IMuxRewardRouter muxRewardRouter = IMuxRewardRouter(
            store.config.mustGetAddress(MUX_REWARD_ROUTER)
        );
        IERC20Upgradeable muxToken = IERC20Upgradeable(store.config.mustGetAddress(MUX_TOKEN));
        IERC20Upgradeable sMlpToken = IERC20Upgradeable(store.config.mustGetAddress(SMLP_TOKEN));
        IMuxVester vester = IMuxVester(muxRewardRouter.mlpVester());
        require(address(vester) != address(0), "StakeHelperImp::INVALID_VESTER");
        uint256 muxAmount = muxToken.balanceOf(address(this));
        if (muxAmount == 0) {
            return;
        }
        uint256 vestedMlpAmount = vester.pairAmounts(address(this));
        uint256 vestedMuxAmount = vester.balanceOf(address(this));
        uint256 requiredMlpAmount = vester.getPairAmount(
            address(this),
            muxAmount + vestedMuxAmount
        );
        uint256 mlpAmount = sMlpToken.balanceOf(address(this)) + vestedMlpAmount;
        uint256 toVestMuxAmount;
        if (mlpAmount >= requiredMlpAmount) {
            toVestMuxAmount = muxAmount;
        } else {
            uint256 rate = (mlpAmount * ONE) / requiredMlpAmount;
            toVestMuxAmount = (muxAmount * rate) / ONE;
            if (toVestMuxAmount > vestedMuxAmount) {
                toVestMuxAmount = toVestMuxAmount - vestedMuxAmount;
            } else {
                toVestMuxAmount = 0;
            }
        }
        if (toVestMuxAmount > 0) {
            muxToken.approve(address(vester), toVestMuxAmount);
            muxRewardRouter.depositToMlpVester(toVestMuxAmount);
        }
        emit AdjustVesting(
            vestedMlpAmount,
            vestedMuxAmount,
            requiredMlpAmount,
            mlpAmount,
            toVestMuxAmount
        );
    }
}
