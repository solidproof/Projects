/**
 *Submitted for verification at BscScan.com on 2024-06-27
*/

//     __  ____       __  _____ __        __       _____ __
//    /  |/  (_)___  / /_/ ___// /_____ _/ /_____ / ___// /_  ____ _________
//   / /|_/ / / __ \/ __/\__ \/ __/ __ `/ //_/ _ \\__ \/ __ \/ __ `/ ___/ _ \
//  / /  / / / / / / /_ ___/ / /_/ /_/ / ,< /  __/__/ / / / / /_/ / /  /  __/
// /_/  /_/_/_/ /_/\__//____/\__/\__,_/_/|_|\___/____/_/ /_/\__,_/_/   \___/
//
// Web: https://www.mintstakeshare.com
// TG: https://t.me/mintstakeshare

// SPDX-License-Identifier: MIT

// File @openzeppelin/contracts/utils/Context.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
	function _msgSender() internal view virtual returns (address) {
		return msg.sender;
	}

	function _msgData() internal view virtual returns (bytes calldata) {
		return msg.data;
	}

	function _contextSuffixLength() internal view virtual returns (uint256) {
		return 0;
	}
}

// File @openzeppelin/contracts/access/Ownable.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
	address private _owner;

	/**
	 * @dev The caller account is not authorized to perform an operation.
	 */
	error OwnableUnauthorizedAccount(address account);

	/**
	 * @dev The owner is not a valid owner account. (eg. `address(0)`)
	 */
	error OwnableInvalidOwner(address owner);

	event OwnershipTransferred(
		address indexed previousOwner,
		address indexed newOwner
	);

	/**
	 * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
	 */
	constructor(address initialOwner) {
		if (initialOwner == address(0)) {
			revert OwnableInvalidOwner(address(0));
		}
		_transferOwnership(initialOwner);
	}

	/**
	 * @dev Throws if called by any account other than the owner.
	 */
	modifier onlyOwner() {
		_checkOwner();
		_;
	}

	/**
	 * @dev Returns the address of the current owner.
	 */
	function owner() public view virtual returns (address) {
		return _owner;
	}

	/**
	 * @dev Throws if the sender is not the owner.
	 */
	function _checkOwner() internal view virtual {
		if (owner() != _msgSender()) {
			revert OwnableUnauthorizedAccount(_msgSender());
		}
	}

	/**
	 * @dev Leaves the contract without owner. It will not be possible to call
	 * `onlyOwner` functions. Can only be called by the current owner.
	 *
	 * NOTE: Renouncing ownership will leave the contract without an owner,
	 * thereby disabling any functionality that is only available to the owner.
	 */
	function renounceOwnership() public virtual onlyOwner {
		_transferOwnership(address(0));
	}

	/**
	 * @dev Transfers ownership of the contract to a new account (`newOwner`).
	 * Can only be called by the current owner.
	 */
	function transferOwnership(address newOwner) public virtual onlyOwner {
		if (newOwner == address(0)) {
			revert OwnableInvalidOwner(address(0));
		}
		_transferOwnership(newOwner);
	}

	/**
	 * @dev Transfers ownership of the contract to a new account (`newOwner`).
	 * Internal function without access restriction.
	 */
	function _transferOwnership(address newOwner) internal virtual {
		address oldOwner = _owner;
		_owner = newOwner;
		emit OwnershipTransferred(oldOwner, newOwner);
	}
}

// File @openzeppelin/contracts/interfaces/draft-IERC6093.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
	/**
	 * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
	 * @param sender Address whose tokens are being transferred.
	 * @param balance Current balance for the interacting account.
	 * @param needed Minimum amount required to perform a transfer.
	 */
	error ERC20InsufficientBalance(
		address sender,
		uint256 balance,
		uint256 needed
	);

	/**
	 * @dev Indicates a failure with the token `sender`. Used in transfers.
	 * @param sender Address whose tokens are being transferred.
	 */
	error ERC20InvalidSender(address sender);

	/**
	 * @dev Indicates a failure with the token `receiver`. Used in transfers.
	 * @param receiver Address to which tokens are being transferred.
	 */
	error ERC20InvalidReceiver(address receiver);

	/**
	 * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
	 * @param spender Address that may be allowed to operate on tokens without being their owner.
	 * @param allowance Amount of tokens a `spender` is allowed to operate with.
	 * @param needed Minimum amount required to perform a transfer.
	 */
	error ERC20InsufficientAllowance(
		address spender,
		uint256 allowance,
		uint256 needed
	);

	/**
	 * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
	 * @param approver Address initiating an approval operation.
	 */
	error ERC20InvalidApprover(address approver);

	/**
	 * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
	 * @param spender Address that may be allowed to operate on tokens without being their owner.
	 */
	error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
	/**
	 * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
	 * Used in balance queries.
	 * @param owner Address of the current owner of a token.
	 */
	error ERC721InvalidOwner(address owner);

	/**
	 * @dev Indicates a `tokenId` whose `owner` is the zero address.
	 * @param tokenId Identifier number of a token.
	 */
	error ERC721NonexistentToken(uint256 tokenId);

	/**
	 * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
	 * @param sender Address whose tokens are being transferred.
	 * @param tokenId Identifier number of a token.
	 * @param owner Address of the current owner of a token.
	 */
	error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

	/**
	 * @dev Indicates a failure with the token `sender`. Used in transfers.
	 * @param sender Address whose tokens are being transferred.
	 */
	error ERC721InvalidSender(address sender);

	/**
	 * @dev Indicates a failure with the token `receiver`. Used in transfers.
	 * @param receiver Address to which tokens are being transferred.
	 */
	error ERC721InvalidReceiver(address receiver);

	/**
	 * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
	 * @param operator Address that may be allowed to operate on tokens without being their owner.
	 * @param tokenId Identifier number of a token.
	 */
	error ERC721InsufficientApproval(address operator, uint256 tokenId);

	/**
	 * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
	 * @param approver Address initiating an approval operation.
	 */
	error ERC721InvalidApprover(address approver);

	/**
	 * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
	 * @param operator Address that may be allowed to operate on tokens without being their owner.
	 */
	error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
	/**
	 * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
	 * @param sender Address whose tokens are being transferred.
	 * @param balance Current balance for the interacting account.
	 * @param needed Minimum amount required to perform a transfer.
	 * @param tokenId Identifier number of a token.
	 */
	error ERC1155InsufficientBalance(
		address sender,
		uint256 balance,
		uint256 needed,
		uint256 tokenId
	);

	/**
	 * @dev Indicates a failure with the token `sender`. Used in transfers.
	 * @param sender Address whose tokens are being transferred.
	 */
	error ERC1155InvalidSender(address sender);

	/**
	 * @dev Indicates a failure with the token `receiver`. Used in transfers.
	 * @param receiver Address to which tokens are being transferred.
	 */
	error ERC1155InvalidReceiver(address receiver);

	/**
	 * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
	 * @param operator Address that may be allowed to operate on tokens without being their owner.
	 * @param owner Address of the current owner of a token.
	 */
	error ERC1155MissingApprovalForAll(address operator, address owner);

	/**
	 * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
	 * @param approver Address initiating an approval operation.
	 */
	error ERC1155InvalidApprover(address approver);

	/**
	 * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
	 * @param operator Address that may be allowed to operate on tokens without being their owner.
	 */
	error ERC1155InvalidOperator(address operator);

	/**
	 * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
	 * Used in batch transfers.
	 * @param idsLength Length of the array of token identifiers
	 * @param valuesLength Length of the array of token amounts
	 */
	error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
	/**
	 * @dev Emitted when `value` tokens are moved from one account (`from`) to
	 * another (`to`).
	 *
	 * Note that `value` may be zero.
	 */
	event Transfer(address indexed from, address indexed to, uint256 value);

	/**
	 * @dev Emitted when the allowance of a `spender` for an `owner` is set by
	 * a call to {approve}. `value` is the new allowance.
	 */
	event Approval(
		address indexed owner,
		address indexed spender,
		uint256 value
	);

	/**
	 * @dev Returns the value of tokens in existence.
	 */
	function totalSupply() external view returns (uint256);

	/**
	 * @dev Returns the value of tokens owned by `account`.
	 */
	function balanceOf(address account) external view returns (uint256);

	/**
	 * @dev Moves a `value` amount of tokens from the caller's account to `to`.
	 *
	 * Returns a boolean value indicating whether the operation succeeded.
	 *
	 * Emits a {Transfer} event.
	 */
	function transfer(address to, uint256 value) external returns (bool);

	/**
	 * @dev Returns the remaining number of tokens that `spender` will be
	 * allowed to spend on behalf of `owner` through {transferFrom}. This is
	 * zero by default.
	 *
	 * This value changes when {approve} or {transferFrom} are called.
	 */
	function allowance(
		address owner,
		address spender
	) external view returns (uint256);

	/**
	 * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
	 * caller's tokens.
	 *
	 * Returns a boolean value indicating whether the operation succeeded.
	 *
	 * IMPORTANT: Beware that changing an allowance with this method brings the risk
	 * that someone may use both the old and the new allowance by unfortunate
	 * transaction ordering. One possible solution to mitigate this race
	 * condition is to first reduce the spender's allowance to 0 and set the
	 * desired value afterwards:
	 * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
	 *
	 * Emits an {Approval} event.
	 */
	function approve(address spender, uint256 value) external returns (bool);

	/**
	 * @dev Moves a `value` amount of tokens from `from` to `to` using the
	 * allowance mechanism. `value` is then deducted from the caller's
	 * allowance.
	 *
	 * Returns a boolean value indicating whether the operation succeeded.
	 *
	 * Emits a {Transfer} event.
	 */
	function transferFrom(
		address from,
		address to,
		uint256 value
	) external returns (bool);
}

// File @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20 {
	/**
	 * @dev Returns the name of the token.
	 */
	function name() external view returns (string memory);

	/**
	 * @dev Returns the symbol of the token.
	 */
	function symbol() external view returns (string memory);

	/**
	 * @dev Returns the decimals places of the token.
	 */
	function decimals() external view returns (uint8);
}

