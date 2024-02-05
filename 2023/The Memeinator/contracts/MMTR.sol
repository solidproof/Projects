// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MMTRToken is ERC20 {
    constructor() ERC20("Memeinator", "MMTR") {
        address target = 0x65aC517c376D7586CB8e5A62d5a498953bDCEd5D;
        _mint(target, 1_000_000_000 * (10 ** decimals()));
    }
}
