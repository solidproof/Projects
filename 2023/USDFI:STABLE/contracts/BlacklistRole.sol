/**
 * @title Blacklist Role
 * @dev BlacklistRole contract
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

contract BlacklistRole is Ownable {
    using Roles for Roles.Role;

    event BlacklisterAdded(address indexed account);
    event BlacklisterRemoved(address indexed account);

    Roles.Role private _blacklisters;

    constructor() internal { // @audit - checked
        _addBlacklister(msg.sender);
    }

    modifier onlyBlacklister() { // @audit - checked
        require(
            isBlacklister(msg.sender),
            "BlacklisterRole: caller does not have the Blacklister role"
        );
        _;
    }

    /**
     * @dev Returns _account address is Blacklister true or false
     *
     * Requirements:
     *
     * - address `_account` cannot be the zero address
     */
    function isBlacklister(address _account) public view returns (bool) { // @audit - checked
        return _blacklisters.has(_account);
    }

    /**
     * @dev add address to the Blacklister role.
     *
     * Requirements:
     *
     * - address `_account` cannot be the zero address
     */
    function addBlacklister(address _account) public onlyOwner { // @audit - checked
        _addBlacklister(_account);
    }

    /**
     * @dev remove address from the Blacklister role.
     *
     * Requirements:
     *
     * - address `_account` cannot be the zero address
     */
    function renounceBlacklister(address _account) public onlyOwner { // @audit - checked
        _removeBlacklister(_account);  // @audit-info - blacklister should be able to renounce their own role
    }

    /**
     * @dev add address to the Blacklister role (internal).
     *
     * Requirements:
     *
     * - address `_account` cannot be the zero address
     */
    function _addBlacklister(address _account) internal { // @audit - checked
        _blacklisters.add(_account);// @audit-issue - zero/dead address
        emit BlacklisterAdded(_account);
    }

    /**
     * @dev remove address from the Blacklister role (internal).
     *
     * Requirements:
     *
     * - address `_account` cannot be the zero address
     */
    function _removeBlacklister(address _account) internal { // @audit - checked
        _blacklisters.remove(_account); // @audit-issue - zero/dead address
        emit BlacklisterRemoved(_account);
    }
}