// File @openzeppelin/contracts/token/ERC20/ERC20.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
	mapping(address account => uint256) private _balances;

	mapping(address account => mapping(address spender => uint256))
		private _allowances;

	uint256 private _totalSupply;

	string private _name;
	string private _symbol;

	/**
	 * @dev Sets the values for {name} and {symbol}.
	 *
	 * All two of these values are immutable: they can only be set once during
	 * construction.
	 */
	constructor(string memory name_, string memory symbol_) {
		_name = name_;
		_symbol = symbol_;
	}

	/**
	 * @dev Returns the name of the token.
	 */
	function name() public view virtual returns (string memory) {
		return _name;
	}

	/**
	 * @dev Returns the symbol of the token, usually a shorter version of the
	 * name.
	 */
	function symbol() public view virtual returns (string memory) {
		return _symbol;
	}

	/**
	 * @dev Returns the number of decimals used to get its user representation.
	 * For example, if `decimals` equals `2`, a balance of `505` tokens should
	 * be displayed to a user as `5.05` (`505 / 10 ** 2`).
	 *
	 * Tokens usually opt for a value of 18, imitating the relationship between
	 * Ether and Wei. This is the default value returned by this function, unless
	 * it's overridden.
	 *
	 * NOTE: This information is only used for _display_ purposes: it in
	 * no way affects any of the arithmetic of the contract, including
	 * {IERC20-balanceOf} and {IERC20-transfer}.
	 */
	function decimals() public view virtual returns (uint8) {
		return 18;
	}

	/**
	 * @dev See {IERC20-totalSupply}.
	 */
	function totalSupply() public view virtual returns (uint256) {
		return _totalSupply;
	}

	/**
	 * @dev See {IERC20-balanceOf}.
	 */
	function balanceOf(address account) public view virtual returns (uint256) {
		return _balances[account];
	}

	/**
	 * @dev See {IERC20-transfer}.
	 *
	 * Requirements:
	 *
	 * - `to` cannot be the zero address.
	 * - the caller must have a balance of at least `value`.
	 */
	function transfer(address to, uint256 value) public virtual returns (bool) {
		address owner = _msgSender();
		_transfer(owner, to, value);
		return true;
	}

	/**
	 * @dev See {IERC20-allowance}.
	 */
	function allowance(
		address owner,
		address spender
	) public view virtual returns (uint256) {
		return _allowances[owner][spender];
	}

	/**
	 * @dev See {IERC20-approve}.
	 *
	 * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
	 * `transferFrom`. This is semantically equivalent to an infinite approval.
	 *
	 * Requirements:
	 *
	 * - `spender` cannot be the zero address.
	 */
	function approve(
		address spender,
		uint256 value
	) public virtual returns (bool) {
		address owner = _msgSender();
		_approve(owner, spender, value);
		return true;
	}

	/**
	 * @dev See {IERC20-transferFrom}.
	 *
	 * Emits an {Approval} event indicating the updated allowance. This is not
	 * required by the EIP. See the note at the beginning of {ERC20}.
	 *
	 * NOTE: Does not update the allowance if the current allowance
	 * is the maximum `uint256`.
	 *
	 * Requirements:
	 *
	 * - `from` and `to` cannot be the zero address.
	 * - `from` must have a balance of at least `value`.
	 * - the caller must have allowance for ``from``'s tokens of at least
	 * `value`.
	 */
	function transferFrom(
		address from,
		address to,
		uint256 value
	) public virtual returns (bool) {
		address spender = _msgSender();
		_spendAllowance(from, spender, value);
		_transfer(from, to, value);
		return true;
	}

	/**
	 * @dev Moves a `value` amount of tokens from `from` to `to`.
	 *
	 * This internal function is equivalent to {transfer}, and can be used to
	 * e.g. implement automatic token fees, slashing mechanisms, etc.
	 *
	 * Emits a {Transfer} event.
	 *
	 * NOTE: This function is not virtual, {_update} should be overridden instead.
	 */
	function _transfer(address from, address to, uint256 value) internal {
		if (from == address(0)) {
			revert ERC20InvalidSender(address(0));
		}
		if (to == address(0)) {
			revert ERC20InvalidReceiver(address(0));
		}
		_update(from, to, value);
	}

	/**
	 * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
	 * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
	 * this function.
	 *
	 * Emits a {Transfer} event.
	 */
	function _update(address from, address to, uint256 value) internal virtual {
		if (from == address(0)) {
			// Overflow check required: The rest of the code assumes that totalSupply never overflows
			_totalSupply += value;
		} else {
			uint256 fromBalance = _balances[from];
			if (fromBalance < value) {
				revert ERC20InsufficientBalance(from, fromBalance, value);
			}
			unchecked {
				// Overflow not possible: value <= fromBalance <= totalSupply.
				_balances[from] = fromBalance - value;
			}
		}

		if (to == address(0)) {
			unchecked {
				// Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
				_totalSupply -= value;
			}
		} else {
			unchecked {
				// Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
				_balances[to] += value;
			}
		}

		emit Transfer(from, to, value);
	}

	/**
	 * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
	 * Relies on the `_update` mechanism
	 *
	 * Emits a {Transfer} event with `from` set to the zero address.
	 *
	 * NOTE: This function is not virtual, {_update} should be overridden instead.
	 */
	function _mint(address account, uint256 value) internal {
		if (account == address(0)) {
			revert ERC20InvalidReceiver(address(0));
		}
		_update(address(0), account, value);
	}

	/**
	 * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
	 * Relies on the `_update` mechanism.
	 *
	 * Emits a {Transfer} event with `to` set to the zero address.
	 *
	 * NOTE: This function is not virtual, {_update} should be overridden instead
	 */
	function _burn(address account, uint256 value) internal {
		if (account == address(0)) {
			revert ERC20InvalidSender(address(0));
		}
		_update(account, address(0), value);
	}

	/**
	 * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
	 *
	 * This internal function is equivalent to `approve`, and can be used to
	 * e.g. set automatic allowances for certain subsystems, etc.
	 *
	 * Emits an {Approval} event.
	 *
	 * Requirements:
	 *
	 * - `owner` cannot be the zero address.
	 * - `spender` cannot be the zero address.
	 *
	 * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
	 */
	function _approve(address owner, address spender, uint256 value) internal {
		_approve(owner, spender, value, true);
	}

	/**
	 * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
	 *
	 * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
	 * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
	 * `Approval` event during `transferFrom` operations.
	 *
	 * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
	 * true using the following override:
	 * ```
	 * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
	 *     super._approve(owner, spender, value, true);
	 * }
	 * ```
	 *
	 * Requirements are the same as {_approve}.
	 */
	function _approve(
		address owner,
		address spender,
		uint256 value,
		bool emitEvent
	) internal virtual {
		if (owner == address(0)) {
			revert ERC20InvalidApprover(address(0));
		}
		if (spender == address(0)) {
			revert ERC20InvalidSpender(address(0));
		}
		_allowances[owner][spender] = value;
		if (emitEvent) {
			emit Approval(owner, spender, value);
		}
	}

	/**
	 * @dev Updates `owner` s allowance for `spender` based on spent `value`.
	 *
	 * Does not update the allowance value in case of infinite allowance.
	 * Revert if not enough allowance is available.
	 *
	 * Does not emit an {Approval} event.
	 */
	function _spendAllowance(
		address owner,
		address spender,
		uint256 value
	) internal virtual {
		uint256 currentAllowance = allowance(owner, spender);
		if (currentAllowance != type(uint256).max) {
			if (currentAllowance < value) {
				revert ERC20InsufficientAllowance(
					spender,
					currentAllowance,
					value
				);
			}
			unchecked {
				_approve(owner, spender, currentAllowance - value, false);
			}
		}
	}
}

// File @openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/ERC20Burnable.sol)

pragma solidity ^0.8.20;

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20Burnable is Context, ERC20 {
	/**
	 * @dev Destroys a `value` amount of tokens from the caller.
	 *
	 * See {ERC20-_burn}.
	 */
	function burn(uint256 value) public virtual {
		_burn(_msgSender(), value);
	}

	/**
	 * @dev Destroys a `value` amount of tokens from `account`, deducting from
	 * the caller's allowance.
	 *
	 * See {ERC20-_burn} and {ERC20-allowance}.
	 *
	 * Requirements:
	 *
	 * - the caller must have allowance for ``accounts``'s tokens of at least
	 * `value`.
	 */
	function burnFrom(address account, uint256 value) public virtual {
		_spendAllowance(account, _msgSender(), value);
		_burn(account, value);
	}
}

