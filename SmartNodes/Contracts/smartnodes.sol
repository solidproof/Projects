// File: interfaces/IPangolinFactory.sol

    pragma solidity >=0.5.0;

    interface IPangolinFactory {
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
    // File: interfaces/IPangolinRouter.sol

    pragma solidity >=0.6.2;

    interface IPangolinRouter {
        function factory() external pure returns (address);
        function WAVAX() external pure returns (address);

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
        function addLiquidityAVAX(
            address token,
            uint amountTokenDesired,
            uint amountTokenMin,
            uint amountAVAXMin,
            address to,
            uint deadline
        ) external payable returns (uint amountToken, uint amountAVAX, uint liquidity);
        function removeLiquidity(
            address tokenA,
            address tokenB,
            uint liquidity,
            uint amountAMin,
            uint amountBMin,
            address to,
            uint deadline
        ) external returns (uint amountA, uint amountB);
        function removeLiquidityAVAX(
            address token,
            uint liquidity,
            uint amountTokenMin,
            uint amountAVAXMin,
            address to,
            uint deadline
        ) external returns (uint amountToken, uint amountAVAX);
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
        function removeLiquidityAVAXWithPermit(
            address token,
            uint liquidity,
            uint amountTokenMin,
            uint amountAVAXMin,
            address to,
            uint deadline,
            bool approveMax, uint8 v, bytes32 r, bytes32 s
        ) external returns (uint amountToken, uint amountAVAX);
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
        function swapExactAVAXForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
            external
            payable
            returns (uint[] memory amounts);
        function swapTokensForExactAVAX(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
            external
            returns (uint[] memory amounts);
        function swapExactTokensForAVAX(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
            external
            returns (uint[] memory amounts);
        function swapAVAXForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
            external
            payable
            returns (uint[] memory amounts);

        function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
        function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
        function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
        function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
        function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);

        function removeLiquidityAVAXSupportingFeeOnTransferTokens(
            address token,
            uint liquidity,
            uint amountTokenMin,
            uint amountAVAXMin,
            address to,
            uint deadline
        ) external returns (uint amountAVAX);
        function removeLiquidityAVAXWithPermitSupportingFeeOnTransferTokens(
            address token,
            uint liquidity,
            uint amountTokenMin,
            uint amountAVAXMin,
            address to,
            uint deadline,
            bool approveMax, uint8 v, bytes32 r, bytes32 s
        ) external returns (uint amountAVAX);

        function swapExactTokensForTokensSupportingFeeOnTransferTokens(
            uint amountIn,
            uint amountOutMin,
            address[] calldata path,
            address to,
            uint deadline
        ) external;
        function swapExactAVAXForTokensSupportingFeeOnTransferTokens(
            uint amountOutMin,
            address[] calldata path,
            address to,
            uint deadline
        ) external payable;
        function swapExactTokensForAVAXSupportingFeeOnTransferTokens(
            uint amountIn,
            uint amountOutMin,
            address[] calldata path,
            address to,
            uint deadline
        ) external;
    }
    // File: interfaces/INodeManager.sol


    pragma solidity ^0.8.0;

    interface INodeManager {
        function getMinPrice() external view returns (uint256);
        function createNode(address account, string memory nodeName, uint256 amount) external;
        function getNodeReward(address account, uint256 _creationTime) external view returns (uint256);
        function getAllNodesRewards(address account) external view returns (uint256);
        function cashoutNodeReward(address account, uint256 _creationTime) external;
        function cashoutAllNodesRewards(address account) external;
        function compoundNodeReward(address account, uint256 creationTime, uint256 rewardAmount) external;
        function getNodeNumberOf(address account) external view returns (uint256);

    }

    // File: interfaces/reflections.sol
    pragma solidity ^0.8.0;

    interface reflections{
        function updateReflections(uint256 _reflections)external;
        function addNodeForReflections(address _user)external;

    }

    // OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

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
            assembly {
                size := extcodesize(account)
            }
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

            (bool success, ) = recipient.call{value: amount}("");
            require(success, "Address: unable to send value, recipient may have reverted");
        }

        /**
        * @dev Performs a Solidity function call using a low level `call`. A
        * plain `call` is an unsafe replacement for a function call: use this
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
        function functionCall(
            address target,
            bytes memory data,
            string memory errorMessage
        ) internal returns (bytes memory) {
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
        function functionCallWithValue(
            address target,
            bytes memory data,
            uint256 value
        ) internal returns (bytes memory) {
            return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
        }

        /**
        * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
        * with `errorMessage` as a fallback revert reason when `target` reverts.
        *
        * _Available since v3.1._
        */
        function functionCallWithValue(
            address target,
            bytes memory data,
            uint256 value,
            string memory errorMessage
        ) internal returns (bytes memory) {
            require(address(this).balance >= value, "Address: insufficient balance for call");
            require(isContract(target), "Address: call to non-contract");

            (bool success, bytes memory returndata) = target.call{value: value}(data);
            return verifyCallResult(success, returndata, errorMessage);
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
        function functionStaticCall(
            address target,
            bytes memory data,
            string memory errorMessage
        ) internal view returns (bytes memory) {
            require(isContract(target), "Address: static call to non-contract");

            (bool success, bytes memory returndata) = target.staticcall(data);
            return verifyCallResult(success, returndata, errorMessage);
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
        function functionDelegateCall(
            address target,
            bytes memory data,
            string memory errorMessage
        ) internal returns (bytes memory) {
            require(isContract(target), "Address: delegate call to non-contract");

            (bool success, bytes memory returndata) = target.delegatecall(data);
            return verifyCallResult(success, returndata, errorMessage);
        }

        /**
        * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
        * revert reason using the provided one.
        *
        * _Available since v4.3._
        */
        function verifyCallResult(
            bool success,
            bytes memory returndata,
            string memory errorMessage
        ) internal pure returns (bytes memory) {
            if (success) {
                return returndata;
            } else {
                // Look for revert reason and bubble it up if present
                if (returndata.length > 0) {
                    // The easiest way to bubble the revert reason is using memory via assembly

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

    // File: @openzeppelin/contracts/token/ERC20/IERC20.sol


    // OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

    pragma solidity ^0.8.0;

    /**
    * @dev Interface of the ERC20 standard as defined in the EIP.
    */
    interface IERC20 {
        /**
        * @dev Returns the amount of tokens in existence.
        */
        function totalSupply() external view returns (uint256);

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
        function allowance(address owner, address spender) external view returns (uint256);

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

    // File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


    // OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

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
            uint256 newAllowance = token.allowance(address(this), spender) + value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }

        function safeDecreaseAllowance(
            IERC20 token,
            address spender,
            uint256 value
        ) internal {
            unchecked {
                uint256 oldAllowance = token.allowance(address(this), spender);
                require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
                uint256 newAllowance = oldAllowance - value;
                _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
            // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
            // the target address contains contract code and also asserts for success in the low-level call.

            bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
            if (returndata.length > 0) {
                // Return data is optional
                require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
            }
        }
    }

    // File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol


    // OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

    pragma solidity ^0.8.0;


    /**
    * @dev Interface for the optional metadata functions from the ERC20 standard.
    *
    * _Available since v4.1._
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

    // File: @openzeppelin/contracts/utils/Context.sol


    // OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

    pragma solidity ^0.8.0;

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

    // File: @openzeppelin/contracts/finance/PaymentSplitter.sol


    // OpenZeppelin Contracts v4.4.1 (finance/PaymentSplitter.sol)

    pragma solidity ^0.8.0;




    /**
    * @title PaymentSplitter
    * @dev This contract allows to split Ether payments among a group of accounts. The sender does not need to be aware
    * that the Ether will be split in this way, since it is handled transparently by the contract.
    *
    * The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each
    * account to a number of shares. Of all the Ether that this contract receives, each account will then be able to claim
    * an amount proportional to the percentage of total shares they were assigned.
    *
    * `PaymentSplitter` follows a _pull payment_ model. This means that payments are not automatically forwarded to the
    * accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the {release}
    * function.
    *
    * NOTE: This contract assumes that ERC20 tokens will behave similarly to native tokens (Ether). Rebasing tokens, and
    * tokens that apply fees during transfers, are likely to not be supported as expected. If in doubt, we encourage you
    * to run tests before sending real value to this contract.
    */
    contract PaymentSplitter is Context {
        event PayeeAdded(address account, uint256 shares);
        event PaymentReleased(address to, uint256 amount);
        event ERC20PaymentReleased(IERC20 indexed token, address to, uint256 amount);
        event PaymentReceived(address from, uint256 amount);

        uint256 private _totalShares;
        uint256 private _totalReleased;

        mapping(address => uint256) private _shares;
        mapping(address => uint256) private _released;
        address[] private _payees;

        mapping(IERC20 => uint256) private _erc20TotalReleased;
        mapping(IERC20 => mapping(address => uint256)) private _erc20Released;

        /**
        * @dev Creates an instance of `PaymentSplitter` where each account in `payees` is assigned the number of shares at
        * the matching position in the `shares` array.
        *
        * All addresses in `payees` must be non-zero. Both arrays must have the same non-zero length, and there must be no
        * duplicates in `payees`.
        */
        constructor(address[] memory payees, uint256[] memory shares_) payable {
            require(payees.length == shares_.length, "PaymentSplitter: payees and shares length mismatch");
            require(payees.length > 0, "PaymentSplitter: no payees");

            for (uint256 i = 0; i < payees.length; i++) {
                _addPayee(payees[i], shares_[i]);
            }
        }

        /**
        * @dev The Ether received will be logged with {PaymentReceived} events. Note that these events are not fully
        * reliable: it's possible for a contract to receive Ether without triggering this function. This only affects the
        * reliability of the events, and not the actual splitting of Ether.
        *
        * To learn more about this see the Solidity documentation for
        * https://solidity.readthedocs.io/en/latest/contracts.html#fallback-function[fallback
        * functions].
        */
        receive() external payable virtual {
            emit PaymentReceived(_msgSender(), msg.value);
        }

        /**
        * @dev Getter for the total shares held by payees.
        */
        function totalShares() public view returns (uint256) {
            return _totalShares;
        }

        /**
        * @dev Getter for the total amount of Ether already released.
        */
        function totalReleased() public view returns (uint256) {
            return _totalReleased;
        }

        /**
        * @dev Getter for the total amount of `token` already released. `token` should be the address of an IERC20
        * contract.
        */
        function totalReleased(IERC20 token) public view returns (uint256) {
            return _erc20TotalReleased[token];
        }

        /**
        * @dev Getter for the amount of shares held by an account.
        */
        function shares(address account) public view returns (uint256) {
            return _shares[account];
        }

        /**
        * @dev Getter for the amount of Ether already released to a payee.
        */
        function released(address account) public view returns (uint256) {
            return _released[account];
        }

        /**
        * @dev Getter for the amount of `token` tokens already released to a payee. `token` should be the address of an
        * IERC20 contract.
        */
        function released(IERC20 token, address account) public view returns (uint256) {
            return _erc20Released[token][account];
        }

        /**
        * @dev Getter for the address of the payee number `index`.
        */
        function payee(uint256 index) public view returns (address) {
            return _payees[index];
        }

        /**
        * @dev Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
        * total shares and their previous withdrawals.
        */
        function release(address payable account) public virtual {
            require(_shares[account] > 0, "PaymentSplitter: account has no shares");

            uint256 totalReceived = address(this).balance + totalReleased();
            uint256 payment = _pendingPayment(account, totalReceived, released(account));

            require(payment != 0, "PaymentSplitter: account is not due payment");

            _released[account] += payment;
            _totalReleased += payment;

            Address.sendValue(account, payment);
            emit PaymentReleased(account, payment);
        }

        /**
        * @dev Triggers a transfer to `account` of the amount of `token` tokens they are owed, according to their
        * percentage of the total shares and their previous withdrawals. `token` must be the address of an IERC20
        * contract.
        */
        function release(IERC20 token, address account) public virtual {
            require(_shares[account] > 0, "PaymentSplitter: account has no shares");

            uint256 totalReceived = token.balanceOf(address(this)) + totalReleased(token);
            uint256 payment = _pendingPayment(account, totalReceived, released(token, account));

            require(payment != 0, "PaymentSplitter: account is not due payment");

            _erc20Released[token][account] += payment;
            _erc20TotalReleased[token] += payment;

            SafeERC20.safeTransfer(token, account, payment);
            emit ERC20PaymentReleased(token, account, payment);
        }

        /**
        * @dev internal logic for computing the pending payment of an `account` given the token historical balances and
        * already released amounts.
        */
        function _pendingPayment(
            address account,
            uint256 totalReceived,
            uint256 alreadyReleased
        ) private view returns (uint256) {
            return (totalReceived * _shares[account]) / _totalShares - alreadyReleased;
        }

        /**
        * @dev Add a new payee to the contract.
        * @param account The address of the payee to add.
        * @param shares_ The number of shares owned by the payee.
        */
        function _addPayee(address account, uint256 shares_) private {
            require(account != address(0), "PaymentSplitter: account is the zero address");
            require(shares_ > 0, "PaymentSplitter: shares are 0");
            require(_shares[account] == 0, "PaymentSplitter: account already has shares");

            _payees.push(account);
            _shares[account] = shares_;
            _totalShares = _totalShares + shares_;
            emit PayeeAdded(account, shares_);
        }
    }

    // File: @openzeppelin/contracts/token/ERC20/ERC20.sol


    // OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

    pragma solidity ^0.8.0;




    /**
    * @dev Implementation of the {IERC20} interface.
    *
    * This implementation is agnostic to the way tokens are created. This means
    * that a supply mechanism has to be added in a derived contract using {_mint}.
    * For a generic mechanism see {ERC20PresetMinterPauser}.
    *
    * TIP: For a detailed writeup see our guide
    * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
    * to implement supply mechanisms].
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
    *
    * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
    * functions have been added to mitigate the well-known issues around setting
    * allowances. See {IERC20-approve}.
    */
    contract ERC20 is Context, IERC20, IERC20Metadata {
        mapping(address => uint256) private _balances;

        mapping(address => mapping(address => uint256)) private _allowances;

        uint256 private _totalSupply;

        string private _name;
        string private _symbol;

        /**
        * @dev Sets the values for {name} and {symbol}.
        *
        * The default value of {decimals} is 18. To select a different value for
        * {decimals} you should overload it.
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
        function name() public view virtual override returns (string memory) {
            return _name;
        }

        /**
        * @dev Returns the symbol of the token, usually a shorter version of the
        * name.
        */
        function symbol() public view virtual override returns (string memory) {
            return _symbol;
        }

        /**
        * @dev Returns the number of decimals used to get its user representation.
        * For example, if `decimals` equals `2`, a balance of `505` tokens should
        * be displayed to a user as `5.05` (`505 / 10 ** 2`).
        *
        * Tokens usually opt for a value of 18, imitating the relationship between
        * Ether and Wei. This is the value {ERC20} uses, unless this function is
        * overridden;
        *
        * NOTE: This information is only used for _display_ purposes: it in
        * no way affects any of the arithmetic of the contract, including
        * {IERC20-balanceOf} and {IERC20-transfer}.
        */
        function decimals() public view virtual override returns (uint8) {
            return 18;
        }

        /**
        * @dev See {IERC20-totalSupply}.
        */
        function totalSupply() public view virtual override returns (uint256) {
            return _totalSupply;
        }

        /**
        * @dev See {IERC20-balanceOf}.
        */
        function balanceOf(address account) public view virtual override returns (uint256) {
            return _balances[account];
        }

        /**
        * @dev See {IERC20-transfer}.
        *
        * Requirements:
        *
        * - `recipient` cannot be the zero address.
        * - the caller must have a balance of at least `amount`.
        */
        function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
            _transfer(_msgSender(), recipient, amount);
            return true;
        }

        /**
        * @dev See {IERC20-allowance}.
        */
        function allowance(address owner, address spender) public view virtual override returns (uint256) {
            return _allowances[owner][spender];
        }

        /**
        * @dev See {IERC20-approve}.
        *
        * Requirements:
        *
        * - `spender` cannot be the zero address.
        */
        function approve(address spender, uint256 amount) public virtual override returns (bool) {
            _approve(_msgSender(), spender, amount);
            return true;
        }

        /**
        * @dev See {IERC20-transferFrom}.
        *
        * Emits an {Approval} event indicating the updated allowance. This is not
        * required by the EIP. See the note at the beginning of {ERC20}.
        *
        * Requirements:
        *
        * - `sender` and `recipient` cannot be the zero address.
        * - `sender` must have a balance of at least `amount`.
        * - the caller must have allowance for ``sender``'s tokens of at least
        * `amount`.
        */
        function transferFrom(
            address sender,
            address recipient,
            uint256 amount
        ) public virtual override returns (bool) {
            _transfer(sender, recipient, amount);

            uint256 currentAllowance = _allowances[sender][_msgSender()];
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            unchecked {
                _approve(sender, _msgSender(), currentAllowance - amount);
            }

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
            _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
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
        * `subtractedValue`.
        */
        function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
            uint256 currentAllowance = _allowances[_msgSender()][spender];
            require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
            unchecked {
                _approve(_msgSender(), spender, currentAllowance - subtractedValue);
            }

            return true;
        }

        /**
        * @dev Moves `amount` of tokens from `sender` to `recipient`.
        *
        * This internal function is equivalent to {transfer}, and can be used to
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

            _beforeTokenTransfer(sender, recipient, amount);

            uint256 senderBalance = _balances[sender];
            require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
            unchecked {
                _balances[sender] = senderBalance - amount;
            }
            _balances[recipient] += amount;

            emit Transfer(sender, recipient, amount);

            _afterTokenTransfer(sender, recipient, amount);
        }

        /** @dev Creates `amount` tokens and assigns them to `account`, increasing
        * the total supply.
        *
        * Emits a {Transfer} event with `from` set to the zero address.
        *
        * Requirements:
        *
        * - `account` cannot be the zero address.
        */
        function _mint(address account, uint256 amount) internal virtual {
            require(account != address(0), "ERC20: mint to the zero address");

            _beforeTokenTransfer(address(0), account, amount);

            _totalSupply += amount;
            _balances[account] += amount;
            emit Transfer(address(0), account, amount);

            _afterTokenTransfer(address(0), account, amount);
        }

        /**
        * @dev Destroys `amount` tokens from `account`, reducing the
        * total supply.
        *
        * Emits a {Transfer} event with `to` set to the zero address.
        *
        * Requirements:
        *
        * - `account` cannot be the zero address.
        * - `account` must have at least `amount` tokens.
        */
        function _burn(address account, uint256 amount) internal virtual {
            require(account != address(0), "ERC20: burn from the zero address");

            _beforeTokenTransfer(account, address(0), amount);

            uint256 accountBalance = _balances[account];
            require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
            unchecked {
                _balances[account] = accountBalance - amount;
            }
            _totalSupply -= amount;

            emit Transfer(account, address(0), amount);

            _afterTokenTransfer(account, address(0), amount);
        }

        /**
        * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
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
        function _approve(
            address owner,
            address spender,
            uint256 amount
        ) internal virtual {
            require(owner != address(0), "ERC20: approve from the zero address");
            require(spender != address(0), "ERC20: approve to the zero address");

            _allowances[owner][spender] = amount;
            emit Approval(owner, spender, amount);
        }

        /**
        * @dev Hook that is called before any transfer of tokens. This includes
        * minting and burning.
        *
        * Calling conditions:
        *
        * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
        * will be transferred to `to`.
        * - when `from` is zero, `amount` tokens will be minted for `to`.
        * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
        * - `from` and `to` are never both zero.
        *
        * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
        */
        function _beforeTokenTransfer(
            address from,
            address to,
            uint256 amount
        ) internal virtual {}

        /**
        * @dev Hook that is called after any transfer of tokens. This includes
        * minting and burning.
        *
        * Calling conditions:
        *
        * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
        * has been transferred to `to`.
        * - when `from` is zero, `amount` tokens have been minted for `to`.
        * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
        * - `from` and `to` are never both zero.
        *
        * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
        */
        function _afterTokenTransfer(
            address from,
            address to,
            uint256 amount
        ) internal virtual {}
    }

    // File: @openzeppelin/contracts/access/Ownable.sol


    // OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

    pragma solidity ^0.8.0;


    /**
    * @dev Contract module which provides a basic access control mechanism, where
    * there is an account (an owner) that can be granted exclusive access to
    * specific functions.
    *
    * By default, the owner account will be the one that deploys the contract. This
    * can later be changed with {transferOwnership}.
    *
    * This module is used through inheritance. It will make available the modifier
    * `onlyOwner`, which can be applied to your functions to restrict their use to
    * the owner.
    */
    abstract contract Ownable is Context {
        address private _owner;

        event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

        /**
        * @dev Initializes the contract setting the deployer as the initial owner.
        */
        constructor() {
            _transferOwnership(_msgSender());
        }

        /**
        * @dev Returns the address of the current owner.
        */
        function owner() public view virtual returns (address) {
            return _owner;
        }

        /**
        * @dev Throws if called by any account other than the owner.
        */
        modifier onlyOwner() {
            require(owner() == _msgSender(), "Ownable: caller is not the owner");
            _;
        }

        /**
        * @dev Leaves the contract without owner. It will not be possible to call
        * `onlyOwner` functions anymore. Can only be called by the current owner.
        *
        * NOTE: Renouncing ownership will leave the contract without an owner,
        * thereby removing any functionality that is only available to the owner.
        */
        function renounceOwnership() public virtual onlyOwner {
            _transferOwnership(address(0));
        }

        /**
        * @dev Transfers ownership of the contract to a new account (`newOwner`).
        * Can only be called by the current owner.
        */
        function transferOwnership(address newOwner) public virtual onlyOwner {
            require(newOwner != address(0), "Ownable: new owner is the zero address");
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

    // File: @openzeppelin/contracts/utils/math/SafeMath.sol


    // OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

    pragma solidity ^0.8.0;

    // CAUTION
    // This version of SafeMath should only be used with Solidity 0.8 or later,
    // because it relies on the compiler's built in overflow checks.

    /**
    * @dev Wrappers over Solidity's arithmetic operations.
    *
    * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
    * now has built in overflow checking.
    */
    library SafeMath {
        /**
        * @dev Returns the addition of two unsigned integers, with an overflow flag.
        *
        * _Available since v3.4._
        */
        function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
            unchecked {
                uint256 c = a + b;
                if (c < a) return (false, 0);
                return (true, c);
            }
        }

        /**
        * @dev Returns the substraction of two unsigned integers, with an overflow flag.
        *
        * _Available since v3.4._
        */
        function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
            unchecked {
                if (b > a) return (false, 0);
                return (true, a - b);
            }
        }

        /**
        * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
        *
        * _Available since v3.4._
        */
        function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
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
        *
        * _Available since v3.4._
        */
        function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
            unchecked {
                if (b == 0) return (false, 0);
                return (true, a / b);
            }
        }

        /**
        * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
        *
        * _Available since v3.4._
        */
        function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
            unchecked {
                if (b == 0) return (false, 0);
                return (true, a % b);
            }
        }

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
            return a + b;
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
            return a - b;
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
            return a * b;
        }

        /**
        * @dev Returns the integer division of two unsigned integers, reverting on
        * division by zero. The result is rounded towards zero.
        *
        * Counterpart to Solidity's `/` operator.
        *
        * Requirements:
        *
        * - The divisor cannot be zero.
        */
        function div(uint256 a, uint256 b) internal pure returns (uint256) {
            return a / b;
        }

        /**
        * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
        * reverting when dividing by zero.
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
            return a % b;
        }

        /**
        * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
        * overflow (when the result is negative).
        *
        * CAUTION: This function is deprecated because it requires allocating memory for the error
        * message unnecessarily. For custom revert reasons use {trySub}.
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
            unchecked {
                require(b <= a, errorMessage);
                return a - b;
            }
        }

        /**
        * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
            unchecked {
                require(b > 0, errorMessage);
                return a / b;
            }
        }

        /**
        * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
        * reverting with custom message when dividing by zero.
        *
        * CAUTION: This function is deprecated because it requires allocating memory for the error
        * message unnecessarily. For custom revert reasons use {tryMod}.
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
            unchecked {
                require(b > 0, errorMessage);
                return a % b;
            }
        }
    }

pragma solidity ^0.8.0;


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
    pragma solidity ^0.8.4;

    contract SmartNodes is ERC20, Ownable, PaymentSplitter{

        using Address for address;
        using SafeMath for uint256;

        address public joePair;

        address public joeRouterAddress = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4; // TraderJoe Router
        // address public joeRouterAddress = 0x5db0735cf88F85E78ed742215090c465979B5006; // TraderJoe Router fuji testnet

        address public teamPool;
        address public rewardsPool;
        address public refPool;

        uint256 private rewardsFee;
        uint256 private liquidityPoolFee;
        uint256 private teamPoolFee;
        uint256 private cashoutFee;
        uint256 private totalFees;

        uint256 public nodeValue;

        // Max transfer amount rate in basis points. (default is 10% of total supply)
        uint16 public maxTransferAmountRate = 200;
        // Max balance amount rate in basis points. (default is 5% of total supply)
        uint16 public maxBalanceAmountRate = 1000;

        uint256 public swapTokensAmount;
        uint256 public totalClaimed = 0;
        bool public isTradingEnabled = true;
        bool public swapLiquifyEnabled = true;

        IPangolinRouter public joeRouter;
        INodeManager private nodeManager;
        reflections private refManager;

        uint256 private rwSwap;
        bool private swapping = false;

        mapping(address => bool) public isBlacklisted;
        mapping(address => bool) public automatedMarketMakerPairs;
        mapping(address => bool) private _excludedFromAntiWhale;
        mapping(address => bool) private _excludedFromAntiSniper;

        mapping(address => bool) private isExcludedfromTax;

        uint256 public salesTax1;
        uint256 public salesTax2;
        uint256 public transferTax1;
        uint256 public transferTax2;
        uint256 public sTaxLim;
        uint256 public tTaxLim;
        uint256 public rewPercent;
        uint256 public trePercent;
        uint256 public refPercent;
        uint256 public teamPercent;

        uint256 public teamPoolPercent;
        uint256 public rewardsPoolPercent;

        address public presale;
        address public airdrop;
        bool public pauseNoding = false;

        // address[] public noders;
        // struct UserReceipt{
        //     uint256 userRefClaimed;
        //     uint256 nodesAtClaim;
        // }
        // mapping(address => UserReceipt) public userReceipts;

        // mapping(address => bool) public returnNoder;
        event UpdateJoeRouter(
            address indexed newAddress,
            address indexed oldAddress
        );

        event MaxTransferAmountRateUpdated(address indexed operator, uint256 previousRate, uint256 newRate);
        event maxBalanceAmountRateUpdated(address indexed operator, uint256 previousRate, uint256 newRate);

        event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

        event LiquidityWalletUpdated(
            address indexed newLiquidityWallet,
            address indexed oldLiquidityWallet
        );

        event SwapAndLiquify(
            uint256 tokensSwapped,
            uint256 ethReceived,
            uint256 tokensIntoLiqudity
        );

        event Cashout(
            address indexed account,
            uint256 amount,
            uint256 indexed blockTime
        );

        event Compound(
            address indexed account,
            uint256 amount,
            uint256 indexed blockTime
        );

        modifier antiWhale(address sender, address recipient, uint256 amount) {
            if (maxTransferAmount() > 0) {
                if (
                    _excludedFromAntiWhale[sender] == false
                    && _excludedFromAntiWhale[recipient] == false
                ) {
                    require(amount <= maxTransferAmount(), "SmartNodes:: AntiWhale: Transfer amount exceeds the maxTransferAmount");
                    if (sender == joePair) {
                        require(balanceOf(recipient).add(amount) <= maxBalanceAmount(), "SmartNodes: AntiWhale: Transfer would exceed the maxBalanceAmount of the recipient");
                    }
                }
            }
            _;
        }

        modifier antiSniper(address from, address to, address callee){
            uint256 size1;
            uint256 size2;
            uint256 size3;
            assembly {
                size1 := extcodesize(callee)
                size2 := extcodesize(to)
                size3 := extcodesize(from)
            }
            if(!_excludedFromAntiSniper[from]
                && !_excludedFromAntiSniper[to] && !_excludedFromAntiSniper[callee])
                    require(!(size1 > 0 || size2 > 0 || size3 > 0),"SmartNodes: Sniper Detected");
            _;
        }

        modifier onlyGuard() {
            require(owner() == _msgSender() || presale == _msgSender() || airdrop == _msgSender(), "NOT_GUARD");
            _;
        }
        modifier notPaused{
            require(!pauseNoding);
            _;
        }

        constructor(
            address[] memory payees,
            uint256[] memory shares,
            address[] memory addresses,
            uint256[] memory fees,
            uint256 swapAmount
        )
            ERC20("SmartNodes", "SMRT")
            PaymentSplitter(payees, shares)
        {
            _excludedFromAntiWhale[address(this)] = true;
            _excludedFromAntiWhale[addresses[0]] = true;
            _excludedFromAntiWhale[addresses[1]] = true;
            _excludedFromAntiWhale[addresses[2]] = true;
            isExcludedfromTax[address(this)] = true;
            isExcludedfromTax[addresses[0]] = true;
            isExcludedfromTax[addresses[1]] = true;
            isExcludedfromTax[addresses[2]] = true;
            _excludedFromAntiSniper[address(this)] = true;
            _excludedFromAntiSniper[addresses[0]] = true;
            _excludedFromAntiSniper[addresses[1]] = true;
            _excludedFromAntiSniper[addresses[2]] = true;

            require(
                addresses[0] != address(0) && addresses[1] != address(0) && addresses[2] != address(0) && addresses[3] != address(0),
                "SmartNodes: Invalid Addresses"
            );
            teamPool = addresses[0];
            rewardsPool = addresses[1];
            refPool = addresses[2];
            nodeManager = INodeManager(addresses[3]);
            refManager = reflections(refPool);

            require(joeRouterAddress != address(0), "SmartNodes: Invalid JoeRouter Address");
            IPangolinRouter _joeRouter = IPangolinRouter(joeRouterAddress);
            // address _joePair;
            address _joePair = IPangolinFactory(_joeRouter.factory())
            .createPair(address(this), _joeRouter.WAVAX());

            joeRouter = _joeRouter;
            joePair = _joePair;
            _excludedFromAntiSniper[joeRouterAddress] = true;
            _excludedFromAntiSniper[joePair] = true;

            _setAutomatedMarketMakerPair(_joePair, true);

            require(
                fees[0] != 0 && fees[1] != 0 && fees[2] != 0 && fees[3] != 0,
                "SmartNodes: Fees cannot be 0"
            );
            teamPoolFee = fees[0];
            rewardsFee = fees[1];
            liquidityPoolFee = fees[2];
            cashoutFee = fees[3];
            rwSwap = fees[4];

            totalFees = rewardsFee.add(liquidityPoolFee).add(teamPoolFee);

            require(swapAmount > 0, "SmartNodes: Swap Amount cannot be 0");
            swapTokensAmount = swapAmount * (10**18);
        }

        function migrate(address[] memory addresses_, uint256[] memory balances_) external onlyOwner {
            for (uint256 i = 0; i < addresses_.length; i++) {
                _mint(addresses_[i], balances_[i] * 10**decimals());
            }
        }

        function burn(address account, uint256 amount) external onlyOwner {
            _burn(account, amount);
        }

        function updateJoeRouterAddress(address newAddress) external onlyOwner {
            require(
                newAddress != address(joeRouter),
                "SmartNodes: Cannot update with existing address"
            );
            emit UpdateJoeRouter(newAddress, address(joeRouter));
            IPangolinRouter	 _joeRouter = IPangolinRouter(newAddress);
            address _joePair = IPangolinFactory(joeRouter.factory()).createPair(
                address(this),
                _joeRouter.WAVAX()
            );
            joePair = _joePair;
            joeRouterAddress = newAddress;
            _excludedFromAntiSniper[joeRouterAddress] = true;
            _excludedFromAntiSniper[joePair] = true;
        }

        function updateNodeValue(uint256 newVal) external onlyOwner {
            nodeValue = newVal;
        }

        function updateSwapTokensAmount(uint256 newVal) external onlyOwner {
            swapTokensAmount = newVal;
        }

        function updateTeamPool(address payable newVal) external onlyOwner {
            teamPool = newVal;
            _excludedFromAntiSniper[teamPool] = true;
            _excludedFromAntiWhale[teamPool] = true;
            isExcludedfromTax[teamPool] = true;
        }

        function updateRewardsPool(address payable newVal) external onlyOwner {
            rewardsPool = newVal;
            _excludedFromAntiSniper[rewardsPool] = true;
            _excludedFromAntiWhale[rewardsPool] = true;
            isExcludedfromTax[rewardsPool] = true;

        }

        function updateRefPool(address payable newVal) external onlyOwner {
            refPool = newVal;
            _excludedFromAntiSniper[refPool] = true;
            _excludedFromAntiWhale[refPool] = true;
            isExcludedfromTax[refPool] = true;
        }

        function updateRewardsFee(uint256 newVal) external onlyOwner {
            rewardsFee = newVal;
            totalFees = rewardsFee.add(liquidityPoolFee).add(teamPoolFee);
        }

        function updateLiquidityFee(uint256 newVal) external onlyOwner {
            liquidityPoolFee = newVal;
            totalFees = rewardsFee.add(liquidityPoolFee).add(teamPoolFee);
        }

        function updateTeamFee(uint256 newVal) external onlyOwner {
            teamPoolFee = newVal;
            totalFees = rewardsFee.add(liquidityPoolFee).add(teamPoolFee);
        }

        function updateCashoutFee(uint256 newVal) external onlyOwner {
            cashoutFee = newVal;
        }

        function updateRwSwapFee(uint256 newVal) external onlyOwner {
            rwSwap = newVal;
        }

        function updateSwapLiquify(bool newVal) external onlyOwner {
            swapLiquifyEnabled = newVal;
        }

        function updateIsTradingEnabled(bool newVal) external onlyOwner {
            isTradingEnabled = newVal;
        }

        function setAutomatedMarketMakerPair(address pair, bool value)
            external
            onlyOwner
        {
            require(
                pair != joePair,
                "SmartNodes: Cannot set automated market maker pair to existing JoePair"
            );

            _setAutomatedMarketMakerPair(pair, value);
        }

        function blacklistAddress(address account, bool value)
            external
            onlyOwner
        {
            isBlacklisted[account] = value;
        }

        function isExcludedFromAntiWhale(address _account) public view returns (bool) {
            return _excludedFromAntiWhale[_account];
        }

        function setExcludedFromTaxes(address _account, bool value) external onlyOwner
        {
            isExcludedfromTax[_account] = value;
        }
        /**
        * @dev Returns the max wallet amount.
        */
        function maxBalanceAmount() public view returns (uint256) {
            return (totalSupply()-balanceOf(rewardsPool)).mul(maxBalanceAmountRate).div(10000);
        }

        /**
        * @dev Returns the max transfer amount.
        */
        function maxTransferAmount() public view returns (uint256) {
            return (totalSupply()-balanceOf(rewardsPool)).mul(maxTransferAmountRate).div(10000);
        }

        function setExcludedFromAntiWhale(address _account, bool _excluded) public onlyOwner {
            _excludedFromAntiWhale[_account] = _excluded;
        }
        function setExcludedFromAntiSniper(address _account, bool _excluded)public onlyOwner{
            _excludedFromAntiSniper[_account] = _excluded;
        }

        /**
        * @dev Update the max balance amount rate.
        * Can only be called by the current operator.
        */
        function updatemaxBalanceAmountRate(uint16 _maxBalanceAmountRate) external onlyOwner {
            require(_maxBalanceAmountRate <= 10000, "SmartNodes: updatemaxBalanceAmountRate: Max transfer amount rate must not exceed the maximum rate.");
            require(_maxBalanceAmountRate >= 200, "SmartNodes: updatemaxBalanceAmountRate: Max transfer amount rate must  exceed the minimum rate.");
            emit maxBalanceAmountRateUpdated(msg.sender, maxBalanceAmountRate, _maxBalanceAmountRate);
            maxBalanceAmountRate = _maxBalanceAmountRate;
        }

        /**
        * @dev Update the max transfer amount rate.
        * Can only be called by the current operator.
        */
        function updateMaxTransferAmountRate(uint16 _maxTransferAmountRate) public onlyOwner {
            require(_maxTransferAmountRate <= 10000, "SmartNodes: updateMaxTransferAmountRate: Max transfer amount rate must not exceed the maximum rate.");
            require(_maxTransferAmountRate >= 100, "SmartNodes: updateMaxTransferAmountRate: Max transfer amount rate must exceed the minimum rate.");
            emit MaxTransferAmountRateUpdated(msg.sender, maxTransferAmountRate, _maxTransferAmountRate);
            maxTransferAmountRate = _maxTransferAmountRate;
        }

        // Private methods

        function _setAutomatedMarketMakerPair(address pair, bool value) private {
            require(
                automatedMarketMakerPairs[pair] != value,
                "SmartNodes: Error"
            );
            automatedMarketMakerPairs[pair] = value;

            emit SetAutomatedMarketMakerPair(pair, value);
        }

        function transferFrom(
        address from,
        address to,
        uint256 amount
        ) public override antiWhale(from, to, amount)
        antiSniper(from, to, msg.sender)
        returns (bool) {

            uint256 currentAllowance = allowance(from, _msgSender());
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            unchecked {
                _approve(from, _msgSender(), currentAllowance - amount);
            }
            _transfer(from, to, amount);
            return true;
        }

        function transfer(
            address to, uint256 amount
            ) public override antiWhale(msg.sender, to, amount)
            antiSniper(msg.sender, to, msg.sender)
            returns (bool) {
            address owner = _msgSender();
            _transfer(owner, to, amount);
            return true;
        }
        function _transfer(
            address from,
            address to,
            uint256 amount
        ) internal  override{
            require(
                !isBlacklisted[from] && !isBlacklisted[to],
                "SmartNodes: BLACKLISTED"
            );
            require(from != address(0), "ERC20:1");
            require(to != address(0), "ERC20:2");
            require(isTradingEnabled, "SmartNodes: TRADING_DISABLED");

            bool isSell = (to == joePair || to == joeRouterAddress);
            bool isTransfer = from != joePair && from != joeRouterAddress && to != joePair && to != joeRouterAddress;
            _transferWithTax(isSell, isTransfer, from, to, amount);
        }

        function _transferWithTax(bool isSell, bool isTransfer, address from, address to, uint256 amount) internal {
            uint256 tax;
            uint256 taxAmt;
            uint256 transferAmount;
            if(isSell && !isExcludedfromTax[from]) {
                tax = getSalesTax(block.timestamp);
                taxAmt = amount.mul(tax).div(100);
                transferAmount = amount.sub(taxAmt);
                _distributeTax(taxAmt, from);
                super._transfer(from, to, transferAmount);
            }
            else if(isTransfer && !isExcludedfromTax[from]) {

                tax = getTransferTax(block.timestamp);
                taxAmt = amount.mul(tax).div(100);
                transferAmount = amount.sub(taxAmt);
                _distributeTax(taxAmt, from);
                super._transfer(from, to, transferAmount);
            }
            else{
                super._transfer(from, to, amount);
            }
        }

        function _distributeTax(uint256 taxAmount, address from) internal {

            super._transfer(from, address(this), taxAmount);
            if (
                swapLiquifyEnabled &&
                !swapping &&
                msg.sender != owner() &&
                !automatedMarketMakerPairs[msg.sender]
            ) {
                swapping = true;

                uint256 rewardsPoolTokens = taxAmount.mul(rewPercent).div(100);

                super._transfer(
                    address(this),
                    rewardsPool,
                    rewardsPoolTokens
                );
                uint256 treasuryRewardstoSwap = taxAmount.mul(trePercent).div(100);
                swapAndSendToFee(rewardsPool, treasuryRewardstoSwap);
                uint256 teamTokens = taxAmount.mul(teamPercent).div(100);

                swapAndSendToFee(teamPool, teamTokens);
                uint256 refReceived = taxAmount.sub(rewardsPoolTokens).sub(treasuryRewardstoSwap).sub(teamTokens);
                super._transfer(address(this), refPool, refReceived);
                refManager.updateReflections(refReceived);
                swapping = false;


            }
        }
        function getSalesTax(uint256 _timestamp) public view returns(uint256){
            if(_timestamp <= sTaxLim)
                return salesTax1;
            else
                return salesTax2;
        }

        function getTransferTax(uint256 _timestamp) public view returns(uint256){
            if(_timestamp <= tTaxLim)
                return transferTax1;
            else
                return transferTax2;
        }
        function updateTaxes(uint256[] memory taxes, uint256[] memory taxPercents)external onlyOwner{

            salesTax1 = taxes[0];
            salesTax2 = taxes[1];
            transferTax1 = taxes[2];
            transferTax2 = taxes[3];
            rewPercent = taxPercents[0];
            trePercent = taxPercents[1];
            refPercent = taxPercents[2];
            teamPercent = taxPercents[3];
            // sTaxLim = block.timestamp + taxLim1;
            // tTaxLim = block.timestamp + taxLim2;
        }

        function updateTaxesPeriod(uint256 taxLim1, uint256 taxLim2)external onlyOwner{
            sTaxLim = block.timestamp + taxLim1;
            tTaxLim = block.timestamp + taxLim2;
        }

        function swapAndSendToFee(address destination, uint256 tokens) private {
            uint256 initialAVAXBalance = address(this).balance;

            swapTokensForAVAX(tokens);

            uint256 newBalance = (address(this).balance).sub(initialAVAXBalance);
            payable(destination).transfer(newBalance);
        }

        function swapAndLiquify(uint256 tokens) private {
            uint256 half = tokens.div(2);
            uint256 otherHalf = tokens.sub(half);
            uint256 initialBalance = address(this).balance;
            swapTokensForAVAX(half);

            uint256 newBalance = address(this).balance.sub(initialBalance);
            addLiquidity(otherHalf, newBalance);
            emit SwapAndLiquify(half, newBalance, otherHalf);
        }

        function swapTokensForAVAX(uint256 tokenAmount) private {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = joeRouter.WAVAX();

            _approve(address(this), address(joeRouter), tokenAmount);

            joeRouter.swapExactTokensForAVAXSupportingFeeOnTransferTokens(
                tokenAmount,
                0, // accept any amount of AVAX
                path,
                address(this),
                block.timestamp
            );
        }

        function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
            // approve token transfer to cover all possible scenarios
            _approve(address(this), address(joeRouter), tokenAmount);

            // add the liquidity
            joeRouter.addLiquidityAVAX{value: ethAmount}(
                address(this),
                tokenAmount,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                rewardsPool,
                block.timestamp
            );
        }

        function addLiquidityJR(uint256 tokenAmount, uint256 ethAmount) public payable onlyOwner{
            // approve token transfer to cover all possible scenarios
            _approve(address(this), address(joeRouter), tokenAmount);

            // add the liquidity
            joeRouter.addLiquidityAVAX{value: ethAmount}(
                address(this),
                tokenAmount,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                rewardsPool,
                block.timestamp
            );
        }

        // External node methods

        function createNodeWithTokens(string memory name, uint256 amount_) external notPaused{
            address sender = _msgSender();
            require(
                amount_ >= nodeValue, "SmartNodes: Not enough SMN tokens"
            );
            require(
                bytes(name).length > 3 && bytes(name).length < 32,
                "SmartNodes: Invalid Name"
            );
            require(
                sender != address(0),
                "SmartNodes: Wrong address"
            );
            require(!isBlacklisted[sender], "SmartNodes: BLACKLISTED");
            require(
                sender != teamPool && sender != rewardsPool,
                "SmartNodes: Wrong address"
            );
            require(
                balanceOf(sender) >= amount_,
                "SmartNodes: Insufficient balance"
            );
            uint256 initBal1 = balanceOf(address(this));
            super._transfer(sender, address(this), amount_);
            uint256 initBal2 = balanceOf(address(this));

            uint256 contractTokenBalance = initBal2 - initBal1;
            if (
                swapLiquifyEnabled &&
                !swapping &&
                sender != owner() &&
                !automatedMarketMakerPairs[sender]
            ) {
                swapping = true;
                uint256 teamTokens = contractTokenBalance
                    .mul(teamPoolFee)
                    .div(100);

                swapAndSendToFee(teamPool, teamTokens);

                uint256 rewardsPoolTokens = contractTokenBalance
                    .mul(rewardsFee)
                    .div(100);


                uint256 rewardsTokenstoSwap = rewardsPoolTokens.mul(rwSwap).div(
                    100
                );

                swapAndSendToFee(rewardsPool, rewardsTokenstoSwap);

                super._transfer(
                    address(this),
                    rewardsPool,
                    rewardsPoolTokens.sub(rewardsTokenstoSwap)
                );

                uint256 swapTokens = contractTokenBalance.mul(liquidityPoolFee).div(
                    100
                );
                swapAndLiquify(swapTokens);
                if(balanceOf(address(this)) > 0)
                    swapTokensForAVAX(balanceOf(address(this)));

                swapping = false;
            }
            refManager.addNodeForReflections(sender);
            nodeManager.createNode(sender, name, amount_);
            // if(!returnNoder[sender]){
            //     returnNoder[sender] = true;
            //     noders.push(sender);
            // }

        }

        function cashoutReward(uint256 blocktime) external {
            address sender = _msgSender();
            require(
                sender != address(0),
                "SmartNodes: Wrong address"
            );
            require(
                !isBlacklisted[sender],
                "SmartNodes: BLACKLISTED"
            );
            require(
                sender != teamPool && sender != rewardsPool,
                "SmartNodes: Wrong address"
            );
            uint256 rewardAmount = nodeManager.getNodeReward(sender, blocktime);
            require(
                rewardAmount > 0,
                "SmartNodes: No reward to cash out"
            );

            if (swapLiquifyEnabled) {
                uint256 feeAmount;
                if (cashoutFee > 0) {
                    feeAmount = rewardAmount.mul(cashoutFee).div(100);
                    super._transfer(rewardsPool, address(this), feeAmount);
                    swapAndSendToFee(rewardsPool, feeAmount);
                }
                rewardAmount -= feeAmount;
            }
            super._transfer(rewardsPool, sender, rewardAmount);
            nodeManager.cashoutNodeReward(sender, blocktime);
            totalClaimed += rewardAmount;

            emit Cashout(sender, rewardAmount, blocktime);
        }

        function cashoutAll() external {
            address sender = _msgSender();
            require(
                sender != address(0),
                "SmartNodes: Wrong address"
            );
            require(
                !isBlacklisted[sender],
                "SmartNodes: BLACKLISTED"
            );
            require(
                sender != teamPool && sender != rewardsPool,
                "SmartNodes: Wrong address"
            );
            uint256 rewardAmount = nodeManager.getAllNodesRewards(sender);
            require(
                rewardAmount > 0,
                "SmartNodes: No reward to cash out"
            );

            if (swapLiquifyEnabled) {
                uint256 feeAmount;
                if (cashoutFee > 0) {
                    feeAmount = rewardAmount.mul(cashoutFee).div(100);
                    super._transfer(rewardsPool, address(this), feeAmount);

                    uint256 rewardsPoolCut = feeAmount.mul(rewardsPoolPercent).div(100);
                    swapAndSendToFee(rewardsPool, rewardsPoolCut);

                    uint256 teamPoolCut = feeAmount.mul(teamPoolPercent).div(100);
                    swapAndSendToFee(teamPool, teamPoolCut);
                }
                rewardAmount -= feeAmount;
            }
            super._transfer(rewardsPool, sender, rewardAmount);
            nodeManager.cashoutAllNodesRewards(sender);
            totalClaimed += rewardAmount;

            emit Cashout(sender, rewardAmount, 0);
        }

        function updateCashoutDistribution(uint256 _rewardsPoolCut, uint256 _teamPoolCut)public onlyOwner{
            rewardsPoolPercent = _rewardsPoolCut;
            teamPoolPercent = _teamPoolCut;
        }
        function compoundNodeRewards(uint256 blocktime) external {
            address sender = _msgSender();
            require(
                sender != address(0),
                "SmartNodes: Wrong address"
            );
            require(
                !isBlacklisted[sender],
                "SmartNodes: BLACKLISTED"
            );
            require(
                sender != teamPool && sender != rewardsPool,
                "SmartNodes: Wrong address"
            );
            uint256 rewardAmount = nodeManager.getNodeReward(sender, blocktime);
            require(
                rewardAmount > 0,
                "SmartNodes: No rewards to compound"
            );
            uint256 initBal1 = balanceOf(address(this));
            super._transfer(rewardsPool, address(this), rewardAmount);
            uint256 initBal2 = balanceOf(address(this));
            uint256 contractTokenBalance = initBal2 - initBal1;

            if (
                swapLiquifyEnabled &&
                !swapping &&
                sender != owner() &&
                !automatedMarketMakerPairs[sender]
            ) {
                swapping = true;

                uint256 teamTokens = contractTokenBalance
                    .mul(teamPoolFee)
                    .div(100);

                swapAndSendToFee(teamPool, teamTokens);

                uint256 rewardsPoolTokens = contractTokenBalance
                    .mul(rewardsFee)
                    .div(100);

                uint256 rewardsTokenstoSwap = rewardsPoolTokens.mul(rwSwap).div(
                    100
                );

                swapAndSendToFee(rewardsPool, rewardsTokenstoSwap);

                super._transfer(
                    address(this),
                    rewardsPool,
                    rewardsPoolTokens.sub(rewardsTokenstoSwap)
                );

                uint256 swapTokens = contractTokenBalance.mul(liquidityPoolFee).div(
                    100
                );

                swapAndLiquify(swapTokens);
                swapTokensForAVAX(balanceOf(address(this)));

                swapping = false;
            }
            nodeManager.compoundNodeReward(sender, blocktime, rewardAmount);

            emit Compound(sender, rewardAmount, blocktime);
        }

        function pauseNodeCreation(bool pause) external onlyOwner{
            pauseNoding = pause;
        }

        // function addNoder(address _noder) external onlyGuard{
        //     noders.push(_noder);
        // }

        // function getTotalNoders()external view returns(uint256){
        //     return noders.length;
        // }

        function updatePresale(address _presale) external onlyOwner{
            presale = _presale;
        }

        function updateAirdrop(address _airdrop) external onlyOwner{
            airdrop = _airdrop;
        }

        function airdropTokens(address _account, uint256 _amount) external onlyOwner{
            super._transfer(rewardsPool, _account, _amount);
        }

    }