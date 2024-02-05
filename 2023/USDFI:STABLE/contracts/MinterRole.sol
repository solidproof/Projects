/**
 * @title Minter Role
 * @dev MinterRole contract
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

contract MinterRole is Ownable {
    using Roles for Roles.Role;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    constructor() internal {
        _addMinter(msg.sender);
    }

    modifier onlyMinter() {
        require(
            isMinter(msg.sender),
            "MinterRole: caller does not have the Minter role"
        );
        _;
    }

    /**
     * @dev Returns account address is Minter true or false.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address
     */
    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    /**
     * @dev Adds address to the Minter role.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address
     */
    function addMinter(address account) public onlyOwner {
        _addMinter(account);
    }

    /**
     * @dev Removes address from the Minter role.
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address
     */
    function renounceMinter(address account) public onlyOwner {
        _removeMinter(account);
    }

    /**
     * @dev Adds address to the Minter role (internally).
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address
     */
    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    /**
     * @dev Removes address from the Minter role (internally).
     *
     * Requirements:
     *
     * - address `account` cannot be the zero address
     */
    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}
