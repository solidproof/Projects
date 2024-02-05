/**
 *Submitted for verification at BscScan.com on 2022-07-15
*/

/**
 *Submitted for verification at BscScan.com on 2022-07-12
*/

pragma solidity 0.8.0;


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
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


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


// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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
     * by making the `nonReentrant` function external, and making it call a
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
    function transferFrom(
        address from,
        address to,
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
contract ERC20 is Context, IERC20, IERC20Metadata, ReentrancyGuard {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name = "Vectous";
    string private _symbol = "VCT";

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    // constructor(string memory name_, string memory symbol_) {
    //     _name = name_;
    //     _symbol = symbol_;
    // }

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
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
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
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
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
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
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
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
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
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
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
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
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



contract Vectous is ERC20, Ownable {
    address private devWallet = 0x964216236CAa8F5133aB6A81F2Cb9cA1e8944171;
    address private tokenAddr = 0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee; // BUSD Testnet
    //address private tokenAddr = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // BUSD
	IERC20 public token_BUSD;

    constructor() {
        token_BUSD = IERC20(tokenAddr);
        daysStartingTimeStamp[1] = block.timestamp;
	    daysReturnPercent[1] = 100000; // 1%
        dayWithdrawFee[1] = 3000000; // 30%
    }

    event E_newEntry(
        address indexed addr,
        uint256 timestamp,
        uint256 amount
    );

    event E_getLoanOnDeposit(
        address indexed addr,
        uint256 timestamp,
        uint256 amount,
        uint256 returnAmount,
        uint256 Deposit_ID
    );

    event E_lendOnDeposit(
        address indexed addr,
        address loaner,
        uint256 timestamp,
        uint256 lenderLendId
    );


    /* Contract is active */
    bool public LAUNCHED = false;

    /* Contract's days are 6 hour long */
    uint256 public contractDay = 1;

    /* We use this to check for a new contract day */
    uint256 public CD_check;

    /* A Global % that adds up to the deposit value of the deposits creating from user deposot's profit */
    uint256 public fromProfit_globalVirtualAmountPercent = 6;

    /* Using this to dedicate a unique ID to every deposit */
    uint256 public _currentDepositID = 0;

    /* Loaning feature is paused? */
    bool public loaningIsPaused = true;

    /* current active BUSD entries (dedacating it 1 BUSD initiate amount) */
    uint256 public totalEntry_dynamic = 1 * 1e18;

    /* Saving timeStamp of start of each contract day */
    mapping(uint256 => uint256) public daysStartingTimeStamp;

    /* */
    mapping(address => uint256) public referralsBonus;

    /* Return percentage on deposits of every contract day (devides by 100000) */
    mapping(uint256 => uint256) public daysReturnPercent;
    mapping(uint256 => uint256) public dayWithdrawFee;
    uint256 public breakDuration = 1 days / 4;
    uint256 GpercentRate = 100000;
    uint256 public lastReturnPercentChangeTS;

    /* Mapping form investor to deposit IDs */
    mapping(address => uint256[]) public ownedDeposits;

    /* ___CONTRACT_GLOBAL_DATA___ */
    mapping(address => uint256) public TotalDeposited;
    mapping(address => uint256) public TotalWithdrawed;
    mapping(uint256 => uint256) public data_dailyEntry;
    mapping(uint256 => uint256) public data_dailyEntry_NoVirtualBonus;
    mapping(uint256 => uint256) public data_dailyEntryCount;
    uint256 public data_totalEntry;
    uint256 public data_totalCollectedReward;
    uint256 public data_totalEntry_NoVirtualBonus;
    uint256 public data_totalEntryCount;
    uint256 public data_allUsersCounter;
    uint256 public totalLoanFeePaid;
    uint256 public totalLoancount;
    /* ___CONTRACT_GLOBAL_DATA___ */



    /* Mapping for every address (includes all the addresses entries) */
    mapping(address => mapping(uint256 => _depositData)) public depositData;
    mapping(address => mapping(uint256 => _depositData_2)) public depositData_2;


    /* A struct for every entry */
    struct _depositData {
        address investor;
        address referrer;
        uint256 originalEntryAmount;
        uint256 Active_entryAmount;
        uint256 claimedAmount_dynamic;
        uint256 claimedAmount_Total;
        uint256 lastClaimedContractDay;
        uint256 lastClaimedTime;
        uint256 depositID;
        uint256 startDayOfNewAction;
        uint256 loansReturnAmount;
        bool ROIed;
    }

    struct _depositData_2 {
        address investor;
        bool deposit_hasLoan;
        bool deposit_forLoan;
    }


    /**
     * @dev Owner setting a global extra virtual amount % that adds up to new deposits creating from user deposit's profit
     */
    function Update_fromProfit_globalVirtualAmountPercent(uint256 num) external onlyOwner() {
        require(num >= 0);
        require(num <= 20);

        fromProfit_globalVirtualAmountPercent = num;
    }


    /**
     * @dev Owner switching the loaning feature status
     */
    function switchLoaningStatus() external onlyOwner() {
        if (loaningIsPaused == true) {
            loaningIsPaused = false;
        }
        else if (loaningIsPaused == false) {
            loaningIsPaused = true;
        }
    }


    /**
     * @dev Owner launching the contract
     */
    function DOLAUNCH() external onlyOwner() {
        CD_check = block.timestamp;
        LAUNCHED = true;
    }


    /**
     * @dev Checks for a new contract day.
     * - every contract day is 6 hours long, aka 21600 second.
     */
    function _globalDataCheck() public {
        require(LAUNCHED == true , "ERR: Contract not yet launched");
        require(block.timestamp > CD_check, "next day not reached yet");

        uint256 contractDayDuration = ((1 days / 24) / 60) * 5;
        uint256 timeCheck = (block.timestamp - CD_check) / contractDayDuration;

        if (timeCheck >= 1 ) {
            // next contract day: calc and save the return percentage for the new contract day
            contractDay ++ ;

	        // The interest rate begins at 1% and grows by 0.005% daily for six months. The interest rate is capped at 1.9%.
            // 0.005 / 4 = 0.00125 ==> * GpercentRate = 125
            daysReturnPercent[contractDay] = daysReturnPercent[contractDay -1] + 125;
            if (daysReturnPercent[contractDay] >= 190000) {
                daysReturnPercent[contractDay] = 190000;
            }
            if (dayWithdrawFee[contractDay] > 0) {
                // Users are charged a profit withdrawal fee of 30% on their first withdrawal. The fee reduces by 0.3% every day till it reaches 0% in 100 days
                // 0.3 / 4 = 0.075 ==> * GpercentRate = 7500
                dayWithdrawFee[contractDay] = dayWithdrawFee[contractDay -1] - 7500;
            } else {
                dayWithdrawFee[contractDay] = 0;
            }
            daysStartingTimeStamp[contractDay] = daysStartingTimeStamp[contractDay -1] + contractDayDuration;

            CD_check += contractDayDuration;
        }
    }


    /**
     * @dev External function for a new entry
     * @param referrerAddr address of referring user (optional; 0x0 for no referrer)
     * @param amount amount of BUSD entrying to lobby
     */
    function NewEntry(address referrerAddr, uint256 amount) external {
        require(LAUNCHED == true , "ERR: Contract not yet launched");
        require(amount > 0 , "ERR: Amount required");

        token_BUSD.transferFrom(msg.sender, address(this), amount);

        uint256 bonusAmount = 0;
        _newEntry(referrerAddr, amount, bonusAmount);
    }


    /**
     * @dev External function for a new entry creation from profits of one of the user's entries
     * NOTE in this case we add up an extra 10% virtual value to the entry
     * @param referrerAddr address of referring user (optional; 0x0 for no referrer)
     * @param Deposit_ID ID of the target deposit
     */
    function NewEntry_fromProfits(address referrerAddr, uint256 Deposit_ID) external {
        uint256 entryProfits = calcDepositReturn(msg.sender, Deposit_ID);
        require(entryProfits > 0);
        require(depositData_2[msg.sender][Deposit_ID].deposit_hasLoan == false);

        uint256 bonusAmount = entryProfits * fromProfit_globalVirtualAmountPercent / 100;

        depositData[msg.sender][Deposit_ID].lastClaimedTime = block.timestamp;
        depositData[msg.sender][Deposit_ID].lastClaimedContractDay = contractDay;
        depositData[msg.sender][Deposit_ID].claimedAmount_dynamic += entryProfits;

        _newEntry(referrerAddr, entryProfits, bonusAmount);
    }


    /**
     * @dev New user entry
     * @param _referrerAddr address of referrer (optional; 0x0 for no referrer)
     * @param _amount amount of BUSD entrying
     * @param _virtualBonusAmount the virtual amount of tokens dedicated to this entry
     */
    function _newEntry(address _referrerAddr, uint256 _amount, uint256 _virtualBonusAmount) internal {
        _globalDataCheck();

        uint256 Deposit_ID = _generateNextDepositID();
        ownedDeposits[msg.sender].push(Deposit_ID);

        uint256 referredBonus = 0;
        /*
            "referredBonus" ==> If user is referred, because of using a refferal link they will get 1% extra virtual amount on their deposit
            "referralsBonus" ==> Users by reffering others will receive 1.5% of their deposit amount saved up in a map for their next deposit, so the next deposit that they do they will receive all the bonus amount on top of their deposit amount
        */

        if (_referrerAddr != msg.sender) {
            /* No Self-referred */
            depositData[msg.sender][Deposit_ID].referrer = _referrerAddr;
            referredBonus = _amount * 10 /1000; // 1%
            referralsBonus[_referrerAddr] += _amount * 15 /1000; // 1.5%
        } else {
            depositData[msg.sender][Deposit_ID].referrer = address(0);
        }

        // pay the 2.7% dev fee
        uint256 devFee = _amount * 27 / 1000;
        _amount -= devFee;
        token_BUSD.transfer(address(devWallet), devFee);

        // setting/updating new entry data for the msg.sender address
        depositData[msg.sender][Deposit_ID].investor = msg.sender;
        depositData[msg.sender][Deposit_ID].depositID = Deposit_ID;
        depositData[msg.sender][Deposit_ID].originalEntryAmount = _amount + _virtualBonusAmount + referredBonus + referralsBonus[msg.sender];
        depositData[msg.sender][Deposit_ID].Active_entryAmount = _amount + _virtualBonusAmount + referredBonus + referralsBonus[msg.sender];
        depositData[msg.sender][Deposit_ID].lastClaimedTime = block.timestamp;
        depositData[msg.sender][Deposit_ID].lastClaimedContractDay = contractDay;
        depositData[msg.sender][Deposit_ID].startDayOfNewAction = contractDay;
        depositData[msg.sender][Deposit_ID].ROIed = false;

        depositData_2[msg.sender][Deposit_ID].deposit_hasLoan = false;
        depositData_2[msg.sender][Deposit_ID].deposit_forLoan = false;
        depositData_2[msg.sender][Deposit_ID].investor = msg.sender;

        // updating global data
        data_dailyEntry[contractDay] += _amount + _virtualBonusAmount + referralsBonus[msg.sender];
        data_dailyEntry_NoVirtualBonus[contractDay] += _amount;

        data_totalEntry += _amount + _virtualBonusAmount;
        data_totalEntry_NoVirtualBonus += _amount;

        data_dailyEntryCount[contractDay] ++;
        data_totalEntryCount ++;

        TotalDeposited[msg.sender] += _amount;

        if (ownedDeposits[msg.sender].length == 1) {
            data_allUsersCounter ++;
        }

        totalEntry_dynamic += (_amount + _virtualBonusAmount + referredBonus + referralsBonus[msg.sender]);
        referralsBonus[msg.sender] = 0;

        emit E_newEntry(
            msg.sender,
            block.timestamp,
            _amount
        );
    }


    /**
     * @dev External function for an entry action.
     * every time that an entry ROI's (based on it's "Active_entryAmount" amount) contract will stop considering profit/divs for * the deposit until users makes an action via this function, their options are:
     * 1st choice ===> users must add value equal to 50% of their total active entry value.
     * 2nd choice ===> users choses not to add the 50% value to their entry and so we reduce the amount of their entry to half.
     * NOTE we do this purely to help keping the project last and making it more fair for users who are not early to the project by avoiding early users to earn return on their deposit forever.
     * @param noIncrease user chosed not to increase their entry amount
     * @param Deposit_ID ID of the target deposit
     * @param amount amount of BUSD entry
     */
    function EntryAction(bool noIncrease, uint256 Deposit_ID, uint256 amount) external {
        _globalDataCheck();

        require(checkForROI(msg.sender, Deposit_ID) == true || depositData[msg.sender][Deposit_ID].ROIed == true);

        require(depositData_2[msg.sender][Deposit_ID].deposit_hasLoan == false);

        CollectEntryProfit(Deposit_ID);

        if (noIncrease == false) {
            // user chosed to add to their entry (amount must be equal to half of their Active_entryAmount)
            uint256 halfOfDeposit = depositData[msg.sender][Deposit_ID].Active_entryAmount / 2;
            require(amount >= halfOfDeposit , "ERR: Amount Not correct");

            token_BUSD.transferFrom(msg.sender, address(this), halfOfDeposit);

            depositData[msg.sender][Deposit_ID].Active_entryAmount += halfOfDeposit;
            totalEntry_dynamic += halfOfDeposit;
        }
        else if (noIncrease == true) {
            // user chosed not to add to their entry, so we reduce their entry amount to half
            depositData[msg.sender][Deposit_ID].Active_entryAmount /= 2;
            totalEntry_dynamic -= depositData[msg.sender][Deposit_ID].Active_entryAmount /2;
        }

        depositData[msg.sender][Deposit_ID].claimedAmount_dynamic = 0;
        depositData[msg.sender][Deposit_ID].lastClaimedContractDay = contractDay;
        depositData[msg.sender][Deposit_ID].lastClaimedTime = block.timestamp;
        depositData[msg.sender][Deposit_ID].ROIed = false;
    }


    /**
     * @dev User request to collect their deposit earnings
     * NOTE in contract we call every user entry a "deposit"
     * @param Deposit_ID if of the target deposit
     */
    function CollectEntryProfit(uint256 Deposit_ID) public nonReentrant {
        require(depositData_2[msg.sender][Deposit_ID].deposit_hasLoan == false);

        _globalDataCheck();

        uint256 depositEarnings = calcDepositReturn(msg.sender, Deposit_ID);
        require(depositEarnings > 0);

        depositEarnings -= (depositEarnings * dayWithdrawFee[contractDay] / GpercentRate);

        token_BUSD.transfer(address(msg.sender), depositEarnings);
        TotalWithdrawed[msg.sender] += depositEarnings;

        depositData[msg.sender][Deposit_ID].lastClaimedTime = block.timestamp;
        depositData[msg.sender][Deposit_ID].lastClaimedContractDay = contractDay;
        depositData[msg.sender][Deposit_ID].claimedAmount_dynamic += depositEarnings;
        depositData[msg.sender][Deposit_ID].claimedAmount_Total += depositEarnings;
        data_totalCollectedReward += depositEarnings;
    }



    /**
     * @dev In order to calculate a live return amount on a deposit we go through coupel steps, we do the calc based on ending and starting timestamps of the duration that we want to calc the return amoutn between, we call the time between them "sections".
     the main calc is done in function "calcMDP", but first we need to detect where the section is in:
        - case[A] ==> the whole section is in a one single contract day.
        - case[B] ==> starting part of the section is in one contract day and the ending part is in the next contract day.
        - case[C] ==> starting part of the section is in one contract day, middle part of the section includes full day/days and the ending part is in the last contract day.

     * @param _address address of the user
     * @param Deposit_ID Deposit_ID
     */
    function calcDepositReturn(address _address, uint256 Deposit_ID) public view returns(uint256) {
        // the last day that the deposit reward was claimed
        uint256 lastClaimedContractDay = depositData[_address][Deposit_ID].lastClaimedContractDay;
        uint256 _profit;


        // case[A]
        if (contractDay - lastClaimedContractDay == 0) {
            uint256[2] memory sectionData_1 = calc_section_timestamps_same_day(_address, Deposit_ID);

            _profit += calcMDP(_address, Deposit_ID, sectionData_1[0], sectionData_1[1]);
        }

        // case[B]
        else if (contractDay - lastClaimedContractDay == 1) {
            uint256[2] memory sectionData_1 = calc_starting_section(_address, Deposit_ID);
            uint256[2] memory sectionData_2 = calc_ending_section();

            _profit += calcMDP(_address, Deposit_ID, sectionData_1[0], sectionData_1[1]);
            _profit += calcMDP(_address, Deposit_ID, sectionData_2[0], sectionData_2[1]);
        }

        // case[C]
        else if (contractDay - lastClaimedContractDay >= 2) {
            uint256[2] memory sectionData_1 = calc_starting_section(_address, Deposit_ID);
            uint256[2] memory sectionData_2 = calc_middle_section(_address, Deposit_ID);
            uint256[2] memory sectionData_3 = calc_ending_section();

            _profit += calcMDP(_address, Deposit_ID, sectionData_1[0], sectionData_1[1]);
            _profit += calcMDP(_address, Deposit_ID, sectionData_2[0], sectionData_2[1]);
            _profit += calcMDP(_address, Deposit_ID, sectionData_3[0], sectionData_3[1]);
        }


        // check for ROI
        if (depositData[_address][Deposit_ID].claimedAmount_dynamic + _profit >= depositData[_address][Deposit_ID].Active_entryAmount) {

            // has ROI-ed, so we don't pay more deposit earnings than the total entryAmount
            _profit = depositData[_address][Deposit_ID].Active_entryAmount - depositData[_address][Deposit_ID].claimedAmount_dynamic;
        }

        return _profit;
    }

    // calculates starting section (duration of between two timestamps) and return % in that section
    function calc_section_timestamps_same_day(address _address, uint256 Deposit_ID) public view returns (uint256[2] memory) {
        // the last day that the deposit reward was claimed
        uint256 lastClaimedContractDay = depositData[_address][Deposit_ID].lastClaimedContractDay;

        uint256 section = block.timestamp - depositData[_address][Deposit_ID].lastClaimedTime;

        uint256 returnPercent = daysReturnPercent[lastClaimedContractDay];

        uint256[2] memory Datas = [section, returnPercent];
        return Datas;
    }

    // calculates starting section (duration of between two timestamps) and return % in that section
    function calc_starting_section(address _address, uint256 Deposit_ID) internal view returns (uint256[2] memory) {
        // the last day that the deposit reward was claimed
        uint256 lastClaimedContractDay = depositData[_address][Deposit_ID].lastClaimedContractDay;

        uint256 section =
        (daysStartingTimeStamp[lastClaimedContractDay + 1] - depositData[_address][Deposit_ID].lastClaimedTime);

        uint256 returnPercent = daysReturnPercent[lastClaimedContractDay];

        uint256[2] memory Datas = [section, returnPercent];
        return Datas;
    }

    // calculates middle section (duration of between two timestamps) and return % in that section
    function calc_middle_section(address _address, uint256 Deposit_ID) internal view returns (uint256[2] memory) {
        // the last day that the deposit reward was claimed
        uint256 lastClaimedContractDay = depositData[_address][Deposit_ID].lastClaimedContractDay;

        uint256 section = (daysStartingTimeStamp[contractDay] - daysStartingTimeStamp[lastClaimedContractDay + 1]);

        // calculate average daily return
        uint256 returnPercent = getAverageReturnPerc(lastClaimedContractDay +1, contractDay);

        uint256[2] memory Datas = [section, returnPercent];
        return Datas;
    }

    // calculates ending section (duration of between two timestamps) and return % in that section
    function calc_ending_section() internal view returns (uint256[2] memory) {
        uint256 section = (block.timestamp - daysStartingTimeStamp[contractDay]);

        uint256 returnPercent = daysReturnPercent[contractDay];

        uint256[2] memory Datas = [section, returnPercent];
        return Datas;
    }




    /**
     * @dev
     */
    function calcMDP(address _address, uint256 Deposit_ID, uint256 duration_in_timestamp, uint256 apr) public view returns(uint256) {

        uint256 rewardPeriod = 1 days;
        uint256 percentRate = 100;

        // all calculated claimable amount from deposit time
        uint256 claimableAmount =
        (duration_in_timestamp * depositData[_address][Deposit_ID].Active_entryAmount * (apr / GpercentRate)) / (percentRate * rewardPeriod);

        return claimableAmount;
    }


    /**
     * @dev returns the next unique ID
     */
    function _generateNextDepositID() private returns (uint256) {
        _currentDepositID ++;
        return _currentDepositID;
    }

    /**
     * @dev returns all deposit IDs of investor
     */
    function getOwnedDeposits(address _address) public view returns (uint256[] memory) {
        return ownedDeposits[_address];
    }

    /**
     * @dev returns average return % between two days
     */
    function getAverageReturnPerc(uint256 day1, uint256 day2) public view returns (uint256) {
        require(day2 > day1);

        uint256 _days = day2 - day1;
        uint256 daysReturnSum = 0;

        for (uint256 i = 0 ; i < _days ; i++) {
            daysReturnSum += daysReturnPercent[day1 + i];
        }

        daysReturnSum /= _days;

        return daysReturnSum;
    }


    /**
     * @dev A function that checks if a deposit has ROI-ed or not
     */
    function checkForROI (address _address, uint256 Deposit_ID) public view returns (bool) {
        bool ROIed = false;

        uint256 profitToBeCollected = calcDepositReturn(_address, Deposit_ID);

        if (profitToBeCollected + depositData[_address][Deposit_ID].claimedAmount_dynamic >= depositData[_address][Deposit_ID].Active_entryAmount) {
            ROIed = true;
        }

        return ROIed;
    }



    /**
     * @dev User setting their own deposit as ROIed
     */
    function setDepositAsROIed (uint256 Deposit_ID) external {
        require(depositData[msg.sender][Deposit_ID].investor == msg.sender, 'auth failed');

        depositData[msg.sender][Deposit_ID].ROIed = true;
    }






    struct loanRequest {
        address loanerAddress; // address
        address lenderAddress; // address (sets after loan request accepted by a lender)
        uint256 Deposit_ID;    // id of the deposit that is being loaned on
        uint256 lenderLendId;  // id of the lends that a lender has given out (sets after loan request accepted by a lender)
        uint256 loanAmount;    // requesting loan BUSD amount
        uint256 returnAmount;  // requesting loan BUSD return amount
        uint256 lend_startDay; // lend start day (sets after loan request accepted by a lender)
        bool hasLoan;
        bool loanIsPaid;       // gets true after loan due date is reached and loan is paid
    }

    struct lendInfo {
        address lenderAddress;
        address loanerAddress;
        uint256 lenderLendId;
        uint256 loanAmount;
        uint256 returnAmount;
        bool loanIsPaid;
    }


    /* withdrawable funds for the loaner address */
    mapping(address => uint256) public LoanedFunds;
    mapping(address => uint256) public LendedFunds;

    uint256 public totalLoanedAmount;
    uint256 public totalLoanedCount;

    mapping(address => mapping(uint256 => loanRequest)) public mapRequestingLoans;
    mapping(address => mapping(uint256 => lendInfo)) public mapLenderInfo;
    mapping(address => uint256) public lendersPaidAmount; // total amounts of paid to lender

    /**
     * @dev User submiting a loan request on their deposit or changing the previously setted loan request data
     * @param Deposit_ID deposit id
     * @param loanAmount amount of requesting BUSD loan
     * @param returnAmount amount of BUSD loan return
     */
    function getLoanOnDeposit(uint256 Deposit_ID ,uint256 loanAmount, uint256 returnAmount) external {
        _globalDataCheck();

        require(loaningIsPaused == false, 'functionality is paused');
        require(returnAmount > (loanAmount * 3 /100 + loanAmount), 'loan return must be at least 3% higher than loan amount');
        require(depositData[msg.sender][Deposit_ID].investor == msg.sender, 'auth failed');
        require(depositData_2[msg.sender][Deposit_ID].deposit_hasLoan == false, 'Target deposit has an active loan on it');
        require(returnAmount <= depositData[msg.sender][Deposit_ID].Active_entryAmount - depositData[msg.sender][Deposit_ID].claimedAmount_dynamic, 'Target deposit do not have enough balance for the offered returnAmount');
        require(depositData[msg.sender][Deposit_ID].startDayOfNewAction < contractDay, 'must have passed at least a day from deposit creation day');

        depositData_2[msg.sender][Deposit_ID].deposit_forLoan = true;

        /* data of the requesting loan */
        mapRequestingLoans[msg.sender][Deposit_ID].loanerAddress = msg.sender;
        mapRequestingLoans[msg.sender][Deposit_ID].Deposit_ID = Deposit_ID;
        mapRequestingLoans[msg.sender][Deposit_ID].loanAmount = loanAmount;
        mapRequestingLoans[msg.sender][Deposit_ID].returnAmount = returnAmount;
        mapRequestingLoans[msg.sender][Deposit_ID].loanIsPaid = false;


        emit E_getLoanOnDeposit(
            msg.sender,
            block.timestamp,
            loanAmount,
            returnAmount,
            Deposit_ID
        );
    }


    /**
     * @dev Canceling loan request
     * @param Deposit_ID deposit id
     */
    function cancelDepositLoanRequest(uint256 Deposit_ID) public {
        require(depositData_2[msg.sender][Deposit_ID].deposit_hasLoan == false);

        depositData_2[msg.sender][Deposit_ID].deposit_forLoan = false;
    }


    /**
     * @dev User filling loan request (lending)
     * @param loanerAddress address of loaner aka the person who is requesting for loan
     * @param Deposit_ID deposit id
     * @param amount lend amount that is tranfered to the contract
     */
    function lendOnDeposit(address loanerAddress , uint256 Deposit_ID, uint256 amount) external nonReentrant {
        _globalDataCheck();

        require(loaningIsPaused == false, 'functionality is paused');
        require(depositData[loanerAddress][Deposit_ID].investor != msg.sender, 'no self lend');
        require(depositData_2[loanerAddress][Deposit_ID].deposit_hasLoan == false, 'Target deposit has an active loan on it');
        require(depositData_2[loanerAddress][Deposit_ID].deposit_forLoan == true, 'Target deposit is not requesting a loan');


        uint256 loanAmount = mapRequestingLoans[loanerAddress][Deposit_ID].loanAmount;
        uint256 returnAmount = mapRequestingLoans[loanerAddress][Deposit_ID].returnAmount;
        uint256 rawAmount = amount;

        require(rawAmount == mapRequestingLoans[loanerAddress][Deposit_ID].loanAmount);

        token_BUSD.transferFrom(msg.sender, address(this), amount);

        depositData_2[loanerAddress][Deposit_ID].deposit_hasLoan = true;
        depositData_2[loanerAddress][Deposit_ID].deposit_forLoan = false;

        /* 3% loaning fee, taken from loaner's deposit, going to contract */
        uint256 theLoanFee = (rawAmount * 3) /100;
        totalLoanFeePaid += theLoanFee;
        totalLoancount ++;

        depositData[loanerAddress][Deposit_ID].loansReturnAmount += returnAmount;


        uint256 lenderLendId = clcLenderLendId(msg.sender);

        mapRequestingLoans[loanerAddress][Deposit_ID].hasLoan = true;
        mapRequestingLoans[loanerAddress][Deposit_ID].loanIsPaid = false;
        mapRequestingLoans[loanerAddress][Deposit_ID].lenderAddress = msg.sender;
        mapRequestingLoans[loanerAddress][Deposit_ID].lenderLendId = lenderLendId;
        mapRequestingLoans[loanerAddress][Deposit_ID].lend_startDay = contractDay;


        mapLenderInfo[msg.sender][lenderLendId].lenderAddress = msg.sender;
        mapLenderInfo[msg.sender][lenderLendId].loanerAddress = loanerAddress;
        mapLenderInfo[msg.sender][lenderLendId].lenderLendId = lenderLendId; // not same with the deposit id on "mapRequestingLoans"
        mapLenderInfo[msg.sender][lenderLendId].loanAmount = loanAmount;
        mapLenderInfo[msg.sender][lenderLendId].returnAmount = returnAmount;


        LoanedFunds[loanerAddress] += (rawAmount * 97) /100;
        LendedFunds[msg.sender] += (rawAmount * 97) /100;
        totalLoanedAmount += (rawAmount * 97) /100;
        totalLoanedCount += 1;

        emit E_lendOnDeposit(
            msg.sender,
            loanerAddress,
            block.timestamp,
            lenderLendId
        );
    }


    /**
     * @dev User asking to withdraw their loaned funds
     */
    function withdrawLoanedFunds() external nonReentrant {
        require(LoanedFunds[msg.sender] > 0, 'No funds to withdraw');

        uint256 toBeSend = LoanedFunds[msg.sender];
        LoanedFunds[msg.sender] = 0;

        token_BUSD.transfer(address(msg.sender), toBeSend);
    }


    /**
     * @dev returns a unique id for the lend by lopping through the user's lends and counting them
     * @param _address the lender user address
     */
    function clcLenderLendId(address _address) public view returns (uint256) {
        uint256 counter = 0;

        for (uint256 i = 0; mapLenderInfo[_address][i].lenderAddress == _address; i++) {
            counter += 1;
        }

        return counter;
    }


    /*
        there is no automatic way in contract to pay the lender and set the lend data as finished (for the sake of performance and gas)
        so either the one of lender or loaner user calls the "collectLendReturn" function or the loaner user automatically call the  "updateFinishedLoan" function by trying to collect their deposit
    */

    /**
     * @dev Lender requesting to collect their return amount from their finished lend
     * @param Deposit_ID id of a loaner's deposit for that the loaner requested a loan and received a lend
     * @param lenderLendId id of the lends that a lender has given out (different from Deposit_ID)
     */
    function collectLendReturn(uint256 Deposit_ID, uint256 lenderLendId) external nonReentrant {
        updateFinishedLoan(msg.sender, mapLenderInfo[msg.sender][lenderLendId].loanerAddress, lenderLendId, Deposit_ID);
    }

    /**
     * @dev Checks if the loan on loaner's deposit is finished
     * @param lenderAddress lender address
     * @param loanerAddress loaner address
     * @param lenderLendId id of the lend that a lender has given out (different from Deposit_ID)
     * @param Deposit_ID id of a loaner's deposit for that the loaner requested a loan and received a lend
     */
    function updateFinishedLoan(address lenderAddress, address loanerAddress, uint256 lenderLendId, uint256 Deposit_ID) public {
        _globalDataCheck();

        require(depositData_2[loanerAddress][Deposit_ID].deposit_hasLoan == true, 'Target deposit does not have an active loan on it');
        require(mapLenderInfo[lenderAddress][lenderLendId].loanIsPaid == false);
        require(mapRequestingLoans[loanerAddress][Deposit_ID].loanIsPaid == false);
        require(mapRequestingLoans[loanerAddress][Deposit_ID].hasLoan == true);
        require(mapRequestingLoans[loanerAddress][Deposit_ID].lenderAddress == lenderAddress);
        require(mapRequestingLoans[loanerAddress][Deposit_ID].lenderLendId == lenderLendId);

        uint256 toBePaid = mapRequestingLoans[loanerAddress][Deposit_ID].returnAmount;
        uint256 depositEarnings = calcDepositReturn(loanerAddress, Deposit_ID);
        require(depositEarnings >= toBePaid, 'Deposit does not have enough earnings to pay the lender');


        depositData[loanerAddress][Deposit_ID].lastClaimedTime = block.timestamp;
        depositData[loanerAddress][Deposit_ID].lastClaimedContractDay = contractDay;
        depositData[loanerAddress][Deposit_ID].claimedAmount_dynamic += depositEarnings;
        depositData[loanerAddress][Deposit_ID].claimedAmount_Total += depositEarnings;
        data_totalCollectedReward += depositEarnings;

        TotalWithdrawed[loanerAddress] += depositEarnings;

        depositData_2[loanerAddress][Deposit_ID].deposit_hasLoan = false;
        mapLenderInfo[lenderAddress][lenderLendId].loanIsPaid = true;
        mapRequestingLoans[loanerAddress][Deposit_ID].hasLoan = false;
        mapRequestingLoans[loanerAddress][Deposit_ID].loanIsPaid = true;


        lendersPaidAmount[lenderAddress] += toBePaid;

        mapRequestingLoans[loanerAddress][Deposit_ID].returnAmount = 0;

        token_BUSD.transfer(address(lenderAddress), toBePaid);
    }


}

