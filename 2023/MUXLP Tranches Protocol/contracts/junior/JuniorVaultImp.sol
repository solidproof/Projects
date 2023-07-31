// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../libraries/LibERC4626.sol";
import "./Type.sol";
import "./StakeHelperImp.sol";

library JuniorVaultImp {
    using LibERC4626 for ERC4626Store;
    using StakeHelperImp for JuniorStateStore;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using LibConfigSet for LibConfigSet.ConfigSet;

    event Deposit(address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller,
        address indexed owner,
        uint256 shares,
        uint256 assets,
        address receiver
    );
    event TransferIn(uint256 assets);
    event TransferOut(uint256 assets, address receiver);

    function initialize(JuniorStateStore storage store, address asset) internal {
        store.asset.initialize(asset);
    }

    function totalAssets(
        JuniorStateStore storage store
    ) internal view returns (uint256 totalManagedAssets) {
        totalManagedAssets = store.asset.totalAssets;
    }

    function balanceOf(
        JuniorStateStore storage store,
        address owner
    ) internal view returns (uint256) {
        return store.asset.balanceOf(owner);
    }

    function deposit(
        JuniorStateStore storage store,
        uint256 assets,
        address receiver
    ) internal returns (uint256 shares) {
        shares = store.asset.convertToShares(assets);
        store.asset.update(address(0), receiver, shares);
        transferIn(store, assets);
        emit Deposit(receiver, assets, shares);
    }

    function withdraw(
        JuniorStateStore storage store,
        address caller,
        address owner,
        uint256 shares,
        address receiver
    ) internal returns (uint256 assets) {
        require(shares <= balanceOf(store, owner), "JuniorVaultImp::EXCEEDS_BALANCE");
        if (caller != owner) {
            store.asset.spendAllowance(owner, caller, shares);
        }
        assets = store.asset.convertToAssets(shares);
        store.asset.update(owner, address(0), shares);
        transferOut(store, assets, receiver);

        emit Withdraw(caller, owner, shares, assets, receiver);
    }

    function transferIn(JuniorStateStore storage store, uint256 assets) internal {
        uint256 balance = IERC20Upgradeable(store.depositToken).balanceOf(address(this));
        require(balance >= assets, "JuniorVaultImp::INSUFFICIENT_ASSETS");
        store.asset.increaseAssets(assets);
        store.stake(assets);
        store.adjustVesting();

        emit TransferIn(assets);
    }

    function transferOut(
        JuniorStateStore storage store,
        uint256 assets,
        address receiver
    ) internal {
        require(assets <= store.asset.totalAssets, "JuniorVaultImp::INSUFFICIENT_ASSETS");
        store.unstake(assets);
        IERC20Upgradeable(store.depositToken).safeTransfer(receiver, assets);
        store.asset.decreaseAssets(assets);
        store.adjustVesting();

        emit TransferOut(assets, receiver);
    }

    function collectRewards(JuniorStateStore storage store, address receiver) internal {
        store.collectRewards(receiver);
    }

    function adjustVesting(JuniorStateStore storage store) internal {
        store.adjustVesting();
    }
}
