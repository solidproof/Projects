// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/// @title Climate Base Tonne.
/// @author Theo Dale & Peter Whitby.
/// @notice A token that represents unretired climate assets.
contract CBT is ERC20, Ownable {
    /// @dev Follow CBT naming conventions.
    /// @param name Name of CBT.
    /// @param symbol Symbol of CBT.
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /// @notice Mint an amount of CBT to a user's wallet.
    /// @param who Recipient of fresh CBT.
    /// @param amount Amount of CBT that will be minted.
    function mint(address who, uint256 amount) public onlyOwner {
        _mint(who, amount);
    }

    /// @notice Burn an amount of CBT from a user's wallet.
    /// @param who Address who's CBT will be burned.
    /// @param amount Amount of CBT that will be burned.
    function burn(address who, uint256 amount) public onlyOwner {
        _burn(who, amount);
    }
}
