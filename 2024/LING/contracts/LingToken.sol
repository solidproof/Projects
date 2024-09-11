// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20.sol";

/// @custom:security-contact info@lingontron.com
contract LingToken is ERC20 {
    constructor() ERC20("LING", "LING") {
        _mint(msg.sender, 10000000000 * 10 ** decimals());
    }
}