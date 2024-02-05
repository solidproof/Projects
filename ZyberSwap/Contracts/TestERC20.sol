// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract TestERC20 is ERC20, ERC20Permit {
    using SafeERC20 for IERC20;

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply
    ) ERC20(name, symbol) ERC20Permit(name) {
        _mint(msg.sender, totalSupply);
    }

    function mint(address _who, uint256 _amount) public {
        _mint(_who, _amount);
    }
}
