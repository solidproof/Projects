//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

interface IRoleManager {

    function isAdmin(address account) external returns (bool);

    function isIDOManager(address account) external returns (bool);

    function isIDOManagerAdmin(address account) external returns (bool);

    function isIDOModerator(address account) external returns (bool);

    function grantRole(bytes32 role, address account) external;

    function IDOManagerRole() external returns (bytes32);

    function IDOManagerAdminRole() external returns (bytes32);
}
