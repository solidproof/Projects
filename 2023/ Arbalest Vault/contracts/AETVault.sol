// SPDX-License-Identifier: MIT

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

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    function scaledBalanceOf(address user) external view returns (uint256);

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
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/SafeERC20.sol";
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
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
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
    function functionCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
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
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
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
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data
    ) internal view returns (bytes memory) {
        return
            functionStaticCall(
                target,
                data,
                "Address: low-level static call failed"
            );
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

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return
            functionDelegateCall(
                target,
                data,
                "Address: low-level delegate call failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
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

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
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
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(
            value
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
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
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
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

        bytes memory returndata = address(token).functionCall(
            data,
            "SafeERC20: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

pragma solidity >=0.6.0 <0.9.0;

/**
 * @title Initializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 */
contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private initializing;

    /**
     * @dev Modifier to use in the initializer function of a contract.
     */
    modifier initializer() {
        require(
            initializing || isConstructor() || !initialized,
            "Contract instance has already been initialized"
        );

        bool isTopLevelCall = !initializing;
        if (isTopLevelCall) {
            initializing = true;
            initialized = true;
        }

        _;

        if (isTopLevelCall) {
            initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(initializing, "Initializable: contract is not initializing");
        _;
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function isConstructor() private view returns (bool) {
        // extcodesize checks the size of the code stored in an address, and
        // address returns the current address. Since the code is still not
        // deployed when running a constructor, any checks on its code size will
        // yield zero, making it an effective way to detect if a contract is
        // under construction or not.
        address self = address(this);
        uint256 cs;
        assembly {
            cs := extcodesize(self)
        }
        return cs == 0;
    }

    // Reserved storage space to allow for layout changes in the future.
    uint256[50] private ______gap;
}

pragma solidity >=0.6.0 <0.9.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context is Initializable {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.

    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {}

    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }

    uint256[50] private __gap;
}

pragma solidity >=0.6.0 <0.9.0;

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
contract Ownable is Initializable, Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */

    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    uint256[49] private __gap;
}

interface IUsedFarm {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function depositETH(
        address lendingPool,
        address onBehalfOf,
        uint16 referralCode
    ) external payable;

    function withdrawETH(
        address lendingPool,
        uint256 amount,
        address to
    ) external;

    function withdraw(address asset, uint256 amount, address to) external;
}

interface IUsedLpFarm {
    //view earned
    function earned(uint _tokenId) external view returns (uint256);

    // getAllReward
    function getAllReward() external;

    function harvestAndMerge(uint _from, uint _to) external;

    // Deposit LP tokens to MasterChef for CAKE allocation.
    function deposit(uint256 amount) external;

    // Withdraw LP tokens from MasterChef.
    function withdraw(address asset, uint256 amount, address to) external;

    function withdrawAndHarvest(uint _tokenId) external;

    function withdrawAndHarvestAll() external;
}

interface IAetZap {
    function swapTokenToLp(
        address _router,
        address _from,
        address lp,
        uint256 amount,
        address[] memory path1,
        address[] memory path2,
        address receiver
    ) external;

    function swapChrToLp(uint256 amount, address lp) external payable;
}

interface IMaLPNFT {
    function maGaugeTokensOfOwner(
        address _owner,
        address _gauge
    ) external view returns (uint256[] memory);
}

interface IWETH {
    function balanceOf(address) external returns (uint);

    function deposit() external payable;

    function withdraw(uint256) external;

    function approve(address guy, uint256 wad) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);

    function transfer(address to, uint value) external returns (bool);
}

interface IAETVault {
    function isMe() external view returns (bool);
}

contract AETVault is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public wantAddress;
    address public masterchefAddress;
    address public farmContractAddress;

    struct UserInfo {
        uint256 amount;
        uint256 shares;
        uint256 update;
        // uint256[] rewardDebt; // Reward debt. See explanation below.
    }

    struct EarnInfo {
        address token;
        uint256 amount;
    }

    mapping(address => UserInfo) public userInfo;

    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public userPending;

    address public govAddress;
    address public rToken;
    address public aetzap;
    address public lendingPool;
    bool public onlyGov = true;

    uint256 public wantLockedTotal = 0;
    uint256 public sharesTotal = 0;
    uint256 public accSushiPerShare = 0;
    uint8 public poolType = 0; // poolType == 0 lp  , poolType ===1 token ,poolType ===w weth ,poolType ===3 aet

    address public constant maNFTs = 0x9774Ae804E6662385F5AB9b01417BC2c6E548468;

    address public constant CHR = 0x15b2fb8f08E4Ac1Ce019EADAe02eE92AeDF06851;

    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    receive() external payable {}

    function sharesInfo() public view returns (uint256, uint256) {
        return (wantLockedTotal, sharesTotal);
    }

    function initialize(
        address _masterchefAddress,
        address _wantAddress,
        address _farmContractAddress,
        uint8 _poolType,
        address _rToken,
        address _aetzap,
        address _lendingPool
    ) public initializer {
        Ownable.__Ownable_init();
        govAddress = msg.sender;
        wantAddress = _wantAddress;
        masterchefAddress = _masterchefAddress;
        farmContractAddress = _farmContractAddress;
        poolType = _poolType;
        rToken = _rToken;
        aetzap = _aetzap;
        lendingPool = _lendingPool;
    }

    uint256 public lastStakeAmount = 0;

    function changePoolType(uint8 _type) public {
        require(msg.sender == govAddress);
        poolType = _type;
    }

    function changeWant(address _want) public onlyOwner {
        wantAddress = _want;
    }

    function setLastStakeAmount() public {
        require(
            msg.sender == masterchefAddress ||
                IAETVault(address(this)).isMe() ||
                msg.sender == govAddress
        );

        if (rToken != address(0x0)) {
            uint256 rBalance = IERC20(rToken).balanceOf(address(this));
            lastStakeAmount = rBalance;
        }
    }

    function isMe() external view returns (bool) {
        if (msg.sender == address(this)) return true;
        return false;
    }

    function deposit(
        address _userAddress,
        uint256 _wantAmt
    ) public returns (uint256) {
        require(
            msg.sender == masterchefAddress || IAETVault(address(this)).isMe()
        );
        earn();
        onHarvest(_userAddress);

        uint256 sharesAdded = _wantAmt;
        wantLockedTotal = wantLockedTotal.add(_wantAmt);

        sharesTotal = sharesTotal.add(sharesAdded);
        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        if (poolType == 0 && _wantAmt > 0) {
            IERC20(wantAddress).safeApprove(
                address(farmContractAddress),
                _wantAmt
            );
            IUsedLpFarm(farmContractAddress).deposit(_wantAmt);
        }
        if (poolType == 1 && _wantAmt > 0) {
            IERC20(wantAddress).safeApprove(
                address(farmContractAddress),
                _wantAmt
            );
            IUsedFarm(farmContractAddress).deposit(
                wantAddress,
                _wantAmt,
                address(this),
                0
            );
        }

        if (poolType == 2 && _wantAmt > 0) {
            IWETH(WETH).withdraw(_wantAmt);
            IUsedFarm(farmContractAddress).depositETH{value: _wantAmt}(
                lendingPool,
                address(this),
                0
            );
        }

        onRewardEarn(_userAddress, sharesAdded, 0);

        return sharesAdded;
    }

    function _approveTokenIfNeeded(address token, address _router) private {
        if (IERC20(token).allowance(address(this), _router) == 0) {
            IERC20(token).safeApprove(_router, uint256(2 ** 256 - 1));
        }
    }

    function earn() public {
        require(
            msg.sender == masterchefAddress ||
                IAETVault(address(this)).isMe() ||
                msg.sender == govAddress
        );

        uint256 _sharesTotal = sharesTotal;
        uint256 rewards;

        if (poolType == 0) {
            IUsedLpFarm(farmContractAddress).withdrawAndHarvestAll();
            // zap chr to lp
            uint256 cBalance = IERC20(CHR).balanceOf(address(this));
            _approveTokenIfNeeded(CHR, aetzap);
            try IAetZap(aetzap).swapChrToLp(cBalance, wantAddress) {} catch {}

            uint256 totalToken = IERC20(wantAddress).balanceOf(address(this));
            rewards = totalToken - sharesTotal;
            if (rewards > 0) {
                IERC20(wantAddress).safeApprove(
                    address(farmContractAddress),
                    rewards
                );
                IUsedLpFarm(farmContractAddress).deposit(rewards);
            }
        } else if (poolType == 1) {
            uint256 rBalance = IERC20(rToken).balanceOf(address(this));
            rewards = rBalance - lastStakeAmount;
            IUsedFarm(farmContractAddress).withdraw(
                wantAddress,
                rBalance,
                address(this)
            );
            IERC20(wantAddress).safeApprove(
                address(farmContractAddress),
                rBalance
            );
            IUsedFarm(farmContractAddress).deposit(
                wantAddress,
                rBalance,
                address(this),
                0
            );
        } else if (poolType == 2) {
            uint256 rBalance = IERC20(rToken).balanceOf(address(this));
            rewards = rBalance - lastStakeAmount;
            IERC20(rToken).safeApprove(address(farmContractAddress), rBalance);
            IUsedFarm(farmContractAddress).withdrawETH(
                lendingPool,
                rBalance,
                address(this)
            );

            IUsedFarm(farmContractAddress).depositETH{value: rBalance}(
                lendingPool,
                address(this),
                0
            );
        }

        if (_sharesTotal > 0 && poolType != 3) {
            accSushiPerShare = accSushiPerShare.add(
                rewards.mul(1e12).div(_sharesTotal)
            );
        }
    }

    function pendingEarn(
        address _userAddress
    ) public view returns (EarnInfo memory) {
        UserInfo memory user = userInfo[_userAddress];
        uint256 pending;
        uint256 rewardDebt_ = rewardDebt[_userAddress];

        pending = user.shares.mul(accSushiPerShare).div(1e12).sub(rewardDebt_);
        uint256 allPending = userPending[_userAddress] + pending;

        EarnInfo memory earnInfo = EarnInfo({
            token: wantAddress,
            amount: allPending
        });

        return earnInfo;
    }

    function withdraw(
        address _userAddress,
        uint256 _wantAmt
    ) public returns (uint256) {
        require(_wantAmt >= 0, "_wantAmt < 0");
        require(
            msg.sender == masterchefAddress || IAETVault(address(this)).isMe()
        );
        earn();
        onHarvest(_userAddress);
        if (wantLockedTotal < _wantAmt) {
            _wantAmt = wantLockedTotal;
        }

        uint256 sharesRemoved = _wantAmt;
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        wantLockedTotal = wantLockedTotal.sub(_wantAmt);

        sharesTotal = sharesTotal.sub(sharesRemoved);
        if (poolType == 0) {
            earn();
            IUsedLpFarm(farmContractAddress).withdrawAndHarvestAll();
            IERC20(wantAddress).safeTransfer(masterchefAddress, _wantAmt);
            uint256 totalAmount = IERC20(wantAddress).balanceOf(address(this));
            IERC20(wantAddress).safeApprove(
                address(farmContractAddress),
                totalAmount
            );
            IUsedLpFarm(farmContractAddress).deposit(totalAmount);
        }
        if (poolType == 1) {
            IUsedFarm(farmContractAddress).withdraw(
                wantAddress,
                _wantAmt,
                address(this)
            );
            IERC20(wantAddress).safeTransfer(masterchefAddress, _wantAmt);
        }

        if (poolType == 2) {
            IERC20(rToken).safeApprove(address(farmContractAddress), _wantAmt);
            IUsedFarm(farmContractAddress).withdrawETH(
                lendingPool,
                _wantAmt,
                address(this)
            );
            IWETH(WETH).deposit{value: _wantAmt}();
            IERC20(wantAddress).safeTransfer(masterchefAddress, _wantAmt);
        }
        if (poolType == 3) {
            IERC20(wantAddress).safeTransfer(masterchefAddress, _wantAmt);
        }
        onRewardEarn(_userAddress, sharesRemoved, 1);

        return sharesRemoved;
    }

    function harvest(address _userAddress) public {
        uint256 pending = pendingEarn(_userAddress).amount;
        if (pending > 0) {
            if (poolType == 0) {
                withdraw(_userAddress, 0);

                IUsedLpFarm(farmContractAddress).withdrawAndHarvestAll();
                uint256 totalAmount = IERC20(wantAddress).balanceOf(
                    address(this)
                );
                uint256 totalAmount1 = totalAmount - pending;
                if (totalAmount1 < wantLockedTotal) {
                    return;
                }
                IERC20(wantAddress).safeTransfer(_userAddress, pending);
                IERC20(wantAddress).safeApprove(
                    address(farmContractAddress),
                    totalAmount1
                );
                IUsedLpFarm(farmContractAddress).deposit(totalAmount1);
            }
            if (poolType == 1) {
                deposit(_userAddress, 0);
                uint256 rBalance = IERC20(rToken).balanceOf(address(this));
                uint256 totalAmount1 = rBalance - pending;
                if (totalAmount1 < wantLockedTotal) {
                    return;
                }
                IUsedFarm(farmContractAddress).withdraw(
                    wantAddress,
                    pending,
                    address(this)
                );
                IERC20(wantAddress).safeTransfer(_userAddress, pending);
            }

            if (poolType == 2) {
                deposit(_userAddress, 0);
                uint256 rBalance = IERC20(rToken).balanceOf(address(this));

                uint256 totalAmount1 = rBalance - pending;
                if (totalAmount1 < wantLockedTotal) {
                    return;
                }
                IERC20(rToken).safeApprove(
                    address(farmContractAddress),
                    pending
                );
                IUsedFarm(farmContractAddress).withdrawETH(
                    lendingPool,
                    pending,
                    address(this)
                );
                _safeTransferETH(_userAddress, pending);
            }
        }

        userPending[_userAddress] = 0;
    }

    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "ETH_TRANSFER_FAILED");
    }

    function onHarvest(address _userAddress) internal {
        UserInfo storage user = userInfo[_userAddress];
        uint256 pending;
        uint256 rewardDebt_ = rewardDebt[_userAddress];

        pending = user.shares.mul(accSushiPerShare).div(1e12).sub(rewardDebt_);
        if (pending > 0) {
            userPending[_userAddress] = userPending[_userAddress] + pending;
        }
    }

    function onRewardEarn(
        address _userAddress,
        uint256 _userSharesAdd,
        uint8 _type
    ) internal {
        UserInfo storage user = userInfo[_userAddress];
        uint256 shares = user.shares.add(_userSharesAdd);
        if (_type == 0) {
            shares = user.shares.add(_userSharesAdd);
        }
        if (_type == 1) {
            shares = user.shares.sub(_userSharesAdd);
        }
        setLastStakeAmount();
        rewardDebt[_userAddress] = shares.mul(accSushiPerShare).div(1e12);
        user.shares = shares;
    }

    function safeTokenTransfer(
        address _to,
        uint256 _amt,
        address token
    ) internal {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (_amt > bal) {
            IERC20(token).transfer(_to, bal);
        } else {
            IERC20(token).transfer(_to, _amt);
        }
    }

    function setMasterchef(address _masterchefAddress) public {
        require(msg.sender == govAddress, "!gov");
        masterchefAddress = _masterchefAddress;
    }

    function setLendingPool(address _lendingPool) public {
        require(msg.sender == govAddress, "!gov");
        lendingPool = _lendingPool;
    }

    function setRToken(address _rToken) public {
        require(msg.sender == govAddress, "!gov");
        rToken = _rToken;
    }

    function setAetzap(address _aetzap) public {
        require(msg.sender == govAddress, "!gov");
        aetzap = _aetzap;
    }

    function setOnlyGov(bool _onlyGov) public {
        require(msg.sender == govAddress, "!gov");
        onlyGov = _onlyGov;
    }
}