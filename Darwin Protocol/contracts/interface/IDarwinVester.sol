// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

/// @title Interface for the Darwin Vester
interface IDarwinVester {

    /// Presale contract is already initialized
    error AlreadyInitialized();
    /// Presale contract is not initialized
    error NotInitialized();
    /// Caller is not private sale
    error NotPrivateSale();
    /// Caller is not vester
    error NotVestUser();
    /// Parameter cannot be the zero address
    error ZeroAddress();
    /// Selected amount exceeds the withdrawable amount
    error AmountExceedsWithdrawable();
    /// Selected amount exceeds the claimable amount
    error AmountExceedsClaimable();
    /// Attempted transfer failed
    error TransferFailed();

    event Vest(address indexed user, uint indexed vestAmount);
    event Withdraw(address indexed user, uint indexed withdrawAmount);
    event Claim(address indexed user, uint indexed claimAmount);

    struct UserInfo {
        uint256 withdrawn;
        uint256 vested;
        uint256 vestTimestamp;
        uint256 claimed;
    }
}