// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";


contract TRUSTT_Token is ERC20, Ownable {

    address public minter;

    constructor() ERC20("TRUSTT Token", "TRUSTT") {
        minter = msg.sender;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "Ownable: caller is not the minter");
        _;
    }

    function setMinter(address newMinter) public virtual onlyOwner {
        require(newMinter != address(0), "Ownable: new owner is the zero address");
        minter = newMinter;
    }

    function mint(address to, uint256 amount) onlyMinter public {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) onlyMinter external{
      _burn(account, amount);
    }

    function approve(address owner, address spender, uint256 amount) external{
        _approve(owner, spender, amount);
    }

}