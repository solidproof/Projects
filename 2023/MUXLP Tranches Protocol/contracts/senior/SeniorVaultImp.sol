// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../libraries/LibConfigSet.sol";
import "../libraries/LibERC4626.sol";
import "./SeniorVaultStore.sol";

library SeniorVaultImp {
    using LibERC4626 for ERC4626Store;
    using LibConfigSet for LibConfigSet.ConfigSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event Deposit(address indexed owner, uint256 assets, uint256 shares, uint256 unlockTime);
    event Withdraw(
        address indexed caller,
        address indexed owner,
        uint256 shares,
        uint256 assets,
        address receiver,
        uint256 penalty
    );
    event Borrow(uint256 assets, address receiver);
    event Repay(uint256 assets, address receiver);

    event TransferIn(uint256 assets);
    event TransferOut(uint256 assets, address receiver);

    function initialize(SeniorStateStore storage store, address asset) internal {
        store.asset.initialize(asset);
    }

    function totalAssets(SeniorStateStore storage store) internal view returns (uint256) {
        return store.asset.totalAssets;
    }

    function borrowable(
        SeniorStateStore storage store,
        address receiver
    ) internal view returns (uint256 assets) {
        // max borrows
        uint256 maxBorrow = store.config.getUint256(MAX_BORROWS);
        uint256 available = IERC20Upgradeable(store.asset.asset).balanceOf(address(this));
        if (maxBorrow != 0) {
            uint256 capacity = maxBorrow > store.totalBorrows ? maxBorrow - store.totalBorrows : 0;
            assets = MathUpgradeable.min(capacity, available);
        } else {
            assets = available;
        }
        uint256 borrowLimit = store.config.getUint256(keccak256(abi.encode(MAX_BORROWS, receiver)));
        if (borrowLimit != 0) {
            uint256 capacity = borrowLimit > store.borrows[receiver]
                ? borrowLimit - store.borrows[receiver]
                : 0;
            assets = MathUpgradeable.min(capacity, borrowLimit);
        }
    }

    function balanceOf(
        SeniorStateStore storage store,
        address owner
    ) internal view returns (uint256) {
        return store.asset.balanceOf(owner);
    }

    function convertToShares(
        SeniorStateStore storage store,
        uint256 assets // assetDecimals
    ) internal view returns (uint256 shares) {
        shares = assets * (10 ** (18 - store.asset.assetDecimals));
    }

    function convertToAssets(
        SeniorStateStore storage store,
        uint256 shares
    ) internal view returns (uint256 assets) {
        assets = shares / (10 ** (18 - store.asset.assetDecimals));
    }

    // deposit stable coin into vault
    function deposit(
        SeniorStateStore storage store,
        uint256 assets,
        address receiver
    ) internal returns (uint256 shares) {
        require(assets > 0, "SeniorVaultImp::INVALID_ASSETS");
        shares = convertToShares(store, assets);
        store.asset.update(address(0), receiver, shares);
        transferIn(store, assets);
        uint256 unlockTime = updateTimelock(store, receiver);

        emit Deposit(receiver, assets, shares, unlockTime);
    }

    function withdraw(
        SeniorStateStore storage store,
        address caller,
        address owner,
        uint256 shares,
        address receiver
    ) internal returns (uint256 assets, uint256 penalty) {
        require(shares <= balanceOf(store, owner), "SeniorVaultImp::EXCEEDS_MAX_REDEEM");
        assets = convertToAssets(store, shares);
        if (caller != owner) {
            store.asset.spendAllowance(owner, caller, shares);
        }
        store.asset.update(owner, address(0), shares);
        penalty = collectPenaltyByTimelock(store, owner, assets);
        assets -= penalty;
        transferOut(store, assets, receiver);

        emit Withdraw(caller, owner, shares, assets, receiver, penalty);
    }

    function collectPenaltyByTimelock(
        SeniorStateStore storage store,
        address owner,
        uint256 assets // assetDecimals
    ) internal returns (uint256) {
        if (block.timestamp > store.timelocks[owner]) {
            return 0;
        }
        LockType lockType = LockType(store.config.getUint256(LOCK_TYPE));
        if (lockType == LockType.HardLock) {
            require(block.timestamp > store.timelocks[owner], "SeniorVaultImp::LOCKED");
        } else if (lockType == LockType.SoftLock) {
            uint256 lockPenaltyRate = store.config.getUint256(LOCK_PENALTY_RATE);
            address receiver = store.config.getAddress(LOCK_PENALTY_RECIPIENT);
            if (lockPenaltyRate != 0 && receiver != address(0)) {
                uint256 penalty = (assets * lockPenaltyRate) / ONE;
                transferOut(store, penalty, receiver);
                return penalty;
            }
        }
        return 0;
    }

    function borrow(SeniorStateStore storage store, uint256 assets, address receiver) internal {
        uint256 borrowableAssets = borrowable(store, receiver);
        require(assets <= borrowableAssets, "SeniorVaultImp::EXCEEDS_BORROWABLE");
        store.borrows[receiver] += assets;
        store.totalBorrows += assets;
        transferOut(store, assets, receiver);

        emit Borrow(assets, receiver);
    }

    function repay(SeniorStateStore storage store, address repayer, uint256 assets) internal {
        require(assets <= store.totalBorrows, "SeniorVaultImp::EXCEEDS_TOTAL_BORROWS");
        transferIn(store, assets);
        store.totalBorrows -= assets;
        store.borrows[repayer] -= assets;

        emit Repay(assets, repayer);
    }

    function transferIn(SeniorStateStore storage store, uint256 assets) internal {
        uint256 balance = IERC20Upgradeable(store.asset.asset).balanceOf(address(this));
        uint256 delta = balance - store.previousBalance;
        require(delta >= assets, "SeniorVaultImp::INSUFFICENT_ASSETS");
        store.previousBalance = balance;
        store.asset.increaseAssets(assets);

        emit TransferIn(assets);
    }

    function transferOut(
        SeniorStateStore storage store,
        uint256 assets,
        address receiver
    ) internal {
        IERC20Upgradeable(store.asset.asset).safeTransfer(receiver, assets);
        store.previousBalance = IERC20Upgradeable(store.asset.asset).balanceOf(address(this));
        store.asset.decreaseAssets(assets);

        emit TransferOut(assets, receiver);
    }

    function updateTimelock(
        SeniorStateStore storage store,
        address receiver
    ) internal returns (uint256 unlockTime) {
        uint256 lockType = store.config.getUint256(LOCK_TYPE);
        uint256 lockPeriod = store.config.getUint256(LOCK_PERIOD);
        if (lockType == uint256(LockType.None)) {
            unlockTime = store.timelocks[receiver];
        } else {
            unlockTime = block.timestamp + lockPeriod;
            store.timelocks[receiver] = unlockTime;
        }
    }
}
