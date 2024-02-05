/// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

/// @title MetaWealth's internal minimal access control implementation
/// @dev This contract implements only two roles, Super Admin and an Admin
/// @dev Super admin is only responsible for changing admins
/// @dev Normal admins are checked for all of the access controls otherwise
/// @author Ghulam Haider
interface IMetaWealthAccessControlled {
    /// @notice Maintain event logs for every admin change calls
    /// @param changedBy is the wallet that called the change
    /// @param newAccount is the account that was granted admin access
    /// @param isSuper is a boolean representing whether the role was superAdmin or not
    event AdminChanged(address changedBy, address newAccount, bool isSuper);

    /// @notice Returns the current admin address
    /// @return adminWallet is the wallet address of current admin
    function getAdmin() external view returns(address adminWallet);

    /// @notice Grants admin role access to a new account, revoking from previous
    /// @param newAccount is the new wallet address to grant admin role to
    function setAdmin(address newAccount) external;

    /// @notice Returns the current super admin address
    /// @return superAdminWallet is the wallet address of current super admin
    function getSuperAdmin() external view returns(address superAdminWallet);

    /// @notice Grants super admin role access to a new account, revoking from previous
    /// @param newAccount is the new wallet address to grant super admin role to
    function setSuperAdmin(address newAccount) external;
}
