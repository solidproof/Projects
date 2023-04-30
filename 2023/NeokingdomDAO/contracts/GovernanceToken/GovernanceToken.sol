// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./GovernanceTokenSnapshot.sol";
import { Roles } from "../extensions/Roles.sol";
import "../extensions/DAORoles.sol";
import "../extensions/HasRole.sol";

contract GovernanceToken is Initializable, HasRole, GovernanceTokenSnapshot {
    function initialize(
        DAORoles roles,
        string memory name,
        string memory symbol
    ) public initializer {
        _initialize(name, symbol);
        _setRoles(roles);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function snapshot()
        public
        virtual
        override
        onlyRole(Roles.RESOLUTION_ROLE)
        returns (uint256)
    {
        return _snapshot();
    }

    function setVoting(
        IVoting voting
    ) external virtual onlyRole(Roles.OPERATOR_ROLE) {
        _setVoting(voting);
    }

    function setTokenExternal(
        address tokenExternalAddress
    ) external virtual onlyRole(Roles.OPERATOR_ROLE) {
        _setTokenExternal(tokenExternalAddress);
    }

    function setRedemptionController(
        IRedemptionController redemption
    ) external virtual onlyRole(Roles.OPERATOR_ROLE) {
        _setRedemptionController(redemption);
    }

    function mint(
        address to,
        uint256 amount
    ) public virtual onlyRole(Roles.RESOLUTION_ROLE) {
        _mint(to, amount);
    }

    function burn(
        address from,
        uint256 amount
    ) public virtual onlyRole(Roles.MARKET_ROLE) {
        _burn(from, amount);
    }

    function wrap(
        address from,
        uint256 amount
    ) public virtual onlyRole(Roles.MARKET_ROLE) {
        _wrap(from, amount);
    }

    function unwrap(
        address from,
        address to,
        uint256 amount
    ) public virtual onlyRole(Roles.MARKET_ROLE) {
        _unwrap(from, to, amount);
    }

    function mintVesting(
        address to,
        uint256 amount
    ) public virtual onlyRole(Roles.RESOLUTION_ROLE) {
        _mintVesting(to, amount);
    }

    function setVesting(
        address to,
        uint256 amount
    ) public virtual onlyRole(Roles.OPERATOR_ROLE) {
        _setVesting(to, amount);
    }

    function transfer(
        address to,
        uint256 amount
    )
        public
        virtual
        override(ERC20Upgradeable, IERC20Upgradeable)
        onlyRole(Roles.MARKET_ROLE)
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        virtual
        override(ERC20Upgradeable, IERC20Upgradeable)
        onlyRole(Roles.MARKET_ROLE)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }
}
