// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract DGNXLocker is Ownable {
    using SafeERC20 for ERC20;
    using Address for address;

    address public token;
    uint256 public balance;

    event Withdraw(address to, uint256 amount, uint256 proposalId);
    event Deposit(address from, uint256 amount);

    constructor(address _token) {
        require(_token != address(0), 'no token');
        token = _token;
    }

    function deposit(uint256 amount) external onlyOwner {
        require(ERC20(token).balanceOf(msg.sender) >= amount, 'no funds');
        balance += amount;
        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount);
    }

    function withdraw(
        address to,
        uint256 amount,
        uint256 proposalId
    ) external onlyOwner {
        require(amount <= balance, 'insufficient balance');
        balance -= amount;
        ERC20(token).safeTransfer(to, amount);
        emit Withdraw(to, amount, proposalId);
    }
}
