// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Inherenting ERC20 basic standard
contract Token is ERC20, Ownable {
	constructor()ERC20("Test Token","TTT"){}
	function mint(address to, uint256 amount) public onlyOwner {
	 _mint(to,amount);
	}
}
