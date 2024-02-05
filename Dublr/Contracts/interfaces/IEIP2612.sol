// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @dev Interface of the EIP2612 permitting standard.
 */
interface IEIP2612 {
    /**
     * @notice Convert a signed certificate into a permit or allowance for a spender account to spend tokens
     * on behalf of a holder account.
     *
     * @dev [EIP2612] Implements the EIP2612 permit standard. Sets the spendable allowance for `spender` to
     * spend `holder`'s tokens, which can then be transferred using the ERC20 `transferFrom` function.
     *
     * https://eips.ethereum.org/EIPS/eip-2612
     * https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2ERC20.sol
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
     * @param spender The spender who will be authorized to spend tokens on behalf of `holder`.
     * @param amount The number of tokens `spender` will be authorized to spend on behalf of `holder`.
     * @param deadline The block timestamp after which the certificate expires.
     *          Note that if the permit is granted, then the allowance that is approved has its own deadline,
     *          separate from the certificate deadline. By default, allowances expire 1 hour after they are
     *          granted, but this may be modified by the contract owner -- call `defaultAllowanceExpirationSec()`
     *          to get the current value.
     * @param v The ECDSA `v` value.
     * @param r The ECDSA `r` value.
     * @param s The ECDSA `s` value.
     */
    function permit(address holder, address spender, uint amount, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    /** @notice EIP2612 permit nonces. */
    function nonces(address holder) external view returns (uint);

    /** @notice EIP712 domain separator for EIP2612 permits. */
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

