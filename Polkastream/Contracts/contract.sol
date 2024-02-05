// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
   #Polkastream
   Initially:
    - 3% fee distributed to all holders
    - 1% fee burned

   After 50% supply burned:
    - 4% fee distributed to all holders

 */

/**
 * @dev Interface of the ERC20 standard as defined in the EIP
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`
     *
     * Returns a boolean value indicating whether the operation succeeded
     *
     * Emits a {Transfer} event
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining amount of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default
     *
     * This value changes when {approve} or {transferFrom} are called
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens
     *
     * Returns a boolean value indicating whether the operation succeeded
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterward:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance
     *
     * Returns a boolean value indicating whether the operation succeeded
     *
     * Emits a {Transfer} event
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emits when `value` tokens are moved from one account (`from`) to
     * another (`to`)
     *
     * `value` may be zero
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emits when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner` which can be applied to functions to restrict their use to
 * the owner
 */
abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting of the deployer as the initial owner
     */
    constructor () {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. The current owner can only call it
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner
     */
    function renounceOwnership() public virtual onlyOwner() {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers contract ownership to a new account (`newOwner`).
     * The current owner can only call it
     */
    function transferOwnership(address newOwner) public virtual onlyOwner() {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract Polkastream is IERC20, Ownable {

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;


    mapping (address => bool) private _isExcludedFromMaxTxLimit;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcluded;
    mapping (address => bool) private _isBlacklisted;
    address[] private _excluded;

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 private constant _tTotal = 1000 * 10**6 * 10**18; // 1 Billion

    // Polkastream wallet addresses
    address public constant VESTING_CONTRACT = 0x0beF5f7E292fB8523256415941D097Aa479C1BA7;
    address public constant PUBLIC_SALE = 0x0F18A35beee3604bDAa28A45e299d166f037116A;
    address public constant LIQUIDITY_POOL = 0x5a5E2777dD1e3ae0c39521fEb49012cA3845D48F;
    address public constant REWARDS = 0xEe9143f5Efc1bA0315aE0cADc148843e4D7920Ea;
    address public constant OPS_AND_MKTG = 0x37ECAaFBc289dA731B81c81A4454B108beD425a4;
    address public constant COMMUNITY = 0xf353B8Bb584c75900090e7F5e4309706e79d5385;
    address public constant CHARITY = 0x8A4904c92eA3F6508f4b7bA26537BFe31B09A5ee;

    uint256 private _rTotal = (~uint256(0) - (~uint256(0) % _tTotal));
    uint256 private _tFeeTotal;

    uint256 private _taxFee = 3;
    uint256 private _burnFee = 1;

    uint256 private _previousTaxFee = _taxFee;
    uint256 private _previousBurnFee = _burnFee;

    uint256 public _maxTxLimit = 1 * 10**6 * 10**18; // 1 Million per transaction limit
    uint256 public goLiveBlock;
    uint256 public sniperBlockDuration;
    address public uniswapV2Pair;
    bool public isTokenLive;

    constructor () {

        // Temporarily assigns the total supply to self
        _rOwned[address(this)] = _rTotal;
        emit Transfer(address(0), address(this), _tTotal);

        // Excludes all reserved wallets from:
        //  - Paying fees
        //  - Receiving dividends
        //  - Transaction limits
        excludeFromAll(VESTING_CONTRACT);
        excludeFromAll(PUBLIC_SALE);
        excludeFromAll(LIQUIDITY_POOL);
        excludeFromAll(REWARDS);
        excludeFromAll(OPS_AND_MKTG);
        excludeFromAll(COMMUNITY);
        excludeFromAll(CHARITY);

        _tokenTransfer(address(this), VESTING_CONTRACT, _tTotal * 42 / 100, false); // 42% of the total supply
        _tokenTransfer(address(this), PUBLIC_SALE, _tTotal * 4 / 100, false);       // 4% of the total supply
        _tokenTransfer(address(this), LIQUIDITY_POOL, _tTotal * 3 / 100, false);    // 3% of the total supply
        _tokenTransfer(address(this), REWARDS, _tTotal * 25 / 100, false);          // 25% of the total supply
        _tokenTransfer(address(this), OPS_AND_MKTG, _tTotal * 20 / 100, false);     // 20% of the total supply
        _tokenTransfer(address(this), COMMUNITY, _tTotal * 4 / 100, false);         // 4% of the total supply
        _tokenTransfer(address(this), CHARITY, _tTotal * 2 / 100, false);           // 2% of the total supply
    }

    function name() public pure returns (string memory) {
        return "Polkastream";
    }

    function symbol() public pure returns (string memory) {
        return "PSTR";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] - subtractedValue);
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function isExcludedFromMaxTransactionLimit(address account) public view returns (bool) {
        return _isExcludedFromMaxTxLimit[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount / currentRate;
    }

    function excludeFromReward(address account) public onlyOwner() {
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function excludeFromFee(address account) public onlyOwner() {
        require(!_isExcludedFromFee[account], "Account is already excluded");
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) external onlyOwner() {
        require(_isExcludedFromFee[account], "Account is already included");
        _isExcludedFromFee[account] = false;
    }

    function excludeFromMaxTxLimit(address account) public onlyOwner() {
        require(!_isExcludedFromMaxTxLimit[account], "Account is already excluded");
        _isExcludedFromMaxTxLimit[account] = true;
    }

    function includeInMaxTxLimit(address account) public onlyOwner() {
        require(_isExcludedFromMaxTxLimit[account], "Account is already included");
        _isExcludedFromMaxTxLimit[account] = false;
    }

    function excludeFromAll(address account) public onlyOwner() {
        excludeFromReward(account);
        excludeFromFee(account);
        excludeFromMaxTxLimit(account);
    }

    function addInBlacklist(address account) public onlyOwner() {
        require(!_isBlacklisted[account], "Account is already added");
        _isBlacklisted[account] = true;
    }

    function removeFromBlacklist(address account) public onlyOwner() {
        require(_isBlacklisted[account], "Account is already removed");
        _isBlacklisted[account] = false;
    }

    function goLive(address _uniswapV2Pair, uint256 _sniperBlockDuration) external onlyOwner() {
        require(!isTokenLive, "Polkastream: PSTR is already live");
        isTokenLive = true;
        goLiveBlock = block.number;
        uniswapV2Pair = _uniswapV2Pair;
        sniperBlockDuration = _sniperBlockDuration;
    }

    function setMaxTransactionLimit(uint256 newLimit) external onlyOwner() {
        _maxTxLimit = newLimit * 10**18;
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tBurn, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tBurn);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        (uint256 tFee, uint256 tBurn) = _calculateTaxAndBurnFee(tAmount);
        uint256 tTransferAmount = tAmount - tFee - tBurn;
        return (tTransferAmount, tFee, tBurn);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tBurn, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rBurn = tBurn * currentRate;
        uint256 rTransferAmount = rAmount - rFee - rBurn;
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply -= _rOwned[_excluded[i]];
            tSupply -= _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeBurn(uint256 tBurn) private {
        uint256 currentRate =  _getRate();
        uint256 rBurn = tBurn * currentRate;
        _rOwned[BURN_ADDRESS] += rBurn;
        if(_isExcluded[BURN_ADDRESS])
            _tOwned[BURN_ADDRESS] += tBurn;
    }

    function _calculateTaxAndBurnFee(uint256 _amount) private view returns (uint256, uint256) {
        uint256 burntSupply = balanceOf(BURN_ADDRESS);
        if(burntSupply < totalSupply() / 2) {
            return (_amount * _taxFee / 100, _amount * _burnFee / 100);
        }
        return (_taxFee + _burnFee, 0);
    }

    function _removeAllFee() private {
        if(_taxFee == 0 && _burnFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousBurnFee = _burnFee;

        _taxFee = 0;
        _burnFee = 0;
    }

    function _restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _burnFee = _previousBurnFee;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(isTokenLive || _isExcludedFromFee[from], "Polkastream: PSTR not live yet");
        require(!_isBlacklisted[from], "Polkastream: transfer from blacklisted address");
        require(amount <= _maxTxLimit || _isExcludedFromMaxTxLimit[from], "Polkastream: Transfer amount exceeds limit");

        if(
            isTokenLive &&
            block.number < goLiveBlock + sniperBlockDuration
            && from == uniswapV2Pair
            && to != uniswapV2Pair
        ) {
            // Blacklists a token buy very close to liquidity addition
            _isBlacklisted[to] = true;
        }

        // Indicates if the fee should be deducted from transfer
        bool takeFee = true;

        // Removes the fee if the account belongs to `_isExcludedFromFee`
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        // Transfers amount and takes 3% redistribution and 1% burn fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        if(!takeFee)
            _removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if(!takeFee)
            _restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getValues(tAmount);
        _rOwned[sender] -= rAmount;
        _rOwned[recipient] += rTransferAmount;
        _takeBurn(tBurn);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getValues(tAmount);
        _rOwned[sender] -= rAmount;
        _tOwned[recipient] += tTransferAmount;
        _rOwned[recipient] += rTransferAmount;
        _takeBurn(tBurn);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getValues(tAmount);
        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= rAmount;
        _rOwned[recipient] += rTransferAmount;
        _takeBurn(tBurn);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getValues(tAmount);
        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= rAmount;
        _tOwned[recipient] += tTransferAmount;
        _rOwned[recipient] += rTransferAmount;
        _takeBurn(tBurn);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}
