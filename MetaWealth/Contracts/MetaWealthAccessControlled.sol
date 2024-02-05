/// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Context.sol";
import "./interfaces/IMetaWealthAccessControlled.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MetaWealthAccessControlled is
    IMetaWealthAccessControlled,
    Context,
    Initializable
{
    /// @notice Maintain exactly one super admin at state-level
    address public superAdmin;

    /// @notice Maintain exactly one admin at state-level
    address public admin;

    /// @notice Modifier to check if caller is super admin or not
    modifier onlySuperAdmin() {
        require(
            _msgSender() == superAdmin,
            "MetaWealthAccessControl: Resctricted to Super Admins"
        );
        _;
    }

    /// @notice Modifier to check if caller is an admin
    modifier onlyAdmin() {
        require(
            _msgSender() == superAdmin || _msgSender() == admin,
            "MetaWealthAccessControl: Resctricted to Admins"
        );
        _;
    }

    /// @notice Instantiate the smart contract with necessary roles
    /// @custom:oz-upgrades-unsafe-allow constructor
    function initializeMetaWealthAccessControl() public initializer {
        superAdmin = _msgSender();
        admin = _msgSender();
    }

    function getAdmin() external view override returns (address) {
        return admin;
    }

    function setAdmin(address newAccount) external override onlySuperAdmin {
        admin = newAccount;
        emit AdminChanged(_msgSender(), newAccount, false);
    }

    function getSuperAdmin() external view override returns (address) {
        return superAdmin;
    }

    function setSuperAdmin(address newAccount)
        external
        override
        onlySuperAdmin
    {
        superAdmin = newAccount;
        emit AdminChanged(_msgSender(), newAccount, true);
    }
}
