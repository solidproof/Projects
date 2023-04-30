// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./RedemptionControllerBase.sol";
import { Roles } from "../extensions/Roles.sol";
import "../extensions/DAORoles.sol";
import "../extensions/HasRole.sol";

// Redeemable tokens are decided on Offer
// - when user offers, we check how many tokens are eligible for redemption (3 months, 15 months rule)
//   and mark it as redeemable in 60 days
// - when user offers, we check how many tokens are in the vault and how many are currently redeemable. We take the redeemable amount
//   straight into the vault, the rest remains locked for 7 days
// - when 60 days pass, the token are redeemable for 10 days
//    - if the user redeems, tokens are subtracted
//    - if the user moves the tokens to the outside or to the contributor wallet, tokens are subtracted
//    - if the user forgets, the tokens are not redeemable. they can only be moved outside the vault (contributor or 2ndary)
// - when the 10 days expire
//    -

// The contract tells how many tokens are redeemable by Contributors

contract RedemptionController is
    Initializable,
    HasRole,
    RedemptionControllerBase
{
    function initialize(DAORoles roles) public initializer {
        _setRoles(roles);
        _initialize();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function afterMint(
        address to,
        uint256 amount
    ) external override onlyRole(Roles.TOKEN_MANAGER_ROLE) {
        _afterMint(to, amount);
    }

    function afterOffer(
        address account,
        uint256 amount
    ) external override onlyRole(Roles.TOKEN_MANAGER_ROLE) {
        _afterOffer(account, amount);
    }

    function afterRedeem(
        address account,
        uint256 amount
    ) external override onlyRole(Roles.TOKEN_MANAGER_ROLE) {
        _afterRedeem(account, amount);
    }
}
