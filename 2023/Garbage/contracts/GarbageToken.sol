// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IGarbageSale.sol";

contract GarbageToken is Ownable, ERC20 {

    error ZeroAddress();

    constructor(address _mintAddress) ERC20("Garbage Token", "$GARBAGE") {
        if (_mintAddress == address(0)) revert ZeroAddress();
        _mint(_mintAddress, 1_000_000_000 * (10 ** uint256(decimals()))); // mint 1 billion tokens
    }
}
