// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @dev Time-limited token allowances, as proposed in the following draft:
 *
 * https://github.com/vrypan/EIPs/blob/master/EIPS/eip-draft_time_limited_token_allowances.md
 */
interface IERC20TimeLimitedTokenAllowances {
    /**
     * @notice Emitted when the allowance of a `spender` for a `holder` is set by a call to `approve`.
     *
     * @dev This event is not part of the proposal for this ERC20 extension, and we log expiration
     * time rather than expiration block number.
     *
     * @param holder The token holder.
     * @param spender The spender.
     * @param value The new allowance.
     * @param expirationTimestamp the block timestamp after which the approval will expire. (Note that this is
     *          the actual expiration timestamp, not the number of seconds the approval should last for, which
     *          is passed into `approveWithExpiration`.)
     */
    event ApprovalWithExpiration(address indexed holder, address indexed spender, uint256 value,
            uint256 expirationTimestamp);

    /**
     * @notice Approve a spender to spend your tokens with a specified expiration time.
     *
     * @dev ERC20 extension function for approving with time-limited allowances.
     *
     * See: https://github.com/vrypan/EIPs/blob/master/EIPS/eip-draft_time_limited_token_allowances.md
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
     * @param amount The amount to allow.
     * @param expirationSec The number of seconds after which the allowance expires, or `2**256-1` if the
     *          allowance should not expire (consider this unsafe), or `0` if spending must happen in the
     *          same block as approval (e.g. for a flash loan).
     *          Note: The proposal for this ERC20 extension API requires a user to specify the number of
     *          blocks an approval should be valid for before expiration. OmniToken uses seconds instead
     *          of number of blocks, because mining does not happen at a reliable interval.
     * @return success `true` if approval was successful.
     */
    function approveWithExpiration(address spender, uint256 amount, uint256 expirationSec) external
            returns (bool success);
    
    /**
     * @notice Get the expiration timestamp for the allowance of a spender to spend tokens on behalf of a holder.
     * 
     * @dev ERC20 extension function for returning the allowance amount and block timestamp after which allowance
     * expires. Expiration time will be `2**256-1` for allowances that do not expire, or smaller than that value
     * for time-limited allowances.
     *
     * See: https://github.com/vrypan/EIPs/blob/master/EIPS/eip-draft_time_limited_token_allowance.md
     *
     * @param holder The token holder.
     * @param spender The token spender.
     * @return remainingAmount The amount of the allowance remaining, or 0 if the allowance has expired.
     * @return expirationTimestamp The block timestamp after which the allowance expires.
     */
    function allowanceWithExpiration(address holder, address spender) external view
            returns (uint256 remainingAmount, uint256 expirationTimestamp);
}

