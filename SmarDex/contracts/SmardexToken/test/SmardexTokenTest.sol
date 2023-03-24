// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../SmardexToken.sol";

contract SmardexTokenTest is SmardexToken {
    constructor(string memory _name, string memory _symbol, uint256 _supply) SmardexToken(_name, _symbol, _supply) {}

    function mint(address to, uint256 value) external {
        _mint(to, value);
    }
}
