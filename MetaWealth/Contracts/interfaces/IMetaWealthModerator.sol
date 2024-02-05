/// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

import "./IMetaWealthAccessControlled.sol";

/// @title MetaWealth's centralized moderation contract for currencies and whitelist checks
/// @author Ghulam Haider
interface IMetaWealthModerator is IMetaWealthAccessControlled {
    /// @notice Fired when a currency support is added/removed
    /// @param currency is the address of the currency
    /// @param supported is the boolean representing the support state
    /// @param isDefault is the boolean representing if this is set as default currency
    event CurrencySupportToggled(address currency, bool supported, bool isDefault);

    /// @notice Fired when KYC Whitelist root is changed
    /// @param oldRoot is the previous root of the merkle tree
    /// @param newRoot is the updated root of the merkle tree
    event WhitelistRootUpdated(bytes32 oldRoot, bytes32 newRoot);

    /// @notice Fired when default burning unlock period is changed
    /// @param oldPeriod is the previous unlock time in seconds
    /// @param newPeriod is the new unlock time in seconds
    event UnlockPeriodChanged(uint64 oldPeriod, uint64 newPeriod);

    /// @notice Checks if currency is supported
    /// @param token is the address of currency to check
    /// @return supported is the boolean representing if the currency is supported
    function isSupportedCurrency(address token) external view returns (bool supported);

    /// @notice Return the default currency supported by MetaWealth platform
    /// @return defaultCurrency is the default currency supported by the platform
    function getDefaultCurrency() external view returns (address defaultCurrency);

    /// @notice Change the MetaWealth defaault platform currency
    /// @param newCurrency is the new token to set as MetaWealth's default currency
    function setDefaultCurrency(address newCurrency) external;

    /// @notice Owner can add/remove supported currencies
    /// @param token is the currency to change status of
    /// @return newState is the state of currency being added/removed
    function toggleSupportedCurrency(address token) external returns (bool newState);

    /// @notice Deployer can update the root
    /// @param _newRoot is the new merkle tree root to replace from
    function updateWhitelistRoot(bytes32 _newRoot) external;

    /// @notice Checks if an arbitrary wallet is whitelisted
    /// @param _merkleProof is the proof of merkle tree to check against
    /// @param wallet is the addres to check whitelist of
    /// @return whitelisted is the boolean representing the whitelist state
    function checkWhitelist(bytes32[] calldata _merkleProof, address wallet)
        external
        view
        returns (bool whitelisted);

    /// @notice Returns the default unlock period to defractionalize assets
    /// @return unlockPeriod is the number of seconds after deployment
    function getDefaultUnlockPeriod() external view returns(uint64 unlockPeriod);

    /// @notice Changes the unlock period timestamp for fracitonal assets
    /// @param newPeriod is the number of seconds to change to
    function setDefaultUnlockPeriod(uint64 newPeriod) external;
}
