//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract NOVO is ERC20, ERC20Burnable {
    uint constant TOTAL_SUPPLY = 1e8; // 100M
    constructor() ERC20('NOVO', 'NOVO') {
        _mint(msg.sender, TOTAL_SUPPLY * (10 ** decimals()));
    }
}
