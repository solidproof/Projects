// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * UniSwap interface packages for reading and integration with DEX and SWAP
*/
interface IFactoryV2 {
    event PairCreated(address indexed token0, address indexed token1, address lpPair, uint);
    function getPair(address tokenA, address tokenB) external view returns (address lpPair);
    function createPair(address tokenA, address tokenB) external returns (address lpPair);
}

interface IV2Pair {
    function factory() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function sync() external;
}

interface IRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
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
    function swapExactETHForTokens(
        uint amountOutMin, 
        address[] calldata path, 
        address to, uint deadline
    ) external payable returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IRouter02 is IRouter01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
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
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

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
}

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting sender `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
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
    address public _owner;

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

/**
 * @dev Standard ERC20 Errors
 * Interface of the ERC6093 custom errors for ERC20 tokens
 * as defined in https://eips.ethereum.org/EIPS/eip-6093
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
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
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
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
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

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        if (nonceAfter != nonceBefore + 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors, ReentrancyGuard {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error ERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
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
        return _decimals;
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
    function transfer(address to, uint256 value) public virtual nonReentrant returns (bool) {
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
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `requestedDecrease`.
     *
     * NOTE: Although this function is designed to avoid double spending with {approval},
     * it can still be frontrunned, preventing any attempt of allowance reduction.
     */
    function decreaseAllowance(address spender, uint256 requestedDecrease) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < requestedDecrease) {
            revert ERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
        }
        unchecked {
            _approve(owner, spender, currentAllowance - requestedDecrease);
        }

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
    function _transfer(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from` (or `to`) is
     * the zero address. All customizations to transfers, mints, and burns should be done by overriding this function.
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
     * @dev Destroys a `value` amount of tokens from `account`, by transferring it to address(0).
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
     */
    function _approve(address owner, address spender, uint256 value) internal virtual {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Alternative version of {_approve} with an optional flag that can enable or disable the Approval event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to true
     * using the following override:
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
     * Might emit an {Approval} event.
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

interface INFTDividend {
    function notifyTransfer(uint256 amount) external;
}

contract SmartContToken is Context, ERC20, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address;

    //Manages and stores user balances
    mapping(address => uint256) private _balance;

    //Include or WhiteList to fee
    mapping(address => bool) private _isWhiteList;

    //Wallets of Fee transactions
    address public dividendAddress;
    address public developmentAddress;
    address public marketAddress;
    address public listingAddress;
    address private bnbAddress;

    //Constant fee of transactions
    uint256 private dividendFee_;
    uint256 private developmentFee_;
    uint256 private marketingFee_;
    uint256 private listingFee_;

    //Buy Fee List
    struct BuyFee {
        uint256 Dividend_Fee;
        uint256 Development_Fee;
        uint256 Marketing_Fee;
        uint256 Listing_Fee;
        bool exist;
    }
    mapping(uint256 => BuyFee) private buyItems;

    //Sell Fee List
    struct SellFee {
        uint256 Dividend_Fee;
        uint256 Development_Fee;
        uint256 Marketing_Fee;
        uint256 Listing_Fee;
        bool exist;
    }
    mapping(uint256 => SellFee) private sellItems;

    //Token Informations and Supply
    string private constant NAME = "Vitra Studios";
    string private constant SYMBOL = "VITRA";
    uint8 private constant DECIMALS = 18;

    uint256 private constant DECIMALFACTOR = 10 ** uint256(18);
    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _totalSupply = 185 * 10**6 * DECIMALFACTOR;

    //Totals of acumulation of fee
    uint256 private _tokenFeeTotal;
    uint256 private _tokenDividendTotal;
    uint256 private _tokenDevelopmentTotal;
    uint256 private _tokenMarketingTotal;
    uint256 private _tokenListingTotal;
    uint256 private _maxSwapAmount;

    bool private _inTransfer;
    bool private _inSwapTransact;
    bool public is_dividend = false;
    bool public swapAndTransferFeeEnabled = false;

    modifier lockTheSwap() {
        _inSwapTransact = true;
        _;
        _inSwapTransact = false;
    }

    // @dev what pairs are allowed to work in the token
    mapping(address => bool) private automatedMarketMakerPairs;

    address private _Swap_Route;
    IRouter02 public tokenSwapRoute;
    address public tokenSwapPair;
    IV2Pair internal tokenReserv;

    constructor(
        address _DividendAddr,
        address _MarketingAddr,
        address _DevelopmentAddr,
        address _ListingAddr,
        address Swap_Route_
    ) ERC20(NAME, SYMBOL, DECIMALS) Ownable(msg.sender) {
        dividendAddress = _DividendAddr;
        marketAddress = _MarketingAddr;
        listingAddress = _DevelopmentAddr;
        developmentAddress = _ListingAddr;

        /* Create a Pancakeswap pair for this new token */
        _Swap_Route = Swap_Route_;
        IRouter02 _tokenSwapRoute = IRouter02(Swap_Route_);
        tokenSwapPair = IFactoryV2(_tokenSwapRoute.factory())
            .createPair(address(this), _tokenSwapRoute.WETH());
        tokenSwapRoute = _tokenSwapRoute;
        bnbAddress = _tokenSwapRoute.WETH();
        tokenReserv = IV2Pair(tokenSwapPair);
        _approve(msg.sender, address(Swap_Route_), type(uint256).max);
        _approve(address(this), address(Swap_Route_), type(uint256).max);

        /* Set the rest of the contract variables */
        _setAutomatedMarketMakerPair(tokenSwapPair, true);
        _isWhiteList[address(this)] = true;
        _isWhiteList[msg.sender] = true;

        _balance[msg.sender] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balance[account];
    }

    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }

    function decimalFactor() public pure returns (uint256) {
        return DECIMALFACTOR;
    }

    function totalBalance() external view returns (uint256) {
        return payable(address(this)).balance;
    }

    /*
     *get Max Amount to swap fee
     */
    function getMaxSwapAmount() external view returns (uint256) {
        return _maxSwapAmount;
    }

    /*
     *get getBuyFeeDetails
     */
    function getBuyFee()
        public
        view
        returns (
            uint256 dividendFee,
            uint256 developmentFee,
            uint256 marketingFee,
            uint256 listingFee
        )
    {
        return (
            buyItems[0].Dividend_Fee,
            buyItems[0].Development_Fee,
            buyItems[0].Marketing_Fee,
            buyItems[0].Listing_Fee
        );
    }

    /*
     *get getBuyFeeDetails
     */
    function getSellFee()
        public
        view
        returns (
            uint256 dividendFee,
            uint256 developmentFee,
            uint256 marketingFee,
            uint256 listingFee
        )
    {
        return (
            buyItems[0].Dividend_Fee,
            buyItems[0].Development_Fee,
            sellItems[0].Marketing_Fee,
            sellItems[0].Listing_Fee
        );
    }

    function totalFees() public view returns (uint256) {
        return _tokenFeeTotal;
    }

    function totalDividend() public view returns (uint256) {
        return _tokenDividendTotal;
    }

    function totalDevelopment() public view returns (uint256) {
        return _tokenDevelopmentTotal;
    }

    function totalMarketing() public view returns (uint256) {
        return _tokenMarketingTotal;
    }

    function totalListing() public view returns (uint256) {
        return _tokenListingTotal;
    }

    function isIncludedToWhiteList(address account) public view returns (bool) {
        return _isWhiteList[account];
    }

    /**
     * @dev Enables the contract to receive BNB.
     */
    receive() external payable {}
    fallback() external payable {}

    /* Internal Transfer function of Token */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "ERC20: transfer sender the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        uint256 tokenAmount = 0;

        if (
            // is Buy transaction
            automatedMarketMakerPairs[sender] &&
            !automatedMarketMakerPairs[recipient]
        ) {
            dividendFee_ = buyItems[0].Dividend_Fee;
            developmentFee_ = buyItems[0].Development_Fee;
            marketingFee_ = buyItems[0].Marketing_Fee;
            listingFee_ = buyItems[0].Listing_Fee;
        } else if (
            // is Sell transaction
            !automatedMarketMakerPairs[sender] &&
            automatedMarketMakerPairs[recipient]
        ) {
            dividendFee_ = sellItems[0].Dividend_Fee;
            developmentFee_ = sellItems[0].Development_Fee;
            marketingFee_ = sellItems[0].Marketing_Fee;
            listingFee_ = sellItems[0].Listing_Fee;
        }

        if (
            !automatedMarketMakerPairs[sender] && !automatedMarketMakerPairs[recipient] ||
            _isWhiteList[sender] || _inSwapTransact
        ) {
            _removeAllFee();
        }

        uint256 tokenTransferAmount = _executeFeeTransfer(sender, amount);

        if (
            !automatedMarketMakerPairs[sender] &&
            !_inSwapTransact &&
            swapAndTransferFeeEnabled
        ) {
            tokenAmount = balanceOf(address(this));
            if(tokenAmount > _maxSwapAmount){
                _swapAndTransferFee(tokenAmount);
                dividendFee_ = sellItems[0].Dividend_Fee;
                developmentFee_ = sellItems[0].Development_Fee;
                marketingFee_ = sellItems[0].Marketing_Fee;
                listingFee_ = sellItems[0].Listing_Fee;
            }
        }

        if (!_inTransfer) {
            _inTransfer = true;
            _balance[sender] -= amount;
            _balance[recipient] += tokenTransferAmount;
            _removeAllFee();
            _inTransfer = false;
        }

        emit Transfer(sender, recipient, amount);
    }

    function _executeFeeTransfer(address sender, uint256 tokenAmount) private returns(uint256) {
        (uint256 tokenDividend, uint256 tokenDevelopment, uint256 tokenMarketing, uint256 tokenListing) = _getTransferFee(tokenAmount);
        uint256 transferAmount = _getTransferAmount(tokenAmount,tokenDividend, tokenDevelopment, tokenMarketing, tokenListing);
        if (tokenDividend > 0) {
            _tokenDividendTotal += tokenDividend;
            _sendFeeTransfer(sender, dividendAddress, tokenDividend);
            if(is_dividend){
                INFTDividend(dividendAddress).notifyTransfer(tokenDividend);
            }
        }
        if (tokenDevelopment > 0) {
            _tokenDevelopmentTotal += tokenDevelopment;
            _sendFeeTransfer(sender, developmentAddress, tokenDevelopment);
        }
        if (tokenMarketing > 0) {
            _tokenMarketingTotal += tokenMarketing;
            _sendFeeTransfer(sender, marketAddress, tokenMarketing);
        }
        if (tokenListing > 0){
            _tokenListingTotal += tokenListing;
            _sendFeeTransfer(sender, listingAddress, tokenListing);
        }
        _tokenFeeTotal = _tokenFeeTotal.add(tokenDividend).add(tokenDevelopment).add(tokenMarketing).add(tokenListing);
        emit FeeTransaction(tokenDividend, tokenDevelopment, tokenMarketing, tokenListing);
        return transferAmount;
    }

    function _sendFeeTransfer(address sender, address feeAddress, uint256 feeAmount) private {
        address _feeAddress = address(this);
        if(!swapAndTransferFeeEnabled){
            _feeAddress = feeAddress;
        }
        
        _balance[_feeAddress] += feeAmount;
        emit Transfer(sender, _feeAddress, feeAmount);
    }

    function _getTransferFee(uint256 tokenAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tokenDividend = tokenAmount.mul(dividendFee_).div(100);
        uint256 tokenDevelopment = tokenAmount.mul(developmentFee_).div(100);
        uint256 tokenMarketing = tokenAmount.mul(marketingFee_).div(100);
        uint256 tokenListing = tokenAmount.mul(listingFee_).div(100);
        return (tokenDividend, tokenDevelopment, tokenMarketing, tokenListing);
    }

    function _getTransferAmount(
        uint256 tokenAmount,
        uint256 tokenDividend,
        uint256 tokenDevelopment,
        uint256 tokenMarketing,
        uint256 tokenListing
        ) private pure
        returns (
            uint256
        )
    {
        uint256 tokenTransferAmount = tokenAmount.sub(tokenDividend).sub(tokenDevelopment).sub(tokenMarketing).sub(tokenListing);
        return (tokenTransferAmount);
    }

    /*
     *Internal Function to swap Tokens and add to Marketing
     */
    function _swapAndTransferFee(uint256 tokenAmount) private lockTheSwap {
        /* Generate the Pancakeswap pair path of token -> wbnb */
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = tokenSwapRoute.WETH();

        /* Swap tokens for BNB */
        _approve(msg.sender, address(_Swap_Route), type(uint256).max);

        /* Make the swap */
        tokenSwapRoute.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );

        /* Send BNB to Wallets Fee */
        uint256 withAmount = (address(this).balance).div(3);
        _sendFeeBNB(developmentAddress, withAmount);
        _sendFeeBNB(marketAddress, withAmount);
        _sendFeeBNB(listingAddress, withAmount);
    }

    function _sendFeeBNB(address recipient, uint256 withAmount) private {
        // prevent re-entrancy attacks
        (bool tmpSuccess,) =  payable(recipient).call{value: withAmount, gas: 30000}("");
        tmpSuccess = false;

        emit sendWhitedrawFee(recipient, withAmount);
    }

    function _removeAllFee() private {
        if (
            dividendFee_ == 0 && developmentFee_ == 0 && marketingFee_ == 0 && listingFee_ == 0
        ) return;
        dividendFee_ = 0;
        developmentFee_ = 0;
        marketingFee_ = 0;
        listingFee_ = 0;
    }

    /* Function     : Set a new Pair Address for Update */
    /* Parameters   : New Pair Address Fee*/
    function _setAutomatedMarketMakerPair(address pair, bool isPair) private {
        automatedMarketMakerPairs[pair] = isPair;
        emit SetAutomatedMarketMakerPair(pair, isPair);
    }

    /*
     * @dev Sitem of Create/View/Update/Delete
     * @dev Management System fee Buy
     */
    function createBuyFee(
        uint256 dividendFee,
        uint256 developmentFee,
        uint256 marketingFee,
        uint256 listingFee
    ) external onlyOwner {
        require(!buyItems[0].exist, "A fee already exists, created");
        require((dividendFee.add(developmentFee).add(marketingFee).add(listingFee)) <= 15, "Total fees should not be more than 15%.");
        uint256 _buyId = 0;
        buyItems[_buyId].Dividend_Fee = dividendFee;
        buyItems[_buyId].Development_Fee = developmentFee;
        buyItems[_buyId].Marketing_Fee = marketingFee;
        buyItems[_buyId].Listing_Fee = listingFee;
        buyItems[_buyId].exist = true;
    }

    function updateBuyFee(
        uint256 dividendFee,
        uint256 developmentFee,
        uint256 marketingFee,
        uint256 listingFee
    ) external onlyOwner {
        require((dividendFee.add(developmentFee).add(marketingFee).add(listingFee)) <= 15, "Total fees should not be more than 15%.");
        buyItems[0].Dividend_Fee = dividendFee;
        buyItems[0].Development_Fee = developmentFee;
        buyItems[0].Marketing_Fee = marketingFee;
        buyItems[0].Listing_Fee = listingFee;
    }

    function updateMaxSwapAmount(uint256 maxSwapAmount) external onlyOwner {
        _maxSwapAmount = maxSwapAmount;
    }

    /*
     * @dev Sitem of Create/View/Update/Delete
     * @dev Management System fee Sell
     */
    function createSellFee(
        uint256 dividendFee,
        uint256 developmentFee,
        uint256 marketingFee,
        uint256 listingFee
    ) external onlyOwner {
        require(!sellItems[0].exist, "A fee already exists, created");
        require((dividendFee.add(developmentFee).add(marketingFee).add(listingFee)) <= 15, "Total fees should not be more than 15%.");
        uint256 _sellId = 0;
        sellItems[_sellId].Dividend_Fee = dividendFee;
        sellItems[_sellId].Development_Fee = developmentFee;
        sellItems[_sellId].Marketing_Fee = marketingFee;
        sellItems[_sellId].Listing_Fee = listingFee;
        sellItems[_sellId].exist = true;
    }

    function updateSellFee(
        uint256 dividendFee,
        uint256 developmentFee,
        uint256 marketingFee,
        uint256 listingFee
    ) external onlyOwner {
        require((dividendFee.add(developmentFee).add(marketingFee).add(listingFee)) <= 15, "Total fees should not be more than 15%.");
        sellItems[0].Dividend_Fee = dividendFee;
        sellItems[0].Development_Fee = developmentFee;
        sellItems[0].Marketing_Fee = marketingFee;
        sellItems[0].Listing_Fee = listingFee;
    }

    /*
     * @dev Manually performs cumulative fee conversions.
     */
    function executeAutoTransferFee(uint256 amountToken) external onlyOwner {
        require(
            amountToken <= balanceOf(address(this)),
            "Insufficient balance for this transaction."
        );
        _swapAndTransferFee(amountToken);
    }

    /* Function     : Set a new router if released */
    /* Parameters   : New router Address */
    function setRouterAddress(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Should not be address 0");
        IRouter02 _tokenSwapRoute = IRouter02(newRouter);
        /* Create a Pancakeswap pair for this new token */
        tokenSwapPair = IFactoryV2(_tokenSwapRoute.factory())
            .createPair(address(this), _tokenSwapRoute.WETH());
        /* Set the rest of the contract variables */
        tokenSwapRoute = _tokenSwapRoute;
        _setAutomatedMarketMakerPair(tokenSwapPair, true);
        emit SetRouterAddressEvent(newRouter);
    }

    /* Function     : Set a new Fee address for Update */
    /* Parameters   : New Address */
    function setDividendAdress(address dividendAddress_) external onlyOwner {
        require(dividendAddress_ != address(0), "ERC20: It is not a valid address");
        require(dividendAddress_ != dividendAddress, "This is the same dividend address.");
        dividendAddress = dividendAddress_;
        emit UpdateAddressFee(dividendAddress_);
    }

    /* Function     : Set a new Fee address for Update */
    /* Parameters   : New Address */
    function setDevelopmentAdress(address developmentAddress_) external onlyOwner {
        require(developmentAddress_ != address(0), "ERC20: It is not a valid address");
        require(developmentAddress_ != developmentAddress, "This is the same development address.");
        developmentAddress = developmentAddress_;
        emit UpdateAddressFee(developmentAddress_);
    }

    /* Function     : Set a new Fee address for Update */
    /* Parameters   : New Address */
    function setMarketingAdress(address marketingAddress_) external onlyOwner {
        require(marketingAddress_ != address(0), "ERC20: It is not a valid address");
        require(marketingAddress_ != marketAddress, "This is the same marketing address.");
        marketAddress = marketingAddress_;
        emit UpdateAddressFee(marketingAddress_);
    }

    /* Function     : Set a new Fee address for Update */
    /* Parameters   : New Address */
    function setListingAdress(address listingAddress_) external onlyOwner {
        require(listingAddress_ != address(0), "ERC20: It is not a valid address");
        require(listingAddress_ != listingAddress, "This is the same listing address.");
        listingAddress = listingAddress_;
        emit UpdateAddressFee(listingAddress_);
    }

    /* Function     : Turns ON/OFF Marketing swap */
    /* Parameters   : Set 'true' to turn ON and 'false' to turn OFF */
    function setSwapAndTransferFeeEnabled() external onlyOwner {
        swapAndTransferFeeEnabled ? swapAndTransferFeeEnabled = false
        : swapAndTransferFeeEnabled = true;
        emit SwapEnabledUpdated(swapAndTransferFeeEnabled);
    }

    /* Function     : Turns ON/OFF Dividend Fee */
    /* Parameters   : Set 'true' to turn ON and 'false' to turn OFF */
    function setIs_dividend() external onlyOwner {
        is_dividend ? is_dividend = false
        : is_dividend = true;
    }

    /* Function     : Turns ON/OFF User for WhiteList */
    /* Parameters   : Set 'true' to turn ON and 'false' to turn OFF */
    function setWhiteList(address account) external onlyOwner {
        _isWhiteList[account] ? _isWhiteList[account] = false
        : _isWhiteList[account] = true;
        emit UserWhiteList(_isWhiteList[account]);
    }

    /*
     * @dev Function created to recover funds sent in error
     */
    function rescueBalanceBNB() external onlyOwner returns (bool) {
        require(
            this.totalBalance() > 0,
            "You do not have enough balance for this withdrawal"
        );
        payable(_owner).transfer(this.totalBalance());

        emit Transfer(address(this), _owner, this.totalBalance());
        return true;
    }

    /*
     * @dev Function created to recover funds sent by mistake or 
     * remove suspicious tokens sent as spam
     */
    function rescueBalanceTokens(address _contractAdd) external onlyOwner returns (bool) {
        IERC20 ContractAdd = IERC20(_contractAdd);
        uint256 dexBalance = ContractAdd.balanceOf(address(this));
        require(
            dexBalance > 0,
            "You do not have enough balance for this withdrawal"
        );
        ContractAdd.transfer(_owner, dexBalance);

        emit Transfer(address(this), _owner, dexBalance);
        return true;
    }

    event UserWhiteList(bool enabled);
    event SwapEnabledUpdated(bool enabled);
    event UpdateAddressFee(address Address);
    event SetRouterAddressEvent(address Address);
    event FeeTransaction(uint256 tDividend, uint256 tDevelopment,  uint256 tMarketing, uint256 tListing);
    event sendWhitedrawFee(address beneficiary, uint256 value);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
}
