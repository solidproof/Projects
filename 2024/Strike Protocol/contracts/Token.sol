/**
 *Submitted for verification at Etherscan.io on 2024-03-17
*/

// Sources flattened with hardhat v2.19.5 https://hardhat.org

// SPDX-License-Identifier: MIT

// File contracts/interfaces/IERC20.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity 0.8.24;

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
    event Approval(address indexed owner, address indexed spender, uint256 value);

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
    function allowance(address owner, address spender) external view returns (uint256);

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
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// File contracts/interfaces/IERC20Metadata.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity 0.8.24;
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


// File contracts/interfaces/IUniswapV2Router01.sol

pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}


// File contracts/interfaces/IUniswapV2Router02.sol

pragma solidity >=0.6.2;
interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


// File contracts/interfaces/draft-IERC6093.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)
pragma solidity 0.8.24;

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
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

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
     * @dev Indicates a failure with the `spender`ΓÇÖs `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

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
     * @dev Indicates a failure with the `operator`ΓÇÖs approval. Used in transfers.
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
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

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
     * @dev Indicates a failure with the `operator`ΓÇÖs approval. Used in transfers.
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


// File contracts/libraries/Context.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity 0.8.24;

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


// File contracts/libraries/ERC20.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)

pragma solidity 0.8.24;
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

    mapping(address account => mapping(address spender => uint256)) private _allowances;

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
    function allowance(address owner, address spender) public view virtual returns (uint256) {
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
    function approve(address spender, uint256 value) public virtual returns (bool) {
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
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
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
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
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
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}


// File contracts/libraries/Ownable.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity 0.8.24;
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

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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


// File contracts/TaxHelper.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity 0.8.24;
/// @title TaxHelperUniswapV2
/// @author Boka
/// @notice Contract to convert tokens to ETH and divide among tax wallets using UniswapV2
/// @dev Can be used with multiple tokens
contract TaxHelperUniswapV2 is Ownable {
    address public routerAddress;
    mapping (address => bool) public approvedTokens;

    event ApproveToken(address token, bool value);
    event RouterAddressSet(address routerAddress);
    event ConvertedToEth(address token, uint256 amount, address[] walletsWithTax, uint256[] percentages, uint256 DENOMINATOR, uint256 ethBalance);
    event SentEth(address wallet, uint256 amount);

    error TokenNotApproved(address sender);
    error ZeroAddress();

    constructor(address initialOwner, address _routerAddress)
        Ownable(initialOwner)
    {
        setRouterAddress(_routerAddress);
    }

    /// @notice Approve a token to use this contract
    /// @param token the token to approve
    /// @param value true or false
    function approveToken(address token, bool value) public onlyOwner {
        approvedTokens[token] = value;
        emit ApproveToken(token, value);
    }

    /// @notice Convert a token to ETH and divide among tax wallets
    /// @dev only approve tokens or the owner may call this function
    /// @param token the token to convert
    /// @param walletsWithTax the wallets to divide the ETH among
    /// @param percentages the percentages to divide the ETH among
    /// @param DENOMINATOR the denominator to divide the percentages by
    function convertToEthAndSend(address token, address[] memory walletsWithTax, uint256[] memory percentages, uint256 DENOMINATOR, uint256 maxThresholdSell) external {   
        if(!approvedTokens[msg.sender] && msg.sender != owner()) revert TokenNotApproved(msg.sender);
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        if(balance > maxThresholdSell) {
            balance = maxThresholdSell;
        }
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(routerAddress);
        tokenContract.approve(address(uniswapRouter), balance);
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = uniswapRouter.WETH();
        if(balance > 0) {
            uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                balance,
                0, // accept any amount of ETH
                path,
                address(this),
                block.timestamp
            ); 

            uint256 ethBalance = address(this).balance;
            emit ConvertedToEth(token, balance, walletsWithTax, percentages, DENOMINATOR, ethBalance);
            for(uint256 i = 0; i < walletsWithTax.length; ++i) {
                uint256 amountToSend = ethBalance * percentages[i] / DENOMINATOR;
                payable(walletsWithTax[i]).transfer(amountToSend);
                emit SentEth(walletsWithTax[i], amountToSend);
            }
        }
        
    } 

    /// @notice Set the router address
    /// @param _routerAddress the address of the UniswapV2Router02
    function setRouterAddress(address _routerAddress) public onlyOwner {
        if(_routerAddress == address(0)) revert ZeroAddress();
        routerAddress = _routerAddress;
        emit RouterAddressSet(_routerAddress);
    }

    /// @notice Withdraw the ETH from the contract
    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /// @notice Receive ETH
    receive() payable external {
    }
}


// File contracts/interfaces/ITaxHelper.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity 0.8.24;

interface ITaxHelper {
    function convertToEthAndSend(address token, address[] memory walletsWithTax, uint256[] memory percentages, uint256 DENOMINATOR, uint256 maxThresholdSell) external;
}


// File contracts/Token.sol

// Original license: SPDX_License_Identifier: MIT

// Website: https://strike-protocol.com/
// Twitter: https://twitter.com/StrikeProtocol1
// TG: https://t.me/StrikeProtocol

pragma solidity 0.8.24;



/// @title Token
/// @author Boka
/// @notice ERC20 token with tax functionality
contract Token is ERC20, Ownable {

    Tax[] public taxes;
    uint256 public taxLength;
    Settings public settings;

    struct Settings {
        uint256 threshold;
        uint256 maxThresholdSell;
        uint256 maxTax;
        uint256 maxTxAmount;
        uint256 minMaxTxAmount;
        uint256 maxWalletAmount;
        uint256 minMaxWalletAmount;
        bool taxEnabled;
        bool maxTxAmountEnabled;
        bool maxWalletAmountEnabled;
    }
 
    struct Fee {
        uint256 buy;
        uint256 sell;
        uint256 transfer;
    }

    struct Tax {
        string name;
        Fee fee;
        address wallet;
        bool withdrawAsGas;
    }

    uint256 public DENOMINATOR = 10000;

    uint8 internal taxReentrancy = 1;

    mapping (address => bool) public taxWhitelist;
    mapping (address => bool) public maxWalletWhitelist;
    mapping (address => bool) public maxTxWhitelist;
    mapping (address => bool) public lpTokens;
    mapping (address => bool) public taxesWithBalance;
    mapping (address => uint256) public taxBalances;
    address[] public walletsWithTax;

    address public taxHelper;

    event UpdatedTaxes(Tax[] _taxes, bool cleanWallets);
    event TaxTransferred(address indexed sender, uint256 fee, address indexed wallet, bool isBuy, bool isSell, bool isTransfer, bool withdrawAsGas);
    event TaxWithdrawn(uint256 amount, address[] walletsWithTax, uint256[] percentages);
    event SetTaxHelper(address _taxHelper);
    event SetDenominator(uint256 _denominator);
    event SetTaxWhitelist(address _address, bool _value);
    event SetLPToken(address _address, bool _value);
    event SetTaxEnabled(bool _value);
    event SetThreshold(uint256 _threshold);
    event SetMaxTxAmount(uint256 _maxTxAmount);
    event SetMaxWalletAmount(uint256 _maxWalletAmount);
    event SetMaxWalletWhitelist(address _address, bool _value);
    event SetMaxTxWhitelist(address _address, bool _value);
    event SetMaxTxEnabled(bool _value);
    event SetMaxWalletEnabled(bool _value);
    event SetMaxThresholdSell(uint256 _maxThresholdSell);

    error ExceedsMaxTax();
    error ZeroAddressWallet();
    error ZeroAddress();
    error ExceedsMaxTxAmount();
    error ExceedsMaxWalletAmount();
    error UnderMinMaxTxAmount();
    error UnderMinMaxWalletAmount();


    constructor(
        string memory name_, 
        string memory symbol_, 
        uint256 totalSupply_, 
        address initialOwner,
        uint256 _maxTax,
        uint256 _minMaxTxAmount,
        uint256 _minMaxWalletAmount
        ) payable
        ERC20(name_, symbol_)
        Ownable(initialOwner)
    {
        _mint(initialOwner, totalSupply_);
        settings.taxEnabled = false;
        settings.maxTxAmountEnabled = false;
        settings.maxWalletAmountEnabled = false;
        settings.maxTax = _maxTax;
        settings.minMaxTxAmount = _minMaxTxAmount;
        settings.minMaxWalletAmount = _minMaxWalletAmount;
    }

    /// @notice enable the maximum transaction amount
    /// @param _value true or false
    function setMaxTxEnabled(bool _value) payable public onlyOwner {
        settings.maxTxAmountEnabled = _value;
        emit SetMaxTxEnabled(_value);
    }

    /// @notice enable the maximum wallet amount
    /// @param _value true or false
    function setMaxWalletEnabled(bool _value) payable public onlyOwner {
        settings.maxWalletAmountEnabled = _value;
        emit SetMaxWalletEnabled(_value);
    }

    /// @notice set the maximum transaction amount
    /// @param _maxTxAmount the maximum transaction amount
    function setMaxTxAmount(uint256 _maxTxAmount) payable public onlyOwner {
        if(_maxTxAmount < settings.minMaxTxAmount) revert UnderMinMaxTxAmount();
        settings.maxTxAmount = _maxTxAmount;
        emit SetMaxTxAmount(_maxTxAmount);
    }

    /// @notice set the maximum wallet amount
    /// @param _maxWalletAmount the maximum wallet amount
    function setMaxWalletAmount(uint256 _maxWalletAmount) payable public onlyOwner {
        if(_maxWalletAmount < settings.minMaxWalletAmount) revert UnderMinMaxWalletAmount();
        settings.maxWalletAmount = _maxWalletAmount;
        emit SetMaxWalletAmount(_maxWalletAmount);
    }

    /// @notice set the minimum balance to trigger the tax conversion
    /// @param _threshold the minimum balance to trigger the tax conversion
    function setThreshold(uint256 _threshold) payable public onlyOwner {
        settings.threshold = _threshold;
        emit SetThreshold(_threshold);
    }

    /// @notice set the maximum sell amount when the threshold is triggered to convert the tax
    /// @param _maxThresholdSell the maximum sell amount
    function setMaxThresholdSell(uint256 _maxThresholdSell) payable public onlyOwner {
        settings.maxThresholdSell = _maxThresholdSell;
        emit SetMaxThresholdSell(_maxThresholdSell);
    }

    /// @notice set the taxEnabled flag
    /// @param _value sets the taxEnabled flag to true or false
    function setTaxEnabled(bool _value) payable public onlyOwner {
        settings.taxEnabled = _value;
        emit SetTaxEnabled(_value);
    }

    /// @notice set the maxWalletWhitelist flag
    /// @param _address the address to adjust the maxWalletWhitelist
    /// @param _value true or false
    function setMaxWalletWhitelist(address _address, bool _value) payable public onlyOwner {
        maxWalletWhitelist[_address] = _value;
        emit SetMaxWalletWhitelist(_address, _value);
    }

    /// @notice set the maxTxWhitelist flag
    /// @param _address the address to adjust the maxTxWhitelist
    /// @param _value true or false
    function setMaxTxWhitelist(address _address, bool _value) payable public onlyOwner {
        maxTxWhitelist[_address] = _value;
        emit SetMaxTxWhitelist(_address, _value);
    }

    /// @notice set the taxWhitelist flag
    /// @param _address the address to adjust the taxWhitelist
    /// @param _value true or false 
    function setTaxWhitelist(address _address, bool _value) payable public onlyOwner {
        taxWhitelist[_address] = _value;
        emit SetTaxWhitelist(_address, _value);
    }

    /// @notice set whether an LP token is used to trigger the tax
    /// @param _address the address of the LP token
    /// @param _value true or false
    function setLPToken(address _address, bool _value) payable public onlyOwner {
        if(_address == address(0)) revert ZeroAddress();
        lpTokens[_address] = _value;
        emit SetLPToken(_address, _value);
    }

    /// @notice set the taxHelper address
    /// @param _taxHelper the address of the taxHelper contract
    function setTaxHelper(address _taxHelper) payable public onlyOwner {
        if(_taxHelper == address(0)) revert ZeroAddress();
        taxHelper = _taxHelper;
        emit SetTaxHelper(_taxHelper);
    }

    /// @notice set the denominator to use for the tax calculation
    /// @param _denominator the denominator to use for the tax calculation
    function setDenominator(uint256 _denominator) payable public onlyOwner {
        DENOMINATOR = _denominator;
        emit SetDenominator(_denominator);
    }

    /// @notice update the taxes for the token
    /// @dev if cleanWallets is true, the tax balances will be converted to ETH. This is useful if the taxes are updated and have different wallet addresses
    /// @param _taxes the new taxes to apply
    /// @param cleanWallets if true, the tax balances will be converted to ETH
    function updateTaxes(Tax[] calldata _taxes, bool cleanWallets) payable public onlyOwner {
        if(cleanWallets) {
            _convertTaxToEth();
        }
        delete taxes;

        uint256 totalTaxBuy;
        uint256 totalTaxSell;
        uint256 totalTaxTransfer;
        for(uint i = 0; i < _taxes.length; ++i) {
            if(_taxes[i].wallet == address(0)) revert ZeroAddressWallet();
            taxes.push(_taxes[i]);
            totalTaxBuy += _taxes[i].fee.buy;
            totalTaxSell += _taxes[i].fee.sell;
            totalTaxTransfer += _taxes[i].fee.transfer;
        }
        taxLength = _taxes.length;
        if(totalTaxBuy > settings.maxTax || totalTaxSell > settings.maxTax || totalTaxTransfer > settings.maxTax) {
            revert ExceedsMaxTax();
        }

        emit UpdatedTaxes(_taxes, cleanWallets);
    }

    /// @notice check the maximum transaction amount
    /// @param from the address the tokens are being transferred from
    /// @param to the address the tokens are being transferred to
    /// @param value the amount of tokens being transferred
    /// @param isBuy true if the transaction is a buy
    /// @param isSell true if the transaction is a sell
    function checkMaxTxAmount(address from, address to, uint256 value, bool isBuy, bool isSell) internal view {
        if(settings.maxTxAmountEnabled == false) {
            return;
        }
        if(isBuy) {
            if(maxTxWhitelist[to]) {
                return;
            }
        }
        if(isSell) {
            if(maxTxWhitelist[from]) {
                return;
            }
        }
        if(!isSell && !isBuy) {
            return;
        }
        if(value > settings.maxTxAmount) {
            revert ExceedsMaxTxAmount();
        }
    }

    /// @notice check the maximum wallet amount
    /// @param to the address the tokens are being transferred to
    /// @param value the amount of tokens being transferred
    function checkMaxWalletAmount(address to, uint256 value) internal view {
        if(settings.maxWalletAmountEnabled == false) {
            return;
        }
        if(maxWalletWhitelist[to]) {
            return;
        }
        if(balanceOf(to) + value > settings.maxWalletAmount) {
            revert ExceedsMaxWalletAmount();
        }
    }

    /// @notice handle the tax for a transfer
    /// @dev if the transaction is a sell, the tax will be converted to ETH if the taxHelper balance is above the threshold
    /// @param from the address the tokens are being transferred from
    /// @param to the address the tokens are being transferred to
    /// @param value the amount of tokens being transferred
    /// @return totalFeeAmount the total fee amount
    function handleTax(address from, address to, uint256 value) internal returns (uint256) {

        bool isBuy = false;
        bool isSell = false;
        bool isTransfer = false;

        if(lpTokens[from]) {
            isBuy = true;
        }
        if(lpTokens[to]) {
            isSell = true;
        }
        if(!isBuy && !isSell) {
            isTransfer = true;
        }

        checkMaxTxAmount(from, to, value, isBuy, isSell);
        checkMaxWalletAmount(to, value);

        if(isBuy && taxWhitelist[to]) {
            return 0;
        }

        if(isSell && taxWhitelist[from]) {
            return 0;
        }

        if(isTransfer) {
            if(taxWhitelist[from] || taxWhitelist[to]) {
                return 0;
            }
        }

        if(!settings.taxEnabled) {
            return 0;
        }

        ITaxHelper TaxHelper = ITaxHelper(taxHelper);
        if(from == address(TaxHelper) || to == address(TaxHelper)) {
            return 0;
        }

        uint256 totalFeeAmount;

        if(taxes.length > 0) {
            for(uint8 i = 0; i < taxes.length; ++i) {
                uint256 fee;
                if(isBuy) {
                    if(taxes[i].fee.buy > 0) {
                        fee = value * taxes[i].fee.buy / DENOMINATOR;
                    }
                } else if(isSell) {
                    if(taxes[i].fee.sell > 0) {
                        fee = value * taxes[i].fee.sell / DENOMINATOR;
                    }
                } else if(isTransfer) {
                    if(taxes[i].fee.transfer > 0) {
                        fee = value * taxes[i].fee.transfer / DENOMINATOR;
                    }
                } 
                totalFeeAmount += fee;
                if(fee != 0) {
                    if(!taxes[i].withdrawAsGas) {
                        _update(from, taxes[i].wallet, fee);
                        emit TaxTransferred(from, fee, taxes[i].wallet, isBuy, isSell, isTransfer, taxes[i].withdrawAsGas);
                    } else { 
                        taxBalances[taxes[i].wallet] += fee;
                        if(!taxesWithBalance[taxes[i].wallet]) {
                            walletsWithTax.push(taxes[i].wallet);
                            taxesWithBalance[taxes[i].wallet] = true;
                        }
                        _update(from, address(TaxHelper), fee);
                        emit TaxTransferred(from, fee, address(TaxHelper), isBuy, isSell, isTransfer, taxes[i].withdrawAsGas);
                    }
                } 
            }
            if(isSell && balanceOf(address(TaxHelper)) > settings.threshold ){
                _convertTaxToEth();
            }
            return totalFeeAmount;
        }    
    }

    /// @notice convert the tax balances to ETH
    /// @dev this is a manual function call to be used to convert the tax balances to ETH if necessary
    function convertTaxToEth() payable public onlyOwner {
        _convertTaxToEth();
    }

    /// @notice convert the tax balances to ETH
    function _convertTaxToEth() internal {
        ITaxHelper TaxHelper = ITaxHelper(taxHelper);
        // calculate percentages from taxHelper balance for each tax wallet
        uint256 totalBalance = balanceOf(address(TaxHelper));
        if(totalBalance > 0) {
            uint256[] memory percentages = new uint256[](walletsWithTax.length);
            for(uint i = 0; i < walletsWithTax.length; ++i) {
                // calculate percentage of totalBalance for each wallet
                uint256 balance = taxBalances[walletsWithTax[i]];
                if(balance > 0) {
                    percentages[i] = balance * DENOMINATOR / totalBalance;
                    if(totalBalance <= settings.maxThresholdSell) {
                        taxBalances[walletsWithTax[i]] = 0;
                        taxesWithBalance[walletsWithTax[i]] = false;
                    } else {
                        taxBalances[walletsWithTax[i]] = balance - (settings.maxThresholdSell * percentages[i] / DENOMINATOR);
                    }
                }
            }
            TaxHelper.convertToEthAndSend(address(this), walletsWithTax, percentages, DENOMINATOR, settings.maxThresholdSell);
            emit TaxWithdrawn(totalBalance, walletsWithTax, percentages);
            if(totalBalance <= settings.maxThresholdSell) {
                delete walletsWithTax;
            }
                
        }
    }

    /// @notice ERC20 transfer function
    /// @dev overriden to handle the tax
    /// @param to the address to transfer to
    /// @param value the amount to transfer
    /// @return true if the transfer is successful
    function transfer(address to, uint256 value) override public virtual returns (bool) {
        address owner = _msgSender();
        uint256 fee = 0;
        if(taxReentrancy == 1) {
            taxReentrancy = 2;
            fee = handleTax(owner, to, value);
            taxReentrancy = 1;
        }
        _transfer(owner, to, value - fee);
        return true;
    }

    /// @notice ERC20 transferFrom function
    /// @dev overriden to handle the tax
    /// @param from the address to transfer from
    /// @param to the address to transfer to
    /// @param value the amount to transfer
    /// @return true if the transfer is successful
    function transferFrom(address from, address to, uint256 value) override public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        uint256 fee = 0;
        if(taxReentrancy == 1) {
            taxReentrancy = 2;
            fee = handleTax(from, to, value);
            taxReentrancy = 1;
        }
        _transfer(from, to, value - fee);
        return true;
    }
}


// File contracts/interfaces/IUniswapV2Pair.sol

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
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
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}