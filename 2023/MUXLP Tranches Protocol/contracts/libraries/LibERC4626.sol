// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

struct ERC4626Store {
    uint8 assetDecimals;
    address asset;
    uint256 totalAssets;
    uint256 totalSupply;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    bytes32[20] __reserves;
}

library LibERC4626 {
    using MathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    function initialize(ERC4626Store storage store, address asset) internal {
        require(asset != address(0), "ERC4626Store::INVALID_ASSET");
        (bool success, uint8 decimals) = tryGetDecimals(asset);
        store.assetDecimals = success ? decimals : 18;
        store.asset = asset;
    }

    function tryGetDecimals(address asset) private view returns (bool, uint8) {
        (bool success, bytes memory encodedDecimals) = address(asset).staticcall(
            abi.encodeWithSignature("decimals()")
        );
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }

    function increaseAssets(ERC4626Store storage store, uint256 assets) internal {
        store.totalAssets += assets;
    }

    function decreaseAssets(ERC4626Store storage store, uint256 assets) internal {
        store.totalAssets -= assets;
    }

    function convertToShares(
        ERC4626Store storage store,
        uint256 assets
    ) internal view returns (uint256) {
        return convertToShares(store, assets, MathUpgradeable.Rounding.Down);
    }

    function convertToAssets(
        ERC4626Store storage store,
        uint256 shares
    ) internal view returns (uint256) {
        return convertToAssets(store, shares, MathUpgradeable.Rounding.Down);
    }

    function convertToShares(
        ERC4626Store storage store,
        uint256 assets,
        MathUpgradeable.Rounding rounding
    ) internal view returns (uint256) {
        return assets.mulDiv(store.totalSupply + 1, store.totalAssets + 1, rounding);
    }

    function convertToAssets(
        ERC4626Store storage store,
        uint256 shares,
        MathUpgradeable.Rounding rounding
    ) internal view returns (uint256) {
        return shares.mulDiv(store.totalAssets + 1, store.totalSupply + 1, rounding);
    }

    function balanceOf(
        ERC4626Store storage store,
        address account
    ) internal view returns (uint256) {
        return store.balances[account];
    }

    function transfer(
        ERC4626Store storage store,
        address to,
        uint256 amount
    ) internal returns (bool) {
        require(to != address(0), "ERC4626::INVALID_TO");
        address owner = msg.sender;
        update(store, owner, to, amount);
        return true;
    }

    function transferFrom(
        ERC4626Store storage store,
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        require(from != address(0), "ERC4626::INVALID_FROM");
        require(to != address(0), "ERC4626::INVALID_TO");
        address spender = msg.sender;
        spendAllowance(store, from, spender, amount);
        update(store, from, to, amount);
        return true;
    }

    function allowance(
        ERC4626Store storage store,
        address owner,
        address spender
    ) internal view returns (uint256) {
        return store.allowances[owner][spender];
    }

    function approve(
        ERC4626Store storage store,
        address spender,
        uint256 amount
    ) internal returns (bool) {
        address owner = msg.sender;
        approve(store, owner, spender, amount);
        return true;
    }

    function update(ERC4626Store storage store, address from, address to, uint256 amount) internal {
        if (from == address(0)) {
            store.totalSupply += amount;
        } else {
            uint256 fromBalance = store.balances[from];
            require(amount <= fromBalance, "ERC4626::EXCEEDED_BALANCE");
            store.balances[from] = fromBalance - amount;
        }
        if (to == address(0)) {
            store.totalSupply -= amount;
        } else {
            store.balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function approve(
        ERC4626Store storage store,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "ERC4626::INVALID_OWNER");
        require(spender != address(0), "ERC4626::INVALID_SPENDER");
        store.allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function spendAllowance(
        ERC4626Store storage store,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = allowance(store, owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(amount <= currentAllowance, "ERC4626::ALLOWANCE");
            approve(store, owner, spender, currentAllowance - amount);
        }
    }
}
