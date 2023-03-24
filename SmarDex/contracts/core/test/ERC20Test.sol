// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.17;

// contracts
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract ERC20Test is ERC20Permit {
    constructor(uint256 _totalSupply) ERC20("SmarDex LP-Token", "SDEX-LP") ERC20Permit("SmarDex LP-Token") {
        _mint(msg.sender, _totalSupply);
    }

    function mint(address to, uint256 value) external {
        _mint(to, value);
    }
}
