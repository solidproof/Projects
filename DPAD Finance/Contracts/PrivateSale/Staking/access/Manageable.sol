// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.4.0;

import '../GSN/Context.sol';

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an manager) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the manager account will be the one that deploys the contract. This
 * can later be changed with {transferManagement}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyManager`, which can be applied to your functions to restrict their use to
 * the manager.
 */
contract Manageable is Context {
    address private _manager;

    event ManagementTransferred(address indexed previousManager, address indexed newManager);

    /**
     * @dev Initializes the contract setting the deployer as the initial manager.
     */
    constructor() internal {
        address msgSender = _msgSender();
        _manager = msgSender;
        emit ManagementTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current manager.
     */
    function manager() public view returns (address) {
        return _manager;
    }

    /**
     * @dev Throws if called by any account other than the manager.
     */
    modifier onlyManager() {
        require(_manager == _msgSender(), 'Manageable: caller is not the manager');
        _;
    }

    /**
     * @dev Leaves the contract without manager. It will not be possible to call
     * `onlyManager` functions anymore. Can only be called by the current manager.
     *
     * NOTE: Renouncing management will leave the contract without an manager,
     * thereby removing any functionality that is only available to the manager.
     */
    function renounceManagement() public onlyManager {
        emit ManagementTransferred(_manager, address(0));
        _manager = address(0);
    }

    /**
     * @dev Transfers management of the contract to a new account (`newManager`).
     * Can only be called by the current manager.
     */
    function transferManagement(address newManager) public onlyManager {
        _transferManagement(newManager);
    }

    /**
     * @dev Transfers management of the contract to a new account (`newManager`).
     */
    function _transferManagement(address newManager) internal {
        require(newManager != address(0), 'Manageable: new manager is the zero address');
        emit ManagementTransferred(_manager, newManager);
        _manager = newManager;
    }
}
