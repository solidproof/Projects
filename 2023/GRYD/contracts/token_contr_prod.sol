// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GRYD is ERC20 {
    constructor() ERC20("GRYD", "GRD") {
        _mint(msg.sender, 5000000000 * 10 ** decimals());
    }
}