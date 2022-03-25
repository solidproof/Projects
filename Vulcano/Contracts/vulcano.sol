// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IPinkAntiBot.sol";

contract VulcanoToken is ERC20, ERC20Burnable, Pausable, AccessControl {
	IPinkAntiBot public pinkAntiBot;
	bool public antiBotEnabled;
	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

	constructor(
		string memory tokenName,
		string memory symbol,
		address pinkAntiBot_
	) ERC20(tokenName, symbol) {
		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(PAUSER_ROLE, msg.sender);
		_mint(msg.sender, 100000000 * 10**decimals());

		// Create an instance of the PinkAntiBot variable from the provided address
		pinkAntiBot = IPinkAntiBot(pinkAntiBot_);
		// Register the deployer to be the token owner with PinkAntiBot. You can
		// later change the token owner in the PinkAntiBot contract
		pinkAntiBot.setTokenOwner(msg.sender);
		antiBotEnabled = true;
	}

	function pause() public onlyRole(PAUSER_ROLE) {
		_pause();
	}

	function unpause() public onlyRole(PAUSER_ROLE) {
		_unpause();
	}

	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal override whenNotPaused {
		super._beforeTokenTransfer(from, to, amount);
	}

	// Use this function to control whether to use PinkAntiBot or not instead
	// of managing this in the PinkAntiBot contract
	function setEnableAntiBot(bool _enable)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		antiBotEnabled = _enable;
	}

	// Inside ERC20's _transfer function:
	function _transfer(
		address sender,
		address recipient,
		uint256 amount
	) internal virtual override {
		require(sender != address(0), "ERC20: transfer from the zero address");
		require(recipient != address(0), "ERC20: transfer to the zero address");

		// Only use PinkAntiBot if this state is true
		if (antiBotEnabled) {
			pinkAntiBot.onPreTransferCheck(sender, recipient, amount);
		}
		super._transfer(sender, recipient, amount);
	}
}