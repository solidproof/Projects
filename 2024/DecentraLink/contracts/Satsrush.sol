// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Satsrush is ERC20, ERC20Burnable, ERC20Permit,Ownable{
    constructor(address Owner)Ownable(Owner) ERC20("Satsrush", "SR30") ERC20Permit("Satsrush") {
        _mint(Owner, 1000000000 * 10 ** decimals());
        _transferOwnership(Owner);
    
}
 
}