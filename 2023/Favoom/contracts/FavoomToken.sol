// SPDX-License-Identifier: MIT
// Favoom (FAV) ERC20 token
// (c)2023 Favoom - Web3 social media platform
// https://favoom.com
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @custom:security-contact security@favoom.com
contract FavoomToken is ERC20Burnable, ERC20Capped, ERC20Permit {
    constructor(address minter)
    ERC20("Favoom", "FAV")
    ERC20Capped(1_000_000_000 ether)
    ERC20Permit("Favoom")
    {
        _mint(minter, 1_000_000_000 ether);
    }

    function _update(address from, address to, uint256 value) internal virtual override (ERC20, ERC20Capped) {
        super._update(from, to, value);
    }
}