// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import './libraries/SafeMath.sol';
import './interfaces/IBEP20.sol';
// import 'hardhat/console.sol';

interface ApproveAndCallFallBack {
    function receiveApproval(address _from, uint256 _amount, bytes calldata _data) external;
}

// DEX Router Interface
interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function WETH() external pure returns (address);
    function factory() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
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
}

// File: contracts/zep/Roles.sol

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
  struct Role {
    mapping (address => bool) bearer;
  }

  /**
   * @dev give an account access to this role
   */
  function add(Role storage role, address account) internal {
    require(account != address(0));
    require(!has(role, account));

    role.bearer[account] = true;
  }

  /**
   * @dev remove an account's access to this role
   */
  function remove(Role storage role, address account) internal {
    require(account != address(0));
    require(has(role, account));

    role.bearer[account] = false;
  }

  /**
   * @dev check if an account has this role
   * @return bool
   */
  function has(Role storage role, address account)
    internal
    view
    returns (bool)
  {
    require(account != address(0));
    return role.bearer[account];
  }
}

// File: contracts/CairoToken.sol
contract CairoToken is OwnableUpgradeable, PausableUpgradeable, IBEP20 {
    using SafeMath for uint256;
    using Roles for Roles.Role;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    bool private _mintable;

    Roles.Role private networkContracts;

    // Tax Related
    mapping (address => uint8) private _customTaxRate;
    mapping (address => bool) private _hasCustomTax;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;

    event TaxPayed(address from, address vault, uint256 amount);
    event TokenBurn(address from, uint256 amount);

    // DEX Transfer
    address[] public pairs;
    address pancakeV2BNBPair;
    IDEXRouter router;

    // Admin Tax Collections - Liquidity Pool and Marketing and Development
    address taxFeeSplit1;
    address taxFeeSplit2;

    // Network contract transparency
    event NetworkContractAdded(address contractAddress);
    event NetworkContractRemoved(address contractAddress);

    address[] public allNetworkContracts;

    // Simple burn transparency
    uint256 private _totalBurned;

    // Custom buy/sale tax transparency
    event ChangedCustomTaxRate(address sender, uint8 newTaxPercent);

    /**
     * @dev Throws if called by a non network contract.
     */
    modifier onlyNetwork() {
        require(networkContracts.has(msg.sender));
        _;
    }

    /**
     * @dev sets initials supply and the owner
     */
    function initialize() external initializer {
        __Ownable_init();
        __Pausable_init();

        _name = "Cairo";
        _symbol = "CAIRO";
        _decimals = 18;
        _mintable = true;

        uint256 initialSupply = 100000000 * 10 ** 18;
        mint(initialSupply);
        _mintable = false;
    }

     /**
     * @dev setup sales tax collector addresses (one for liquidity, other for marketing and development)
     */
    function setAdminFeeAddresses(address feeOne, address feeTwo) onlyOwner public {
        taxFeeSplit1 = feeOne;
        taxFeeSplit2 = feeTwo;
    }

    /**
     * @dev Returns if the token is mintable or not
     */
    function mintable() external view returns (bool) {
        return _mintable;
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
    function decimals() external override view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external override view returns (string memory) {
        return _symbol;
    }

    /**
    * @dev Returns the token name.
    */
    function name() external override view returns (string memory) {
        return _name;
    }

    /**
     * @dev See {BEP20-totalSupply}.
     */
    function totalSupply() external override view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {BEP20-balanceOf}.
     */
    function balanceOf(address account) external override view returns (uint256) {
        return _balances[account];
    }

    function totalBurn() external view returns (uint256) {
        return _totalBurned;
    }

    /**
     * @dev See {BEP20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {BEP20-allowance}.
     */
    function allowance(address owner, address spender) external override view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {BEP20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) whenNotPaused external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
    * @dev
    *  @notice `msg.sender` approves `_spender` to send `_amount` tokens on
    * its behalf, and then a function is triggered in the contract that is
    * being approved, `_spender`. This allows users to use their tokens to
    * interact with contracts in one function call instead of two
    *
    * Requirements:
    *
    * - `spender` The address of the contract able to transfer the tokens
    * - `_amount` The amount of tokens to be approved for transfer
    * - `_extraData` The raw data for call another contract
    * - return True if the function call was successful
    */
    function approveAndCall(ApproveAndCallFallBack _spender, uint256 _amount, bytes calldata _extraData) whenNotPaused external returns (bool success) {
        _approve(_msgSender(), address(_spender), _amount);

        _spender.receiveApproval(
            msg.sender,
            _amount,
            _extraData
        );

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
    function transferFrom(address sender, address recipient, uint256 amount) whenNotPaused external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
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
    function increaseAllowance(address spender, uint256 addedValue) whenNotPaused public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
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
    function decreaseAllowance(address spender, uint256 subtractedValue) whenNotPaused public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
        return true;
    }


    /**
   * @dev Burn `amount` tokens and decreasing the total supply.
   */
    function burn(uint256 amount) whenNotPaused public returns (bool) {
        _burn(_msgSender(), amount);
        return true;
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
        require(account != address(0), "BEP20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }


    /**
     * @dev Creates `amount` tokens and assigns them to `msg.sender`, increasing
     * the total supply.
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     * - `_mintable` must be true
     */
    function mint(uint256 amount) public onlyOwner returns (bool) {
        require(_mintable, "this token is not mintable");
        _mint(owner(), amount);
        return true;
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
        require(account != address(0), "BEP20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        _totalBurned = _totalBurned.add(amount);
        emit Transfer(account, address(0), amount);
        emit TokenBurn(account, amount);
    }

    /**
     * @dev Removes a contract from the Cairo network
     *
     * Requirements
     *
     * - `msg.sender` must be the owner of the contract
     */
    function removeNetworkContract(address contractAddress) onlyOwner public {
        networkContracts.remove(contractAddress);
        emit NetworkContractRemoved(contractAddress);

        for (uint i=0;i<allNetworkContracts.length;i++) {
            if (allNetworkContracts[i] == contractAddress)
            {
                allNetworkContracts[i] = allNetworkContracts[allNetworkContracts.length-1];
                allNetworkContracts.pop();
                break;
            }
        }
    }

    /**
     * @dev Adds a contract to the Cairo network
     *
     * Requirements
     *
     * - `msg.sender` must be the owner of the contract
     */
    function addNetworkContract(address contractAddress) onlyOwner public returns (address) {
        networkContracts.add(contractAddress);
        allNetworkContracts.push(contractAddress);
        emit NetworkContractAdded(contractAddress);
        return contractAddress;
    }

    /**
     * @dev Allows Cairo network projects to burn tokens (i.e. when using the Maximizer)
     *
     * Requirements
     *
     * - `msg.sender` must be the owner of the contract
     */
    function burnFromCairoNetwork(address account, uint256 amount) onlyNetwork external {
        _burn(account, amount);
    }

    /**
     * @dev Allows Cairo network projects to transfer tokens as necessary for the operation of the network
     *
     * Requirements
     *
     * - `msg.sender` must be the owner of the contract
     */
    function transferFromCairoNetwork(address sender, address recipient, uint256 amount) onlyNetwork external {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
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
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

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
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "BEP20: burn amount exceeds allowance"));
    }

    /**
     * @dev Simply calculates the tax adjusted value and returns it for internal use (percentage function for refuse)
    */
    function calculateTransactionTax(uint256 _value, uint8 _tax) internal pure returns (uint256 adjustedValue, uint256 taxAmount) {
        taxAmount = _value.mul(_tax).div(100);
        adjustedValue = _value.mul(SafeMath.sub(100, _tax)).div(100);
        return (adjustedValue, taxAmount);
    }

    /**
     * @dev Calculate transfer taxes where applicable
    */
    function calculateTransferTaxes(address _from, uint256 _value) external view returns (uint256 adjustedValue, uint256 taxAmount){
        adjustedValue = _value;
        taxAmount = 0;

        if (!_isExcluded[_from]) {
            uint8 taxPercent = 10; // set to default tax 10%

            // set custom tax rate if applicable
            if (_hasCustomTax[_from]){
                taxPercent = _customTaxRate[_from];
            }

            (adjustedValue, taxAmount) = calculateTransactionTax(_value, taxPercent);
        }
        return (adjustedValue, taxAmount);
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
    function _transfer(address sender, address recipient, uint256 amount) whenNotPaused internal {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");

        uint256 amountReceived = shouldTakeFee(sender, recipient) ? takeFee(sender, amount) : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);

        emit Transfer(sender, recipient, amount);
    }

    /*
     * Transfer tax swap related functions
     */

    function setCustomTaxRate(address sender, uint8 taxRate) external onlyOwner {
        _hasCustomTax[sender] = true;
        _customTaxRate[sender] = taxRate;
        emit ChangedCustomTaxRate(sender, taxRate);
    }

    // Checking if the sender is a liqpair controls whether fees are taken on buy or sell
    function shouldTakeFee(address sender, address recipient) internal view returns (bool) {
        if (_isExcluded[sender] || _isExcluded[recipient]) return false;
        address[] memory liqPairs = pairs;
        for (uint256 i = 0; i < liqPairs.length; i++) {
            if (sender == liqPairs[i] || recipient == liqPairs[i]) return true;
        }
        return false;
    }

    function takeFee(address sender, uint256 amount) internal returns (uint256) {
        uint8 taxPercent = 10; // set to default trading tax 10%

        // set custom tax rate if applicable
        if (_hasCustomTax[sender]){
            taxPercent = _customTaxRate[sender];
        }

        uint256 halfFeeAmount = amount.mul(taxPercent).div(100).div(2);

        // Transfer between two wallets the 10% taken on buy/sell
        _balances[taxFeeSplit1] = _balances[taxFeeSplit1].add(halfFeeAmount);
        _balances[taxFeeSplit2] = _balances[taxFeeSplit2].add(halfFeeAmount);
        emit Transfer(sender, address(taxFeeSplit1), halfFeeAmount);
        emit Transfer(sender, address(taxFeeSplit2), halfFeeAmount);
        emit TaxPayed(sender, address(this), halfFeeAmount.add(halfFeeAmount));

        return amount.sub(halfFeeAmount.add(halfFeeAmount));
    }

    /*
     * Add actively trading pair
     */
    function addKnownPairAddress(address lpPair) onlyOwner external {
        pairs.push(lpPair);
    }

    // https://amm.kiemtienonline360.com/#BSC
    function setupPancakeV1(address routerAddress, address wbnbAddress) onlyOwner external {
        router = IDEXRouter(routerAddress);
        pancakeV2BNBPair = IDEXFactory(router.factory()).createPair(wbnbAddress, address(this));
        pairs.push(pancakeV2BNBPair);

        _allowances[address(this)][address(router)] = ~uint256(0);
    }

    function getPairs() public view returns (address[] memory) {
        return pairs;
    }

    /*
     * Add transfer tax exempt address for adding liquidity
     */
    function addTaxExcludedAddress(address excludeAddress) onlyOwner external {
        _isExcluded[excludeAddress] = true;
        _excluded.push(excludeAddress);
    }

    function removeTaxExcludedAddress(address excludeAddress) onlyOwner external {
        _isExcluded[excludeAddress] = false;
        for (uint i=0;i<_excluded.length;i++) {
            if (_excluded[i] == excludeAddress)
            {
                _excluded[i] = _excluded[_excluded.length-1];
                _excluded.pop();
                break;
            }
        }
    }

    function taxExcludedAddresses() external view returns(address[] memory) {
        return _excluded;
    }

    /*
     * Check network contracts
     */
    function isNetworkContract(address addr) external view returns(bool) {
        return networkContracts.has(addr);
    }

}