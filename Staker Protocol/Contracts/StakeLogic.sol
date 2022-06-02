// File: @openzeppelin/contracts/access/IAccessControl.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.4;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// File: @openzeppelin/contracts/utils/Context.sol

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.4;

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

// File: @openzeppelin/contracts/utils/Strings.sol

// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.4;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.4;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/utils/introspection/ERC165.sol

// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.4;

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// File: @openzeppelin/contracts/access/AccessControl.sol

// OpenZeppelin Contracts v4.4.1 (access/AccessControl.sol)

pragma solidity ^0.8.4;




/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// File: StakeLogic.sol

pragma solidity ^0.8.4;

// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


interface ISwap {
    /**
     * @dev Pricing function for converting between TRX && Tokens.
   * @param input_amount Amount of TRX or Tokens being sold.
   * @param input_reserve Amount of TRX or Tokens (input type) in exchange reserves.
   * @param output_reserve Amount of TRX or Tokens (output type) in exchange reserves.
   * @return Amount of TRX or Tokens bought.
   */
    function getInputPrice(
        uint256 input_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) external view returns (uint256);

    /**
     * @dev Pricing function for converting between TRX && Tokens.
   * @param output_amount Amount of TRX or Tokens being bought.
   * @param input_reserve Amount of TRX or Tokens (input type) in exchange reserves.
   * @param output_reserve Amount of TRX or Tokens (output type) in exchange reserves.
   * @return Amount of TRX or Tokens sold.
   */
    function getOutputPrice(
        uint256 output_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) external view returns (uint256);

    /**
     * @notice Convert TRX to Tokens.
   * @dev User specifies exact input (msg.value) && minimum output.
   * @param min_tokens Minimum Tokens bought.
   * @return Amount of Tokens bought.
   */
    function trxToTokenSwapInput(uint256 min_tokens)
    external
    payable
    returns (uint256);

    /**
     * @notice Convert TRX to Tokens.
   * @dev User specifies maximum input (msg.value) && exact output.
   * @param tokens_bought Amount of tokens bought.
   * @return Amount of TRX sold.
   */
    function trxToTokenSwapOutput(uint256 tokens_bought)
    external
    payable
    returns (uint256);

    /**
     * @notice Convert Tokens to TRX.
   * @dev User specifies exact input && minimum output.
   * @param tokens_sold Amount of Tokens sold.
   * @param min_trx Minimum TRX purchased.
   * @return Amount of TRX bought.
   */
    function tokenToTrxSwapInput(uint256 tokens_sold, uint256 min_trx)
    external
    returns (uint256);

    /**
     * @notice Convert Tokens to TRX.
   * @dev User specifies maximum input && exact output.
   * @param trx_bought Amount of TRX purchased.
   * @param max_tokens Maximum Tokens sold.
   * @return Amount of Tokens sold.
   */
    function tokenToTrxSwapOutput(uint256 trx_bought, uint256 max_tokens)
    external
    returns (uint256);

    /***********************************|
    |         Getter Functions          |
    |__________________________________*/

    /**
     * @notice Public price function for TRX to Token trades with an exact input.
   * @param trx_sold Amount of TRX sold.
   * @return Amount of Tokens that can be bought with input TRX.
   */
    function getTrxToTokenInputPrice(uint256 trx_sold)
    external
    view
    returns (uint256);

    /**
     * @notice Public price function for TRX to Token trades with an exact output.
   * @param tokens_bought Amount of Tokens bought.
   * @return Amount of TRX needed to buy output Tokens.
   */
    function getTrxToTokenOutputPrice(uint256 tokens_bought)
    external
    view
    returns (uint256);

    /**
     * @notice Public price function for Token to TRX trades with an exact input.
   * @param tokens_sold Amount of Tokens sold.
   * @return Amount of TRX that can be bought with input Tokens.
   */
    function getTokenToTrxInputPrice(uint256 tokens_sold)
    external
    view
    returns (uint256);

    /**
     * @notice Public price function for Token to TRX trades with an exact output.
   * @param trx_bought Amount of output TRX.
   * @return Amount of Tokens needed to buy output TRX.
   */
    function getTokenToTrxOutputPrice(uint256 trx_bought)
    external
    view
    returns (uint256);

