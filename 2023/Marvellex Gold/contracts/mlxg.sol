// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MarvellexGold is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    constructor(address initalAccount) ERC20("MarvellexGold", "MLXG") {
        require(initalAccount != address(0), "Initial Account is the zero address");
        _grantRole(DEFAULT_ADMIN_ROLE, initalAccount);
        _mint(initalAccount, 10000 * 10 ** decimals());
        _grantRole(MINTER_ROLE, initalAccount);
    }
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(hasRole(MINTER_ROLE, _msgSender()), "MLXG: must have minter role to mint");
        _mint(to, amount);
    }

}