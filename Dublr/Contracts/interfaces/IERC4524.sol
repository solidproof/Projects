// SPDX-License-Identifier: MIT
// From: https://eips.ethereum.org/EIPS/eip-4524

pragma solidity ^0.8.15;

import "./IERC20.sol";
import "./IERC165.sol";

/**
 * @dev A safer ERC20 trasfer protocol, similar to ERC777's recipient notification protocol.
 *
 * The EIP-165 interfaceId for this interface is 0x534f5876.
 */
interface IERC4524 is IERC20, IERC165 {
    /**
     * @notice Transfer funds and then notify the recipient via the ERC4524 receiver interface.
     *
     * @dev [ERC4524] Move `amount` tokens from the caller's account to `recipient`. Only succeeds if `recipient`
     * correctly implements the ERC4524 receiver interface, or if the receiver is an EOA (non-contract wallet).
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
    function safeTransfer(address recipient, uint256 amount) external returns(bool success);

    /**
     * @notice Transfer funds and then notify the recipient via the ERC4524 receiver interface.
     *
     * @dev [ERC4524] Move `amount` tokens from the caller's account to `recipient`. Only succeeds if `recipient`
     * correctly implements the ERC4524 receiver interface, or if the receiver is an EOA (non-contract wallet).
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
     * @param data Extra data to add to the emmitted transfer event.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function safeTransfer(address recipient, uint256 amount, bytes memory data) external returns(bool success);

    /**
     * @notice Transfer funds and then notify the recipient via the ERC4524 receiver interface.
     *
     * @dev [ERC4524] Move `amount` tokens from `holder` to `recipient`. (The caller must have
     * previously been approved by `holder` to send at least `amount` tokens on behalf of `holder`, by
     * `holder` calling `approve`.) `amount` is then deducted from the caller’s allowance.
     * Only succeeds if `recipient` correctly implements the ERC4524 receiver interface,
     * or if `recipient` is an EOA (non-contract wallet).
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
    function safeTransferFrom(address holder, address recipient, uint256 amount) external returns(bool success);

    /**
     * @notice Transfer funds and then notify the recipient via the ERC4524 receiver interface.
     *
     * @dev [ERC4524] Move `amount` tokens from `holder` to `recipient`. (The caller must have
     * previously been approved by `holder` to send at least `amount` tokens on behalf of `holder`, by
     * `holder` calling `approve`.) `amount` is then deducted from the caller’s allowance.
     * Only succeeds if `recipient` correctly implements the ERC4524 receiver interface,
     * or if `recipient` is an EOA (non-contract wallet).
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
     * @param data Extra data to add to the emmitted transfer event.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function safeTransferFrom(address holder, address recipient, uint256 amount, bytes memory data)
            external returns(bool success);
}

