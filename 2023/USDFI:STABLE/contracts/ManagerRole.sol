/**
 * @title Manager Role
 * @dev ManagerRole contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

import "./Roles.sol";
import "./Ownable.sol";

contract ManagerRole is Ownable {
    using Roles for Roles.Role;

    event ManagerAdded(address indexed account);
    event ManagerRemoved(address indexed account);

    Roles.Role private _managers;

    constructor() internal {
        _addManager(msg.sender);
    }

    modifier onlyManager() {
        require(
            isManager(msg.sender),
            "ManagerRole: caller does not have the Manager role"
        );
        _;
    }

    /**
     * @dev Returns account address is Manager true or false.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address
     */
    function isManager(address account) public view returns (bool) {
        return _managers.has(account);
    }

    /**
     * @dev Adds address to the Manager role.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address
     */
    function addManager(address account) public onlyOwner {
        _addManager(account);
    }

    /**
     * @dev Removes address from the Manager role.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address
     */
    function renounceManager(address account) public onlyOwner {
        _removeManager(account);
    }

    /**
     * @dev Adds address to the Manager role (internally).
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address
     */
    function _addManager(address account) internal {
        _managers.add(account);
        emit ManagerAdded(account);
    }

    /**
     * @dev Removes address from the Manager role (internally).
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address
     */
    function _removeManager(address account) internal {
        _managers.remove(account);
        emit ManagerRemoved(account);
    }
}
