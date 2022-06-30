// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @dev An ERC20 safe approval protocol suggested in:
 * "ERC20 API: An Attack Vector on Approve/TransferFrom Methods"
 * https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit
 */
interface IERC20SafeApproval {
    /**
     * @notice Transfer event for safe "compare and set" approval alternative.
     *
     * @dev This is designed to mitigate the ERC-20 allowance attack described in:
     *
     * "ERC20 API: An Attack Vector on Approve/TransferFrom Methods"
     * https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit
     *
     * Note that this event is named `Transfer` in the original proposal, but it has been renamed to
     * `TransferInfo` here because ERC20 already defines an event with the name `Transfer` (and
     * Ethers doesn't like contracts that have two events with the same name).
     *
     * @param spender The spender.
     * @param from The sender.
     * @param to The recipient.
     * @param value The amount transferred (may be zero).
     */
    event TransferInfo(address indexed spender, address indexed from, address indexed to, uint256 value);

    /**
     * @notice Approval event for safe "compare and set" approval alternative.
     *
     * @dev This is designed to mitigate the ERC-20 allowance attack described in:
     *
     * "ERC20 API: An Attack Vector on Approve/TransferFrom Methods"
     * https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit
     *
     * Note that this event is named `Approval` in the original proposal, but it has been renamed to
     * `ApprovalInfo` here because ERC20 already defines an event with the name `Approval` (and
     * Ethers doesn't like contracts that have two events with the same name).
     *
     * @param holder The token holder.
     * @param spender The spender granted an allowance.
     * @param oldValue The previous value of the allowance.
     * @param value The new allowance to set.
     */
    event ApprovalInfo(address indexed holder, address indexed spender, uint256 oldValue, uint256 value);

    /**
     * @notice Safely "compare and set" the allowance for a spender to spend your tokens.
     * 
     * @dev [ERC20 extension] Atomically compare-and-set the allowance for a spender.
     * This is designed to mitigate the ERC-20 allowance attack described in:
     *
     * "ERC20 API: An Attack Vector on Approve/TransferFrom Methods"
     * https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or spender.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is a taxable
     * event. It is your responsibility to record the purchase price and sale price in ETH or your local currency
     * for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param spender The spender.
     * @param expectedCurrentAmount The expected amount of `spender`'s current allowance.
     *        If the current allowance does not match this value, then the transaction will revert.
     * @param amount The new allowance amount.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function approve(address spender, uint256 expectedCurrentAmount, uint256 amount) external returns (bool success);
}

