// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/IController.sol";

contract OcUSD is ERC20 {
    IController public controller;

    modifier onlyMintAllowed() {
        require(controller.mintAllowed(msg.sender), "Minter only");
        _;
    }
    modifier onlyBurnAllowed() {
        require(controller.burnAllowed(msg.sender), "Burner only");
        _;
    }

    constructor(IController _controller) ERC20("Oceanos USD", "ocUSD") {
        controller = _controller;
    }

    function mint(
        address to,
        uint256 amount
    ) external onlyMintAllowed returns (bool) {
        _mint(to, amount);
        return true;
    }

    function burn(
        address account,
        uint256 amount
    ) external onlyBurnAllowed returns (bool) {
        _burn(account, amount);
        return true;
    }
}
