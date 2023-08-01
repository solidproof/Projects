// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract MockERC20 is ERC20PresetFixedSupply {
    uint8 _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner,
        uint8 newDecimals
    ) ERC20PresetFixedSupply(name, symbol, initialSupply, owner) {
        _decimals = newDecimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function faucet(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
