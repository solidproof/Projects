pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Seed is ERC20, Ownable {
    constructor() ERC20("Binance USD", "BUSD") {
        _mint(msg.sender, 2500000000 * 10 ** decimals());
    }

    function getOwner() external view returns (address) {
        return owner();
    }
}