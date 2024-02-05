pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract PokeToken is ERC20{
    constructor() ERC20("PokeDoge", "POKE"){
        _mint(msg.sender,430000000*10**18);
    }
}
