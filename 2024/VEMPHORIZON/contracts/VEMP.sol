// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VEMP is ERC20 {
    constructor() ERC20("VEMP", "VEMP") {
        _mint(msg.sender, 500000000 * 10 ** decimals());
    }
}