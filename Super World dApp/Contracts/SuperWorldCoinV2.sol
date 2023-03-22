pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.8/contracts/token/ERC20/ERC20.sol";

// SuperWorldCoin inherits ERC20
contract SuperWorldCoin is ERC20 {
    //string name = 'SuperWorldCoin';
    //string symbol = 'SUPERWORLD';
    //uint8 decimals = 18;
    uint public INITIAL_SUPPLY = 10000000000000000000000000; // 10,000,000 SUPERWORLD
    
    constructor() ERC20('SuperWorldCoin','SUPERWORLD') public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}