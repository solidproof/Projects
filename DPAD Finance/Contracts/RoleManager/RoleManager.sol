//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract RoleManager is AccessControlEnumerable {

    bytes32 public constant IDOManagerRole = keccak256('IDOManagerRole');
    bytes32 public constant IDOManagerAdminRole = keccak256('IDOManagerAdminRole');
    bytes32 public constant IDOModeratorRole = keccak256('IDOModeratorRole');

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(IDOManagerRole, IDOManagerAdminRole);
        _setRoleAdmin(IDOManagerAdminRole, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(IDOModeratorRole, DEFAULT_ADMIN_ROLE);

        grantRole(IDOManagerAdminRole, msg.sender); // Make owner ido manager
        grantRole(IDOManagerRole, msg.sender); // Make owner ido manager
        grantRole(IDOModeratorRole, msg.sender); // make owner ido moderator
    }

    function isAdmin(address account) public virtual view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function isIDOManager(address account) public virtual view returns (bool) {
        return hasRole(IDOManagerRole, account);
    }

    function isIDOManagerAdmin(address account) public virtual view returns (bool) {
        return hasRole(IDOManagerAdminRole, account);
    }

    function isIDOModerator(address account) public virtual view returns (bool) {
        return hasRole(IDOModeratorRole, account);
    }
}
