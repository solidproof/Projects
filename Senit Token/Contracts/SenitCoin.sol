// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
        
// @custom: security-contact: coins@senit.com
contract SenitCoin is ERC20 {

    constructor(string memory name, string memory symbol, uint256 maxSupply) ERC20(name, symbol) {
        _mint(msg.sender, maxSupply);
    }

}
