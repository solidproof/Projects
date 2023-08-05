// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {ILBToken} from "./interfaces/ILBToken.sol";

/**
 * @title Liquidity Book Token
 * @author Trader Joe
 * @notice The LBToken is an implementation of a multi-token.
 * It allows to create multi-ERC20 represented by their ids.
 * Its implementation is really similar to the ERC1155 standard the main difference
 * is that it doesn't do any call to the receiver contract to prevent reentrancy.
 * As it's only for ERC20s, the uri function is not implemented.
 * The contract is made for batch operations.
 */
abstract contract LBToken is ILBToken {
    /**
     * @dev The mapping from account to token id to account balance.
     */
    mapping(address => mapping(uint256 => uint256)) private _balances;

    /**
     * @dev The mapping from token id to total supply.
     */
    mapping(uint256 => uint256) private _totalSupplies;

    /**
     * @dev Mapping from account to spender approvals.
     */
    mapping(address => mapping(address => bool)) private _spenderApprovals;

    /**
     * @dev Modifier to check if the spender is approved for all.
     */
    modifier checkApproval(address from, address spender) {
        if (!_isApprovedForAll(from, spender)) revert LBToken__SpenderNotApproved(from, spender);
        _;
    }

    /**
     * @dev Modifier to check if the address is not zero or the contract itself.
     */
    modifier notAddressZeroOrThis(address account) {
        if (account == address(0) || account == address(this)) revert LBToken__AddressThisOrZero();
        _;
    }

    /**
     * @dev Modifier to check if the length of the arrays are equal.
     */
    modifier checkLength(uint256 lengthA, uint256 lengthB) {
        if (lengthA != lengthB) revert LBToken__InvalidLength();
        _;
    }

    /**
     * @notice Returns the name of the token.
     * @return The name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return "Liquidity Book Token";
    }

    /**
     * @notice Returns the symbol of the token, usually a shorter version of the name.
     * @return The symbol of the token.
     */
    function symbol() public view virtual override returns (string memory) {
        return "LBT";
    }

    /**
     * @notice Returns the total supply of token of type `id`.
     * /**
     * @dev This is the amount of token of type `id` minted minus the amount burned.
     * @param id The token id.
     * @return The total supply of that token id.
     */
    function totalSupply(uint256 id) public view virtual override returns (uint256) {
        return _totalSupplies[id];
    }

    /**
     * @notice Returns the amount of tokens of type `id` owned by `account`.
     * @param account The address of the owner.
     * @param id The token id.
     * @return The amount of tokens of type `id` owned by `account`.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        return _balances[account][id];
    }

    /**
     * @notice Return the balance of multiple (account/id) pairs.
     * @param accounts The addresses of the owners.
     * @param ids The token ids.
     * @return batchBalances The balance for each (account, id) pair.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        public
        view
        virtual
        override
        checkLength(accounts.length, ids.length)
        returns (uint256[] memory batchBalances)
    {
        batchBalances = new uint256[](accounts.length);

        unchecked {
            for (uint256 i; i < accounts.length; ++i) {
                batchBalances[i] = balanceOf(accounts[i], ids[i]);
            }
        }
    }

    /**
     * @notice Returns true if `spender` is approved to transfer `owner`'s tokens or if `spender` is the `owner`.
     * @param owner The address of the owner.
     * @param spender The address of the spender.
     * @return True if `spender` is approved to transfer `owner`'s tokens.
     */
    function isApprovedForAll(address owner, address spender) public view virtual override returns (bool) {
        return _isApprovedForAll(owner, spender);
    }

    /**
     * @notice Grants or revokes permission to `spender` to transfer the caller's lbTokens, according to `approved`.
     * @param spender The address of the spender.
     * @param approved The boolean value to grant or revoke permission.
     */
    function approveForAll(address spender, bool approved) public virtual override {
        _approveForAll(msg.sender, spender, approved);
    }

    /**
     * @notice Batch transfers `amounts` of `ids` from `from` to `to`.
     * @param from The address of the owner.
     * @param to The address of the recipient.
     * @param ids The list of token ids.
     * @param amounts The list of amounts to transfer for each token id in `ids`.
     */
    function batchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts)
        public
        virtual
        override
        checkApproval(from, msg.sender)
    {
        _batchTransferFrom(from, to, ids, amounts);
    }

    /**
     * @notice Returns true if `spender` is approved to transfer `owner`'s tokens or if `spender` is the `owner`.
     * @param owner The address of the owner.
     * @param spender The address of the spender.
     * @return True if `spender` is approved to transfer `owner`'s tokens.
     */
    function _isApprovedForAll(address owner, address spender) internal view returns (bool) {
        return owner == spender || _spenderApprovals[owner][spender];
    }

    /**
     * @dev Mint `amount` of `id` to `account`.
     * The `account` must not be the zero address.
     * The event should be emitted by the contract that inherits this contract.
     * @param account The address of the owner.
     * @param id The token id.
     * @param amount The amount to mint.
     */
    function _mint(address account, uint256 id, uint256 amount) internal {
        _totalSupplies[id] += amount;

        unchecked {
            _balances[account][id] += amount;
        }
    }

    /**
     * @dev Burn `amount` of `id` from `account`.
     * The `account` must not be the zero address.
     * The event should be emitted by the contract that inherits this contract.
     * @param account The address of the owner.
     * @param id The token id.
     * @param amount The amount to burn.
     */
    function _burn(address account, uint256 id, uint256 amount) internal {
        mapping(uint256 => uint256) storage accountBalances = _balances[account];

        uint256 balance = accountBalances[id];
        if (balance < amount) revert LBToken__BurnExceedsBalance(account, id, amount);

        unchecked {
            _totalSupplies[id] -= amount;
            accountBalances[id] = balance - amount;
        }
    }

    /**
     * @dev Batch transfers `amounts` of `ids` from `from` to `to`.
     * The `to` must not be the zero address and the `ids` and `amounts` must have the same length.
     * @param from The address of the owner.
     * @param to The address of the recipient.
     * @param ids The list of token ids.
     * @param amounts The list of amounts to transfer for each token id in `ids`.
     */
    function _batchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts)
        internal
        checkLength(ids.length, amounts.length)
        notAddressZeroOrThis(to)
    {
        mapping(uint256 => uint256) storage fromBalances = _balances[from];
        mapping(uint256 => uint256) storage toBalances = _balances[to];

        for (uint256 i; i < ids.length;) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = fromBalances[id];
            if (fromBalance < amount) revert LBToken__TransferExceedsBalance(from, id, amount);

            unchecked {
                fromBalances[id] = fromBalance - amount;
                toBalances[id] += amount;

                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);
    }

    /**
     * @notice Grants or revokes permission to `spender` to transfer the caller's tokens, according to `approved`
     * @param owner The address of the owner
     * @param spender The address of the spender
     * @param approved The boolean value to grant or revoke permission
     */
    function _approveForAll(address owner, address spender, bool approved) internal notAddressZeroOrThis(owner) {
        if (owner == spender) revert LBToken__SelfApproval(owner);

        _spenderApprovals[owner][spender] = approved;
        emit ApprovalForAll(owner, spender, approved);
    }
}
