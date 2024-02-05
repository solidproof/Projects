// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC777/IERC777.sol)
//
// Modified from:
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC777/IERC777.sol

pragma solidity ^0.8.15;

/**
 * @dev Interface of the ERC777Token standard as defined in the ERC777.
 *
 * This contract uses the ERC1820 registry standard to let token holders (senders) and recipients register to be
 * notified of token movements, by implementing the appropriate interface.
 */
interface IERC777 {
    /**
     * @notice Tokens sent.
     *
     * @dev [ERC777] Emitted when tokens are sent from `holder` to `recipient`, possibly by another account
     *          (`operator`) on behalf of `holder`.
     *
     * @param operator The operator.
     * @param holder The account tokens were sent from.
     * @param recipient The account tokens were sent to.
     * @param amount The number of tokens sent.
     * @param data Extra data sent to `recipient`.
     * @param operatorData Extra data supplied by the operator to `recipient`.
     */
    event Sent(address indexed operator, address indexed holder, address indexed recipient, uint256 amount, bytes data,
        bytes operatorData);

    /**
     * @notice Tokens minted.
     *
     * @dev [ERC777] Emitted when `amount` tokens are created by `operator` and assigned to `account`.
     *
     * @param operator The operator.
     * @param account The account tokens were minted for.
     * @param amount The number of tokens minted.
     * @param data Extra data sent to `account`.
     * @param operatorData Extra data supplied by the operator to `account`.
     */
    event Minted(address indexed operator, address indexed account, uint256 amount, bytes data, bytes operatorData);

    /**
     * @notice Tokens burned.
     *
     * @dev [ERC777] Emitted when `operator` destroys `amount` tokens from `account`.
     *
     * @param operator The operator.
     * @param account The account tokens were burned for.
     * @param amount The number of tokens burned.
     * @param data Extra data sent to `account`.
     * @param operatorData Extra data supplied by the operator to `account`.
     */
    event Burned(address indexed operator, address indexed account, uint256 amount, bytes data, bytes operatorData);

    /**
     * @notice Operator status authorized.
     *
     * @dev [ERC777] Emitted when `operator` is made an operator for `account`.
     *
     * @param operator The operator.
     * @param account The account `operator` is authorized to act on behalf of.
     */
    event AuthorizedOperator(address indexed operator, address indexed account);

    /**
     * @notice Operator status revoked.
     *
     * @dev [ERC777] Emitted when `operator` has its operator status revoked for `account`.
     *
     * @param operator The operator.
     * @param account The account `operator` is no longer authorized to act on behalf of.
     */
    event RevokedOperator(address indexed operator, address indexed account);

    /** @notice The name of the token. */
    function name() external view returns (string memory);

    /** @notice The symbol of the token. */
    function symbol() external view returns (string memory);

    /**
     * @notice The granularity of the token.
     *
     * @dev [ERC777] For OmniToken, this value is 1 for compatibility with ERC20.
     */
    function granularity() external view returns (uint256 tokenGranularity);

    /** @notice The number of tokens in existence. */
    function totalSupply() external view returns (uint256 tokenSupply);

    /**
     * @notice The number of tokens owned by a given address.
     *
     * @param account The account to query.
     * @return balance The account balance.
     */
    function balanceOf(address account) external view returns (uint256 balance);

    /**
     * @notice Send tokens to a recipient.
     *
     * @dev [ERC777] Send `amount` tokens to `recipient`, passing `data` to the recipient. `recipient` must
     * implement the ERC777 recipient interface, unless it is a non-contract account (EOA wallet).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is a taxable
     * event. It is your responsibility to record the purchase price and sale price in ETH or your local currency
     * for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param recipient The address of the recipient.
     * @param amount The number of tokens to be sent.
     */
    function send(address recipient, uint256 amount, bytes calldata data) external;

    /**
     * @notice Burn tokens.
     *
     * @dev [ERC777] Burn tokens. Destroys `amount` tokens from caller's account forever,
     * reducing the total supply.
     *
     * Use with caution, as this cannot be reverted, and you should ensure that some other contract
     * guarantees you some benefit for burning tokens before you burn them.
     *
     * @param amount The number of tokens to burn.
     * @param data Extra data to log.
     */
    function burn(uint256 amount, bytes calldata data) external;

    /**
     * @notice Check whether an operator is authorized to manage the tokens held by a given address.
     *
     * @dev [ERC777] Checking whether `operator` is authorized to manage the tokens held by
     * `account` address. Returns `true` if `operator` is a non-revoked default operator, or has
     * been previously authorized (and not later revoked) by `account` calling `authorizeOperator(operator)`.
     *
     * @param operator address to check if it has the right to manage the tokens.
     * @param account address which holds the tokens to be managed.
     * @return isOperator `true` if `operator` is authorized for `account`.
     */
    function isOperatorFor(address operator, address account) external view returns (bool isOperator);

    /**
     * @notice Authorize another address, `operator`, to be able to send your tokens.
     *
     * @dev [ERC777] Authorize `operator` to be able to send the caller's tokens. The operator can then call
     * `operatorSend` to transfer the caller's tokens to a recipient.
     *
     * @param operator The operator to authorize.
     */
    function authorizeOperator(address operator) external;

    /**
     * @notice Revoke `operator` from being able to send your tokens.
     *
     * @dev [ERC777] Revoke `operator` from being able to send the caller's tokens.
     *
     * @param operator The operator to revoke.
     */
    function revokeOperator(address operator) external;

    /**
     * @notice The default operator list.
     *
     * @dev [ERC777] The list of default operators. These accounts are operators for all token holders,
     * even if `authorizeOperator` was never called on them.
     *
     * This list is immutable, but individual holders may revoke these via `revokeOperator`, in which case
     * `isOperatorFor` will return false.
     */
    function defaultOperators() external view returns (address[] memory);

    /**
     * @notice Send tokens on behalf of a token holder (or sender) that you have previously been authorized
     * to be an operator for.
     *
     * @dev [ERC777] Send `amount` tokens on behalf of the address `holder` to the address `recipient`.
     * The caller must have previously been authorized for as an operator for `holder`, by `holder`
     * calling `authorizeOperator`.
     *
     * The `holder` account may optionally implement the ERC777 sender interface to be notified when
     * tokens are sent.
     * 
     * `recipient` must implement the ERC777 recipient interface, unless it is a non-contract
     * account (EOA wallet).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jursidiction
     * of the holder or recipient account.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is a taxable
     * event. It is your responsibility to record the purchase price and sale price in ETH or your local currency
     * for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param holder The address holding the tokens being sent.
     * @param recipient The address of the recipient.
     * @param amount The number of tokens to be sent.
     * @param data Data generated by the user to be sent to the recipient.
     * @param operatorData Data generated by the operator to be sent to the recipient.
     */
    function operatorSend(address holder, address recipient, uint256 amount, bytes calldata data,
        bytes calldata operatorData) external;

    /**
     * @notice Burn tokens.
     *
     * @dev [ERC777] Burn tokens. Destroys `amount` tokens from `account` account forever, reducing the total supply.
     * Caller must have previously been approved as an operator for `account`.
     *
     * Use with caution, as this cannot be reverted, and you should ensure that some other contract guarantees
     * you some benefit for burning tokens before you burn them.
     *
     * @param account The account to destroy tokens from.
     * @param amount The number of tokens to burn.
     * @param data Extra data to log.
     * @param operatorData Extra data to log.
     */
    function operatorBurn(address account, uint256 amount, bytes calldata data, bytes calldata operatorData) external;
}