// File @openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
	/**
	 * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
	 * given ``owner``'s signed approval.
	 *
	 * IMPORTANT: The same issues {IERC20-approve} has related to transaction
	 * ordering also apply here.
	 *
	 * Emits an {Approval} event.
	 *
	 * Requirements:
	 *
	 * - `spender` cannot be the zero address.
	 * - `deadline` must be a timestamp in the future.
	 * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
	 * over the EIP712-formatted function arguments.
	 * - the signature must use ``owner``'s current nonce (see {nonces}).
	 *
	 * For more information on the signature format, see the
	 * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
	 * section].
	 *
	 * CAUTION: See Security Considerations above.
	 */
	function permit(
		address owner,
		address spender,
		uint256 value,
		uint256 deadline,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external;

	/**
	 * @dev Returns the current nonce for `owner`. This value must be
	 * included whenever a signature is generated for {permit}.
	 *
	 * Every successful call to {permit} increases ``owner``'s nonce by one. This
	 * prevents a signature from being used multiple times.
	 */
	function nonces(address owner) external view returns (uint256);

	/**
	 * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
	 */
	// solhint-disable-next-line func-name-mixedcase
	function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// File @openzeppelin/contracts/utils/cryptography/ECDSA.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.20;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
	enum RecoverError {
		NoError,
		InvalidSignature,
		InvalidSignatureLength,
		InvalidSignatureS
	}

	/**
	 * @dev The signature derives the `address(0)`.
	 */
	error ECDSAInvalidSignature();

	/**
	 * @dev The signature has an invalid length.
	 */
	error ECDSAInvalidSignatureLength(uint256 length);

	/**
	 * @dev The signature has an S value that is in the upper half order.
	 */
	error ECDSAInvalidSignatureS(bytes32 s);

	/**
	 * @dev Returns the address that signed a hashed message (`hash`) with `signature` or an error. This will not
	 * return address(0) without also returning an error description. Errors are documented using an enum (error type)
	 * and a bytes32 providing additional information about the error.
	 *
	 * If no error is returned, then the address can be used for verification purposes.
	 *
	 * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
	 * this function rejects them by requiring the `s` value to be in the lower
	 * half order, and the `v` value to be either 27 or 28.
	 *
	 * IMPORTANT: `hash` _must_ be the result of a hash operation for the
	 * verification to be secure: it is possible to craft signatures that
	 * recover to arbitrary addresses for non-hashed data. A safe way to ensure
	 * this is by receiving a hash of the original message (which may otherwise
	 * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
	 *
	 * Documentation for signature generation:
	 * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
	 * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
	 */
	function tryRecover(
		bytes32 hash,
		bytes memory signature
	) internal pure returns (address, RecoverError, bytes32) {
		if (signature.length == 65) {
			bytes32 r;
			bytes32 s;
			uint8 v;
			// ecrecover takes the signature parameters, and the only way to get them
			// currently is to use assembly.
			/// @solidity memory-safe-assembly
			assembly {
				r := mload(add(signature, 0x20))
				s := mload(add(signature, 0x40))
				v := byte(0, mload(add(signature, 0x60)))
			}
			return tryRecover(hash, v, r, s);
		} else {
			return (
				address(0),
				RecoverError.InvalidSignatureLength,
				bytes32(signature.length)
			);
		}
	}

	/**
	 * @dev Returns the address that signed a hashed message (`hash`) with
	 * `signature`. This address can then be used for verification purposes.
	 *
	 * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
	 * this function rejects them by requiring the `s` value to be in the lower
	 * half order, and the `v` value to be either 27 or 28.
	 *
	 * IMPORTANT: `hash` _must_ be the result of a hash operation for the
	 * verification to be secure: it is possible to craft signatures that
	 * recover to arbitrary addresses for non-hashed data. A safe way to ensure
	 * this is by receiving a hash of the original message (which may otherwise
	 * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
	 */
	function recover(
		bytes32 hash,
		bytes memory signature
	) internal pure returns (address) {
		(address recovered, RecoverError error, bytes32 errorArg) = tryRecover(
			hash,
			signature
		);
		_throwError(error, errorArg);
		return recovered;
	}

	/**
	 * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
	 *
	 * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
	 */
	function tryRecover(
		bytes32 hash,
		bytes32 r,
		bytes32 vs
	) internal pure returns (address, RecoverError, bytes32) {
		unchecked {
			bytes32 s = vs &
				bytes32(
					0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
				);
			// We do not check for an overflow here since the shift operation results in 0 or 1.
			uint8 v = uint8((uint256(vs) >> 255) + 27);
			return tryRecover(hash, v, r, s);
		}
	}

	/**
	 * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
	 */
	function recover(
		bytes32 hash,
		bytes32 r,
		bytes32 vs
	) internal pure returns (address) {
		(address recovered, RecoverError error, bytes32 errorArg) = tryRecover(
			hash,
			r,
			vs
		);
		_throwError(error, errorArg);
		return recovered;
	}

	/**
	 * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
	 * `r` and `s` signature fields separately.
	 */
	function tryRecover(
		bytes32 hash,
		uint8 v,
		bytes32 r,
		bytes32 s
	) internal pure returns (address, RecoverError, bytes32) {
		// EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
		// unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
		// the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
		// signatures from current libraries generate a unique signature with an s-value in the lower half order.
		//
		// If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
		// with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
		// vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
		// these malleable signatures as well.
		if (
			uint256(s) >
			0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
		) {
			return (address(0), RecoverError.InvalidSignatureS, s);
		}

		// If the signature is valid (and not malleable), return the signer address
		address signer = ecrecover(hash, v, r, s);
		if (signer == address(0)) {
			return (address(0), RecoverError.InvalidSignature, bytes32(0));
		}

		return (signer, RecoverError.NoError, bytes32(0));
	}

	/**
	 * @dev Overload of {ECDSA-recover} that receives the `v`,
	 * `r` and `s` signature fields separately.
	 */
	function recover(
		bytes32 hash,
		uint8 v,
		bytes32 r,
		bytes32 s
	) internal pure returns (address) {
		(address recovered, RecoverError error, bytes32 errorArg) = tryRecover(
			hash,
			v,
			r,
			s
		);
		_throwError(error, errorArg);
		return recovered;
	}

	/**
	 * @dev Optionally reverts with the corresponding custom error according to the `error` argument provided.
	 */
	function _throwError(RecoverError error, bytes32 errorArg) private pure {
		if (error == RecoverError.NoError) {
			return; // no error: do nothing
		} else if (error == RecoverError.InvalidSignature) {
			revert ECDSAInvalidSignature();
		} else if (error == RecoverError.InvalidSignatureLength) {
			revert ECDSAInvalidSignatureLength(uint256(errorArg));
		} else if (error == RecoverError.InvalidSignatureS) {
			revert ECDSAInvalidSignatureS(errorArg);
		}
	}
}

// File @openzeppelin/contracts/interfaces/IERC5267.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC5267.sol)

pragma solidity ^0.8.20;

interface IERC5267 {
	/**
	 * @dev MAY be emitted to signal that the domain could have changed.
	 */
	event EIP712DomainChanged();

	/**
	 * @dev returns the fields and values that describe the domain separator used by this contract for EIP-712
	 * signature.
	 */
	function eip712Domain()
		external
		view
		returns (
			bytes1 fields,
			string memory name,
			string memory version,
			uint256 chainId,
			address verifyingContract,
			bytes32 salt,
			uint256[] memory extensions
		);
}

// File @openzeppelin/contracts/utils/math/Math.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
	/**
	 * @dev Muldiv operation overflow.
	 */
	error MathOverflowedMulDiv();

	enum Rounding {
		Floor, // Toward negative infinity
		Ceil, // Toward positive infinity
		Trunc, // Toward zero
		Expand // Away from zero
	}

	/**
	 * @dev Returns the addition of two unsigned integers, with an overflow flag.
	 */
	function tryAdd(
		uint256 a,
		uint256 b
	) internal pure returns (bool, uint256) {
		unchecked {
			uint256 c = a + b;
			if (c < a) return (false, 0);
			return (true, c);
		}
	}

	/**
	 * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
	 */
	function trySub(
		uint256 a,
		uint256 b
	) internal pure returns (bool, uint256) {
		unchecked {
			if (b > a) return (false, 0);
			return (true, a - b);
		}
	}

	/**
	 * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
	 */
	function tryMul(
		uint256 a,
		uint256 b
	) internal pure returns (bool, uint256) {
		unchecked {
			// Gas optimization: this is cheaper than requiring 'a' not being zero, but the
			// benefit is lost if 'b' is also tested.
			// See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
			if (a == 0) return (true, 0);
			uint256 c = a * b;
			if (c / a != b) return (false, 0);
			return (true, c);
		}
	}

	/**
	 * @dev Returns the division of two unsigned integers, with a division by zero flag.
	 */
	function tryDiv(
		uint256 a,
		uint256 b
	) internal pure returns (bool, uint256) {
		unchecked {
			if (b == 0) return (false, 0);
			return (true, a / b);
		}
	}

	/**
	 * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
	 */
	function tryMod(
		uint256 a,
		uint256 b
	) internal pure returns (bool, uint256) {
		unchecked {
			if (b == 0) return (false, 0);
			return (true, a % b);
		}
	}

	/**
	 * @dev Returns the largest of two numbers.
	 */
	function max(uint256 a, uint256 b) internal pure returns (uint256) {
		return a > b ? a : b;
	}

	/**
	 * @dev Returns the smallest of two numbers.
	 */
	function min(uint256 a, uint256 b) internal pure returns (uint256) {
		return a < b ? a : b;
	}

	/**
	 * @dev Returns the average of two numbers. The result is rounded towards
	 * zero.
	 */
	function average(uint256 a, uint256 b) internal pure returns (uint256) {
		// (a + b) / 2 can overflow.
		return (a & b) + (a ^ b) / 2;
	}

	/**
	 * @dev Returns the ceiling of the division of two numbers.
	 *
	 * This differs from standard division with `/` in that it rounds towards infinity instead
	 * of rounding towards zero.
	 */
	function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
		if (b == 0) {
			// Guarantee the same behavior as in a regular Solidity division.
			return a / b;
		}

		// (a + b - 1) / b can overflow on addition, so we distribute.
		return a == 0 ? 0 : (a - 1) / b + 1;
	}

	/**
	 * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
	 * denominator == 0.
	 * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
	 * Uniswap Labs also under MIT license.
	 */
	function mulDiv(
		uint256 x,
		uint256 y,
		uint256 denominator
	) internal pure returns (uint256 result) {
		unchecked {
			// 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
			// use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
			// variables such that product = prod1 * 2^256 + prod0.
			uint256 prod0 = x * y; // Least significant 256 bits of the product
			uint256 prod1; // Most significant 256 bits of the product
			assembly {
				let mm := mulmod(x, y, not(0))
				prod1 := sub(sub(mm, prod0), lt(mm, prod0))
			}

			// Handle non-overflow cases, 256 by 256 division.
			if (prod1 == 0) {
				// Solidity will revert if denominator == 0, unlike the div opcode on its own.
				// The surrounding unchecked block does not change this fact.
				// See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
				return prod0 / denominator;
			}

			// Make sure the result is less than 2^256. Also prevents denominator == 0.
			if (denominator <= prod1) {
				revert MathOverflowedMulDiv();
			}

			///////////////////////////////////////////////
			// 512 by 256 division.
			///////////////////////////////////////////////

			// Make division exact by subtracting the remainder from [prod1 prod0].
			uint256 remainder;
			assembly {
				// Compute remainder using mulmod.
				remainder := mulmod(x, y, denominator)

				// Subtract 256 bit number from 512 bit number.
				prod1 := sub(prod1, gt(remainder, prod0))
				prod0 := sub(prod0, remainder)
			}

			// Factor powers of two out of denominator and compute largest power of two divisor of denominator.
			// Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

			uint256 twos = denominator & (0 - denominator);
			assembly {
				// Divide denominator by twos.
				denominator := div(denominator, twos)

				// Divide [prod1 prod0] by twos.
				prod0 := div(prod0, twos)

				// Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
				twos := add(div(sub(0, twos), twos), 1)
			}

			// Shift in bits from prod1 into prod0.
			prod0 |= prod1 * twos;

			// Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
			// that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
			// four bits. That is, denominator * inv = 1 mod 2^4.
			uint256 inverse = (3 * denominator) ^ 2;

			// Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
			// works in modular arithmetic, doubling the correct bits in each step.
			inverse *= 2 - denominator * inverse; // inverse mod 2^8
			inverse *= 2 - denominator * inverse; // inverse mod 2^16
			inverse *= 2 - denominator * inverse; // inverse mod 2^32
			inverse *= 2 - denominator * inverse; // inverse mod 2^64
			inverse *= 2 - denominator * inverse; // inverse mod 2^128
			inverse *= 2 - denominator * inverse; // inverse mod 2^256

			// Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
			// This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
			// less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
			// is no longer required.
			result = prod0 * inverse;
			return result;
		}
	}

	/**
	 * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
	 */
	function mulDiv(
		uint256 x,
		uint256 y,
		uint256 denominator,
		Rounding rounding
	) internal pure returns (uint256) {
		uint256 result = mulDiv(x, y, denominator);
		if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
			result += 1;
		}
		return result;
	}

	/**
	 * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
	 * towards zero.
	 *
	 * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
	 */
	function sqrt(uint256 a) internal pure returns (uint256) {
		if (a == 0) {
			return 0;
		}

		// For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
		//
		// We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
		// `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
		//
		// This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
		// → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
		// → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
		//
		// Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
		uint256 result = 1 << (log2(a) >> 1);

		// At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
		// since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
		// every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
		// into the expected uint128 result.
		unchecked {
			result = (result + a / result) >> 1;
			result = (result + a / result) >> 1;
			result = (result + a / result) >> 1;
			result = (result + a / result) >> 1;
			result = (result + a / result) >> 1;
			result = (result + a / result) >> 1;
			result = (result + a / result) >> 1;
			return min(result, a / result);
		}
	}

	/**
	 * @notice Calculates sqrt(a), following the selected rounding direction.
	 */
	function sqrt(
		uint256 a,
		Rounding rounding
	) internal pure returns (uint256) {
		unchecked {
			uint256 result = sqrt(a);
			return
				result +
				(unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
		}
	}

	/**
	 * @dev Return the log in base 2 of a positive value rounded towards zero.
	 * Returns 0 if given 0.
	 */
	function log2(uint256 value) internal pure returns (uint256) {
		uint256 result = 0;
		unchecked {
			if (value >> 128 > 0) {
				value >>= 128;
				result += 128;
			}
			if (value >> 64 > 0) {
				value >>= 64;
				result += 64;
			}
			if (value >> 32 > 0) {
				value >>= 32;
				result += 32;
			}
			if (value >> 16 > 0) {
				value >>= 16;
				result += 16;
			}
			if (value >> 8 > 0) {
				value >>= 8;
				result += 8;
			}
			if (value >> 4 > 0) {
				value >>= 4;
				result += 4;
			}
			if (value >> 2 > 0) {
				value >>= 2;
				result += 2;
			}
			if (value >> 1 > 0) {
				result += 1;
			}
		}
		return result;
	}

	/**
	 * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
	 * Returns 0 if given 0.
	 */
	function log2(
		uint256 value,
		Rounding rounding
	) internal pure returns (uint256) {
		unchecked {
			uint256 result = log2(value);
			return
				result +
				(unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
		}
	}

	/**
	 * @dev Return the log in base 10 of a positive value rounded towards zero.
	 * Returns 0 if given 0.
	 */
	function log10(uint256 value) internal pure returns (uint256) {
		uint256 result = 0;
		unchecked {
			if (value >= 10 ** 64) {
				value /= 10 ** 64;
				result += 64;
			}
			if (value >= 10 ** 32) {
				value /= 10 ** 32;
				result += 32;
			}
			if (value >= 10 ** 16) {
				value /= 10 ** 16;
				result += 16;
			}
			if (value >= 10 ** 8) {
				value /= 10 ** 8;
				result += 8;
			}
			if (value >= 10 ** 4) {
				value /= 10 ** 4;
				result += 4;
			}
			if (value >= 10 ** 2) {
				value /= 10 ** 2;
				result += 2;
			}
			if (value >= 10 ** 1) {
				result += 1;
			}
		}
		return result;
	}

	/**
	 * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
	 * Returns 0 if given 0.
	 */
	function log10(
		uint256 value,
		Rounding rounding
	) internal pure returns (uint256) {
		unchecked {
			uint256 result = log10(value);
			return
				result +
				(unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
		}
	}

	/**
	 * @dev Return the log in base 256 of a positive value rounded towards zero.
	 * Returns 0 if given 0.
	 *
	 * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
	 */
	function log256(uint256 value) internal pure returns (uint256) {
		uint256 result = 0;
		unchecked {
			if (value >> 128 > 0) {
				value >>= 128;
				result += 16;
			}
			if (value >> 64 > 0) {
				value >>= 64;
				result += 8;
			}
			if (value >> 32 > 0) {
				value >>= 32;
				result += 4;
			}
			if (value >> 16 > 0) {
				value >>= 16;
				result += 2;
			}
			if (value >> 8 > 0) {
				result += 1;
			}
		}
		return result;
	}

	/**
	 * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
	 * Returns 0 if given 0.
	 */
	function log256(
		uint256 value,
		Rounding rounding
	) internal pure returns (uint256) {
		unchecked {
			uint256 result = log256(value);
			return
				result +
				(
					unsignedRoundsUp(rounding) && 1 << (result << 3) < value
						? 1
						: 0
				);
		}
	}

	/**
	 * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
	 */
	function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
		return uint8(rounding) % 2 == 1;
	}
}

// File @openzeppelin/contracts/utils/math/SignedMath.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
	/**
	 * @dev Returns the largest of two signed numbers.
	 */
	function max(int256 a, int256 b) internal pure returns (int256) {
		return a > b ? a : b;
	}

	/**
	 * @dev Returns the smallest of two signed numbers.
	 */
	function min(int256 a, int256 b) internal pure returns (int256) {
		return a < b ? a : b;
	}

	/**
	 * @dev Returns the average of two signed numbers without overflow.
	 * The result is rounded towards zero.
	 */
	function average(int256 a, int256 b) internal pure returns (int256) {
		// Formula from the book "Hacker's Delight"
		int256 x = (a & b) + ((a ^ b) >> 1);
		return x + (int256(uint256(x) >> 255) & (a ^ b));
	}

	/**
	 * @dev Returns the absolute unsigned value of a signed value.
	 */
	function abs(int256 n) internal pure returns (uint256) {
		unchecked {
			// must be unchecked in order to support `n = type(int256).min`
			return uint256(n >= 0 ? n : -n);
		}
	}
}

