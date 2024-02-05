/**
 * @title ERC20
 * @dev ERC20 contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 * File @openzeppelin/contracts/token/ERC20/ERC20.sol
 *
 **/

pragma solidity 0.6.12;

import "./Context.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./Manager.sol";
import "./Blacklist.sol";

contract ERC20 is Context, IERC20, Manager, MinterRole, Blacklist {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint256 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * These three values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes:
     * it does not affect any of the arithmetic in the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint256) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Sets {decimals} to a value other than the default of 18.
     *
     * WARNING: This function should only be called by the developer.
     * Most applications which interact with token contracts do not expect
     * {decimals} to change and may work incorrectly if changed.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev See {IERC20-transfer}.
     * Send amount sub fee or without fee.
     *
     * Requirements:
     *
     * - the caller must have a balance of at least `amount`
     */
    function transfer(address recipient, uint256 amount)  // @audit - checked
        external
        override
        whenNotPaused  // @audit-issue - owner can lock funds
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)// @audit - checked
        public
        view
        virtual
        override
        whenNotPaused  // @audit-issue - allowances can only be seen when it is not paused
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address
     */
    function approve(address spender, uint256 amount)// @audit - checked
        public
        virtual
        override
        whenNotPaused   // @audit-issue - only possible if its not paused
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     * Send amount - with fee or without fee.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` must have a balance of at least `amount`
     * - the caller must have allowance for `sender`'s tokens of at least `amount`
     */
    function transferFrom(// @audit - checked, only when not paused
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override whenNotPaused returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    /**
     * @dev Automatically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} which can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address
     */
    function increaseAllowance(address spender, uint256 addedValue) // @audit - checked
        public
        virtual
        whenNotPaused
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    /**
     * @dev Automatically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} which can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address
     * - `spender` must have allowance for the caller of at least `subtractedValue`
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) // @audit - checked
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient` and `feeReceiver`.
     *
     * This is internal function is equivalent to {transfer}, and used also for automatic token fees.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` must have a balance of at least `amount`
     */
    function _transfer( // @audit - checked, lock
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual whenNotPaused {
        require(isBlacklisted(sender) == false, "sender blacklisted");
        require(isBlacklisted(recipient) == false, "recipient blacklisted");

        _balances[sender] = _balances[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    /** @dev Emits a {burn} event and sets the BlackFund address to 0.
     *
     * Requirements:
     *
     * - only `onlyMinter` can trigger the destroyBlackFunds
     * - `_blackListedUser` is on the blacklist
     *
     */
    function destroyBlackFunds(address _blackListedUser) public onlyMinter { // @audit - checked, minter can destroy tokens without allowance
        require(isBlacklisted(_blackListedUser) == true, "is not Blacklisted");

        uint256 dirtyFunds = balanceOf(_blackListedUser);

        _burn(_blackListedUser, dirtyFunds);
    }

    /** @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * Emits an Admin {Transfer} event on the amount of Black Funds.
     *
     * Requirements:
     *
     * - only `onlyMinter` can trigger the redeemBlackFunds
     * - `sender` must be on the blacklist
     *
     */
    function redeemBlackFunds( // @audit - checked
        address sender, // @audit - rename to "from" because caller is not "sender"
        address recipient,
        uint256 amount
    ) public onlyMinter {
        require(isBlacklisted(sender) == true, "is not Blacklisted"); // @audit-info - repeating modifier -> add modifier
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address
     * - `freeSupply` must be larger than the amount to be created
     */
    function _mint(address account, uint256 amount) internal virtual { // @audit - checked
        require(account != address(0), "ERC20: mint to the zero address"); // @audit - check dead address
        freeMintSupply = freeMintSupply.sub(
            amount,
            "ERC20: no more free supply (total)"
        );
        freeMintSupplyMinter[msg.sender] = freeMintSupplyMinter[msg.sender].sub(
            amount,
            "ERC20: no more free supply (minter)"
        );
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount); // @audit-info - Change Transfer to Mint event, add mint event
    }

    /**
     * Purpose:
     * onlyMinter mints tokens on the _to address
     *
     * @param _amount - amount of newly issued tokens
     * @param _to - address for the new issued tokens
     */
    function mint(address _to, uint256 _amount) public onlyMinter { // @audit - checked
        _mint(_to, _amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address
     * - `account` must have at least `amount` tokens
     */
    function _burn(address account, uint256 amount) internal virtual { // @audit - checked
        require(account != address(0), "ERC20: burn from the zero address");
        _balances[account] = _balances[account].sub(
            amount,
            "ERC20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` tokens.
     *
     * This internal function is the equivalent to `approve`, and can be used to
     * set automatic allowances for certain subsystems etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address
     * - `spender` cannot be the zero address
     */
    function _approve(  // @audit - checked
        address owner,
        address spender,
        uint256 amount
    ) internal virtual whenNotPaused {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