    /**
     * @return Address of Token that is sold on this exchange.
   */
    function tokenAddress() external view returns (address);

    function tronBalance() external view returns (uint256);

    function tokenBalance() external view returns (uint256);

    function getTrxToLiquidityInputPrice(uint256 trx_sold)
    external
    view
    returns (uint256);

    function getLiquidityToReserveInputPrice(uint256 amount)
    external
    view
    returns (uint256, uint256);

    function txs(address owner) external view returns (uint256);

    /***********************************|
    |        Liquidity Functions        |
    |__________________________________*/

    /**
     * @notice Deposit TRX && Tokens (token) at current ratio to mint SWAP tokens.
   * @dev min_liquidity does nothing when total SWAP supply is 0.
   * @param min_liquidity Minimum number of SWAP sender will mint if total SWAP supply is greater than 0.
   * @param max_tokens Maximum number of tokens deposited. Deposits max amount if total SWAP supply is 0.
   * @return The amount of SWAP minted.
   */
    function addLiquidity(uint256 min_liquidity, uint256 max_tokens)
    external
    payable
    returns (uint256);

    /**
     * @dev Burn SWAP tokens to withdraw TRX && Tokens at current ratio.
   * @param amount Amount of SWAP burned.
   * @param min_trx Minimum TRX withdrawn.
   * @param min_tokens Minimum Tokens withdrawn.
   * @return The amount of TRX && Tokens withdrawn.
   */
    function removeLiquidity(
        uint256 amount,
        uint256 min_trx,
        uint256 min_tokens
    ) external returns (uint256, uint256);
}

interface IToken {
    function remainingMintableSupply() external view returns (uint256);

    function calculateTransferTaxes(address _from, uint256 _value) external view returns (uint256 adjustedValue, uint256 taxAmount);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function balanceOf(address who) external view returns (uint256);

    function mintedSupply() external returns (uint256);

    function allowance(address owner, address spender)
    external
    view
    returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
}

interface ITokenMint {

    function mint(address beneficiary, uint256 tokenAmount) external returns (uint256);

    function estimateMint(uint256 _amount) external returns (uint256);

    function remainingMintableSupply() external returns (uint256);
}

interface IStakerVault {

    function withdraw(uint256 tokenAmount) external;

}

