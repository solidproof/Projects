// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./IERC20.sol";
import "./IERC165.sol";

/**
 * @dev Determine whether or not this contract supports a given interface, as defined by ERC165.
 *
 * Note: the ERC-165 identifier for this interface is 0xb0202a11.
 * 0xb0202a11 ===
 *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
 *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
 *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
 *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
 *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
 *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
 */
interface IERC1363 is IERC20, IERC165 {
    /**
     * @notice Transfer tokens to a recipient, and then call the ERC1363 recipient notification interface
     * on the recipient.
     *
     * @dev [ERC1363] Transfer tokens from the caller to `recipient`, and then call the ERC1363 receiver
     * interface's `onTransferReceived` on the recipient. The transaction will fail if the recipient does
     * not implement this interface (including if the recipient address is an EOA address).
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
     * @param recipient The address which you want to transfer tokens to.
     * @param amount The number of tokens to be transferred.
     * @return success `true` unless the transaction is reverted.
     */
    function transferAndCall(address recipient, uint256 amount) external returns (bool success);

    /**
     * @notice Transfer tokens to a recipient, and then call the ERC1363 recipient notification interface
     * on the recipient.
     *
     * @dev [ERC1363] Transfer tokens from the caller to `recipient`, and then call the ERC1363 receiver
     * interface's `onTransferReceived` on the recipient. The transaction will fail if the recipient does
     * not implement this interface (including if the recipient address is an EOA address).
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
     * @param recipient The address which you want to transfer tokens to.
     * @param amount The number of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `recipient`.
     * @return success `true` unless the transaction is reverted.
     */
    function transferAndCall(address recipient, uint256 amount, bytes memory data) external returns (bool success);

    /**
     * @notice Transfer tokens to a recipient on behalf of another account, and then call the ERC1363
     * recipient notification interface on the recipient.
     *
     * @dev [ERC1363] Transfer tokens from `holder` to `recipient`, and then call the ERC1363 spender
     * interface's `onApprovalReceived` on the recipient. The transaction will fail if the recipient does
     * not implement this interface (including if the recipient address is an EOA address).
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
     * @param holder The address which you want to send tokens on behalf of.
     * @param recipient The address which you want to transfer tokens to.
     * @param amount The number of tokens to be transferred.
     * @return success `true` unless the transaction is reverted.
     */
    function transferFromAndCall(address holder, address recipient, uint256 amount) external returns (bool success);

    /**
     * @notice Transfer tokens to a recipient on behalf of another account, and then call the ERC1363
     * recipient notification interface on the recipient.
     *
     * @dev [ERC1363] Transfer tokens from `holder` to `recipient`, and then call the ERC1363 spender
     * interface's `onApprovalReceived` on the recipient. The transaction will fail if the recipient does
     * not implement this interface (including if the recipient address is an EOA address).
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
     * @param holder The address which you want to send tokens from.
     * @param recipient The address which you want to transfer tokens to.
     * @param amount The number of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `recipient`.
     * @return success `true` unless the transaction is reverted.
     */
    function transferFromAndCall(address holder, address recipient, uint256 amount, bytes memory data)
        external returns (bool success);

    /**
     * @notice Approve another account to spend your tokens, and then call the ERC1363 spender notification
     * interface on the spender.
     *
     * @dev [ERC1363] Approve `spender` to spend the specified number of tokens on behalf of
     * caller (the token holder), and then call `onApprovalReceived` on spender.
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the spender or recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is a taxable
     * event. It is your responsibility to record the purchase price and sale price in ETH or your local currency
     * for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param spender The address which will spend the funds.
     * @param amount The number of tokens to allow the spender to spend.
     * @return success `true` unless the transaction is reverted.
     */
    function approveAndCall(address spender, uint256 amount) external returns (bool success);

    /**
     * @notice Approve another account to spend your tokens, and then call the ERC1363 spender notification
     * interface on the spender.
     *
     * @dev [ERC1363] Approve `spender` to spend the specified number of tokens on behalf of
     * caller (the token holder), and then call `onApprovalReceived` on spender.
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the spender or recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is a taxable
     * event. It is your responsibility to record the purchase price and sale price in ETH or your local currency
     * for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param spender The address which will spend the funds.
     * @param amount The number of tokens to be allow the spender to spend.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return success `true` unless the transaction is reverted.
     */
    function approveAndCall(address spender, uint256 amount, bytes memory data) external returns (bool success);
}
