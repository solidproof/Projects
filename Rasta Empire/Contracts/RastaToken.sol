// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./VestingWallets.sol";
import "./Wallets.sol";
import "./binance/IBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @dev Rasta token implementation using BEP-20 interface.
 */
contract RastaToken is Context, Ownable, IBEP20, VestingWallets, Wallets {
    using SafeMath for uint256;

    uint256 internal _tokenPrice = 20;
    uint256 internal constant _tokenPriceDecimals = 2;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string private constant _name = "Rasta";
    string private constant _symbol = "RAST";
    uint256 private constant _totalSupply = 20 * 1000 * 1000 * _baseMultiplier; // 20M tokens.
    uint256 private constant _baseMultiplier = uint256(10)**18;

    constructor(
        address development,
        address founders,
        address presale,
        address marketing,
        address nonProfitAssociations
    )
        VestingWallets(development, founders, marketing, presale)
        Wallets(
            development,
            founders,
            presale,
            marketing,
            nonProfitAssociations
        )
    {
        // Set initial balance to match the initial token supply.
        _balances[msg.sender] = 12 * 1000 * 1000 * _baseMultiplier; // 12M tokens
        _balances[development] = 400 * 1000 * _baseMultiplier; // 400K tokens
        _balances[getDevelopmentVestingWallet()] = 1600 * 1000 * _baseMultiplier; // 1.6M tokens
        _balances[getFoundersVestingWallet()] = 2 * 1000 * 1000 * _baseMultiplier; // 2M tokens
        _balances[presale] = 2250 * 1000 * _baseMultiplier; // 2.25M tokens
        _balances[marketing] = 175 * 1000 * _baseMultiplier; // 175K tokens
        _balances[getMarketingVestingWallet()] = 1575 * 1000 * _baseMultiplier; // 1.575M tokens

        // Emit all the transfer messages.
        emit Transfer(address(0), msg.sender, 12 * 1000 * 1000 * _baseMultiplier);
        emit Transfer(address(0), development, 400 * 1000 * _baseMultiplier);
        emit Transfer(address(0), getDevelopmentVestingWallet(), 1600 * 1000 * _baseMultiplier);
        emit Transfer(address(0), getFoundersVestingWallet(), 2 * 1000 * 1000 * _baseMultiplier);
        emit Transfer(address(0), presale, 2250 * 1000 * _baseMultiplier);
        emit Transfer(address(0), marketing, 175 * 1000 * _baseMultiplier);
        emit Transfer(address(0), getMarketingVestingWallet(), 1575 * 1000 * _baseMultiplier);
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external override view returns (address) {
        return owner();
    }

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external override pure returns (uint8) {
        return 18;
    }

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external override pure returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the token name.
     */
    function name() external override pure returns (string memory) {
        return _name;
    }

    /**
     * @dev See {BEP20-totalSupply}.
     */
    function totalSupply() external override pure returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {BEP20-balanceOf}.
     */
    function balanceOf(address wallet) external override view returns (uint256) {
        return _balances[wallet];
    }

    /**
     * @dev See {BEP20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        // If the recipient is the owner and it's not an internal wallet, then consider it a user sell.
        if (recipient == owner() && !_isInternalWallet(_msgSender())) {
            _transferUserSale(_msgSender(), amount);
        } else {
            // This is a buy action or a transfer from internal.
            // No percentages will be substrated from the total amount.
            _transfer(_msgSender(), recipient, amount);
        }
        return true;
    }

    /**
     * @dev See {BEP20-allowance}.
     */
    function allowance(address owner, address spender)
        external
        override
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {BEP20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {BEP20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {BEP20};
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
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "BEP20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
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
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "BEP20: decreased allowance below zero"
            )
        );
        return true;
    }

    /**
     * @dev This is a function for the internal user sale.
     */
    function _transferUserSale(
        address sender,
        uint256 amount
    ) internal {
        // 3% of the total amount will be substracted and tranfered to internal wallets.
        // Transfered amount will be divided as following:
        //   - 1% to non-rpofit, development, and makerting.
        //   - Rest will be transfered to recipient (97% of total).
        uint256 onePercentOfAmount = amount.div(
            100,
            "RastaToken: Unable to get 1 percentage of total amount"
        );
        uint256 recipientAmount = amount.sub(onePercentOfAmount.mul(3));

        _transfer(sender, _nonProfitAssociations, onePercentOfAmount);
        _transfer(sender, _developmentWallet, onePercentOfAmount);
        _transfer(sender, _marketingWallet, onePercentOfAmount);
        _transfer(sender, owner(), recipientAmount);
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
    ) internal {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        require(
            sender != recipient,
            "BEP20: recipient address is the same as sender"
        );

        _balances[sender] = _balances[sender].sub(
            amount,
            "BEP20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
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
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
