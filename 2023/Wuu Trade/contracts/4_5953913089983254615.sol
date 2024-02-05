// SPDX-License-Identifier: MIT
// File: @openzeppelin/contracts/utils/Context.sol

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


pragma solidity ^0.8.0;

contract Wuut is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("Wuu Trade", "WUUT") {
        _mint(msg.sender, 8_500_000_000 ether);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._transfer(sender, recipient, amount);
    }
}