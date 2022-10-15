// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC20 is ERC20, Ownable {
    constructor() ERC20("MocKERC20", "M20") {
        _mint(_msgSender(), 1 ether * 1 ether);
    }

    function mint() public {
        _mint(_msgSender(), 1 ether * 1 ether);
    }
}