// File @openzeppelin/contracts/utils/Strings.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Strings.sol)

pragma solidity ^0.8.20;

/**
 * @dev String operations.
 */
library Strings {
	bytes16 private constant HEX_DIGITS = "0123456789abcdef";
	uint8 private constant ADDRESS_LENGTH = 20;

	/**
	 * @dev The `value` string doesn't fit in the specified `length`.
	 */
	error StringsInsufficientHexLength(uint256 value, uint256 length);

	/**
	 * @dev Converts a `uint256` to its ASCII `string` decimal representation.
	 */
	function toString(uint256 value) internal pure returns (string memory) {
		unchecked {
			uint256 length = Math.log10(value) + 1;
			string memory buffer = new string(length);
			uint256 ptr;
			/// @solidity memory-safe-assembly
			assembly {
				ptr := add(buffer, add(32, length))
			}
			while (true) {
				ptr--;
				/// @solidity memory-safe-assembly
				assembly {
					mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
				}
				value /= 10;
				if (value == 0) break;
			}
			return buffer;
		}
	}

	/**
	 * @dev Converts a `int256` to its ASCII `string` decimal representation.
	 */
	function toStringSigned(
		int256 value
	) internal pure returns (string memory) {
		return
			string.concat(
				value < 0 ? "-" : "",
				toString(SignedMath.abs(value))
			);
	}

	/**
	 * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
	 */
	function toHexString(uint256 value) internal pure returns (string memory) {
		unchecked {
			return toHexString(value, Math.log256(value) + 1);
		}
	}

	/**
	 * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
	 */
	function toHexString(
		uint256 value,
		uint256 length
	) internal pure returns (string memory) {
		uint256 localValue = value;
		bytes memory buffer = new bytes(2 * length + 2);
		buffer[0] = "0";
		buffer[1] = "x";
		for (uint256 i = 2 * length + 1; i > 1; --i) {
			buffer[i] = HEX_DIGITS[localValue & 0xf];
			localValue >>= 4;
		}
		if (localValue != 0) {
			revert StringsInsufficientHexLength(value, length);
		}
		return string(buffer);
	}

	/**
	 * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
	 * representation.
	 */
	function toHexString(address addr) internal pure returns (string memory) {
		return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
	}

	/**
	 * @dev Returns true if the two strings are equal.
	 */
	function equal(
		string memory a,
		string memory b
	) internal pure returns (bool) {
		return
			bytes(a).length == bytes(b).length &&
			keccak256(bytes(a)) == keccak256(bytes(b));
	}
}

// File @openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/MessageHashUtils.sol)

pragma solidity ^0.8.20;

/**
 * @dev Signature message hash utilities for producing digests to be consumed by {ECDSA} recovery or signing.
 *
 * The library provides methods for generating a hash of a message that conforms to the
 * https://eips.ethereum.org/EIPS/eip-191[EIP 191] and https://eips.ethereum.org/EIPS/eip-712[EIP 712]
 * specifications.
 */
library MessageHashUtils {
	/**
	 * @dev Returns the keccak256 digest of an EIP-191 signed data with version
	 * `0x45` (`personal_sign` messages).
	 *
	 * The digest is calculated by prefixing a bytes32 `messageHash` with
	 * `"\x19Ethereum Signed Message:\n32"` and hashing the result. It corresponds with the
	 * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
	 *
	 * NOTE: The `messageHash` parameter is intended to be the result of hashing a raw message with
	 * keccak256, although any bytes32 value can be safely used because the final digest will
	 * be re-hashed.
	 *
	 * See {ECDSA-recover}.
	 */
	function toEthSignedMessageHash(
		bytes32 messageHash
	) internal pure returns (bytes32 digest) {
		/// @solidity memory-safe-assembly
		assembly {
			mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
			mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
			digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
		}
	}

	/**
	 * @dev Returns the keccak256 digest of an EIP-191 signed data with version
	 * `0x45` (`personal_sign` messages).
	 *
	 * The digest is calculated by prefixing an arbitrary `message` with
	 * `"\x19Ethereum Signed Message:\n" + len(message)` and hashing the result. It corresponds with the
	 * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
	 *
	 * See {ECDSA-recover}.
	 */
	function toEthSignedMessageHash(
		bytes memory message
	) internal pure returns (bytes32) {
		return
			keccak256(
				bytes.concat(
					"\x19Ethereum Signed Message:\n",
					bytes(Strings.toString(message.length)),
					message
				)
			);
	}

	/**
	 * @dev Returns the keccak256 digest of an EIP-191 signed data with version
	 * `0x00` (data with intended validator).
	 *
	 * The digest is calculated by prefixing an arbitrary `data` with `"\x19\x00"` and the intended
	 * `validator` address. Then hashing the result.
	 *
	 * See {ECDSA-recover}.
	 */
	function toDataWithIntendedValidatorHash(
		address validator,
		bytes memory data
	) internal pure returns (bytes32) {
		return keccak256(abi.encodePacked(hex"19_00", validator, data));
	}

	/**
	 * @dev Returns the keccak256 digest of an EIP-712 typed data (EIP-191 version `0x01`).
	 *
	 * The digest is calculated from a `domainSeparator` and a `structHash`, by prefixing them with
	 * `\x19\x01` and hashing the result. It corresponds to the hash signed by the
	 * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`] JSON-RPC method as part of EIP-712.
	 *
	 * See {ECDSA-recover}.
	 */
	function toTypedDataHash(
		bytes32 domainSeparator,
		bytes32 structHash
	) internal pure returns (bytes32 digest) {
		/// @solidity memory-safe-assembly
		assembly {
			let ptr := mload(0x40)
			mstore(ptr, hex"19_01")
			mstore(add(ptr, 0x02), domainSeparator)
			mstore(add(ptr, 0x22), structHash)
			digest := keccak256(ptr, 0x42)
		}
	}
}

