// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Frens is ERC20, Ownable {
    constructor() ERC20("Frens", "FREN") {
       _mint(msg.sender, 690_420_000_000_000 * 10**18);
    }
}