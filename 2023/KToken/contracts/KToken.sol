// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KToken is Ownable, ERC20 {

    uint256 public constant MAX_SUPPLY = 100000000 * 1e18;

    /*
     * Creates a token
     * @param _name Token name
     * @param _symbol Token symbol
     */
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol){
        _mint(msg.sender, MAX_SUPPLY);
    }
}
