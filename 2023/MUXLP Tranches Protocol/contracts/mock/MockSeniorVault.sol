// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

contract MockSeniorVault {
    uint256 public borrowedAmount;

    function setBorrowedAmount(uint256 _borrowedAmount) external {
        borrowedAmount = _borrowedAmount;
    }
}