// File @openzeppelin/contracts/utils/StorageSlot.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 */
library StorageSlot {
	struct AddressSlot {
		address value;
	}

	struct BooleanSlot {
		bool value;
	}

	struct Bytes32Slot {
		bytes32 value;
	}

	struct Uint256Slot {
		uint256 value;
	}

	struct StringSlot {
		string value;
	}

	struct BytesSlot {
		bytes value;
	}

	/**
	 * @dev Returns an `AddressSlot` with member `value` located at `slot`.
	 */
	function getAddressSlot(
		bytes32 slot
	) internal pure returns (AddressSlot storage r) {
		/// @solidity memory-safe-assembly
		assembly {
			r.slot := slot
		}
	}

	/**
	 * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
	 */
	function getBooleanSlot(
		bytes32 slot
	) internal pure returns (BooleanSlot storage r) {
		/// @solidity memory-safe-assembly
		assembly {
			r.slot := slot
		}
	}

	/**
	 * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
	 */
	function getBytes32Slot(
		bytes32 slot
	) internal pure returns (Bytes32Slot storage r) {
		/// @solidity memory-safe-assembly
		assembly {
			r.slot := slot
		}
	}

	/**
	 * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
	 */
	function getUint256Slot(
		bytes32 slot
	) internal pure returns (Uint256Slot storage r) {
		/// @solidity memory-safe-assembly
		assembly {
			r.slot := slot
		}
	}

	/**
	 * @dev Returns an `StringSlot` with member `value` located at `slot`.
	 */
	function getStringSlot(
		bytes32 slot
	) internal pure returns (StringSlot storage r) {
		/// @solidity memory-safe-assembly
		assembly {
			r.slot := slot
		}
	}

	/**
	 * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
	 */
	function getStringSlot(
		string storage store
	) internal pure returns (StringSlot storage r) {
		/// @solidity memory-safe-assembly
		assembly {
			r.slot := store.slot
		}
	}

	/**
	 * @dev Returns an `BytesSlot` with member `value` located at `slot`.
	 */
	function getBytesSlot(
		bytes32 slot
	) internal pure returns (BytesSlot storage r) {
		/// @solidity memory-safe-assembly
		assembly {
			r.slot := slot
		}
	}

	/**
	 * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
	 */
	function getBytesSlot(
		bytes storage store
	) internal pure returns (BytesSlot storage r) {
		/// @solidity memory-safe-assembly
		assembly {
			r.slot := store.slot
		}
	}
}

// File @openzeppelin/contracts/utils/ShortStrings.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ShortStrings.sol)

pragma solidity ^0.8.20;

// | string  | 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA   |
// | length  | 0x                                                              BB |
type ShortString is bytes32;

/**
 * @dev This library provides functions to convert short memory strings
 * into a `ShortString` type that can be used as an immutable variable.
 *
 * Strings of arbitrary length can be optimized using this library if
 * they are short enough (up to 31 bytes) by packing them with their
 * length (1 byte) in a single EVM word (32 bytes). Additionally, a
 * fallback mechanism can be used for every other case.
 *
 * Usage example:
 *
 * ```solidity
 * contract Named {
 *     using ShortStrings for *;
 *
 *     ShortString private immutable _name;
 *     string private _nameFallback;
 *
 *     constructor(string memory contractName) {
 *         _name = contractName.toShortStringWithFallback(_nameFallback);
 *     }
 *
 *     function name() external view returns (string memory) {
 *         return _name.toStringWithFallback(_nameFallback);
 *     }
 * }
 * ```
 */
library ShortStrings {
	// Used as an identifier for strings longer than 31 bytes.
	bytes32 private constant FALLBACK_SENTINEL =
		0x00000000000000000000000000000000000000000000000000000000000000FF;

	error StringTooLong(string str);
	error InvalidShortString();

	/**
	 * @dev Encode a string of at most 31 chars into a `ShortString`.
	 *
	 * This will trigger a `StringTooLong` error is the input string is too long.
	 */
	function toShortString(
		string memory str
	) internal pure returns (ShortString) {
		bytes memory bstr = bytes(str);
		if (bstr.length > 31) {
			revert StringTooLong(str);
		}
		return ShortString.wrap(bytes32(uint256(bytes32(bstr)) | bstr.length));
	}

	/**
	 * @dev Decode a `ShortString` back to a "normal" string.
	 */
	function toString(ShortString sstr) internal pure returns (string memory) {
		uint256 len = byteLength(sstr);
		// using `new string(len)` would work locally but is not memory safe.
		string memory str = new string(32);
		/// @solidity memory-safe-assembly
		assembly {
			mstore(str, len)
			mstore(add(str, 0x20), sstr)
		}
		return str;
	}

	/**
	 * @dev Return the length of a `ShortString`.
	 */
	function byteLength(ShortString sstr) internal pure returns (uint256) {
		uint256 result = uint256(ShortString.unwrap(sstr)) & 0xFF;
		if (result > 31) {
			revert InvalidShortString();
		}
		return result;
	}

	/**
	 * @dev Encode a string into a `ShortString`, or write it to storage if it is too long.
	 */
	function toShortStringWithFallback(
		string memory value,
		string storage store
	) internal returns (ShortString) {
		if (bytes(value).length < 32) {
			return toShortString(value);
		} else {
			StorageSlot.getStringSlot(store).value = value;
			return ShortString.wrap(FALLBACK_SENTINEL);
		}
	}

	/**
	 * @dev Decode a string that was encoded to `ShortString` or written to storage using {setWithFallback}.
	 */
	function toStringWithFallback(
		ShortString value,
		string storage store
	) internal pure returns (string memory) {
		if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
			return toString(value);
		} else {
			return store;
		}
	}

	/**
	 * @dev Return the length of a string that was encoded to `ShortString` or written to storage using
	 * {setWithFallback}.
	 *
	 * WARNING: This will return the "byte length" of the string. This may not reflect the actual length in terms of
	 * actual characters as the UTF-8 encoding of a single character can span over multiple bytes.
	 */
	function byteLengthWithFallback(
		ShortString value,
		string storage store
	) internal view returns (uint256) {
		if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
			return byteLength(value);
		} else {
			return bytes(store).length;
		}
	}
}

// File @openzeppelin/contracts/utils/cryptography/EIP712.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/EIP712.sol)

pragma solidity ^0.8.20;

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding scheme specified in the EIP requires a domain separator and a hash of the typed structured data, whose
 * encoding is very generic and therefore its implementation in Solidity is not feasible, thus this contract
 * does not implement the encoding itself. Protocols need to implement the type-specific encoding they need in order to
 * produce the hash of their typed data using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * NOTE: In the upgradeable version of this contract, the cached values will correspond to the address, and the domain
 * separator of the implementation contract. This will cause the {_domainSeparatorV4} function to always rebuild the
 * separator from the immutable values, which is cheaper than accessing a cached version in cold storage.
 *
 * @custom:oz-upgrades-unsafe-allow state-variable-immutable
 */
abstract contract EIP712 is IERC5267 {
	using ShortStrings for *;

	bytes32 private constant TYPE_HASH =
		keccak256(
			"EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
		);

	// Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
	// invalidate the cached domain separator if the chain id changes.
	bytes32 private immutable _cachedDomainSeparator;
	uint256 private immutable _cachedChainId;
	address private immutable _cachedThis;

	bytes32 private immutable _hashedName;
	bytes32 private immutable _hashedVersion;

	ShortString private immutable _name;
	ShortString private immutable _version;
	string private _nameFallback;
	string private _versionFallback;

	/**
	 * @dev Initializes the domain separator and parameter caches.
	 *
	 * The meaning of `name` and `version` is specified in
	 * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
	 *
	 * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
	 * - `version`: the current major version of the signing domain.
	 *
	 * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
	 * contract upgrade].
	 */
	constructor(string memory name, string memory version) {
		_name = name.toShortStringWithFallback(_nameFallback);
		_version = version.toShortStringWithFallback(_versionFallback);
		_hashedName = keccak256(bytes(name));
		_hashedVersion = keccak256(bytes(version));

		_cachedChainId = block.chainid;
		_cachedDomainSeparator = _buildDomainSeparator();
		_cachedThis = address(this);
	}

	/**
	 * @dev Returns the domain separator for the current chain.
	 */
	function _domainSeparatorV4() internal view returns (bytes32) {
		if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
			return _cachedDomainSeparator;
		} else {
			return _buildDomainSeparator();
		}
	}

	function _buildDomainSeparator() private view returns (bytes32) {
		return
			keccak256(
				abi.encode(
					TYPE_HASH,
					_hashedName,
					_hashedVersion,
					block.chainid,
					address(this)
				)
			);
	}

	/**
	 * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
	 * function returns the hash of the fully encoded EIP712 message for this domain.
	 *
	 * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
	 *
	 * ```solidity
	 * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
	 *     keccak256("Mail(address to,string contents)"),
	 *     mailTo,
	 *     keccak256(bytes(mailContents))
	 * )));
	 * address signer = ECDSA.recover(digest, signature);
	 * ```
	 */
	function _hashTypedDataV4(
		bytes32 structHash
	) internal view virtual returns (bytes32) {
		return
			MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
	}

	/**
	 * @dev See {IERC-5267}.
	 */
	function eip712Domain()
		public
		view
		virtual
		returns (
			bytes1 fields,
			string memory name,
			string memory version,
			uint256 chainId,
			address verifyingContract,
			bytes32 salt,
			uint256[] memory extensions
		)
	{
		return (
			hex"0f", // 01111
			_EIP712Name(),
			_EIP712Version(),
			block.chainid,
			address(this),
			bytes32(0),
			new uint256[](0)
		);
	}

	/**
	 * @dev The name parameter for the EIP712 domain.
	 *
	 * NOTE: By default this function reads _name which is an immutable value.
	 * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
	 */
	// solhint-disable-next-line func-name-mixedcase
	function _EIP712Name() internal view returns (string memory) {
		return _name.toStringWithFallback(_nameFallback);
	}

	/**
	 * @dev The version parameter for the EIP712 domain.
	 *
	 * NOTE: By default this function reads _version which is an immutable value.
	 * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
	 */
	// solhint-disable-next-line func-name-mixedcase
	function _EIP712Version() internal view returns (string memory) {
		return _version.toStringWithFallback(_versionFallback);
	}
}

