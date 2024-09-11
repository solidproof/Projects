// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ThetsToken is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 210_000_000 * (10 ** 18);  // 210 milyon token, 18 ondalık basamak

    constructor() ERC20("ThetsToken", "THETS") {
        _mint(msg.sender, INITIAL_SUPPLY);  // Sözleşme sahibine tüm tokenları bas ve transfer et
    }
}