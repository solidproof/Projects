// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
// Contact: Linktr.ee/kiversegames

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @custom:security-contact admin@kiversegames.io
contract Kiverse is ERC20, ERC20Permit, Ownable {
    constructor(address initialOwner)
        ERC20("Kiverse", "KIVR")
        ERC20Permit("Kiverse")
        Ownable(initialOwner)
    {
        _mint(msg.sender, 100000000000 * 10 ** decimals());
    }
}