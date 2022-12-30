// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 ________      ___    ___ ________   ________  _____ ______   ___  ________
|\   ___ \    |\  \  /  /|\   ___  \|\   __  \|\   _ \  _   \|\  \|\   ____\
\ \  \_|\ \   \ \  \/  / | \  \\ \  \ \  \|\  \ \  \\\__\ \  \ \  \ \  \___|
 \ \  \ \\ \   \ \    / / \ \  \\ \  \ \   __  \ \  \\|__| \  \ \  \ \  \
  \ \  \_\\ \   \/  /  /   \ \  \\ \  \ \  \ \  \ \  \    \ \  \ \  \ \  \____
   \ \_______\__/  / /      \ \__\\ \__\ \__\ \__\ \__\    \ \__\ \__\ \_______\
    \|_______|\___/ /        \|__| \|__|\|__|\|__|\|__|     \|__|\|__|\|_______|
             \|___|/

 */

contract Dynamic is ERC20, Ownable, ERC20Burnable {
    uint256 public totalLocked = 0;
    uint256 public totalBurned = 0;
    uint256 public constant MAX_TOTAL_SUPPLY = 400000 * 10 ** 18;

    event Lock(uint256 amount);
    event Unlock(uint256 amount);

    constructor(uint256 _initialBalance)
        ERC20("Dynamic", "DYNA")
    {
        _mint(_msgSender(), _initialBalance);
    }

    function mint(uint256 _amount) public onlyOwner {
        uint256 _totalSupply = totalSupply();
        require(
            _totalSupply + _amount <= MAX_TOTAL_SUPPLY - totalBurned,
            "[DYNA]: Exceed maximum supply"
        );
        _mint(_msgSender(), _amount);
    }

    function burn(uint256 _amount) public override {
        totalBurned += _amount;
        _burn(_msgSender(), _amount);
    }

    function lock(uint256 _amount) public onlyOwner {
        totalLocked += _amount;
        super.transfer(address(this), _amount);
        emit Lock(_amount);
    }

    function unlock(uint256 _amount) public onlyOwner {
        require(totalLocked >= _amount, "[DYNA]: Not enough token locked");
        totalLocked -= _amount;
        this.transfer(_msgSender(), _amount);
        emit Unlock(_amount);
    }
}