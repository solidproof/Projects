// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Mones is ERC20 {
	constructor() ERC20("Mones", "MONES") {
		_mint(msg.sender, 680_000_000 * 10 ** decimals());
	}
}