// File @openzeppelin/contracts/utils/Nonces.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Nonces.sol)
pragma solidity ^0.8.20;

/**
 * @dev Provides tracking nonces for addresses. Nonces will only increment.
 */
abstract contract Nonces {
	/**
	 * @dev The nonce used for an `account` is not the expected current nonce.
	 */
	error InvalidAccountNonce(address account, uint256 currentNonce);

	mapping(address account => uint256) private _nonces;

	/**
	 * @dev Returns the next unused nonce for an address.
	 */
	function nonces(address owner) public view virtual returns (uint256) {
		return _nonces[owner];
	}

	/**
	 * @dev Consumes a nonce.
	 *
	 * Returns the current value and increments nonce.
	 */
	function _useNonce(address owner) internal virtual returns (uint256) {
		// For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
		// decremented or reset. This guarantees that the nonce never overflows.
		unchecked {
			// It is important to do x++ and not ++x here.
			return _nonces[owner]++;
		}
	}

	/**
	 * @dev Same as {_useNonce} but checking that `nonce` is the next valid for `owner`.
	 */
	function _useCheckedNonce(address owner, uint256 nonce) internal virtual {
		uint256 current = _useNonce(owner);
		if (nonce != current) {
			revert InvalidAccountNonce(owner, current);
		}
	}
}

// File @openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/ERC20Permit.sol)

pragma solidity ^0.8.20;

/**
 * @dev Implementation of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
abstract contract ERC20Permit is ERC20, IERC20Permit, EIP712, Nonces {
	bytes32 private constant PERMIT_TYPEHASH =
		keccak256(
			"Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
		);

	/**
	 * @dev Permit deadline has expired.
	 */
	error ERC2612ExpiredSignature(uint256 deadline);

	/**
	 * @dev Mismatched signature.
	 */
	error ERC2612InvalidSigner(address signer, address owner);

	/**
	 * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
	 *
	 * It's a good idea to use the same `name` that is defined as the ERC20 token name.
	 */
	constructor(string memory name) EIP712(name, "1") {}

	/**
	 * @inheritdoc IERC20Permit
	 */
	function permit(
		address owner,
		address spender,
		uint256 value,
		uint256 deadline,
		uint8 v,
		bytes32 r,
		bytes32 s
	) public virtual {
		if (block.timestamp > deadline) {
			revert ERC2612ExpiredSignature(deadline);
		}

		bytes32 structHash = keccak256(
			abi.encode(
				PERMIT_TYPEHASH,
				owner,
				spender,
				value,
				_useNonce(owner),
				deadline
			)
		);

		bytes32 hash = _hashTypedDataV4(structHash);

		address signer = ECDSA.recover(hash, v, r, s);
		if (signer != owner) {
			revert ERC2612InvalidSigner(signer, owner);
		}

		_approve(owner, spender, value);
	}

	/**
	 * @inheritdoc IERC20Permit
	 */
	function nonces(
		address owner
	) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
		return super.nonces(owner);
	}

	/**
	 * @inheritdoc IERC20Permit
	 */
	// solhint-disable-next-line func-name-mixedcase
	function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
		return _domainSeparatorV4();
	}
}

// File contracts/interfaces/IWETH.sol

// Original license: SPDX_License_Identifier: MIT

pragma solidity ^0.8.9;

interface IWETH is IERC20 {
	function deposit() external payable;

	function withdraw(uint256 wad) external;
}

// File @openzeppelin/contracts/utils/ReentrancyGuard.sol@v5.0.2

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
	// Booleans are more expensive than uint256 or any type that takes up a full
	// word because each write operation emits an extra SLOAD to first read the
	// slot's contents, replace the bits taken up by the boolean, and then write
	// back. This is the compiler's defense against contract upgrades and
	// pointer aliasing, and it cannot be disabled.

	// The values being non-zero value makes deployment a bit more expensive,
	// but in exchange the refund on every call to nonReentrant will be lower in
	// amount. Since refunds are capped to a percentage of the total
	// transaction's gas, it is best to keep them low in cases like this one, to
	// increase the likelihood of the full refund coming into effect.
	uint256 private constant NOT_ENTERED = 1;
	uint256 private constant ENTERED = 2;

	uint256 private _status;

	/**
	 * @dev Unauthorized reentrant call.
	 */
	error ReentrancyGuardReentrantCall();

	constructor() {
		_status = NOT_ENTERED;
	}

	/**
	 * @dev Prevents a contract from calling itself, directly or indirectly.
	 * Calling a `nonReentrant` function from another `nonReentrant`
	 * function is not supported. It is possible to prevent this from happening
	 * by making the `nonReentrant` function external, and making it call a
	 * `private` function that does the actual work.
	 */
	modifier nonReentrant() {
		_nonReentrantBefore();
		_;
		_nonReentrantAfter();
	}

	function _nonReentrantBefore() private {
		// On the first call to nonReentrant, _status will be NOT_ENTERED
		if (_status == ENTERED) {
			revert ReentrancyGuardReentrantCall();
		}

		// Any calls to nonReentrant after this point will fail
		_status = ENTERED;
	}

	function _nonReentrantAfter() private {
		// By storing the original value once again, a refund is triggered (see
		// https://eips.ethereum.org/EIPS/eip-2200)
		_status = NOT_ENTERED;
	}

	/**
	 * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
	 * `nonReentrant` function in the call stack.
	 */
	function _reentrancyGuardEntered() internal view returns (bool) {
		return _status == ENTERED;
	}
}

// File contracts/interfaces/IDexFactory.sol

// Original license: SPDX_License_Identifier: MIT

pragma solidity ^0.8.0;

interface IDexFactory {
	function createPair(
		address tokenA,
		address tokenB
	) external returns (address pair);
}

// File contracts/interfaces/IUniswapV2Pair.sol

// Original license: SPDX_License_Identifier: MIT

pragma solidity ^0.8.0;

interface IUniswapV2Pair {
	event Approval(address indexed owner, address indexed spender, uint value);
	event Transfer(address indexed from, address indexed to, uint value);

	function name() external pure returns (string memory);

	function symbol() external pure returns (string memory);

	function decimals() external pure returns (uint8);

	function totalSupply() external view returns (uint);

	function balanceOf(address owner) external view returns (uint);

	function allowance(
		address owner,
		address spender
	) external view returns (uint);

	function approve(address spender, uint value) external returns (bool);

	function transfer(address to, uint value) external returns (bool);

	function transferFrom(
		address from,
		address to,
		uint value
	) external returns (bool);

	function DOMAIN_SEPARATOR() external view returns (bytes32);

	function PERMIT_TYPEHASH() external pure returns (bytes32);

	function nonces(address owner) external view returns (uint);

	function permit(
		address owner,
		address spender,
		uint value,
		uint deadline,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external;

	event Mint(address indexed sender, uint amount0, uint amount1);
	event Burn(
		address indexed sender,
		uint amount0,
		uint amount1,
		address indexed to
	);
	event Swap(
		address indexed sender,
		uint amount0In,
		uint amount1In,
		uint amount0Out,
		uint amount1Out,
		address indexed to
	);
	event Sync(uint112 reserve0, uint112 reserve1);

	function MINIMUM_LIQUIDITY() external pure returns (uint);

	function factory() external view returns (address);

	function token0() external view returns (address);

	function token1() external view returns (address);

	function getReserves()
		external
		view
		returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

	function price0CumulativeLast() external view returns (uint);

	function price1CumulativeLast() external view returns (uint);

	function kLast() external view returns (uint);

	function mint(address to) external returns (uint liquidity);

	function burn(address to) external returns (uint amount0, uint amount1);

	function swap(
		uint amount0Out,
		uint amount1Out,
		address to,
		bytes calldata data
	) external;

	function skim(address to) external;

	function sync() external;

	function initialize(address, address) external;
}

// File contracts/interfaces/IUniswapV2Router.sol

// Original license: SPDX_License_Identifier: MIT

pragma solidity ^0.8.0;

interface IUniswapV2Router01 {
	function factory() external pure returns (address);

	function WETH() external pure returns (address);

	function addLiquidity(
		address tokenA,
		address tokenB,
		uint256 amountADesired,
		uint256 amountBDesired,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline
	) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

	function addLiquidityETH(
		address token,
		uint256 amountTokenDesired,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	)
		external
		payable
		returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

	function removeLiquidity(
		address tokenA,
		address tokenB,
		uint256 liquidity,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline
	) external returns (uint256 amountA, uint256 amountB);

	function removeLiquidityETH(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	) external returns (uint256 amountToken, uint256 amountETH);

