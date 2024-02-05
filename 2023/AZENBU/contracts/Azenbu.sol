// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Azenbu is ERC20, Ownable {
    using SafeERC20 for IERC20;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, 2000000000 * 10 ** decimals());
    }

    /**
     * @dev Destroys `_amount` tokens from the sender, reducing the total supply. 
     * @param _amount Number of tokens to burn
     */
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    /**
     * @dev Rescue ETH accidentally locked up in this contract  
     * @param _amount The amount to rescue
     */
    function rescueETH(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");

		(bool success, ) = payable(owner()).call{value: _amount}("");
        require(success, "Failed to send Ether");
	}

    /**
     * @dev Withdraw ERC20 tokens from this contract
     * @param erc20Address ERC20 address
     * @param amount ERC20 amount
     */
    function rescueERC20(address erc20Address, uint256 amount) external onlyOwner {
        IERC20(erc20Address).safeTransfer(owner(), amount);
    }
}