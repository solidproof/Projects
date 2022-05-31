// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

// Inherenting ERC20 basic standard
contract Token is ERC20 {
	constructor()ERC20("Test Token","TTT"){}
	function mint(address to, uint256 amount) external {
			_mint(to,amount);
	}
}
