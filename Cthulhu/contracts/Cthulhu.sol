//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract Cthulhu is ERC20 {
    constructor(address account) ERC20("Cthulhu", "CTH") {
        _mint(account, 40_000_000e18);
    }
}