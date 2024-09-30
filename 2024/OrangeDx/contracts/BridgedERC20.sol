// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./interfaces/IBridgedERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error AlreadyInitialised();
contract BridgedERC20 is ERC20, ERC20Burnable, ERC20Permit,IBridgedERC20,Ownable {
    bool initialised = false;
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        ERC20Permit(name)
        Ownable(msg.sender)
    { 

    }
    function initialise (address _lockAddress,uint256 totalSupply) external onlyOwner(){
        if(initialised){
            revert AlreadyInitialised();
        }
        _mint(_lockAddress, totalSupply);
        initialised = true;
    }
}