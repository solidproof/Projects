/**
 *Submitted for verification at BscScan.com on 2022-02-18
*/

// File: contracts\libs\ReentrancyGuard.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// File: contracts\libs\IERC20.sol

pragma solidity >=0.4.0;

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the erc20 token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
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
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}

// File: contracts\libs\SafeMath.sol

pragma solidity ^0.8.0;

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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: contracts\libs\Address.sol

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// File: contracts\libs\SafeERC20.sol

pragma solidity ^0.8.0;




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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(
            value,
            "SafeERC20: decreased allowance below zero"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: contracts\libs\IUniswapAmm.sol

pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

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

// File: contracts\libs\Context.sol

pragma solidity ^0.8.0;

/*
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
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: contracts\libs\Ownable.sol

pragma solidity ^0.8.0;


abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: contracts\libs\ERC20.sol

pragma solidity ^0.8.0;





/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-ERC20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory tokenName, string memory tokenSymbol) {
        _name = tokenName;
        _symbol = tokenSymbol;
        _decimals = 18;
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external override view returns (address) {
        return owner();
    }

    /**
     * @dev Returns the token name.
     */
    function name() public override view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the token decimals.
     */
    function decimals() public override view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the token symbol.
     */
    function symbol() public override view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {ERC20-totalSupply}.
     */
    function totalSupply() public virtual override view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {ERC20-balanceOf}.
     */
    function balanceOf(address account) public virtual override view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {ERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {ERC20-allowance}.
     */
    function allowance(address owner, address spender) public override view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {ERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {ERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance")
        );
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {ERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {ERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero")
        );
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See {_burn} and {_approve}.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(
            account,
            _msgSender(),
            _allowances[account][_msgSender()].sub(amount, "ERC20: burn amount exceeds allowance")
        );
    }
}

// File: contracts\LiquidifyHelper.sol



pragma solidity ^0.8.0;





contract LiquidifyHelper is Ownable {
    using SafeMath for uint256;

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public _token0;
    address public _token1;

    IUniswapV2Router02 public _swapRouter;

    constructor() {
        _swapRouter = IUniswapV2Router02(
            address(0x10ED43C718714eb63d5aA57B78B54704E256024E)
        );
    }

    function setSwapRouter(address newSwapRouter) external onlyOwner {
        require(newSwapRouter != address(0), "Invalid swap router");
        _swapRouter = IUniswapV2Router02(newSwapRouter);
    }

    function setTokenPair(address token0, address token1) external onlyOwner {
        IERC20(token0).balanceOf(address(this));
        IERC20(token1).balanceOf(address(this));
        _token0 = token0;
        _token1 = token1;
    }

    //to recieve ETH from swapRouter when swaping
    receive() external payable {}

    function liquifyAndBurn() external onlyOwner {
        uint256 token0Amount = IERC20(_token0).balanceOf(address(this));
        uint256 token1Amount = IERC20(_token1).balanceOf(address(this));
        if (token0Amount > 0 && token1Amount > 0) {
            addLiquidityAndBurn(token0Amount, token1Amount);
        }
    }

    function addLiquidityAndBurn(uint256 token0Amount, uint256 token1Amount)
        internal
    {
        require(_token0 != address(0), "Invalid token 0");
        require(_token1 != address(0), "Invalid token 1");

        // approve token transfer to cover all possible scenarios
        IERC20(_token0).approve(address(_swapRouter), token0Amount);
        IERC20(_token1).approve(address(_swapRouter), token1Amount);

        // add the liquidity
        _swapRouter.addLiquidity(
            _token0,
            _token1,
            token0Amount,
            token1Amount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            DEAD,
            block.timestamp.add(300)
        );
    }

    function recoverToken(address tokenAddress, uint256 tokenAmount)
        external
        onlyOwner
    {
        // do not allow recovering self token
        require(tokenAddress != address(this), "Self withdraw");
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }
}

// File: contracts\HearnToken.sol



pragma solidity ^0.8.0;




contract HearnToken is ERC20("HEARN", "HEARN") {
    using SafeMath for uint256;
    using Address for address;

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = address(0);
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    uint16 public MaxLiqFee = 3000; // 30% max
    uint16 public MaxMarketingFee = 3000; // 30% max

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcludedFromAntiBot;

    uint256 public constant MAX_TX_AMOUNT_MIN_LIMIT = 1 ether;
    uint256 public constant MAX_WALLET_AMOUNT_MIN_LIMIT = 100 ether;
    uint256 public _maxTxAmount = 10000 ether;
    uint256 public _maxWalletAmount = 100000 ether;

    uint16 public _liquidityFee = 1000; // Fee for Liquidity
    uint16 public _marketingFee = 1000; // Fee for Marketing

    IUniswapV2Router02 public _swapRouter;
    address public _hearnBnbPair;
    address public _hearnBusdPair;

    address public _marketingWallet;
    address private _operator;

    bool _inSwapAndLiquify;
    bool public _swapAndLiquifyEnabled = true;

    uint256 public _numTokensSellToAddToLiquidity = 1000 ether;

    LiquidifyHelper public _liquidifyHelper;

    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event LiquifyAndBurned(
        uint256 tokensSwapped,
        uint256 busdReceived,
        uint256 tokensIntoLiqudity
    );
    event MarketingFeeTrasferred(
        address indexed marketingWallet,
        uint256 tokensSwapped,
        uint256 busdAmount
    );

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    modifier onlyOperator() {
        require(
            operator() == _msgSender(),
            "HEARN: caller is not the operator"
        );
        _;
    }

    constructor() payable {
        _marketingWallet = _msgSender();
        _operator = _msgSender();

        _swapRouter = IUniswapV2Router02(
            address(0x10ED43C718714eb63d5aA57B78B54704E256024E)
        );
        // Create a uniswap pair for this new token
        _hearnBnbPair = IUniswapV2Factory(_swapRouter.factory()).createPair(
            address(this),
            _swapRouter.WETH()
        );
        _hearnBusdPair = IUniswapV2Factory(_swapRouter.factory()).createPair(
            address(this),
            BUSD
        );

        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedFromFee[DEAD] = true;
        _isExcludedFromFee[ZERO] = true;
        _isExcludedFromFee[address(this)] = true;

        _isExcludedFromAntiBot[_msgSender()] = true;
        _isExcludedFromAntiBot[DEAD] = true;
        _isExcludedFromAntiBot[ZERO] = true;
        _isExcludedFromAntiBot[address(this)] = true;
        _isExcludedFromAntiBot[address(_swapRouter)] = true;
        _isExcludedFromAntiBot[address(_hearnBnbPair)] = true;
        _isExcludedFromAntiBot[address(_hearnBusdPair)] = true;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `to`, increasing
     * the total supply.
     *
     * Requirements
     *
     * - `msg.sender` must be the token operator
     */
    function mint(address to, uint256 amount)
        external
        onlyOperator
        returns (bool)
    {
        _mint(to, amount);
        return true;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `msg.sender`, increasing
     * the total supply.
     *
     * Requirements
     *
     * - `msg.sender` must be the token operator
     */
    function mint(uint256 amount) external onlyOperator returns (bool) {
        _mint(_msgSender(), amount);
        return true;
    }

    function operator() public view virtual returns (address) {
        return _operator;
    }

    function transferOperator(address newOperator) public virtual onlyOperator {
        require(
            newOperator != address(0),
            "HEARN: new operator is the zero address"
        );
        emit OperatorTransferred(_operator, newOperator);
        _operator = newOperator;
        // Exclude new operator from anti bot and fee
        _isExcludedFromAntiBot[_operator] = true;
        _isExcludedFromFee[_operator] = true;
    }

    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function excludeFromAntiBot(address account) external onlyOwner {
        _isExcludedFromAntiBot[account] = true;
    }

    function includeInAntiBot(address account) external onlyOwner {
        _isExcludedFromAntiBot[account] = false;
    }

    function setAntiBotConfiguration(
        uint256 maxTxAmount,
        uint256 maxWalletAmount
    ) external onlyOwner {
        require(
            maxTxAmount >= MAX_TX_AMOUNT_MIN_LIMIT,
            "Max tx amount too small"
        );
        require(
            maxWalletAmount >= MAX_WALLET_AMOUNT_MIN_LIMIT,
            "Max wallet amount too small"
        );
        _maxTxAmount = maxTxAmount;
        _maxWalletAmount = maxWalletAmount;
    }

    function setAllFeePercent(uint16 liquidityFee, uint16 marketingFee)
        external
        onlyOwner
    {
        require(liquidityFee <= MaxLiqFee, "Liquidity fee overflow");
        require(marketingFee <= MaxMarketingFee, "Buyback fee overflow");
        _liquidityFee = liquidityFee;
        _marketingFee = marketingFee;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        _swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function setMarketingWallet(address newMarketingWallet) external onlyOwner {
        require(newMarketingWallet != address(0), "ZERO ADDRESS");
        _marketingWallet = newMarketingWallet;
    }

    function setLiquidifyHelper(LiquidifyHelper newLiquidifyHelper)
        external
        onlyOwner
    {
        require(
            address(newLiquidifyHelper) != address(0),
            "Invalid liquidify helper"
        );

        // Include old liquidify helper into anti bot
        if (address(_liquidifyHelper) != address(0)) {
            _isExcludedFromAntiBot[address(_liquidifyHelper)] = false;
        }
        _liquidifyHelper = newLiquidifyHelper;
        // Exclude new liquidify helper from anti bot
        _isExcludedFromAntiBot[address(_liquidifyHelper)] = true;
    }

    function setSwapRouter(address newSwapRouter) external onlyOwner {
        require(newSwapRouter != address(0), "Invalid swap router");

        // Include old router and pairs into anti bot
        _isExcludedFromAntiBot[address(_swapRouter)] = false;
        _isExcludedFromAntiBot[address(_hearnBnbPair)] = false;
        _isExcludedFromAntiBot[address(_hearnBusdPair)] = false;

        _swapRouter = IUniswapV2Router02(newSwapRouter);
        _liquidifyHelper.setSwapRouter(newSwapRouter);

        // Create a uniswap pair for this new token
        _hearnBnbPair = IUniswapV2Factory(_swapRouter.factory()).createPair(
            address(this),
            _swapRouter.WETH()
        );
        _hearnBusdPair = IUniswapV2Factory(_swapRouter.factory()).createPair(
            address(this),
            BUSD
        );

        // Exclude new router and pairs from anti bot
        _isExcludedFromAntiBot[address(_swapRouter)] = false;
        _isExcludedFromAntiBot[address(_hearnBnbPair)] = false;
        _isExcludedFromAntiBot[address(_hearnBusdPair)] = false;
    }

    function setNumTokensSellToAddToLiquidity(
        uint256 numTokensSellToAddToLiquidity
    ) external onlyOwner {
        require(numTokensSellToAddToLiquidity > 0, "Invalid input");
        _numTokensSellToAddToLiquidity = numTokensSellToAddToLiquidity;
    }

    //to recieve ETH from swapRouter when swaping
    receive() external payable {}

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function isExcludedFromAntiBot(address account)
        external
        view
        returns (bool)
    {
        return _isExcludedFromAntiBot[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (!_isExcludedFromAntiBot[from]) {
            require(amount <= _maxTxAmount, "Too many tokens are going to transferred");
        }
        if (!_isExcludedFromAntiBot[to]) {
            require(balanceOf(to).add(amount) <= _maxWalletAmount, "Too many tokens are going to be stored in target account");
        }

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        bool tokenBeingSold = to == _hearnBnbPair || to == _hearnBusdPair;

        if (!_inSwapAndLiquify && tokenBeingSold && _swapAndLiquifyEnabled) {
            if (contractTokenBalance >= _numTokensSellToAddToLiquidity) {
                contractTokenBalance = _numTokensSellToAddToLiquidity;
                // add liquidity, send to marketing wallet
                swapAndLiquify(contractTokenBalance);
            }
        }

        // indicates if fee should be deducted from transfer
        // if any account belongs to _isExcludedFromFee account then remove the fee
        bool takeFee = !_isExcludedFromFee[from] &&
            !_isExcludedFromFee[to] &&
            tokenBeingSold;

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        //This needs to be distributed among marketing wallet and liquidity
        if (_liquidityFee == 0 && _marketingFee == 0) {
            return;
        }

        uint256 marketingBalance = contractTokenBalance.mul(_marketingFee).div(
            uint256(_marketingFee).add(_liquidityFee)
        );
        if (marketingBalance > 0) {
            contractTokenBalance = contractTokenBalance.sub(marketingBalance);
            uint256 busdAmount = swapTokensForBusd(
                marketingBalance,
                _marketingWallet
            );
            emit MarketingFeeTrasferred(
                _marketingWallet,
                marketingBalance,
                busdAmount
            );
        }

        if (contractTokenBalance > 0) {
            // split the contract balance into halves
            uint256 half = contractTokenBalance.div(2);
            uint256 otherHalf = contractTokenBalance.sub(half);

            // tokens and busd are sent to liquidify helper contract and added to liquidity to be burned
            super._transfer(
                address(this),
                address(_liquidifyHelper),
                otherHalf
            );
            // swap tokens for BUSD
            uint256 busdAmount = swapTokensForBusd(
                half,
                address(_liquidifyHelper)
            );

            // add liquidity to pancakeswap
            if (otherHalf > 0 && busdAmount > 0) {
                _liquidifyHelper.liquifyAndBurn();
                emit LiquifyAndBurned(half, busdAmount, otherHalf);
            }
        }
    }

    function swapTokensForBusd(uint256 tokenAmount, address to)
        private
        returns (uint256 busdAmount)
    {
        // generate the uniswap pair path of token -> busd
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = BUSD;

        _approve(address(this), address(_swapRouter), tokenAmount);

        // capture the contract's current BUSD balance.
        // this is so that we can capture exactly the amount of BUSD that the
        // swap creates, and not make the liquidity event include any BUSD that
        // has been manually sent to the contract
        uint256 balanceBefore = IERC20(BUSD).balanceOf(to);

        // make the swap
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BUSD
            path,
            to,
            block.timestamp.add(300)
        );

        // how much BUSD did we just swap into?
        busdAmount = IERC20(BUSD).balanceOf(to).sub(balanceBefore);
    }

    function addLiquidityAndBurn(uint256 tokenAmount, uint256 busdAmount)
        private
    {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(_swapRouter), tokenAmount);
        IERC20(BUSD).approve(address(_swapRouter), busdAmount);

        // add the liquidity
        _swapRouter.addLiquidity(
            address(this),
            BUSD,
            tokenAmount,
            busdAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            DEAD,
            block.timestamp.add(300)
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (takeFee) {
            uint256 feeAmount = amount
                .mul(uint256(_liquidityFee).add(_marketingFee))
                .div(10000);
            if (feeAmount > 0) {
                super._transfer(sender, address(this), feeAmount);
                amount = amount.sub(feeAmount);
            }
        }
        if (amount > 0) {
            super._transfer(sender, recipient, amount);
        }
    }

    function recoverToken(address tokenAddress, uint256 tokenAmount)
        public
        onlyOwner
    {
        // do not allow recovering self token
        require(tokenAddress != address(this), "Self withdraw");
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }
}

// File: contracts\StakingPool.sol



pragma solidity ^0.8.0;





contract StakingPool is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for HearnToken;

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    LiquidifyHelper public liquidifyHelper;

    // Whether a limit is set for users
    bool public hasUserLimit;

    // Whether it is initialized
    bool public isInitialized;

    IUniswapV2Router02 public swapRouter;

    // staking token allocation strategy
    uint16 public buybackPercent = 9000;
    uint16 public liquidifyPercent = 1000;

    // staking token allocation strategy when referral link used
    uint16 public referralBuybackPercent = 9000;
    uint16 public referralUplinePercent = 500;
    uint16 public referralLiquidifyPercent = 500;

    // Accrued token per share
    uint256 public accTokenPerShare;

    // The block number when CAKE mining ends.
    uint256 public bonusEndBlock;

    // The block number when CAKE mining starts.
    uint256 public startBlock;

    // The block number of the last pool update
    uint256 public lastRewardBlock;

    // The last block time when the emission value updated
    uint256 public emissionValueUpdatedAt;

    uint16 public constant MAX_DEPOSIT_FEE = 2000;
    uint256 public constant MAX_EMISSION_RATE = 10**10;

    // The deposit fee
    uint16 public depositFee;

    // The fee address
    address public feeAddress;

    // The dev address
    address public devAddress;

    // The pool limit (0 if none)
    uint256 public poolLimitPerUser;

    // CAKE tokens created per block.
    uint256 public rewardPerBlock;

    // The precision factor
    uint256 public PRECISION_FACTOR;

    // The reward token
    HearnToken public rewardToken;

    // The staked token
    IERC20 public stakedToken;

    // Total supply of staked token
    uint256 public stakedSupply;

    // Total buy back staked token amount
    uint256 public totalBuyback;

    // Total bought back reward token amount
    uint256 public totalBoughtback;

    // Total liquidified amount
    uint256 public totalLiquidify;

    // Referral commissions over the protocol
    uint256 public totalReferralCommissions;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided
        uint256 rewardDebt; // Reward debt
        address referrer; // Referrer
        uint256 referralCommissionEarned; // Earned from referral commission
        uint256 totalEarned; // All-time reward token earned
    }

    enum EmissionUpdateMode {
        MANUAL,
        AUTO
    }

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposited(address indexed user, uint256 amount);
    event EmergencyRewardWithdrawn(uint256 amount);
    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);
    event RewardPerBlockUpdated(
        EmissionUpdateMode mode,
        uint256 oldValue,
        uint256 newValue
    );
    event NewDepositFee(uint16 oldFee, uint16 newFee);
    event NewFeeAddress(address oldAddress, address newAddress);
    event NewDevAddress(address oldAddress, address newAddress);
    event NewPoolLimit(uint256 oldLimit, uint256 newLimit);
    event RewardsStop(uint256 blockNumber);

    constructor() {
        swapRouter = IUniswapV2Router02(
            address(0x10ED43C718714eb63d5aA57B78B54704E256024E)
        );
    }

    /**
     * @notice Initialize the contract
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     * @param _rewardPerBlock: reward per block (in rewardToken)
     * @param _startBlock: start block
     * @param _bonusEndBlock: end block
     * @param _poolLimitPerUser: pool limit per user in stakedToken (if any, else 0)
     * @param _depositFee: deposit fee
     * @param _feeAddress: fee address
     * @param _devAddress: dev address
     * @param _admin: admin address with ownership
     */
    function initialize(
        IERC20 _stakedToken,
        HearnToken _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        uint256 _poolLimitPerUser,
        uint16 _depositFee,
        address _feeAddress,
        address _devAddress,
        address _admin
    ) external onlyOwner {
        require(!isInitialized, "Already initialized");
        require(_feeAddress != address(0), "Invalid fee address");
        require(_devAddress != address(0), "Invalid dev address");
        uint256 rewardDecimals = uint256(_rewardToken.decimals());
        require(
            _rewardPerBlock <= MAX_EMISSION_RATE.mul(10**rewardDecimals),
            "Out of maximum emission value"
        );

        _stakedToken.balanceOf(address(this));
        _rewardToken.balanceOf(address(this));
        // require(_stakedToken != _rewardToken, "stakedToken must be different from rewardToken");
        require(_startBlock > block.number, "startBlock cannot be in the past");
        require(
            _startBlock < _bonusEndBlock,
            "startBlock must be lower than endBlock"
        );

        // Make this contract initialized
        isInitialized = true;

        stakedToken = _stakedToken;
        rewardToken = _rewardToken;

        rewardPerBlock = _rewardPerBlock;
        emissionValueUpdatedAt = block.timestamp;
        emit RewardPerBlockUpdated(
            EmissionUpdateMode.MANUAL,
            0,
            rewardPerBlock
        );

        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;

        require(_depositFee <= MAX_DEPOSIT_FEE, "Invalid deposit fee");
        depositFee = _depositFee;

        feeAddress = _feeAddress;
        devAddress = _devAddress;

        if (_poolLimitPerUser > 0) {
            hasUserLimit = true;
            poolLimitPerUser = _poolLimitPerUser;
        }

        uint256 decimalsRewardToken = uint256(rewardToken.decimals());
        require(decimalsRewardToken < 30, "Must be inferior to 30");

        PRECISION_FACTOR = uint256(10**(uint256(30).sub(decimalsRewardToken)));

        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;

        // Transfer ownership to the admin address who becomes owner of the contract
        transferOwnership(_admin);
    }

    /**
     * @notice Deposit staked tokens and collect reward tokens (if any)
     * @param _amount: amount to deposit (in staking token)
     * @param _referrer: referrer
     */
    function deposit(uint256 _amount, address _referrer) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        if (hasUserLimit) {
            require(
                _amount.add(user.amount) <= poolLimitPerUser,
                "User amount above limit"
            );
        }

        _updatePool();

        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(accTokenPerShare)
                .div(PRECISION_FACTOR)
                .sub(user.rewardDebt);
            if (pending > 0) {
                safeRewardTransfer(msg.sender, pending);
                user.totalEarned = user.totalEarned.add(pending);
            }
        }

        if (_amount > 0) {
            uint256 balanceBefore = stakedToken.balanceOf(address(this));
            stakedToken.safeTransferFrom(msg.sender, address(this), _amount);
            _amount = stakedToken.balanceOf(address(this)).sub(balanceBefore);
            uint256 feeAmount = 0;

            if (depositFee > 0) {
                feeAmount = _amount.mul(depositFee).div(10000);
                if (feeAmount > 0) {
                    stakedToken.safeTransfer(feeAddress, feeAmount);
                }
            }

            user.amount = user.amount.add(_amount).sub(feeAmount);
            stakedSupply = stakedSupply.add(_amount).sub(feeAmount);
            handleDeposits(msg.sender, _referrer, _amount);
        }

        user.rewardDebt = user.amount.mul(accTokenPerShare).div(
            PRECISION_FACTOR
        );

        emit Deposited(msg.sender, _amount);
    }

    /**
     * @notice Handle deposits to buyback tokens and liquidify, upline
     * @param _from: address which did deposit
     * @param _referrer: referrer address
     * @param _amount: deposited amount
     */
    function handleDeposits(
        address _from,
        address _referrer,
        uint256 _amount
    ) internal {
        // When there is a referrer
        UserInfo storage user = userInfo[_from];
        if (
            user.referrer != _referrer &&
            _referrer != _from &&
            _referrer != address(0)
        ) {
            user.referrer = _referrer;
        }
        if (user.referrer != address(0)) {
            uint256 uplineAmount = _amount.mul(referralUplinePercent).div(
                10000
            );
            if (uplineAmount > 0) {
                stakedToken.safeTransfer(user.referrer, uplineAmount);
                totalReferralCommissions = totalReferralCommissions.add(
                    uplineAmount
                );
                UserInfo storage referrer = userInfo[user.referrer];
                referrer.referralCommissionEarned = referrer
                    .referralCommissionEarned
                    .add(uplineAmount);
                _amount = _amount.sub(uplineAmount);
            }
        }

        if (liquidifyPercent + buybackPercent == 0) {
            return;
        }

        uint256 liquidifyAmount = _amount.mul(liquidifyPercent).div(
            liquidifyPercent + buybackPercent
        );
        uint256 halfAmount = liquidifyAmount.div(2);
        uint256 buybackAmount = _amount.sub(liquidifyAmount);

        if (halfAmount > 0) {
            stakedToken.safeTransfer(
                address(liquidifyHelper),
                liquidifyAmount.sub(halfAmount)
            );
            uint256 swappedAmount = swapStakeTokenForRewardToken(
                halfAmount,
                address(liquidifyHelper)
            );
            if (swappedAmount > 0) {
                liquidifyHelper.liquifyAndBurn();
                totalLiquidify = totalLiquidify.add(liquidifyAmount);
            }
        }

        if (buybackAmount > 0) {
            uint256 boughtBackAmount = swapStakeTokenForRewardToken(
                buybackAmount,
                DEAD
            );
            totalBuyback = totalBuyback.add(buybackAmount);
            totalBoughtback = totalBoughtback.add(boughtBackAmount);
        }
    }

    /**
     * @notice Safe reward transfer, just in case if rounding error causes pool to not have enough reward tokens.
     * @param _to receiver address
     * @param _amount amount to transfer
     */
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        if (_amount > rewardBalance) {
            rewardToken.safeTransfer(_to, rewardBalance);
        } else {
            rewardToken.safeTransfer(_to, _amount);
        }
    }

    /**
     * @notice Withdraw all reward tokens
     * @dev Only callable by owner. Needs to be for emergency.
     */
    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        require(
            startBlock > block.number || bonusEndBlock < block.number,
            "Not allowed to remove reward tokens while pool is live"
        );
        safeRewardTransfer(msg.sender, _amount);

        emit EmergencyRewardWithdrawn(_amount);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of tokens to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount)
        external
        onlyOwner
    {
        require(
            _tokenAddress != address(stakedToken),
            "Cannot be staked token"
        );
        require(
            _tokenAddress != address(rewardToken),
            "Cannot be reward token"
        );

        IERC20(_tokenAddress).safeTransfer(msg.sender, _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner
     */
    function stopReward() external onlyOwner {
        require(startBlock < block.number, "Pool has not started");
        require(block.number <= bonusEndBlock, "Pool has ended");
        bonusEndBlock = block.number;

        emit RewardsStop(block.number);
    }

    /**
     * @notice Update swap router
     * @dev Only callable by owner
     */
    function updateSwapRouter(address newSwapRouter) external onlyOwner {
        require(newSwapRouter != address(0), "Invalid swap router");
        swapRouter = IUniswapV2Router02(newSwapRouter);
        liquidifyHelper.setSwapRouter(newSwapRouter);
    }

    /**
     * @notice Update liquidify helper
     * @dev Only callable by owner
     */
    function updateLiquidifyHelper(LiquidifyHelper newLiquidifyHelper)
        external
        onlyOwner
    {
        require(
            address(newLiquidifyHelper) != address(0),
            "Invalid liquidify helper"
        );
        liquidifyHelper = newLiquidifyHelper;
    }

    /**
     * @notice Update staking token allocation percents
     * @param _buybackPercent: buyback percent
     * @param _liquidifyPercent: liquidify percent
     * @dev Only callable by owner
     */
    function updateAllocationPercents(
        uint16 _buybackPercent,
        uint16 _liquidifyPercent
    ) external onlyOwner {
        require(_buybackPercent + _liquidifyPercent == 10000, "Invalid input");
        buybackPercent = _buybackPercent;
        liquidifyPercent = _liquidifyPercent;
    }

    /**
     * @notice Update staking token allocation percents when referral link used
     * @param _buybackPercent: buyback percent
     * @param _uplinePercent: upline percent
     * @param _liquidifyPercent: liquidify percent
     * @dev Only callable by owner
     */
    function updateReferralAllocationPercents(
        uint16 _buybackPercent,
        uint16 _uplinePercent,
        uint16 _liquidifyPercent
    ) external onlyOwner {
        require(
            _buybackPercent + _liquidifyPercent + _uplinePercent == 10000,
            "Invalid input"
        );
        referralBuybackPercent = _buybackPercent;
        referralLiquidifyPercent = _liquidifyPercent;
        referralUplinePercent = _uplinePercent;
    }

    /*
     * @notice Update pool limit per user
     * @dev Only callable by owner.
     * @param _hasUserLimit: whether the limit remains forced
     * @param _poolLimitPerUser: new pool limit per user
     */
    function updatePoolLimitPerUser(
        bool _hasUserLimit,
        uint256 _poolLimitPerUser
    ) external onlyOwner {
        require(hasUserLimit, "Must be set");
        if (_hasUserLimit) {
            require(
                _poolLimitPerUser > poolLimitPerUser,
                "New limit must be higher"
            );
            emit NewPoolLimit(poolLimitPerUser, _poolLimitPerUser);
            poolLimitPerUser = _poolLimitPerUser;
        } else {
            hasUserLimit = _hasUserLimit;
            emit NewPoolLimit(poolLimitPerUser, 0);
            poolLimitPerUser = 0;
        }
    }

    /*
     * @notice Update reward per block
     * @dev Only callable by owner.
     * @param _rewardPerBlock: the reward per block
     */
    function updateRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        uint256 rewardDecimals = uint256(rewardToken.decimals());
        require(
            _rewardPerBlock <= MAX_EMISSION_RATE.mul(10**rewardDecimals),
            "Out of maximum emission value"
        );
        _updatePool();
        emit RewardPerBlockUpdated(
            EmissionUpdateMode.MANUAL,
            rewardPerBlock,
            _rewardPerBlock
        );
        rewardPerBlock = _rewardPerBlock;
        emissionValueUpdatedAt = block.timestamp;
    }

    /*
     * @notice Update deposit fee
     * @dev Only callable by owner.
     * @param _depositFee: the deposit fee
     */
    function updateDepositFee(uint16 _depositFee) external onlyOwner {
        require(_depositFee <= MAX_DEPOSIT_FEE, "Invalid deposit fee");
        emit NewDepositFee(depositFee, _depositFee);
        depositFee = _depositFee;
    }

    /*
     * @notice Update fee address
     * @dev Only callable by owner.
     * @param _feeAddress: the fee address
     */
    function updateFeeAddress(address _feeAddress) external onlyOwner {
        require(_feeAddress != address(0), "Invalid zero address");
        require(feeAddress != _feeAddress, "Same fee address already set");
        emit NewFeeAddress(feeAddress, _feeAddress);
        feeAddress = _feeAddress;
    }

    /*
     * @notice Update dev address
     * @dev Only callable by owner.
     * @param _devAddress: the dev address
     */
    function updateDevAddress(address _devAddress) external onlyOwner {
        require(_devAddress != address(0), "Invalid zero address");
        require(devAddress != _devAddress, "Same dev address already set");
        emit NewDevAddress(devAddress, _devAddress);
        devAddress = _devAddress;
    }

    /**
     * @notice It allows the admin to update start and end blocks
     * @dev This function is only callable by owner.
     * @param _startBlock: the new start block
     * @param _bonusEndBlock: the new end block
     */
    function updateStartAndEndBlocks(
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        require(
            _startBlock < _bonusEndBlock,
            "New startBlock must be lower than new endBlock"
        );
        require(
            block.number < _startBlock,
            "New startBlock must be higher than current block"
        );

        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;

        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;

        emit NewStartAndEndBlocks(_startBlock, _bonusEndBlock);
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        if (block.number > lastRewardBlock && stakedSupply != 0) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);

            uint256 currentRewardPerBlock = viewEmissionValue();
            uint256 cakeReward = multiplier.mul(currentRewardPerBlock);
            uint256 adjustedTokenPerShare = accTokenPerShare.add(
                cakeReward.mul(PRECISION_FACTOR).div(stakedSupply)
            );
            return
                user
                    .amount
                    .mul(adjustedTokenPerShare)
                    .div(PRECISION_FACTOR)
                    .sub(user.rewardDebt);
        } else {
            return
                user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR).sub(
                    user.rewardDebt
                );
        }
    }

    /**
     * @notice Emission value should be reduced by 2% every 30 days
     * @return Current emission value
     */
    function viewEmissionValue() public view returns (uint256) {
        if (block.timestamp > emissionValueUpdatedAt) {
            uint256 times = block.timestamp.sub(emissionValueUpdatedAt).div(
                30 days
            );
            if (times > 0) {
                uint256 deltaValue = rewardPerBlock.mul(2).mul(times).div(100);
                uint256 newRewardPerBlock;
                if (rewardPerBlock > deltaValue) {
                    newRewardPerBlock = rewardPerBlock.sub(deltaValue);
                } else {
                    newRewardPerBlock = rewardPerBlock.mul(2).div(100);
                }
                return newRewardPerBlock;
            }
        }
        return rewardPerBlock;
    }

    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (stakedSupply == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 currentRewardPerBlock = viewEmissionValue();
        if (currentRewardPerBlock != rewardPerBlock) {
            emit RewardPerBlockUpdated(
                EmissionUpdateMode.AUTO,
                rewardPerBlock,
                currentRewardPerBlock
            );
            rewardPerBlock = currentRewardPerBlock;
            emissionValueUpdatedAt = block.timestamp;
        }

        uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
        uint256 cakeReward = multiplier.mul(rewardPerBlock);

        rewardToken.mint(devAddress, cakeReward.div(10)); // 10% minted to dev wallet
        rewardToken.mint(cakeReward);

        accTokenPerShare = accTokenPerShare.add(
            cakeReward.mul(PRECISION_FACTOR).div(stakedSupply)
        );
        lastRewardBlock = block.number;
    }

    /*
     * @notice Return reward multiplier over the given _from to _to block.
     * @param _from: block to start
     * @param _to: block to finish
     */
    function _getMultiplier(uint256 _from, uint256 _to)
        internal
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from);
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock.sub(_from);
        }
    }

    /**
     * @notice Swap staked token to the reward amount and burn them
     * @return _outAmount
     */
    function swapStakeTokenForRewardToken(uint256 _inAmount, address _to)
        internal
        returns (uint256 _outAmount)
    {
        // generate the uniswap pair path of staked token -> reward token
        address[] memory path = new address[](2);
        path[0] = address(stakedToken);
        path[1] = address(rewardToken);

        stakedToken.approve(address(swapRouter), _inAmount);

        uint256 balanceBefore = rewardToken.balanceOf(_to);

        // make the swap
        swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _inAmount,
            0, // accept any amount of HEARN
            path,
            _to,
            block.timestamp.add(300)
        );
        _outAmount = rewardToken.balanceOf(_to).sub(balanceBefore);
    }

    /**
     * @notice Add liquidity and burn them
     */
    function addLiquidityAndBurn(
        uint256 stakedTokenAmount,
        uint256 rewardTokenAmount
    ) internal {
        // approve token transfer to cover all possible scenarios
        stakedToken.approve(address(swapRouter), stakedTokenAmount);
        rewardToken.approve(address(swapRouter), rewardTokenAmount);

        // add the liquidity
        swapRouter.addLiquidity(
            address(stakedToken),
            address(rewardToken),
            stakedTokenAmount,
            rewardTokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            DEAD,
            block.timestamp.add(300)
        );
    }

    //to recieve ETH from swapRouter when swaping
    receive() external payable {}
}