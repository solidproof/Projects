// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract LoveHateInu is ERC20Burnable{
    constructor(address _to) ERC20("Love Hate Inu", "LHINU") {
        _mint(_to, 100_000_000_000 * 10 ** decimals()); //100 billion
    }
}