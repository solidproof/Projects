// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../ShareholderRegistry/IShareholderRegistry.sol";
import "./VotingSnapshot.sol";
import { Roles } from "../extensions/Roles.sol";
import "../extensions/DAORoles.sol";
import "../extensions/HasRole.sol";

contract Voting is VotingSnapshot, Initializable, HasRole {
    function initialize(DAORoles roles) public initializer {
        _setRoles(roles);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    modifier onlyToken() virtual {
        require(
            msg.sender == address(_token) ||
                msg.sender == address(_shareholderRegistry),
            "Voting: only Token contract can call this method."
        );
        _;
    }

    // Dependencies

    function setToken(
        IERC20Upgradeable token
    ) external virtual override onlyRole(Roles.OPERATOR_ROLE) {
        super._setToken(token);
    }

    function setShareholderRegistry(
        IShareholderRegistry shareholderRegistry
    ) external virtual override onlyRole(Roles.OPERATOR_ROLE) {
        _setShareholderRegistry(shareholderRegistry);
    }

    // Snapshottable

    function snapshot()
        public
        virtual
        override
        onlyRole(Roles.RESOLUTION_ROLE)
        returns (uint256)
    {
        return _snapshot();
    }

    // Hooks

    /// @dev Hook to be called by the companion token upon token transfer
    /// @notice Only the companion token can call this method
    /// @notice The voting power transfer logic relies on the correct usage of this hook from the companion token
    /// @param from The sender's address
    /// @param to The receiver's address
    /// @param amount The amount sent
    function afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) external virtual override onlyToken {
        _afterTokenTransfer(from, to, amount);
    }

    function beforeRemoveContributor(
        address account
    ) external virtual override onlyRole(Roles.SHAREHOLDER_REGISTRY_ROLE) {
        _beforeRemoveContributor(account);
    }

    function afterAddContributor(
        address account
    ) external virtual override onlyRole(Roles.SHAREHOLDER_REGISTRY_ROLE) {
        _afterAddContributor(account);
    }

    // Public

    /// @dev Allows sender to delegate another address for voting
    /// @notice The first address to be delegated must be the sender itself
    /// @notice Sub-delegation is not allowed
    /// @param newDelegate Destination address of module transaction.
    function delegate(address newDelegate) public virtual override {
        _delegate(msg.sender, newDelegate);
    }

    /// @dev Allows sender to delegate another address for voting
    /// @notice Sub-delegation is not allowed
    /// @param delegator Delegating address.
    /// @param newDelegate Destination address of module transaction.
    function delegateFrom(
        address delegator,
        address newDelegate
    ) public virtual override onlyRole(Roles.RESOLUTION_ROLE) {
        _delegate(delegator, newDelegate);
    }
}