	function removeLiquidityWithPermit(
		address tokenA,
		address tokenB,
		uint256 liquidity,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external returns (uint256 amountA, uint256 amountB);

	function removeLiquidityETHWithPermit(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external returns (uint256 amountToken, uint256 amountETH);

	function swapExactTokensForTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);

	function swapTokensForExactTokens(
		uint256 amountOut,
		uint256 amountInMax,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);

	function swapExactETHForTokens(
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external payable returns (uint256[] memory amounts);

	function swapTokensForExactETH(
		uint256 amountOut,
		uint256 amountInMax,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);

	function swapExactTokensForETH(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);

	function swapETHForExactTokens(
		uint256 amountOut,
		address[] calldata path,
		address to,
		uint256 deadline
	) external payable returns (uint256[] memory amounts);

	function quote(
		uint256 amountA,
		uint256 reserveA,
		uint256 reserveB
	) external pure returns (uint256 amountB);

	function getAmountOut(
		uint256 amountIn,
		uint256 reserveIn,
		uint256 reserveOut
	) external pure returns (uint256 amountOut);

	function getAmountIn(
		uint256 amountOut,
		uint256 reserveIn,
		uint256 reserveOut
	) external pure returns (uint256 amountIn);

	function getAmountsOut(
		uint256 amountIn,
		address[] calldata path
	) external view returns (uint256[] memory amounts);

	function getAmountsIn(
		uint256 amountOut,
		address[] calldata path
	) external view returns (uint256[] memory amounts);
}

// pragma solidity >=0.6.2;

interface IUniswapV2Router02 is IUniswapV2Router01 {
	function removeLiquidityETHSupportingFeeOnTransferTokens(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	) external returns (uint256 amountETH);

	function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external returns (uint256 amountETH);

	function swapExactTokensForTokensSupportingFeeOnTransferTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external;

	function swapExactETHForTokensSupportingFeeOnTransferTokens(
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external payable;

	function swapExactTokensForETHSupportingFeeOnTransferTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external;
}

// File contracts/MintStakeShare.sol

// Original license: SPDX_License_Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

contract MintStakeShare is
	ERC20,
	ERC20Burnable,
	Ownable,
	ERC20Permit,
	ReentrancyGuard
{
	struct TokenDetails {
		uint256 ethRaised;
		uint256 initialPrice;
		uint256 priceSupplyInterval;
		uint256 priceIncreasePercent;
		uint256 currentPrice;
		uint256 uniswapPrice;
		uint256 totalSupply;
		uint256 currentPriceTier;
	}

	uint256 private totalEthRaised;

	/**
	 * @notice Initial Price of the token
	 */
	uint256 private initialPrice;

	/**
	 * @notice At what total supply intervals the price tier will increase.
	 */
	uint256 private priceSupplyInterval;

	/**
	 * @notice How much the price will increase at every price tier
	 */
	uint256 private priceIncreasePercent;

	mapping(address => address) public referrers;
	mapping(address => uint256) public referralEarnings;
	uint256 public totalReferrals;
	uint256 public referrerReward = 5;
	uint256 public maxReferralLevels = 3;
	uint256 public tierReductionRate = 50;
	IUniswapV2Router02 public dexRouter;
	address public lpPair;

	bool private swapping;
	uint256 public swapTokensAtAmount;

	address public operationsAddress;
	IWETH private immutable WETH;
	address public stakingAddress;
	address public tokenManager;

	uint256 public tradingActiveBlock = 0; // 0 means trading is not active
	mapping(address => bool) public bot;
	uint256 public botsCaught;

	bool public tradingActive = false;
	bool public swapEnabled = false;

	uint256 public buyTotalFees;
	uint256 public sellTotalFees;
	uint256 public percentOfMintForLiquidity;

	mapping(address => bool) private _isExcludedFromFees;

	mapping(address => bool) public automatedMarketMakerPairs;

	event EnabledTrading();

	event ExcludeFromFees(address indexed account, bool isExcluded);

	event AddLiquidity(
		uint256 tokensAdded,
		uint256 ethAdded,
		uint256 liquidityTokens
	);

	event Purchase(
		address indexed beneficiary,
		uint256 contribution,
		uint256 amount
	);

	event Referral(
		address indexed beneficiary,
		address indexed user,
		uint256 amount
	);

	constructor(
		string memory _name,
		string memory _symbol,
		// address _defaultOwner,
		uint256 _initialPrice,
		uint256 _priceSupplyInterval,
		uint256 _priceIncreasePercent,
		address _uniswapV2Router
	)
		ERC20(_name, _symbol)
		ERC20Permit(_name)
		Ownable(msg.sender)
		ReentrancyGuard()
	{
		address newOwner = msg.sender;

		initialPrice = ((1e18 * 1e18) / (_initialPrice));
		priceSupplyInterval = _priceSupplyInterval;
		priceIncreasePercent = 100 / _priceIncreasePercent;

		dexRouter = IUniswapV2Router02(_uniswapV2Router);

		WETH = IWETH(dexRouter.WETH());

		lpPair = IDexFactory(dexRouter.factory()).createPair(
			address(this),
			address(WETH)
		);
		_setAutomatedMarketMakerPair(address(lpPair), true);

		swapTokensAtAmount = (priceSupplyInterval / 50);

		buyTotalFees = 3;

		sellTotalFees = 9;

		percentOfMintForLiquidity = 75;

		excludeFromFees(newOwner, true);
		excludeFromFees(address(0), true);
		excludeFromFees(address(this), true);
		excludeFromFees(address(0xdead), true);

		operationsAddress = newOwner;
	}

	function tokenDetails() external view returns (TokenDetails memory) {
		return
			TokenDetails({
				ethRaised: totalEthRaised,
				initialPrice: initialPrice,
				priceSupplyInterval: priceSupplyInterval,
				priceIncreasePercent: priceIncreasePercent,
				currentPrice: calculatePrice(),
				uniswapPrice: _getUniswapPrice(),
				totalSupply: totalSupply(),
				currentPriceTier: currentPriceTier()
			});
	}

	/**
	 * @notice Calculate the price to mint tokens at the current price tier
	 * @return The price to mint tokens at the given price tier
	 */
	function calculatePrice() public view returns (uint256) {
		uint256 currentTier = currentPriceTier();
		if (currentTier == 0) {
			return initialPrice;
		} else {
			return _calculatePrice(currentTier);
		}
	}

	function setAutomatedMarketMakerPair(
		address pair,
		bool value
	) external onlyOwner {
		require(
			pair != lpPair,
			"The pair cannot be removed from automatedMarketMakerPairs"
		);

		_setAutomatedMarketMakerPair(pair, value);
	}

	/**
	 * @notice Calculate the price to mint tokens at a given price tier
	 * @param _priceTier The price tier to calculate the price for
	 * @return The price to mint tokens at the given price tier
	 */
	function calculatePriceByTier(
		uint _priceTier
	) public view returns (uint256) {
		if (_priceTier == 0) {
			return initialPrice;
		} else {
			return _calculatePrice(_priceTier);
		}
	}

	receive() external payable {
		if (_isContract(msg.sender)) {
			return;
		}
		if (msg.value > 1000) {
			_purchase(msg.sender, msg.value);
		}
	}

	function currentPriceTier() public view returns (uint256) {
		return (totalSupply() / priceSupplyInterval);
	}

	function enableTrading() external onlyOwner {
		require(!tradingActive, "Cannot reenable trading");
		tradingActive = true;
		swapEnabled = true;
		tradingActiveBlock = block.number;

		uint ethBalance = address(this).balance;
		_mintAndAddLiquidityWithETH(ethBalance);

		emit EnabledTrading();
	}

	function mint(address account, uint256 value) external {
		if (msg.sender != tokenManager && msg.sender != stakingAddress) {
			revert("Only token manager and staking contract can mint");
		}
		_mint(account, value);
	}

	function buyWithMint(
		address beneficiary,
		address _referrer
	) external payable nonReentrant {
		uint amount = msg.value;
		totalEthRaised += amount;

		uint256 tokens = getTokenMintAmount(amount);
		_mint(beneficiary, tokens);
		_setReferrer(_referrer);
		_handleReferralETH(amount);
		_handleIncomingETHFromMint();
		emit Purchase(beneficiary, amount, tokens);
	}

	function setReferrer(address referrer) external {
		require(_setReferrer(referrer), "Setting referrer failed.");
	}

	function _setReferrer(address referrer) internal returns (bool) {
		// Check in this order - if referrer doesn't exist for user,
		// if reffer is address not 0, then is not contract
		if (
			referrers[msg.sender] != address(0) ||
			referrer == address(0) ||
			_isContract(referrer)
		) {
			return false;
		}

		referrers[msg.sender] = referrer;
		return true;
	}

	function _handleReferralETH(uint256 amount) internal {
		uint maxLevels = maxReferralLevels;

		address thisReferrer = msg.sender;
		uint256 referralAmount = (amount * referrerReward) / 100;

		for (uint i = 0; i < maxLevels; i++) {
			thisReferrer = referrers[thisReferrer];

			if (thisReferrer == address(0)) {
				break;
			}

			if (!_isContract(thisReferrer)) {
				payable(thisReferrer).transfer(referralAmount);
				referralEarnings[thisReferrer] += referralAmount;
				totalReferrals += referralAmount;
			}
			emit Referral(thisReferrer, msg.sender, referralAmount);
			referralAmount =
				referralAmount -
				(referralAmount * tierReductionRate) /
				100; // drop referral rate each loop iteration
		}
	}

	function _handleIncomingETHFromMint() internal {
		uint amount = address(this).balance;
		//uint256 ethForLiquidity = amount;

		if (tradingActive) {
			_mintAndAddLiquidityWithETH(
				(amount * percentOfMintForLiquidity) / 100
			);
			bool success;
			(success, ) = address(operationsAddress).call{
				value: address(this).balance
			}("");
		}
	}

	function getTokenMintAmount(
		uint256 _inputAmount
	) public view returns (uint256) {
		uint256 price = calculatePrice();
		uint256 outputTokens = (_inputAmount / price) * 10 ** 18;

		if (outputTokens > priceSupplyInterval) {
			uint priceTotalSupply = totalSupply() + outputTokens;

			uint higherPriceTier = (priceTotalSupply / priceSupplyInterval);
			price = _calculatePrice(higherPriceTier);
			outputTokens = (_inputAmount / price) * 10 ** 18;
		}

		return outputTokens;
	}

	function _purchase(address beneficiary, uint256 amount) private {
		totalEthRaised += amount;

		uint256 tokens = getTokenMintAmount(amount);

		if (tradingActive) {
			(
				uint amountOut,
				uint amountOut0,
				uint amountOut1
			) = _getSwapAmounts(amount);

			if (amountOut > tokens) {
				IWETH(WETH).deposit{ value: amount }();
				IWETH(WETH).transfer(lpPair, amount);
				IUniswapV2Pair(lpPair).swap(
					amountOut0,
					amountOut1,
					msg.sender,
					new bytes(0)
				);
			} else {
				_mint(beneficiary, tokens);
				_handleIncomingETHFromMint();
			}
		} else if (!tradingActive) {
			_mint(beneficiary, tokens);
		}

		emit Purchase(beneficiary, amount, tokens);
	}

	function fracExp(
		uint k,
		uint q,
		uint n,
		uint p
	) private pure returns (uint) {
		uint s = 0;
		uint N = 1;
		uint B = 1;
		for (uint i = 0; i < p; ++i) {
			unchecked {
				s += (k * N) / B / (q ** i);
				N = N * (n - i);
				B = B * (i + 1);
			}
		}
		return s;
	}

	function excludeFromFees(address account, bool excluded) public onlyOwner {
		_isExcludedFromFees[account] = excluded;
		emit ExcludeFromFees(account, excluded);
	}

	
	function updateFees(uint256 _buyFee, uint256 _sellFee) external onlyOwner {
		sellTotalFees = _sellFee;

		buyTotalFees = _buyFee;
		require(sellTotalFees <= 30, "Must keep sell fees at 30% or less"); //@audit High Fees
		require(buyTotalFees <= 10, "Must keep buy fees at 10% or less");
	}

	function updateReferrals(
		uint256 _referralFee,
		uint256 _maxReferralLevels,
		uint256 _tierReductionPercent
	) external onlyOwner {
		referrerReward = _referralFee;

		maxReferralLevels = _maxReferralLevels;

		tierReductionRate = _tierReductionPercent;
		require(
			tierReductionRate <= 50,
			"Must keep tier reduction at 50% or less"
		);
		require(referrerReward <= 10, "Must keep referral fee at 10% or less");
		require(maxReferralLevels <= 10, "Must keep levels at 10 or less");
	}

	function transferForeignToken(
		address _token,
		address _to
	) external onlyOwner returns (bool _sent) {
		require(_token != address(0), "_token address cannot be 0");
		uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
		_sent = IERC20(_token).transfer(_to, _contractBalance);
	}

	// withdraw ETH if stuck or someone sends to the address
	function withdrawStuckETH() external onlyOwner {
		bool success;
		(success, ) = address(msg.sender).call{ value: address(this).balance }(
			""
		);
	}

	function setTokenManager(address _tokenManager) external onlyOwner {
		require(
			_tokenManager != address(0),
			"_tokenManager address cannot be 0"
		);
		require(_isContract(_tokenManager), "_tokenManager must be a contract");
		tokenManager = _tokenManager;
	}

	function setStakingAddress(address _stakingAddress) external onlyOwner {
		require(
			_stakingAddress != address(0),
			"_stakingAddress address cannot be 0"
		);
		require(
			_isContract(_stakingAddress),
			"_stakingAddress must be a contract"
		);
		stakingAddress = _stakingAddress;
	}

	function setOperationsAddress(
		address _operationsAddress
	) external onlyOwner {
		require(
			_operationsAddress != address(0),
			"_operationsAddress address cannot be 0"
		);
		operationsAddress = payable(_operationsAddress); //@audit "Missing require check(Honeypot)
	}

	/* INTERNAL FUNCTIONS */

	/**
	 * @notice Add liquidity with given ETH amount, mint the tokens to pair with it
	 * @param ethAmount The amount of ETH to add liquidity with
	 * @return liquidity The amount of liquidity tokens minted
	 */
	function _mintAndAddLiquidityWithETH(
		uint256 ethAmount
	) private returns (uint256 liquidity) {
		require(address(this).balance >= ethAmount, "Insufficient ETH balance");
		IWETH(WETH).deposit{ value: ethAmount }();
		assert(IWETH(WETH).transfer(lpPair, ethAmount));

		(uint res0, uint res1, ) = IUniswapV2Pair(lpPair).getReserves();
		uint tokens;
		if (res0 > 0 && res1 > 0) {
			tokens = _getLiquidityAmount(ethAmount, res0, res1);
		} else {
			tokens = getTokenMintAmount(ethAmount);
		}
		_mint(lpPair, tokens);
		liquidity = IUniswapV2Pair(lpPair).mint(address(0xdead));
		emit AddLiquidity(tokens, ethAmount, liquidity);
	}

	function _getAmountOut(
		uint amountIn,
		uint reserveIn,
		uint reserveOut
	) internal pure returns (uint amountOut) {
		require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
		require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
		uint amountInWithFee = amountIn * 997;
		uint numerator = amountInWithFee * reserveOut;
		uint denominator = (reserveIn * 1000) + amountInWithFee;
		amountOut = numerator / denominator;
	}

	function _buyAndBurn(uint256 amount) private {
		// uint256 amount = msg.value;
		(, uint amountOut0, uint amountOut1) = _getSwapAmounts(amount);
		IWETH(WETH).deposit{ value: amount }();
		IWETH(WETH).transfer(lpPair, amount);
		IUniswapV2Pair(lpPair).swap(
			amountOut0,
			amountOut1,
			address(0xdead),
			new bytes(0)
		);

		// addLiquidity(tokens, amount);
	}

	function _getLiquidityAmount(
		uint amountIn,
		uint reserveIn,
		uint reserveOut
	) internal pure returns (uint amountOut) {
		require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
		require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
		uint numerator = reserveOut;
		uint denominator = (reserveIn);
		amountOut = (numerator / denominator) * amountIn;
	}

	function _getSwapAmounts(
		uint256 _amount
	) private view returns (uint amountOut, uint amountOut0, uint amountOut1) {
		(uint reserve0, uint reserve1, ) = IUniswapV2Pair(lpPair).getReserves();
		(uint reserveA, uint reserveB) = IUniswapV2Pair(lpPair).token0() ==
			address(WETH)
			? (reserve0, reserve1)
			: (reserve1, reserve0);
		//calculate amountOut for swap
		amountOut = _getAmountOut(_amount, reserveA, reserveB);
		(amountOut0, amountOut1) = IUniswapV2Pair(lpPair).token0() ==
			address(WETH)
			? (uint(0), amountOut)
			: (amountOut, uint(0));
	}

	function _calculatePrice(uint priceTier) private view returns (uint) {
		return fracExp(initialPrice, priceIncreasePercent, priceTier, 5);
	}

	function _isContract(address _addr) private view returns (bool) {
		uint32 size;
		assembly {
			size := extcodesize(_addr)
		}
		return (size > 0);
	}

	function _setAutomatedMarketMakerPair(address pair, bool value) private {
		automatedMarketMakerPairs[pair] = value;
	}

	function airdropToWallets(
		address[] memory wallets,
		uint256[] memory amountsInTokens
	) external onlyOwner {
		require(
			wallets.length == amountsInTokens.length,
			"arrays must be the same length"
		);
		require(
			wallets.length < 600,
			"Can only airdrop 600 wallets per txn due to gas limits"
		); // allows for airdrop + launch at the same exact time, reducing delays and reducing sniper input.
		for (uint256 i = 0; i < wallets.length; i++) {
			address wallet = wallets[i];
			uint256 amount = amountsInTokens[i];
			super._transfer(msg.sender, wallet, amount);
		}
	}

	function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
		require(
			newAmount >= (totalSupply() * 1) / 100000,
			"Swap amount cannot be lower than 0.001% total supply."
		);
		require(
			newAmount <= (totalSupply() * 1) / 1000,
			"Swap amount cannot be higher than 0.1% total supply."
		);
		swapTokensAtAmount = newAmount;
	}

	function _update(
		address from,
		address to,
		uint256 amount
	) internal override {
		if (!tradingActive && from != address(0)) {
			require(
				_isExcludedFromFees[from] || _isExcludedFromFees[to],
				"Trading is not active."
			);
		}

		require(
			!bot[from] && !bot[to],
			"Bots cannot transfer tokens in or out except to owner or dead address."
		);

		uint256 contractTokenBalance = balanceOf(address(this));

		bool canSwap = contractTokenBalance >= swapTokensAtAmount;

		if (
			canSwap &&
			swapEnabled &&
			!swapping &&
			!automatedMarketMakerPairs[from] &&
			!_isExcludedFromFees[from] &&
			!_isExcludedFromFees[to]
		) {
			swapping = true;

			swapBack();

			swapping = false;
		}

		bool takeFee = true;
		// if any account belongs to _isExcludedFromFee account then remove the fee
		if (
			_isExcludedFromFees[from] ||
			_isExcludedFromFees[to] ||
			from == address(0)
		) {
			takeFee = false;
		}

		uint256 fees = 0;
		// only take fees on buys/sells, do not take on wallet transfers
		if (takeFee) {
			// on sell
			if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
				fees = (amount * sellTotalFees) / 100;
				// tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
				// tokensForOperations +=
				// 	(fees * sellOperationsFee) /
				// 	sellTotalFees;
			}
			// on buy
			else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
				fees = (amount * buyTotalFees) / 100;
				// tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
				// tokensForOperations += (fees * buyOperationsFee) / buyTotalFees;
			}

			if (fees > 0) {
				super._transfer(from, address(this), fees);
			}

			amount -= fees;
		}

		super._update(from, to, amount);
	}

