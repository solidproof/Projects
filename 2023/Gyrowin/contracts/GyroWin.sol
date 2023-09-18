// SPDX-License-Identifier: BSD-3-Clause


pragma solidity ^0.8.1;

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


pragma solidity ^0.8.0;

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


pragma solidity ^0.8.0;

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
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}


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

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
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
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
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

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
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
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}


pragma solidity = 0.8.19;

/**
* Welcome to Gyrowin,
* Gyrowin is a decentralised cross-chain gaming and defi platform,
* which let's user play lottery and earn interest on their winnings
* through lending available within the platform.
* Users will also be able to borrow token to play lottery with zero liquidation on their collateral.
* Moreover, Gyrowin also introduces the new fun way to stake Gyrowin token in Binance chain
* with multiple rewards sources resulting in higher yield for the participants.
* https://gyro.win
*/

contract Gyrowin {

    string public constant name = "GW TEST";
    string public constant symbol = "GWS";
    uint8 public constant decimals = 18;
    uint256 public constant maxTotalSupply = 5000000000 * 10 ** decimals; // 5 billion Gyrowin

    // totalSupply denotes tokens that have been mined and locked including circulatingSupply
    uint256 private _totalSupply;

    // circulatingSupply denotes tokens that currently exists in circulation
    uint256 public circulatingSupply;

    // notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    // notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event NewOwner(address oldOwner, address newOwner);
    event NewMoneyPlantCA(address oldMoneyPlantCA, address newMoneyPlantCA);
    event NewReserveCA(address oldReserveCA, address NewReserveCA);
    event NewTreasury(address oldTreasury, address NewTreasury);
    event NewFreezeLockCA(address oldFreezeLocakCA, address NewFreezeLockCA);
    event NewLoyaltyCA(address oldLoyaltyCA, address NewLoyaltyCA);
    event NewVestingCA(address oldVestingCA, address NewVestingCA);
    /// @notice An event thats emittied when users are able to trade token
    event TradingOpen(bool indexed boolean, uint256 openTime);
    /// @notice An event thats emitted when token are locked and circulating supply in decreased
    event LockInfo(address indexed account, uint256 amount, uint256 lockTime);
    /// @notice An event thats emitted when token are unlocked and circulating supply in increased back again
    event UnlockInfo(address indexed account, uint256 amount, uint256 lockTime);

    address private _owner;

    address private constant deadAddress = 0x000000000000000000000000000000000000dEaD;

    // money plant contract
    address private _moneyPlantCA;

    // treasury account
    address private _treasury;

    // vesting contract
    address private _vestingCA;

    // reserve contract
    address private _reserveCA;

    // cex listings & loyalty contract
    address private _loyaltyCA;

    // freeze lock contract
    address private _freezeLockCA;


    /**
     * @notice Construct a new Gyrowin token
    */
    bool private _initialize;
    function initialize(address owner) external {
        require(owner == address(0x05803c32E393765a204e22fCF560421729cbCA42), "GW: !owner");
        require(_initialize == false, "GW: initialized");
        _owner = owner;
        _balance[address(this)] = maxTotalSupply;

        _totalSupply = maxTotalSupply;
        circulatingSupply = maxTotalSupply;

        /// @notice buy/sell fee 1%
        _fee = 1;

        _gasPriceLimit = 5000000000 wei;

        // exclude fee for owner and this contract
        _excludedFee[owner] = true;
        _excludedFee[address(this)] = true;

        _initialize = true;
    }

    receive() payable external {}

    modifier onlyOwner() {
        require(isOwner(msg.sender), "GW: !owner"); _;
    }

    modifier onlyMoneyPlantCA() {
        require(isMoneyPlantCA(msg.sender), "GW: no money plant contract"); _;
    }

    modifier onlyOperatorCA() {
        require(isOperator(msg.sender), "GW: !operator"); _;
    }

    using SafeERC20 for IERC20;

    uint256 public _fee;

    /// @notice store trading start block by openTrading function
    uint256 private launchBlock;

    /// @notice initial gas price limit
    uint256 private _gasPriceLimit;

    /// @notice status of open trading
    bool private _openTrading;

    /// @notice status of buy/sell fee
    bool private lockedFee;

    /// @notice status of MEV restriction
    bool private releasedMEV;

    /// @notice to renounce transfering vesting tokens to vesting contract
    bool private vestingLock;

    /// @notice list operator
    mapping(address => bool) private _operator;
  
    /// @notice list buy/sell fee execluded account
    mapping(address => bool) private _excludedFee;

    /// @notice list token pair contract address
    mapping(address => bool) private _swapPair;

    /// @notice limited gas price for mev
    mapping(address => bool) private _mev;

    /// @notice notice Official record of token balances for each account
    mapping(address => uint256) private _balance;

    /// @notice notice Allowance amounts on behalf of others
    mapping(address => mapping(address => uint256)) private _allowance;

    /// @notice A record of each accounts delegate
    mapping(address => address) public _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping(address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping(address => uint256) public nonces;
 

    /// @notice The totalSupply method denotes the current circulating total supply of the tokens including lock
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    
    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(_msgSender(), spender, amount);

        return true;
    }


     /**
     * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
     * @param owner The address of the account holding the funds
     * @param spender The address of the account spending the funds
     * @return The number of tokens approved
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowance[owner][spender];
    }


    // This is an alternative to {approve} that can be used as a mitigation for problems described in {BEP20-approve}.
    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        _approve(_msgSender(), spender, _allowance[_msgSender()][spender] + (addedValue));

        return true;
    }


    // This is an alternative to {approve} that can be used as a mitigation for problems described in {BEP20-approve}.
    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        uint256 currentAllowance = _allowance[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "GW: decreased allowance below zero" );

        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

 
     /**
     * @notice Transfer `amount` tokens from `sender` to `recepient'
     * @param recipient The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address recipient, uint256 amount) external returns (bool) {
        require(recipient != address(0), "GW: can't transfer to the zero address");

        _transfer(_msgSender(), recipient, amount);

        return true;
    }


    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param sender The address of the source account
     * @param recipient The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(recipient != address(0), "GW: can't transfer to the zero address");
        require(sender != address(0), "GW: can't transfer from the zero address");
        
        _spendAllowance(sender, _msgSender(), amount);
        _transfer(sender, recipient, amount);

        return true;
    }


    /**
     * @notice Get the number of tokens held by the `account`
     * @param account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balance[account];
    }


    /**
     * burn and mint for money plant (staking)
     * burnAmount: the amount of burn
     * rewardAmount: the amount of mint
     * rewardAmount can not exceed the burnAmount
     * rewards revert when circulatingSupply is greater than 5% (4.75 billion) of max. total supply
     * circulatingSupply should be 4 billion at least
     */
    function moneyPlant(uint256 burnAmount, uint256 rewardAmount) external onlyMoneyPlantCA() returns (bool) {
        require(_balance[_treasury] >= burnAmount, "GW: burn amount exceeds treasury balance");
        require(rewardAmount <= burnAmount, "GW: reward amount exceeds burn amount");

        _totalSupply -= burnAmount;
        _balance[_treasury] -= burnAmount;
        circulatingSupply -= burnAmount;

        // burn game rewards
        emit Transfer(_treasury, deadAddress, burnAmount);

        // money plant extra rewards
        if (rewardAmount != 0) {
            circulatingSupply += rewardAmount;
            _balance[_treasury] += rewardAmount;

            emit Transfer(deadAddress, _treasury, rewardAmount);

            // totalSupply should be equal and less than 5% of max. total supply with the current run
            if (_totalSupply > maxTotalSupply * 95 / 100) {
                revert("GW: require more burn");
            }
        }

        // totalSupply should be equal to or greater than 20% of max. total supply
        if (_totalSupply < maxTotalSupply * 80 / 100) {
            revert("GW: total supply should be equal to or greater than 4 billion");
        }

        return true;
    }


    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {BEP20-_burn}.
     */
    function burn(uint256 amount) external returns (bool) {
        require(_msgSender() != address(0), "GW: burn from the zero address");
        require(_balance[_msgSender()] >= amount, "GW: burn amount exceeds balance");
        
        _burn(_msgSender(), amount);
        return true;
    }

    /**
     * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See {_burn} and {_approve}.
     */
    function burnFrom(address account, uint256 amount) external returns (bool) {
        require(account != address(0), "GW: burn from the zero address");
        require(_balance[account] >= amount, "GW: burn amount exceeds balance");

        address spender = _msgSender();
        _spendAllowance(account, spender, amount); // check for the allowance

        _burn(account, amount);

        return true;
    }


    /**
     * @notice Delegate votes from `_msgSender()` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) public {
        return _delegate(_msgSender(), delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                getChainId(),
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(
            signatory != address(0),
            "GW::delegateBySig: invalid signature"
        );
        require(
            nonce == nonces[signatory]++,
            "GW::delegateBySig: invalid nonce"
        );
        require(
            block.timestamp <= expiry,
            "GW::delegateBySig: signature expired"
        );
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view returns (uint256) {
        uint32 nCheckpoints = numCheckpoints[account];
        return
            nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "GW::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = _balance[delegator];
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address senderRep, address recepientRep, uint256 amount) internal {
        if (senderRep != recepientRep && amount > 0) {
            if (senderRep != address(0)) {
                uint32 senderRepNum = numCheckpoints[senderRep];
                uint256 senderRepOld = senderRepNum > 0
                    ? checkpoints[senderRep][senderRepNum - 1].votes
                    : 0;
                uint256 senderRepNew = senderRepOld - amount;
                _writeCheckpoint(
                    senderRep,
                    senderRepNum,
                    senderRepOld,
                    senderRepNew
                );
            }

            if (recepientRep != address(0)) {
                uint32 recepientRepNum = numCheckpoints[recepientRep];
                uint256 recepientRepOld = recepientRepNum > 0
                    ? checkpoints[recepientRep][recepientRepNum - 1].votes
                    : 0;
                uint256 recepientRepNew = recepientRepOld + amount;
                _writeCheckpoint(
                    recepientRep,
                    recepientRepNum,
                    recepientRepOld,
                    recepientRepNew
                );
            }
        }
    }

    function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint256 oldVotes, uint256 newVotes) internal {
        uint32 blockNumber = safe32(
            block.number,
            "GW::_writeCheckpoint: block number exceeds 32 bits"
        );

        if (
            nCheckpoints > 0 &&
            checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber
        ) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(
                blockNumber,
                newVotes
            );
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
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
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "GW: can't approve to the zero address");
        require(spender != address(0), "GW: can't approve to the zero address");

        _allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    /**
     * the following features added for standard erc20 _transfer function:
     * check either excluded account for buy/sell fee
     * enable to start swap & wallet transfer when _openTrading is true, otheriwse authorized account transfer only
     * check either swap or wallet transfer
     * added buy/sell fee if tranfer is swap
     * the fee goes to Money plant contract
     * first 4 block numbers has gas price limt with 5 gwei after _openTrading is true
     * and then gas limit for only mev if sender/receipient is in _mev variable
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(_balance[sender] >= amount, "GW: balance is insufficient");

        bool takeFee = true;
        if (_excludedFee[sender] || _excludedFee[recipient]) {
            takeFee = false;
        }

        // start trading
        if (_openTrading) {
            // take fees on buy/sell only, no fees on transfer
            if (_fee != 0 && (_swapPair[sender] || _swapPair[recipient]) && takeFee) {
                uint256 taxAmount = amount * _fee / 100;
                amount = amount - taxAmount;

                // tax distribute to Money plant
                transferToken(sender, _treasury, taxAmount);

                // help to protect honest holders from front-running
                if (block.number <= launchBlock + 3 && tx.gasprice > _gasPriceLimit) {
                    revert("GW: exceeded Gas Price");
                } else if (
                    (_mev[sender] || _mev[recipient]) && 
                    _gasPriceLimit != 0 &&
                    _gasPriceLimit < tx.gasprice
                    ) {
                    revert("GW: exceeded Gas Price");
                }
            }
            _moveDelegates(_delegates[sender], _delegates[recipient], amount);
            transferToken(sender, recipient, amount);
        // authorized account only
        } else if (_excludedFee[sender]) {
            _moveDelegates(_delegates[sender], _delegates[recipient], amount);
            transferToken(sender, recipient, amount);
        } else {
            revert("GW: trading has not been started");
        }
    }

    ///@notice normal token transfer
    function transferToken(address sender, address recipient, uint256 amount) internal {
        unchecked {
            _balance[sender] -= amount;
            _balance[recipient] += amount;
        }

         emit Transfer(sender, recipient, amount);
    }


    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the dead address.
     *
     */
    function _burn(address account, uint256 amount) internal {
        unchecked {
            _balance[account] -= amount;
            circulatingSupply -= amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, deadAddress, amount);

        // totalSupply should be equal to or greater than 20% of max. total supply
        if (_totalSupply < maxTotalSupply * 80 / 100) {
            revert("GW: total supply should be equal to or greater than 4 billion");
        }
    }


    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }


    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2 ** 32, errorMessage);
        return uint32(n);
    }


    function getChainId() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }


    function renounceOwnership(address dead) external onlyOwner() {
        require(dead == address(0), "GW: invalid address");
        _owner = address(0);
    }


    /**
     * @notice change the owner of the contract
     * @dev only callable by the owner
     * @param account new owner address
     */
    function updateOwner(address account) external onlyOwner() {
        require(account != address(0),"GW: invalid owner address");

        _owner = account;

        emit NewOwner(_owner, account);
    }


    /**
     * @notice change the operator of the contract
     * @dev only callable by the owner
     * @param contractAddr new operator address
     */
    function setOperator(address contractAddr, bool status) external onlyOwner() {
        require(isContract(contractAddr), "GW: !contract");
        require(
            contractAddr == _vestingCA ||
            contractAddr == _reserveCA ||
            contractAddr == _loyaltyCA ||
            contractAddr == _freezeLockCA,
            "GW: invalid operator"
            );

        if (status == true) {
            require(_operator[contractAddr] == false, "GW: already listed");
        }

        _operator[contractAddr] = status;
    }


    ///@notice update money plant contract address, another term for our staking system
    ///@dev only callable by the owner
    function updateMoneyPlantCA(address contractAddr) external onlyOwner() {
        require(isContract(contractAddr), "GW: !contract");

        _moneyPlantCA = contractAddr;

        emit NewMoneyPlantCA(_moneyPlantCA, contractAddr);
    }

    /// update treasury account
    /// @dev only callable by the owner
    function updateTreasury(address account) external onlyOwner() {
        _treasury = account;

        emit NewTreasury(_treasury, account);
    }

    /// update reserve contract address
    /// @dev only callable by the owner
    function updateReserveCA(address contractAddr) external onlyOwner() {
        require(isContract(contractAddr), "GW: !contract");

        _reserveCA = contractAddr;

        emit NewReserveCA(_reserveCA, contractAddr);
    }

    /// update loyalty contract address
    /// @dev only callable by the owner
    function updateLoyaltyCA(address contractAddr) external onlyOwner() {
        require(isContract(contractAddr), "GW: !contract");

        _loyaltyCA = contractAddr;

        emit NewLoyaltyCA(_loyaltyCA, contractAddr);
    }

    /// update freeze contract address
    /// @dev only callable by the owner
    function updatefreezeLockCA(address contractAddr) external onlyOwner() {
        require(isContract(contractAddr), "GW: !contract");

        _freezeLockCA = contractAddr;

        emit NewFreezeLockCA(_freezeLockCA, contractAddr);
    }

    /// update vesting contract address
    /// @dev only callable by the owner
    function updateVestingCA(address contractAddr) external onlyOwner() {
        require(isContract(contractAddr), "GW: !contract");
        
        _vestingCA = contractAddr;

        emit NewVestingCA(_vestingCA, contractAddr);
    }


    /// @notice check if the account address is the owner
    /// @dev call by the owner modifier
    function isOwner(address account) public view returns (bool) {
        return account == _owner;
    }

    /// @notice check if the contract address is the operator
    /// @dev call by the operator modifier
    function isOperator(address contractAddr) public view returns (bool) {
        return _operator[contractAddr];
    }

    /// @notice check if the address is the staking contract address (money plant)
    function isMoneyPlantCA(address account) public view returns (bool) {
        return account == _moneyPlantCA;
    }

    /// @notice check if the address is the vesting contract address
    function isVestingCA(address account) public view returns (bool) {
        return account == _vestingCA;
    }

    /// @notice check if the address is the reserve contract address
    function isReserveCA(address account) public view returns (bool) {
        return account == _reserveCA;
    }

    /// @notice check if the address is the loyalty contract address
    function isLoyaltyCA(address account) public view returns (bool) {
        return account == _loyaltyCA;
    }

    /// @notice check if the address is the freezelock contract address
    function isFreezeLockCA(address account) public view returns (bool) {
        return account == _freezeLockCA;
    }

     /// @notice check if the address is the treasury account
    function isTreasury(address account) public view returns (bool) {
        return account == _treasury;
    }


    /**
     * @notice set pair token address
     * @dev only callable by the owner
     * @param account address of the pair
     * @param pair check 
     */
    function setSwapPair(address account, bool pair) external onlyOwner() {
        require(account != address(0), "GW: can't be zero address");
        if (pair == true) {
            require(_swapPair[account] == false, "GW: already listed");
        }
        _swapPair[account] = pair;
    }

    /**
     * @notice check if the address is right pair address
     * @param account address of the swap pair
     * @return Account is valid pair or not
     */
    function isSwapPair(address account) public view returns (bool) {
        return _swapPair[account];
    }


    /**
     * @notice set mev to limit the swap gas price
     * @dev this setting is only valid with setGasLimit function and only callable by owner
     * @param account address of the mev
     * @param mev true to set the limit of address swap price
     */
    function setMEV(address[] calldata account, bool mev) external onlyOwner() {
        require(account.length > 0, "GW: empty accounts");
        for (uint256 i = 0; i < account.length; i++) {
            _mev[account[i]] = mev;
        }
    }


    /**
     * @notice set swap gas price limit to prevent mev
     * @dev if gasPriceLimit sets zero then no more limit possible forever with setMEV function
     * and only callable by owner
     * this setting is only valid with setMEV function
     * the minimum gas price is 3gwei
     * @param gasPriceLimit amount of gas limit
     */
    function setGasLimt(uint256 gasPriceLimit) external onlyOwner() {
        require(gasPriceLimit >= 3000000000 wei, "GW: min. gas price limit is 3gwei");
        require(releasedMEV == false, "GW: gas price limit renounced with zero");
        _gasPriceLimit = gasPriceLimit;
        if (_gasPriceLimit == 0) {
            // release gas price limit & mev forever
            releasedMEV = true;
        }
    }


    /**
     * @notice exclude trading fee(tax) for operators
     * @dev only callable by the owner
     * @param account address to be excluded
     * @param excluded set wether to be exluded or not
     */
    function excludedFeeAccount(address account, bool excluded) external onlyOwner() {
        if (excluded == true) {
            require(_excludedFee[account] == false, "GW: already listed");
        }
        _excludedFee[account] = excluded;
    }


    /**
     * @notice set fees
     * @dev only callable by the owner
     * @param fee buy and sell fee for the token
     * - requirements
     * require maximum 1% buy/sell fee
     * require zero buy/sell forever if _fee set to zero
     */
    function setFee(uint256 fee) external onlyOwner() {
        require(fee <= 1, "GW: max fee is 1%");
        require(lockedFee == false, "GW: fee renounced with zero");
        _fee = fee;
        if (_fee == 0) {
            // fee to zero forever
            lockedFee = true;
        }
    }


    /**
     * @dev Set when to open trading
     * @dev set block number to check when _openTrading is true
     * @dev Trading cannot be set false after it started
     */
    function openTrading(bool start) external onlyOwner() {
        require(!_openTrading, "GW: can't stop trading");
        launchBlock = block.number;
        _openTrading = start;

        // renounce transfering vesting tokens to vesting contract
        vestingLock = true;

        emit TradingOpen(start, block.timestamp);
    }


    /**
     * transfer tokens for lock and subtract it from circulatingSupply
     * renounce transferring automatically when trading opened
     */    
    function initializeLock(address contractAddr, uint256 amount) external onlyOperatorCA() {
        require(
            _swapPair[contractAddr] == true ||
            contractAddr == _vestingCA ||
            contractAddr == _reserveCA ||
            contractAddr == _loyaltyCA ||
            contractAddr == _freezeLockCA,
            "GW: invalid contract");
        require(amount <= _balance[address(this)], "GW: amount exceeds balance");

        if (!vestingLock && _swapPair[contractAddr] == false) {
            transferToken(address(this), contractAddr, amount);
        }
        
        // subtract locked token from circulatingSupply
        circulatingSupply -= amount;

        emit LockInfo(contractAddr, amount, block.timestamp);
    }

    
    // increase circulating supply by unlock    
    function addCirculatingSupply(address contractAddr, uint256 amount) external onlyOperatorCA() {
        require(
            contractAddr == _vestingCA ||
            contractAddr == _reserveCA ||
            contractAddr == _loyaltyCA ||
            contractAddr == _freezeLockCA,
            "GW: invalid contract"
            );
        require(amount <= _balance[contractAddr], "GW: amount exceeds balance");

        // add unlocked token to circulatingSupply
        circulatingSupply += amount;

        emit UnlockInfo(contractAddr, amount, block.timestamp);
    }


    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal {
        uint256 currentAllowance = this.allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {

            require(currentAllowance >= value, "GW: insufficent allowance");

            unchecked {
                _approve(owner, spender, currentAllowance - value);
            }
        }
    }


    /**
     * @notice rescue BNB sent to the address
     * @param amount to be retrieved from the contract
     * @param to address of the destination account
     * @dev only callable by the owner
     */
    function rescueBNB(uint256 amount, address payable to) external onlyOwner() {
        require(amount <= address(this).balance, "GW: insufficient funds");
        to.transfer(amount);
    }

    /**
     * @notice rescue BEP20 token sent to the address
     * @param amount to be retrieved for BEP20 contract
     * @param recipient address of the destination account
     * @dev only callable by the owner
     */
    function rescusBEP20Token(address token, address recipient, uint256 amount) external payable onlyOwner() {
        require(amount <= IERC20(token).balanceOf(address(this)), "GW: insufficient funds");
        IERC20(token).safeTransfer(recipient, amount);
    }   


    /**
     * @notice check if the address is contract
     * @param contractAddr address of the contract
     * @return check true if contractAddr is a contract
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     * 
     * @dev Among others, `isContract` will return false for the following
     * types of addresses:
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed

     */
    function isContract(address contractAddr) private view returns (bool check) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

        assembly {
            codehash := extcodehash(contractAddr)
        }
        return (codehash != accountHash && codehash != 0x0);
    } 
}
