// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TLFToken is ERC20, ERC20Burnable, Pausable, Ownable {
  constructor(address recipient) ERC20("Tradeleaf Token", "TLF") {
	  _mint(recipient, 3_000_000_000 * 10 ** decimals());
  }

	function pause() public onlyOwner {
		_pause();
	}

	function unpause() public onlyOwner {
		_unpause();
	}

	function decimals() public pure override returns (uint8) {
		return 6;
	}

	function _beforeTokenTransfer(address from, address to, uint256 amount) internal whenNotPaused override {
		super._beforeTokenTransfer(from, to, amount);
	}
}
