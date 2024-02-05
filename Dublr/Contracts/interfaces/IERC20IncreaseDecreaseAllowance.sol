// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./IERC20.sol";

/**
 * @dev Non-standard API for safe approvals that can be used as a mitigation for the double-spend race condition
 * attack described here:
 * https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#ERC20-increaseAllowance-address-uint256-
 */
interface IERC20IncreaseDecreaseAllowance {
    /**
     * @notice Safely increase the allowance for a spender to spend your tokens.
     *
     * @dev [ERC20 extension] Increases the ERC20 token allowance granted to `spender` by the caller.
     * This is an alternative to `approve` that can mitigate for the double-spend race condition attack
     * that is described here:
     *
     * https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit
     *
     * N.B. the transaction will revert if the allowance is currently set to the unlimited allowance
     * amount of `2**256-1`, since the correct new allowance amount cannot be determined by addition.
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
     * @param spender The token spender.
     * @param amountToAdd The number of tokens by which to increase the allowance of `spender`.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function increaseAllowance(address spender, uint256 amountToAdd) external returns (bool success);

    /**
     * @notice Safely decrease the allowance for a spender to spend your tokens.
     *
     * @dev [ERC20 extension] Decreases the ERC20 token allowance granted to `spender` by the caller.
     * This is an alternative to `approve` that can mitigate for the double-spend race condition attack
     * that is described here:
     *
     * https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit
     *
     * N.B. the transaction will revert if the allowance is currently set to the unlimited allowance
     * amount of `2**256-1`, since the correct new allowance amount cannot be determined by subtraction.
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
     * @param spender The token spender.
     * @param amountToSubtract The number of tokens by which to decrease the allowance of `spender`.
     * @return success `true` if the operation succeeded (otherwise reverts).
     *         Note that this operation will revert if amountToSubtract is greater than the current allowance.
     */
    function decreaseAllowance(address spender, uint256 amountToSubtract) external returns (bool success);
}