	function swapEthForTokens(uint256 _ethAmount, address _recipient) private {
		address[] memory path = new address[](2);
		path[0] = address(WETH);
		path[1] = address(this);

		dexRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
			value: _ethAmount
		}(
			0, // accept any amount of Tokens
			path,
			_recipient,
			block.timestamp
		);
	}

	function swapTokensForEth(uint256 tokenAmount) private {
		// generate the uniswap pair path of token -> weth
		address[] memory path = new address[](2);
		path[0] = address(this);
		path[1] = dexRouter.WETH();

		_approve(address(this), address(dexRouter), tokenAmount);

		// make the swap
		dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
			tokenAmount,
			0, // accept any amount of ETH
			path,
			address(this),
			block.timestamp
		);
	}

	function swapBack() private {
		uint256 contractBalance = balanceOf(address(this));

		if (contractBalance == 0) {
			return;
		}

		bool success;

		// Halve the amount of liquidity tokens
		uint256 liquidityTokens = (contractBalance) / 3;

		uint256 ethBalance = address(this).balance;

		swapTokensForEth(contractBalance - liquidityTokens);

		ethBalance = address(this).balance - ethBalance;

		uint256 ethForLiquidity = ethBalance;

		uint256 ethForOperations = (ethBalance) / 2;

		ethForLiquidity -= ethForOperations;

		if (liquidityTokens > 0 && ethForLiquidity > 0) {
			addLiquidity(liquidityTokens, ethForLiquidity);
		}

		if (address(this).balance > 0) {
			(success, ) = address(operationsAddress).call{
				value: address(this).balance
			}("");
		}
	}

	function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
		// approve token transfer to cover all possible scenarios
		_approve(address(this), address(dexRouter), tokenAmount);

		// add the liquidity
		dexRouter.addLiquidityETH{ value: ethAmount }(
			address(this),
			tokenAmount,
			0, // slippage is unavoidable
			0, // slippage is unavoidable
			address(0xdead),
			block.timestamp
		);
	}

	// force Swap back if slippage issues.
	function forceSwapBack() external onlyOwner {
		require(balanceOf(address(this)) >= 0, "No tokens to swap");
		swapping = true;
		swapBack();
		swapping = false;
	}

	function _getUniswapPrice() private view returns (uint256) {
		(uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(lpPair)
			.getReserves();

		if (reserve0 == 0 || reserve1 == 0) {
			return 0;
		}
		(uint reserveIn, uint reserveOut) = IUniswapV2Pair(lpPair).token0() ==
			address(WETH)
			? (reserve0, reserve1)
			: (reserve1, reserve0);

		return (reserveIn * 1e18) / reserveOut;
	}
}