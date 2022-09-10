// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6 ;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token2 is ERC20 {
    constructor() ERC20("Token2", "TK2") public {}
}