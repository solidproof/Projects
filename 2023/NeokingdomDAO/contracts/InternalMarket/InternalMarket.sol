// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../ShareholderRegistry/IShareholderRegistry.sol";
import "./InternalMarketBase.sol";
import { Roles } from "../extensions/Roles.sol";
import "../extensions/DAORoles.sol";
import "../extensions/HasRole.sol";

contract InternalMarket is Initializable, HasRole, InternalMarketBase {
    function initialize(
        DAORoles roles,
        IGovernanceToken tokenInternal
    ) public initializer {
        _initialize(tokenInternal, 7 days);
        _setRoles(roles);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function makeOffer(uint256 amount) public virtual {
        _makeOffer(_msgSender(), amount);
    }

    function matchOffer(address account, uint amount) public {
        _matchOffer(account, _msgSender(), amount);
    }

    function withdraw(address to, uint amount) public {
        _withdraw(_msgSender(), to, amount);
    }

    function deposit(uint amount) public {
        _deposit(_msgSender(), amount);
    }

    function redeem(uint amount) public {
        _redeem(_msgSender(), amount);
    }

    function setInternalToken(
        IGovernanceToken token
    ) public onlyRole(Roles.RESOLUTION_ROLE) {
        _setInternalToken(token);
    }

    function setShareholderRegistry(
        IShareholderRegistry shareholderRegistry
    ) public onlyRole(Roles.RESOLUTION_ROLE) {
        _setShareholderRegistry(shareholderRegistry);
    }

    function setExchangePair(
        ERC20 token,
        IStdReference oracle
    ) public onlyRole(Roles.RESOLUTION_ROLE) {
        _setExchangePair(token, oracle);
    }

    function setReserve(
        address reserve_
    ) public onlyRole(Roles.RESOLUTION_ROLE) {
        _setReserve(reserve_);
    }

    function setRedemptionController(
        IRedemptionController redemptionController_
    ) public onlyRole(Roles.RESOLUTION_ROLE) {
        _setRedemptionController(redemptionController_);
    }

    function setOfferDuration(
        uint duration
    ) public onlyRole(Roles.RESOLUTION_ROLE) {
        _setOfferDuration(duration);
    }
}