contract StakeLogic is AccessControl {

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    using SafeMath for uint256;

    struct User {
        //Referral Info
        address upline;
        uint256 referrals;
        uint256 total_structure;

        //Long-term Referral Accounting
        uint256 direct_bonus;
        uint256 match_bonus;

        //Deposit Accounting
        uint256 deposits;
        uint256 deposit_time;

        //Payout and Roll Accounting
        uint256 payouts;
        uint256 rolls;

        //Upline Round Robin tracking
        uint256 ref_claim_pos;

        uint256 accumulatedDiv;
    }

    struct Airdrop {
        //Airdrop tracking
        uint256 airdrops;
        uint256 airdrops_received;
        uint256 last_airdrop;
    }

    struct Custody {
        address manager;
        address beneficiary;
        uint256 last_heartbeat;
        uint256 last_checkin;
        uint256 heartbeat_interval;
    }

    address public stakerVaultAddress;

    ITokenMint public tokenMint;
    IToken public pennyToken;
    IToken public stakerToken;
    IStakerVault public stakerVault;

    mapping(address => User) public users;
    mapping(address => Airdrop) public airdrops;
    mapping(address => Custody) public custody;

    uint256 public CompoundTax = 5;
    uint256 public ExitTax = 10;

    // uint256 public minTeamReferrals = 5;
    uint256 public shareFee = 25;
    uint256 public payoutRate = 90;
    uint256 public payoutRateScale = 100;
    uint256 public ref_depth  = 15;
    uint256 public deposit_ref_bonus  = 10;
    uint256 public claim_ref_bonus = 5;
    bool public refPayOutIsActive = true;

    uint256 public minimumInitial = 10e18;
    uint256 public minimumAmount = 1e18;

    uint256 public deposit_bracket_size = 10000e18;     // @BB 5% increase whale tax per 10000 tokens... 10 below cuts it at 50% since 5 * 10
    uint256 public max_payout_cap = 100000e18;          // 100k STAKER or 10% of supply
    uint256 public deposit_bracket_max = 10;  // sustainability fee is (bracket * 5)

    uint256[] public ref_balances;

    uint256 public total_airdrops;
    uint256 public total_users = 1;
    uint256 public total_deposited;
    uint256 public total_withdraw;
    uint256 public total_bnb;
    uint256 public total_txs;

    uint256 public constant MAX_UINT = 2**256 - 1;
    address public owner;


    event Upline(address indexed addr, address indexed upline);
    event NewDeposit(address indexed addr, uint256 amount);
    event Leaderboard(address indexed addr, uint256 referrals, uint256 total_deposits, uint256 total_payouts, uint256 total_structure);
    event DirectPayout(address indexed addr, address indexed from, uint256 amount);
    event MatchPayout(address indexed addr, address indexed from, uint256 amount);
    event BalanceTransfer(address indexed _src, address indexed _dest, uint256 _deposits, uint256 _payouts);
    event Withdraw(address indexed addr, uint256 amount);
    event LimitReached(address indexed addr, uint256 amount);
    event NewAirdrop(address indexed from, address indexed to, uint256 amount, uint256 timestamp);
    event ManagerUpdate(address indexed addr, address indexed manager, uint256 timestamp);
    event BeneficiaryUpdate(address indexed addr, address indexed beneficiary);
    event HeartBeatIntervalUpdate(address indexed addr, uint256 interval);
    event HeartBeat(address indexed addr, uint256 timestamp);
    event Checkin(address indexed addr, uint256 timestamp);

    /* ========== INITIALIZER ========== */

    // function initialize() external initializer {
    //     __Ownable_init();
    // }

    modifier OnlyGovernance {
        require(hasRole(GOVERNANCE_ROLE, _msgSender()), "Governance");
        _;
    }

    constructor(address _mintAddress, address _PennyTokenAddress, address _stakerTokenAddress, address _vaultAddress) public {

        //Only the mint should own its paired token
        tokenMint = ITokenMint(_mintAddress);

        owner = msg.sender;

        _setupRole(GOVERNANCE_ROLE, _msgSender());

        //Penny
        pennyToken = IToken(_PennyTokenAddress);

        //Staker
        stakerToken = IToken(_stakerTokenAddress);

        //IStakerVault
        stakerVaultAddress = _vaultAddress;
        stakerVault = IStakerVault(_vaultAddress);

        //Referral Balances
        ref_balances.push(2e8);
        ref_balances.push(3e8);
        ref_balances.push(5e8);
        ref_balances.push(8e8);
        ref_balances.push(13e8);
        ref_balances.push(21e8);
        ref_balances.push(34e8);
        ref_balances.push(55e8);
        ref_balances.push(89e8);
        ref_balances.push(144e8);
        ref_balances.push(233e8);
        ref_balances.push(377e8);
        ref_balances.push(510e8);
        ref_balances.push(887e8);
        ref_balances.push(1397e8);
    }

    //@dev Default payable is empty since Faucet executes trades and recieves BNB
    fallback() external payable {
        //Do nothing, BNB will be sent to contract when selling tokens
    }

    /****** Administrative Functions *******/

    function updateRefBalances(uint256 level, uint256 levelAmount) public OnlyGovernance {
        ref_balances[level - 1] = levelAmount;
    }

    function updateTokenMint(address _newTokenMint) public OnlyGovernance {
        tokenMint = ITokenMint(_newTokenMint);
    }

    function updateOwner(address _newOwner) public OnlyGovernance {
        owner = _newOwner;
    }

    function updatePennyToken(address _newPennyToken) public OnlyGovernance {
        pennyToken = IToken(_newPennyToken);
    }

    function updateStakerToken(address _newStakerToken) public OnlyGovernance {
    stakerToken = IToken(_newStakerToken);
    }

    function updateStakerVault(address _newStakerVault) public OnlyGovernance {
        stakerVaultAddress = _newStakerVault;
        stakerVault = IStakerVault(_newStakerVault);
    }

    function updatePayoutRate(uint256 _newPayoutRate) public OnlyGovernance {
        payoutRate = _newPayoutRate;
    }

    function updateRefDepth(uint256 _newRefDepth) public OnlyGovernance {
        ref_depth = _newRefDepth;
    }

    function updateDepositRefBonus(uint256 _newRefBonus) public OnlyGovernance {
        deposit_ref_bonus = _newRefBonus;
    }

    function updateClaimRefBonus(uint256 _newRefBonus) public OnlyGovernance {
        claim_ref_bonus = _newRefBonus;
    }

    function updateRefPayOutActivation(bool _isActive) public OnlyGovernance {
        refPayOutIsActive = _isActive;
    }

    function updateInitialDeposit(uint256 _newInitialDeposit) public OnlyGovernance {
        minimumInitial = _newInitialDeposit;
    }

    function updateMinimumAmountDeposit(uint256 _newMinimumAmountDeposit) public OnlyGovernance {
        minimumAmount = _newMinimumAmountDeposit;
    }

    function updateCompoundTax(uint256 _newCompoundTax) public OnlyGovernance {
        CompoundTax = _newCompoundTax;
    }

    function updateExitTax(uint256 _newExitTax) public OnlyGovernance {
        ExitTax = _newExitTax;
    }

    function updateDepositBracketSize(uint256 _newBracketSize) public OnlyGovernance {
        deposit_bracket_size = _newBracketSize;
    }

    function updateShareFee(uint256 _shareFee) public OnlyGovernance {
        shareFee = _shareFee;
    }

    // function updateMinTeamReferrals(uint256 newMinTeamReferrals) public OnlyGovernance {
    //     minTeamReferrals = newMinTeamReferrals;
    // }

    function updateMaxPayoutCap(uint256 _newPayoutCap) public OnlyGovernance {
        max_payout_cap = _newPayoutCap;
    }

    function updateDeposit_bracket_max(uint256 _newDepositBracketMax) public OnlyGovernance {
        deposit_bracket_max = _newDepositBracketMax;
    }

    function updateHoldRequirements(uint256[] memory _newRefBalances) public OnlyGovernance {
        require(_newRefBalances.length == ref_depth);
        delete ref_balances;
        for(uint8 i = 0; i < ref_depth; i++) {
            ref_balances.push(_newRefBalances[i]);
        }
    }

    /********** User Fuctions **************************************************/
    function checkin() public {
        address _addr = msg.sender;
        custody[_addr].last_checkin = block.timestamp;
        emit Checkin(_addr, custody[_addr].last_checkin);
    }

    //@dev Deposit specified STAKER amount supplying an upline referral
    function deposit(address _upline, uint256 _amount) external {

        address _addr = msg.sender;

        (uint256 realizedDeposit, uint256 taxAmount) = stakerToken.calculateTransferTaxes(_addr, _amount);
        uint256 _total_amount = realizedDeposit;

        //Checkin for custody management.
        checkin();

        require(_amount >= minimumAmount, "Minimum deposit");

        //If fresh account require a minimal amount of STAKER
        if (users[_addr].deposits == 0){
            require(_amount >= minimumInitial, "Initial deposit too low");
        }

        _setUpline(_addr, _upline);

        uint256 taxedDivs;
        // Claim if divs are greater than 1% of the deposit
        // if (claimsAvailable(_addr) > _amount / 100){
        //     uint256 claimedDivs = _claim(_addr, true);
        //     taxedDivs = claimedDivs.mul(SafeMath.sub(100, CompoundTax)).div(100); // 5% tax on compounding
        //     _total_amount += taxedDivs;
        //     taxedDivs = taxedDivs / 2;
        // }

        //Transfer STAKER to the contract
        require(
            stakerToken.transferFrom(
                _addr,
                address(stakerVaultAddress),
                _amount
            ),
            "STAKER token transfer failed"
        );

        /*
        User deposits 10;
        1 goes for tax, 9 are realized deposit
        */

        _deposit(_addr, _total_amount);

        if (refPayOutIsActive) {
            _refPayout(_addr, realizedDeposit + taxedDivs, deposit_ref_bonus);
        }

        emit Leaderboard(_addr, users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure);
        total_txs++;

    }

    //@dev Claim, transfer, withdraw from vault
    function claim() external {

        //Checkin for custody management.  If a user rolls for themselves they are active
        checkin();

        address _addr = msg.sender;

        _claim_out(_addr);
    }

    //@dev Claim and deposit;
    function roll() public {

        //Checkin for custody management.  If a user rolls for themselves they are active
        checkin();

        address _addr = msg.sender;

        _roll(_addr);
    }

    /********** Internal Fuctions **************************************************/

    //@dev Add direct referral and update team structure of upline
    function _setUpline(address _addr, address _upline) internal {
        /*
        1) User must not have existing up-line
        2) Up-line argument must not be equal to senders own address
        3) Senders address must not be equal to the owner
        4) Up-lined user must have a existing deposit
        */
        if(users[_addr].upline == address(0) && _upline != _addr && _addr != owner && (users[_upline].deposit_time > 0 || _upline == owner )) {
            users[_addr].upline = _upline;
            users[_upline].referrals++;

            emit Upline(_addr, _upline);

            total_users++;

            for(uint8 i = 0; i < ref_depth; i++) {
                if(_upline == address(0)) break;

                users[_upline].total_structure++;

                _upline = users[_upline].upline;
            }
        }
    }

    //@dev Deposit
    function _deposit(address _addr, uint256 _amount) internal {
        //Can't maintain upline referrals without this being set

        require(users[_addr].upline != address(0) || _addr == owner, "No upline");

        //stats
        users[_addr].deposits += _amount;
        users[_addr].deposit_time = block.timestamp;

        total_deposited += _amount;

        //events
        emit NewDeposit(_addr, _amount);

    }

    //Payout upline; Bonuses are from 5 - 30% on the 1% paid out daily; Referrals only help
    function _refPayout(address _addr, uint256 _amount, uint256 _refBonus) internal {
        //for deposit _addr is the sender/depositor

        address _up = users[_addr].upline;
        uint256 _bonus = _amount * _refBonus / 100; // 10% of amount
        uint256 _share = _bonus * shareFee / 100;   // 2.5% of amount
        uint256 _up_share = _bonus.sub(_share);     // 7.5% of amount
        bool _team_found = false;

        for(uint8 i = 0; i < ref_depth; i++) {

            // If we have reached the top of the chain, the owner
            if(_up == address(0)){
                //The equivalent of looping through all available
                users[_addr].ref_claim_pos = ref_depth;
                break;
            }

            //We only match if the claim position is valid
            if(users[_addr].ref_claim_pos == i) {
                if (isBalanceCovered(_up, i + 1) && isNetPositive(_up)){

                    //Team wallets are split 75/25%
                    if(users[_up].referrals >= 5 && !_team_found) {

                        //This should only be called once
                        _team_found = true;

                        (uint256 gross_payout_upline,,,) = payoutOf(_up);
                        users[_up].accumulatedDiv = gross_payout_upline;
                        users[_up].deposits += _up_share;
                        users[_up].deposit_time = block.timestamp;

                        (uint256 gross_payout_addr,,,) = payoutOf(_addr);
                        users[_addr].accumulatedDiv = gross_payout_addr;
                        users[_addr].deposits += _share;
                        users[_addr].deposit_time = block.timestamp;

                        //match accounting
                        users[_up].match_bonus += _up_share;

                        //Synthetic Airdrop tracking; team wallets get automatic airdrop benefits
                        airdrops[_up].airdrops += _share;
                        airdrops[_up].last_airdrop = block.timestamp;
                        airdrops[_addr].airdrops_received += _share;

                        //Global airdrops
                        total_airdrops += _share;

                        //Events
                        emit NewDeposit(_addr, _share);
                        emit NewDeposit(_up, _up_share);

                        emit NewAirdrop(_up, _addr, _share, block.timestamp);
                        emit MatchPayout(_up, _addr, _up_share);
                    } else {

                        (uint256 gross_payout,,,) = payoutOf(_up);
                        users[_up].accumulatedDiv = gross_payout;
                        users[_up].deposits += _bonus;
                        users[_up].deposit_time = block.timestamp;


                        //match accounting
                        users[_up].match_bonus += _bonus;

                        //events
                        emit NewDeposit(_up, _bonus);
                        emit MatchPayout(_up, _addr, _bonus);
                    }

                    if (users[_up].upline == address(0)){
                        users[_addr].ref_claim_pos = ref_depth;
                    }

                    //The work has been done for the position; just break
                    break;
                }

                users[_addr].ref_claim_pos += 1;

            }

            _up = users[_up].upline;

        }

        //Reward the next
        users[_addr].ref_claim_pos += 1;

        //Reset if we've hit the end of the line
        if (users[_addr].ref_claim_pos >= ref_depth){
            users[_addr].ref_claim_pos = 0;
        }
    }

    //@dev General purpose heartbeat in the system used for custody/management planning
    function _heart(address _addr) internal {
        custody[_addr].last_heartbeat = block.timestamp;
        emit HeartBeat(_addr, custody[_addr].last_heartbeat);
    }

    //@dev Claim and deposit;
    function _roll(address _addr) internal {

        uint256 to_payout = _claim(_addr, false);

        uint256 payout_taxed;
        payout_taxed = to_payout.mul(SafeMath.sub(100, CompoundTax)).div(100); // 5% tax on compounding


        //Recycle baby!
        _deposit(_addr, payout_taxed);

        //track rolls for net positive
        users[_addr].rolls += payout_taxed;

        emit Leaderboard(_addr, users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure);
        total_txs++;

    }


    //@dev Claim, transfer, and topoff
    function _claim_out(address _addr) internal {

        uint256 to_payout = _claim(_addr, true);

        uint256 vaultBalance = stakerToken.balanceOf(stakerVaultAddress);
        if (vaultBalance < to_payout) {
            uint256 differenceToMint = to_payout.sub(vaultBalance);
            tokenMint.mint(stakerVaultAddress, differenceToMint);
        }

        stakerVault.withdraw(to_payout);

        uint256 realizedPayout = to_payout.mul(SafeMath.sub(100, ExitTax)).div(100); // 10% tax on withdraw
        require(stakerToken.transfer(address(msg.sender), realizedPayout));

        emit Leaderboard(_addr, users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure);
        total_txs++;

    }

    //@dev Claim current payouts
    function _claim(address _addr, bool isClaimedOut) internal returns (uint256) {
        (uint256 _gross_payout, uint256 _max_payout, uint256 _to_payout, uint256 _sustainability_fee) = payoutOf(_addr);
        require(users[_addr].payouts < _max_payout, "Full payouts");

        // Deposit payout
        if(_to_payout > 0) {

            // payout remaining allowable divs if exceeds
            if(users[_addr].payouts + _to_payout > _max_payout) {
                _to_payout = _max_payout.safeSub(users[_addr].payouts);
            }

            users[_addr].payouts += _gross_payout;

            if (!isClaimedOut && refPayOutIsActive){
                //Payout referrals
                uint256 compoundTaxedPayout = _to_payout.mul(SafeMath.sub(100, CompoundTax)).div(100); // 5% tax on compounding
                _refPayout(_addr, compoundTaxedPayout, claim_ref_bonus);
            }
        }

        require(_to_payout > 0, "Zero payout");

        //Update the payouts
        total_withdraw += _to_payout;

        //Update time!
        users[_addr].deposit_time = block.timestamp;
        users[_addr].accumulatedDiv = 0;

        emit Withdraw(_addr, _to_payout);

        if(users[_addr].payouts >= _max_payout) {
            emit LimitReached(_addr, users[_addr].payouts);
        }

        return _to_payout;
    }

    /********* Views ***************************************/

    //@dev Returns true if the address is net positive
    function isNetPositive(address _addr) public view returns (bool) {

        (uint256 _credits, uint256 _debits) = creditsAndDebits(_addr);

        return _credits > _debits;

    }

    //@dev Returns the total credits and debits for a given address
    function creditsAndDebits(address _addr) public view returns (uint256 _credits, uint256 _debits) {
        User memory _user = users[_addr];
        Airdrop memory _airdrop = airdrops[_addr];

        _credits = _airdrop.airdrops + _user.rolls + _user.deposits;
        _debits = _user.payouts;

    }

    //@dev Returns whether BR34P balance matches level
    function isBalanceCovered(address _addr, uint8 _level) public view returns (bool) {
        if (users[_addr].upline == address(0)){
            return true;
        }
        return balanceLevel(_addr) >= _level;
    }

    //@dev Returns the level of the address
    function balanceLevel(address _addr) public view returns (uint8) {
        uint8 _level = 0;
        for (uint8 i = 0; i < ref_depth; i++) {
            if (pennyToken.balanceOf(_addr) < ref_balances[i]) break;
            _level += 1;
        }

        return _level;
    }

    //@dev Returns custody info of _addr
    function getCustody(address _addr) public view returns (address _beneficiary, uint256 _heartbeat_interval, address _manager) {
        return (custody[_addr].beneficiary, custody[_addr].heartbeat_interval, custody[_addr].manager);
    }

    //@dev Returns account activity timestamps
    function lastActivity(address _addr) public view returns (uint256 _heartbeat, uint256 _lapsed_heartbeat, uint256 _checkin, uint256 _lapsed_checkin) {
        _heartbeat = custody[_addr].last_heartbeat;
        _lapsed_heartbeat = block.timestamp.safeSub(_heartbeat);
        _checkin = custody[_addr].last_checkin;
        _lapsed_checkin = block.timestamp.safeSub(_checkin);
    }

    //@dev Returns amount of claims available for sender
    function claimsAvailable(address _addr) public view returns (uint256) {
        (uint256 _gross_payout, uint256 _max_payout, uint256 _to_payout, uint256 _sustainability_fee) = payoutOf(_addr);
        return _to_payout;
    }

    //@dev Maxpayout of 3.65 of deposit
    function maxPayoutOf(uint256 _amount) public view returns(uint256) {
        return _amount * 365 * payoutRate / payoutRateScale / 100;
    }

    function sustainabilityFeeV2(address _addr, uint256 _pendingDiv) public view returns (uint256) {
        uint256 _bracket = users[_addr].payouts.add(_pendingDiv).div(deposit_bracket_size);
        _bracket = SafeMath.min(_bracket, deposit_bracket_max);
        return _bracket * 5;
    }

    //@dev Calculate the current payout and maxpayout of a given address
    function payoutOf(address _addr) public view returns(uint256 payout, uint256 max_payout, uint256 net_payout, uint256 sustainability_fee) {
        //The max_payout is capped so that we can also cap available rewards daily
        max_payout = maxPayoutOf(users[_addr].deposits).min(max_payout_cap);

        uint256 share;

        if(users[_addr].payouts < max_payout) {

            //Using 1e18 we capture all significant digits when calculating available divs
            share = users[_addr].deposits.mul(1e18 * payoutRate / payoutRateScale).div(100e18).div(24 hours); //divide the profit by payout rate and seconds in the day

            payout = share * block.timestamp.safeSub(users[_addr].deposit_time);

            payout += users[_addr].accumulatedDiv;

            // payout remaining allowable divs if exceeds
            if(users[_addr].payouts + payout > max_payout) {
                payout = max_payout.safeSub(users[_addr].payouts);
            }

            uint256 _fee = sustainabilityFeeV2(_addr, payout);

            sustainability_fee = payout * _fee / 100;

            net_payout = payout.safeSub(sustainability_fee);

        }
    }

    //@dev Get current user snapshot
    function userInfo(address _addr) external view returns(address upline, uint256 deposit_time, uint256 deposits, uint256 payouts, uint256 direct_bonus, uint256 match_bonus, uint256 last_airdrop) {
        return (users[_addr].upline, users[_addr].deposit_time, users[_addr].deposits, users[_addr].payouts, users[_addr].direct_bonus, users[_addr].match_bonus, airdrops[_addr].last_airdrop);
    }

    //@dev Get user totals
    function userInfoTotals(address _addr) external view returns(uint256 referrals, uint256 total_deposits, uint256 total_payouts, uint256 total_structure, uint256 airdrops_total, uint256 airdrops_received) {
        return (users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure, airdrops[_addr].airdrops, airdrops[_addr].airdrops_received);
    }

    //@dev Get contract snapshot
    function contractInfo() external view returns(uint256 _total_users, uint256 _total_deposited, uint256 _total_withdraw, uint256 _total_bnb, uint256 _total_txs, uint256 _total_airdrops) {
        return (total_users, total_deposited, total_withdraw, total_bnb, total_txs, total_airdrops);
    }

    /////// Airdrops ///////

    //@dev Send specified STAKER amount supplying an upline referral
    function batchAirdrop(address[] memory _addresses, uint256 _amount) external {

        address _addr = msg.sender;

        (uint256 _realizedAmount, uint256 taxAmount) = stakerToken.calculateTransferTaxes(_addr, _amount);
        //This can only fail if the balance is insufficient
        require(
            stakerToken.transferFrom(
                _addr,
                address(stakerVaultAddress),
                _amount
            ),
            "STAKER to contract transfer failed; check balance and allowance, airdrop"
        );
        _realizedAmount = _realizedAmount / _addresses.length;
        for (uint i = 0; i < _addresses.length; i++) {

            address _to = _addresses[i];

            //Make sure _to exists in the system; we increase
            require(users[_to].upline != address(0), "_to not found");

            (uint256 gross_payout,,,) = payoutOf(_to);

            users[_to].accumulatedDiv = gross_payout;

            //Fund to deposits (not a transfer)
            users[_to].deposits += _realizedAmount;
            users[_to].deposit_time = block.timestamp;

            //User stats
            airdrops[_addr].airdrops += _realizedAmount;
            airdrops[_addr].last_airdrop = block.timestamp;
            airdrops[_to].airdrops_received += _realizedAmount;

            //Keep track of overall stats
            total_airdrops += _realizedAmount;
            total_txs += 1;


            //Let em know!
            emit NewAirdrop(_addr, _to, _realizedAmount, block.timestamp);
            emit NewDeposit(_to, _realizedAmount);
        }

    }

        //@dev Send specified STAKER amount supplying an upline referral
    function airdrop(address _to, uint256 _amount) external {

        address _addr = msg.sender;

        (uint256 _realizedAmount, uint256 taxAmount) = stakerToken.calculateTransferTaxes(_addr, _amount);
        //This can only fail if the balance is insufficient
        require(
            stakerToken.transferFrom(
                _addr,
                address(stakerVaultAddress),
                _amount
            ),
            "STAKER to contract transfer failed; check balance and allowance, airdrop"
        );

        //Make sure _to exists in the system; we increase
        require(users[_to].upline != address(0), "_to not found");

        (uint256 gross_payout,,,) = payoutOf(_to);

        users[_to].accumulatedDiv = gross_payout;

        //Fund to deposits (not a transfer)
        users[_to].deposits += _realizedAmount;
        users[_to].deposit_time = block.timestamp;

        //User stats
        airdrops[_addr].airdrops += _realizedAmount;
        airdrops[_addr].last_airdrop = block.timestamp;
        airdrops[_to].airdrops_received += _realizedAmount;

        //Keep track of overall stats
        total_airdrops += _realizedAmount;
        total_txs += 1;


        //Let em know!
        emit NewAirdrop(_addr, _to, _realizedAmount, block.timestamp);
        emit NewDeposit(_to, _realizedAmount);
    }

}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    /**
     * @dev Multiplies two numbers, throws on overflow.
   */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
   */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
   */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /* @dev Subtracts two numbers, else returns zero */
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b > a) {
            return 0;
        } else {
            return a - b;
        }
    }

    /**
     * @dev Adds two numbers, throws on overflow.
   */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}