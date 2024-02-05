// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)
// From: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol

pragma solidity ^0.8.15;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @notice Tokens transferred.
     * 
     * @dev [ERC20] Emitted when `amount` tokens are moved from `sender` to `recipient`.
     *
     * @param sender The account tokens were transferred from.
     * @param recipient The account tokens were transferred to.
     * @param amount The number of tokens transferred.
     */
    event Transfer(address indexed sender, address indexed recipient, uint256 amount);

    /**
     * @notice Allowance approved.
     *
     * @dev [ERC20] Emitted when `holder` authorizes `spender` to spend `amount` tokens on their behalf.
     *
     * @param holder The token holder granting authorization.
     * @param spender The account granted authorization to spned on behalf of `holder`.
     * @param amount The allowance (the number of tokens `spender` may spend on behalf of `holder`).
     */
    event Approval(address indexed holder, address indexed spender, uint256 amount);

    /**
     * @notice The total supply of tokens.
     *
     * @return supply The total supply of tokens.
     */
    function totalSupply() external view returns (uint256 supply);

    /**
     * @notice The number of tokens owned by a given address.
     *
     * @param holder The address to query.
     * @return amount The number of tokens owned by `holder`.
     */
    function balanceOf(address holder) external view returns (uint256 amount);

    /**
     * @notice Get the number of tokens that `spender` can spend on behalf of `holder`.
     *
     * @dev [ERC20] Returns the remaining number of tokens that `spender` will be allowed to spend on
     * behalf of `holder`, via a call to `transferFrom`. Zero by default. Also returns zero if
     * allowance has expired.
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
     * @param holder The token holder.
     * @param spender The token spender.
     * @return amount The allowance of `spender` to spend the funds of `holder`.
     */
    function allowance(address holder, address spender) external view returns (uint256 amount);

    /**
     * @notice Approve another account (or contract) to spend tokens on your behalf.
     *
     * @dev [ERC20] Approves a `spender` to be allowed to spend `allowedAmount` tokens on behalf of the
     * caller, via a call to `transferFrom`.
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
     * @param amount The allowance amount. Use a value of `0` to disallow `spender` spending tokens on behalf
     *          of the caller. Use a value of `2**256-1` to set unlimited allowance, if unlimited allowances are
     *          enabled. The allowed amount may be greater than the account balance.
     * @return success `true` if the approval succeeded (otherwise reverts).
     */
    function approve(address spender, uint256 amount) external returns (bool success);

    /**
     * @notice Transfer tokens to another account.
     *
     * @dev [ERC20] Moves `amount` tokens from the caller's account to `recipient`.
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is a taxable
     * event. It is your responsibility to record the purchase price and sale price in ETH or your local currency
     * for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param recipient The token recipient.
     * @param amount The number of tokens to transfer from the caller to `recipient`.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function transfer(address recipient, uint256 amount) external returns (bool success);

    /**
     * @notice Transfer tokens from a holder account to a recipient account account, on behalf of the holder.
     *
     * @dev [ERC20] Moves `amount` tokens from `sender` to `recipient`. The caller must have previously been
     * approved by `sender` to send at least `amount` tokens on their behalf, by `sender` calling `approve`.
     * `amount` is deducted from the caller’s allowance (unless the allowance is set to unlimited).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is a taxable
     * event. It is your responsibility to record the purchase price and sale price in ETH or your local currency
     * for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     * 
     * @param holder The token holder.
     * @param recipient The token recipient.
     * @param amount The number of tokens to transfer from the caller to `recipient`.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function transferFrom(address holder, address recipient, uint256 amount) external returns (bool success);
}

