//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPancakeswapV2Factory.sol";
import "./IPancakeswapV2Router02.sol";

contract BNBRagnarok is Context, IERC20, Ownable {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) _isExcludedFromFee;

    address GamePoolAddress;

    string private _name = "BNBRagnarok";
    string private _symbol = "ZENY";
    uint8 private _decimals = 18;
    uint256 private _totalSupply = 100_000_000 * (10 ** _decimals);

    uint256 _BNBFee = 10;
    uint256 private _previousBNBFee = _BNBFee;

    uint256 _liquidityFee = 2;
    uint256 private _previousLiquidityFee = _liquidityFee;

    IPancakeswapV2Router02 public pancakeswapV2Router;
    address public pancakeswapV2Pair;

    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address private constant ZERO = 0x0000000000000000000000000000000000000000;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public presaleEnded = false;

    uint256 public _maxTxAmount =  _totalSupply.div(400); //250,000
    uint256 private numTokensToSwap =  _totalSupply / 2000; // 0.005% 50,000
    uint256 public swapCoolDownTime = 60;
    uint256 private lastSwapTime;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived,uint256 tokensIntoLiquidity);
    event ExcludedFromFee(address account);
    event IncludedToFee(address account);
    event UpdateFees(uint256 bnbFee, uint256 liquidityFee);
    event UpdatedMaxTxAmount(uint256 maxTxAmount);
    event UpdateNumtokensToSwap(uint256 amount);
    event UpdatePoolAddress(address gameaccount);
    event SwapAndCharged(uint256 token, uint256 liquidAmount, uint256 bnbPool,  uint256 bnbLiquidity);
    event UpdatedCoolDowntime(uint256 timeForContract);
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor () {
        IPancakeswapV2Router02 _pancakeswapV2Router = IPancakeswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        pancakeswapV2Pair = IPancakeswapV2Factory(_pancakeswapV2Router.factory()).createPair(address(this), _pancakeswapV2Router.WETH());

        // set the rest of the contract variables
        pancakeswapV2Router = _pancakeswapV2Router;

        _allowances[address(this)][address(pancakeswapV2Router)] = _totalSupply;

        //exclude owner and this contract from fee
        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedFromFee[address(this)] = true;

        approve(address(pancakeswapV2Router), _totalSupply);
        approve(address(pancakeswapV2Pair), _totalSupply);
        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), owner(), _totalSupply);
    }

     //to receive ETH from pancakeswapV2Router when swapping
    receive() external payable {}

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
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
    function decimals() public view virtual returns (uint8) { return _decimals; }
    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }
    // function getOwner() external view override returns (address) { return owner(); }
    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }
    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
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
    function approve(address spender, uint256 amount) public virtual returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, _totalSupply);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            unchecked {
                _approve(sender, _msgSender(), currentAllowance - amount);
            }
        }

        _transfer(sender, recipient, amount);

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

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }

   function getFeesandWallet() external view returns (address GameAddress,uint256 GamePool, uint256 Liquidity) {
        return (GamePoolAddress,_BNBFee , _liquidityFee);
    }
    function setPoolAddress(address gameaccount) external onlyOwner() {
        require(gameaccount != GamePoolAddress, 'This Address was already used');
        GamePoolAddress = gameaccount;
        emit UpdatePoolAddress(gameaccount);
    }

    function setCoolDownTime(uint256 timeForContract) external onlyOwner() {
        require(swapCoolDownTime != timeForContract);
        swapCoolDownTime = timeForContract;
        emit UpdatedCoolDowntime(timeForContract);
    }
    function updatePresaleStatus(bool status) external onlyOwner() {
        presaleEnded = status;
    }

    function excludeFromFee(address account) external onlyOwner() {
        _isExcludedFromFee[account] = true;
        emit ExcludedFromFee(account);
    }

    function includeInFee(address account) external onlyOwner() {
        _isExcludedFromFee[account] = false;
        emit IncludedToFee(account);
    }

    function setFees(uint256 bnbFee, uint256 liquidityFee) external onlyOwner() {
        require(_BNBFee != bnbFee || _liquidityFee != liquidityFee);
        uint256 totalFee = bnbFee.add(liquidityFee);
        require(totalFee <= 15, "Please set fee below than 15");
        _BNBFee = bnbFee;
        _liquidityFee = liquidityFee;
        emit UpdateFees(bnbFee, liquidityFee);
    }

    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner() {
        require(maxTxAmount >= _totalSupply / 1000);
        _maxTxAmount = maxTxAmount;
        emit UpdatedMaxTxAmount(maxTxAmount);
    }

    function setNumTokensToSwap(uint256 amount) external onlyOwner() {
        require(numTokensToSwap != amount);
        numTokensToSwap = amount;
        emit UpdateNumtokensToSwap(amount);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner() {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function _getFeeValues(uint256 tAmount) private view returns (uint256) {
        uint256 fee = tAmount.mul(_BNBFee + _liquidityFee).div(10**2);
        uint256 tTransferAmount = tAmount.sub(fee);
        return tTransferAmount;
    }

    function removeAllFee() private {
        if(_BNBFee == 0 && _liquidityFee == 0) return;

        _previousBNBFee = _BNBFee;
        _previousLiquidityFee = _liquidityFee;

        _BNBFee = 0;
        _liquidityFee = 0;
    }

    function restoreAllFee() private {
        _BNBFee = _previousBNBFee;
        _liquidityFee = _previousLiquidityFee;
    }

    function isExcludedFromFee(address account) external view returns(bool) {
        return _isExcludedFromFee[account];
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
        require(amount > 0, "Transfer amount must be greater than zero");
        if (recipient == pancakeswapV2Pair && balanceOf(pancakeswapV2Pair) == 0) {
            require(presaleEnded == true, "You are not allowed to add liquidity before presale is ended");
        }

        // maxTxAmount only apply at buy and sell
        if(
            !_isExcludedFromFee[sender] &&
            !_isExcludedFromFee[recipient] &&
            balanceOf(pancakeswapV2Pair) > 0 &&
            !inSwapAndLiquify &&
            sender != address(pancakeswapV2Router) &&
            (sender == pancakeswapV2Pair || recipient == pancakeswapV2Pair)
        ) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is pancakeswap pair.
        uint256 tokenBalance = balanceOf(address(this));
        if(tokenBalance >= _maxTxAmount){ tokenBalance = _maxTxAmount; }
        bool overMinTokenBalance = tokenBalance >= numTokensToSwap;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            sender != pancakeswapV2Pair &&
            swapAndLiquifyEnabled &&
            block.timestamp >= lastSwapTime + swapCoolDownTime
        ) {
            tokenBalance = numTokensToSwap;
            swapAndCharge(tokenBalance);
            lastSwapTime = block.timestamp;
        }

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = false;
        if (balanceOf(pancakeswapV2Pair) > 0 && (sender == pancakeswapV2Pair || recipient == pancakeswapV2Pair)) {
            takeFee = true;
        }

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]){
            takeFee = false;
        }

        if(!takeFee)
            removeAllFee();

        uint256 tTransferAmount = _getFeeValues(amount);
        _balances[recipient] = _balances[recipient].add(tTransferAmount);
        _balances[address(this)] = _balances[address(this)].add(amount.sub(tTransferAmount));

        emit Transfer(sender, recipient, tTransferAmount);

        if(!takeFee)
            restoreAllFee();

    }

    function swapAndCharge(uint256 tokenBalance) internal lockTheSwap {
        uint256 initialBalance = address(this).balance;

        uint256 liquidBalance = tokenBalance.mul(_liquidityFee).div(_liquidityFee + _BNBFee).div(2);
        tokenBalance = tokenBalance.sub(liquidBalance);
        swapTokensForEth(tokenBalance);

        uint256 newBalance = address(this).balance.sub(initialBalance);
        uint256 bnbForLiquid = newBalance.mul(liquidBalance).div(tokenBalance);
        addLiquidity(liquidBalance, bnbForLiquid);

        payable(GamePoolAddress).transfer(address(this).balance);
        emit SwapAndCharged(tokenBalance, liquidBalance, address(this).balance, bnbForLiquid);
    }


    function swapTokensForEth(uint256 tokenAmount) internal {
        // generate the pancakeswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapV2Router.WETH();

        // make the swap
        pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {

        // add the liquidity
        pancakeswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }
}