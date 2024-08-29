// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./GenericToken.sol";

contract BuldakToken is GenericToken {
    constructor() GenericToken("BULDAK", "BUL", 4_200_000_000_000 * (10**18)) {}
}