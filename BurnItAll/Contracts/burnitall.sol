// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) { return 0; }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor (address initialOwner) {
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function getUnlockTime() public view returns (uint256) {
        return _lockTime;
    }

    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(_owner, address(0));
    }

    function unlock() public virtual {
        require(_previousOwner == msg.sender, "You don't have permission to unlock");
        require(block.timestamp > _lockTime , "Contract is still locked");
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
        _previousOwner = address(0);
    }
}

interface IUniswapV2Factory {
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

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

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
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
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
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
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
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract BurnItAll is Context, IBEP20, Ownable {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => bool)    private _isExcludedFromFee;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) public _isExcludedFromAutoLiquidity;

    address public _burnAddress     = 0x000000000000000000000000000000000000dEaD;
    address public _marketingWallet = 0xbCc210E4803Bfca8762c76ee5d85bB60263f3e5F; // change this
    address public _rewardWallet    = 0x99c2F835F2415Edb6ECe615Ee9296a232a67633C; // change this

    string  private constant _name        = "BurnItAll";
    string  private constant _symbol      = "Burn";
    uint8   private constant _decimals    = 18;
    uint256 private constant _totalSupply = 2000000000000000 * 10 ** uint256(_decimals);

    /*
        Initial values:
        30% of every buy / sell is sent to burn wallet
        2%  of every buy / sell is added back to liquidity
        1%  of every buy / sell is sent to marketing wallet
        2%  of every buy / sell is sent to reward wallet
    */

    uint256 public  _burnFeeBuy       = 3000;
    uint256 public  _liquidityFeeBuy  = 200;
    uint256 public  _marketingFeeBuy  = 100;
    uint256 public  _rewardFeeBuy     = 200;

    uint256 public  _burnFeeSell      = 3000;
    uint256 public  _liquidityFeeSell = 200;
    uint256 public  _marketingFeeSell = 100;
    uint256 public  _rewardFeeSell    = 200;

    uint256 public _maxTxAmount     = _totalSupply / 2;
    uint256 public _minTokenBalance = _totalSupply / 4000;

    // liquidity
    bool public  _swapAndLiquifyEnabled = true;
    bool private _inSwapAndLiquify;
    IUniswapV2Router02 public _uniswapV2Router;
    address            public _uniswapV2Pair;
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );

    // anti whale
    bool    public _isAntiWhaleEnabled = true;
    uint256 public _antiWhaleThresholdDivisor = 100; // 1% of circulating supply
    uint256 public _antiWhaleAdditionalBurnMultiplier = 100000; // additional 10% burn fee of each 1% of LP
    mapping (address => bool) public _isExcludedFromAntiWhale;

    modifier lockTheSwap {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    constructor (address cOwner) Ownable(cOwner) {
        _balances[cOwner] = _totalSupply;

        // Create a uniswap pair for this new token
        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        _uniswapV2Router = uniswapV2Router;

        // exclude system addresses from fee
        _isExcludedFromFee[owner()]       = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromAntiWhale[owner()] = true;

        _isExcludedFromAutoLiquidity[_uniswapV2Pair] = true;

        emit Transfer(address(0), cOwner, _totalSupply);
    }

    receive() external payable {}

    // BEP20
    function name() public view virtual returns (string memory) {
        return _name;
    }
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "BEP20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance.sub(amount));

        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "BEP20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance.sub(subtractedValue));

        return true;
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // STATE
    function setMarketingWallet(address a) external onlyOwner {
        _marketingWallet = a;
    }
    function setRewardWallet(address a) external onlyOwner {
        _rewardWallet = a;
    }
    function setExcludedFromFee(address account, bool e) external onlyOwner {
        _isExcludedFromFee[account] = e;
    }
    function setBuyFees(uint256 burnFee, uint256 liquidityFee, uint256 marketingFee, uint256 rewardFee) external onlyOwner {
        _burnFeeBuy      = burnFee;
        _liquidityFeeBuy = liquidityFee;
        _marketingFeeBuy = marketingFee;
        _rewardFeeBuy    = rewardFee;
    }
    function setSellFees(uint256 burnFee, uint256 liquidityFee, uint256 marketingFee, uint256 rewardFee) external onlyOwner {
        _burnFeeSell      = burnFee;
        _liquidityFeeSell = liquidityFee;
        _marketingFeeSell = marketingFee;
        _rewardFeeSell    = rewardFee;
    }
    function setAntiWhaleEnabled(bool e) external onlyOwner {
        _isAntiWhaleEnabled = e;
    }
    function setExcludedFromAntiWhale(address a, bool b) external onlyOwner {
        _isExcludedFromAntiWhale[a] = b;
    }
    function setAntiWhaleThresholdDivisor(uint256 a) external onlyOwner {
        _antiWhaleThresholdDivisor = a;
    }
    function setAntiWhaleAdditionalBurnMultiplier(uint256 a) external onlyOwner {
        _antiWhaleAdditionalBurnMultiplier = a;
    }
    function setMaxTx(uint256 maxTx) external onlyOwner {
        _maxTxAmount = maxTx;
    }
    function setMinTokenBalance(uint256 minTokenBalance) external onlyOwner {
        _minTokenBalance = minTokenBalance;
    }
    function setSwapAndLiquifyEnabled(bool enabled) public onlyOwner {
        _swapAndLiquifyEnabled = enabled;
        emit SwapAndLiquifyEnabledUpdated(enabled);
    }
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }
    function setExcludedFromAutoLiquidity(address a, bool b) external onlyOwner {
        _isExcludedFromAutoLiquidity[a] = b;
    }
    function setUniswapRouter(address r) external onlyOwner {
        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(r);
        _uniswapV2Router = uniswapV2Router;
    }
    function setUniswapPair(address p) external onlyOwner {
        _uniswapV2Pair = p;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(_balances[sender] >= amount, "BEP20: transfer amount exceeds balance");

        if (sender != owner() && recipient != owner()) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        /*
            - swapAndLiquify will be initiated when token balance of this contract
            has accumulated enough over the minimum number of tokens required.
            - don't get caught in a circular liquidity event.
            - don't swapAndLiquify if sender is uniswap pair.
        */
        uint256 contractTokenBalance = balanceOf(address(this));
        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }
        bool isOverMinTokenBalance = contractTokenBalance >= _minTokenBalance;
        if (
            isOverMinTokenBalance &&
            !_inSwapAndLiquify &&
            !_isExcludedFromAutoLiquidity[sender] &&
            _swapAndLiquifyEnabled
        ) {
            contractTokenBalance = _minTokenBalance;
            swapAndLiquify(contractTokenBalance);
        }

        bool isBuy  = sender == _uniswapV2Pair && recipient != address(_uniswapV2Router);
        bool isSell = recipient == _uniswapV2Pair;
        bool isFeeExempt = _isExcludedFromFee[sender] || _isExcludedFromFee[recipient];

        if (isFeeExempt || (!isBuy && !isSell)) {
            _transferStandard(sender, recipient, amount);

        } else {
            _transferWithFees(sender, recipient, amount, isBuy, isSell);
        }

        /*
            anti whale: check if recipient balance will be greater than the specified threshold
            if greater, throw error
        */
        if (_isAntiWhaleEnabled && !_isExcludedFromAntiWhale[recipient]) {
            if ( sender == _uniswapV2Pair || sender == address(_uniswapV2Router) ) {
                uint256 antiWhaleThreshold = (_totalSupply - balanceOf(_burnAddress)) / _antiWhaleThresholdDivisor;
                require(balanceOf(recipient) <= antiWhaleThreshold, "Anti whale: can't hold more than the specified threshold");
            }
        }
    }
    function _transferStandard(address sender, address recipient, uint256 amount) private {
        _balances[sender]    = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    function _transferWithFees(address sender, address recipient, uint256 amount, bool isBuy, bool isSell) private {
        (uint256 burnFee, uint256 liquidityFee, uint256 marketingFee, uint256 rewardFee) = _calcTransferFees(amount, isBuy, isSell);
        uint256 transferredAmount = _distributeFees(sender, burnFee, liquidityFee, marketingFee, rewardFee, amount);

        _balances[sender]    = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(transferredAmount);

        emit Transfer(sender, recipient, transferredAmount);
    }
    function _calcTransferFees(uint256 amount, bool isBuy, bool isSell) private view returns(uint256, uint256, uint256, uint256) {
        uint256 burnFee      = 0;
        uint256 liquidityFee = 0;
        uint256 marketingFee = 0;
        uint256 rewardFee    = 0;
        if (isBuy) {
            burnFee      = _burnFeeBuy;
            liquidityFee = _liquidityFeeBuy;
            marketingFee = _marketingFeeBuy;
            rewardFee    = _rewardFeeBuy;

        } else if (isSell) {
            uint256 addBurnFee = _calculateAddBurnFee(amount);

            burnFee = _burnFeeSell + addBurnFee;
            if (burnFee > 9900) { // max 99%
                burnFee = 9900;
            }

            liquidityFee = _liquidityFeeSell;
            marketingFee = _marketingFeeSell;
            rewardFee    = _rewardFeeSell;
        }
        return(burnFee, liquidityFee, marketingFee, rewardFee);
    }
    function _calculateAddBurnFee(uint256 amount) private view returns(uint256) {
        uint256 addBurnFee = 0;
        if (_antiWhaleAdditionalBurnMultiplier != 0) {
            IUniswapV2Pair pair = IUniswapV2Pair(_uniswapV2Pair);
            (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
            if (pair.token0() == address(this)) {
                addBurnFee = amount.mul(_antiWhaleAdditionalBurnMultiplier).div(uint256(reserve0));
            } else if (pair.token1() == address(this)) {
                addBurnFee = amount.mul(_antiWhaleAdditionalBurnMultiplier).div(uint256(reserve1));
            }
        }
        return addBurnFee;
    }
    function _distributeFees(address sender, uint256 burnFee, uint256 liquidityFee, uint256 marketingFee, uint256 rewardFee, uint256 amount) private returns(uint256) {
        uint256 taxedBurn      = amount.mul(burnFee).div(10000);
        uint256 taxedLiquidity = amount.mul(liquidityFee).div(10000);
        uint256 taxedMarketing = amount.mul(marketingFee).div(10000);
        uint256 taxedReward    = amount.mul(rewardFee).div(10000);

        uint256 transferredAmount = amount.sub(taxedBurn).sub(taxedLiquidity).sub(taxedMarketing).sub(taxedReward);

        takeTransactionFee(sender, _burnAddress     , taxedBurn);
        takeTransactionFee(sender, address(this)    , taxedLiquidity);
        takeTransactionFee(sender, _marketingWallet , taxedMarketing);
        takeTransactionFee(sender, _rewardWallet    , taxedReward);

        return transferredAmount;
    }
    function takeTransactionFee(address sender, address feeRecipient, uint256 feeAmount) private {
        if (feeAmount <= 0) { return; }
        _balances[feeRecipient] = _balances[feeRecipient].add(feeAmount);
        if (feeRecipient != address(this)) {
            emit Transfer(sender, feeRecipient, feeAmount);
        }
    }
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split contract balance into halves
        uint256 half      = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        /*
            capture the contract's current BNB balance.
            this is so that we can capture exactly the amount of BNB that
            the swap creates, and not make the liquidity event include any BNB
            that has been manually sent to the contract.
        */
        uint256 initialBalance = address(this).balance;

        // swap tokens for BNB
        swapTokensForBnb(half);

        // this is the amount of BNB that we just swapped into
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }
    function swapTokensForBnb(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _uniswapV2Router.WETH();

        _approve(address(this), address(_uniswapV2Router), tokenAmount);

        // make the swap
        _uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }
    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(_uniswapV2Router), tokenAmount);

        // add the liquidity
        _uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

}


