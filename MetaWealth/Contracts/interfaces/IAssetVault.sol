// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

/// @title MetaWealth Asset Fractionalizer Contract
/// @author Ghulam Haider
/// @notice Prefer deploying this contract through FractionalizerFactory
interface IAssetVault {
    /// @notice Fires when trading currency for an asset is changed
    /// @param oldCurrency is the previously-used currency
    /// @param newCurrency is the new currency added
    event CurrencyChanged(address oldCurrency, address newCurrency);

    /// @notice Emits when the trading is enabled/disabled for the asset
    /// @param trading is the boolean representing the new state of trading
    event StatusChanged(bool trading);

    /// @notice Emits when funcds are deposited and distributed to the users
    /// @param currency is the token that the funds were paid in
    /// @param amount is the amount distributed to the holders
    event FundsDeposited(address currency, uint256 amount);

    /// @notice For cross-contract operability, returns the read-only parameters
    /// @return active_ is the trade activity status of asset
    function isActive() external view returns (bool active_);

    /// @notice Returns the asset's current trading currency
    /// @return currency is the currency the asset is being traded at
    function getTradingCurrency() external view returns (address currency);

    /// @notice Changes the asset's trading currency to a new one
    /// @param newCurrency is the currency to change to
    function setTradingCurrency(address newCurrency) external;

    /// @notice Toggles between active/inactive status for this asset
    /// @notice If inactive, no trades can occur for this asset
    /// @return newStatus is the active/inactive state after execution of this function
    function toggleStatus() external returns (bool newStatus);

    /// @notice Allows off-chain asset manager to distribute funds to the asset owners
    /// @dev Requires the admin to pre-approve the token to be distributed seamlessly
    /// @dev todo Could possibly introduce MetaWealthTreasury contract to eliminate approvals
    /// @param amount is the price is baseCurrency that is being deposited
    function deposit(uint256 amount) external;

    /// @notice Burns specified shares from owner's balance
    /// @param amount is the amount of shares to burn
    /// @dev For security reasons, only the owner can burn, and only the amount that they hold
    function burn(uint256 amount) external;
}
