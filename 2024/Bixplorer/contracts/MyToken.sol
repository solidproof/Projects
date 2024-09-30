// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title BXE
 * @dev This contract implements an ERC20 token with burnable functionality and an owner-controlled withdrawal mechanism.
 * The owner can withdraw native tokens (ETH) or any ERC20 tokens held by the contract.
 */
contract BXE is ERC20, ERC20Burnable {
    /// @notice The address of the contract owner.
    address private owner;

    /**
     * @dev Constructor that initializes the token and mints a fixed supply of tokens to the specified owner.
     * @param initialOwner The address that will receive the initial token supply and become the owner of the contract.
     */
    constructor(address initialOwner)
        ERC20("Bixplorer.com", "BXE")
    {
        owner = initialOwner;
        _mint(initialOwner, 200_000_000_000 ether);
    }

    /**
     * @notice Allows the owner to withdraw either native tokens (ETH) or any ERC20 tokens from the contract.
     * @dev If `token` is the zero address (address(0)), the contract will send the available balance in native tokens (ETH).
     * If `token` is a valid ERC20 contract address, it will transfer the entire ERC20 token balance of the contract.
     * @param token The address of the ERC20 token contract. Use address(0) to withdraw native tokens (ETH).
     * @param to The address to which the withdrawn tokens or ETH will be sent.
     * 
     * Requirements:
     * - Only the owner can call this function.
     * - The contract must hold a balance of the specified token type.
     */
    function withdraw(address token, address to) public {
        require(msg.sender == owner, "You're not the owner"); 
        if (token == address(0)) {
            uint256 balance = address(this).balance;
            require(balance > 0, "Insufficient balance");
            payable(to).transfer(balance);
        } else {
            IERC20 erc20Token = IERC20(token);
            uint256 balance = erc20Token.balanceOf(address(this));
            require(balance > 0, "Insufficient balance");
            erc20Token.transfer(to, balance);
        }
    }
}