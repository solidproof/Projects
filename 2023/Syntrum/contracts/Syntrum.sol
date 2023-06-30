// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity 0.8.2;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Syntrum is ERC20 {
    constructor (
        address receiver_,
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_
    ) ERC20(name_, symbol_) {
        require(receiver_ != address(0), 'Receiver address can not be zero');
        _mint(receiver_, totalSupply_);
    }
}