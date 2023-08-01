// Contract has been created by <DEVAI> a Telegram AI bot. Visit https://t.me/ContractDevAI
// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


interface IERC20
{
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
        if (a == 0) {
            return 0;
        }

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
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

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

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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

}



interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    function createPair(address tokenA, address tokenB) external returns (address pair);}


// pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
        function factory() external view returns (address);

}

// pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

}



// pragma solidity >=0.6.2;

interface IUniswapV2Router02 is IUniswapV2Router01 {

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


contract LockToken is Ownable {
    bool public isOpen = false;
    mapping(address => bool) private _whiteList;
    modifier open(address from, address to) {
        require(isOpen || _whiteList[from] || _whiteList[to], "Not Open");
        _;
    }

    constructor() {
        _whiteList[msg.sender] = true;
        _whiteList[address(this)] = true;
    }

    function openTrade() external onlyOwner
    {
        isOpen = true;
    }

    function includeToWhiteList(address _address) public onlyOwner {
        _whiteList[_address] = true;
    }

}

contract DEVAI is Context, IERC20, LockToken 
{

    using SafeMath for uint256;
    address payable public marketingAddress = payable(0x2a00E688826e7cC4AE768356C94E3C01aB620fFc);
    address payable public devAddress = payable(0x2a00E688826e7cC4AE768356C94E3C01aB620fFc);
    address public newOwner = 0x2a00E688826e7cC4AE768356C94E3C01aB620fFc;
    address public router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcludedFromWhale;
    mapping (address => bool) private _isExcluded;

    address[] private _excluded;
   
    string private _name = "Contract Developer AI";
    string private _symbol = "DEVAI";
    uint8 private _decimals = 18;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 1000000 * 10**18;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    uint256 public _buyLiquidityFee = 0;
    uint256 public _buyMarketingFee = 20;
    uint256 public _buyDevFee = 20;

    uint256 public buyTotalFee = _buyLiquidityFee+_buyMarketingFee+_buyDevFee;
    uint256[] private buyFeesBackup = [_buyLiquidityFee, _buyMarketingFee, _buyDevFee];
              
    uint256 public _sellLiquidityFee = 0;
    uint256 public _sellMarketingFee = 20;
    uint256 public  _sellDevFee = 20;

    uint256 public sellTotalFee = _sellLiquidityFee+_sellMarketingFee+_sellDevFee;

    uint256 public _tfrLiquidityFee = 0;
    uint256 public _tfrMarketingFee = 0;
    uint256 public  _tfrDevFee = 0;
    uint256 public transferTotalFee = _tfrLiquidityFee+_tfrMarketingFee+_tfrDevFee;

    uint256 public _maxTxAmount = _tTotal.div(100).mul(100); //x% of total supply
    uint256 public _walletHoldingMaxLimit =  _tTotal.div(100).mul(100); //x% of total supply
    uint256 private minimumTokensBeforeSwap = 2000 * 10**18;

        
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    
    
    event SwapTokensForETH(
        uint256 amountIn,
        address[] path
    );
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
   
    constructor() {
        _rOwned[newOwner] = _rTotal;
        emit Transfer(address(0), newOwner, _tTotal);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        _isExcludedFromFee[newOwner] = true;
        _isExcludedFromFee[address(this)] = true;
        includeToWhiteList(newOwner);
        _isExcludedFromWhale[newOwner] = true;
        excludeWalletsFromWhales();

        transferOwnership(newOwner);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }


    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function minimumTokensBeforeSwapAmount() public view returns (uint256) {
        return minimumTokensBeforeSwap;
    }



    function tokenFromReflection(uint256 rAmount) private view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }



    function _approve(address owner, address spender, uint256 amount) private
    {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private open(from, to)
    {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if(from != owner() && to != owner()) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinimumTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;

        checkForWhale(from, to, amount);

        if (!inSwapAndLiquify && swapAndLiquifyEnabled && from != uniswapV2Pair)
        {
            if (overMinimumTokenBalance)
            {
                contractTokenBalance = minimumTokensBeforeSwap;
                swapTokens(contractTokenBalance);
            }
        }

        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to])
        {
            takeFee = false;
        }
        _tokenTransfer(from, to, amount, takeFee);
    }


    function swapTokens(uint256 contractTokenBalance) private lockTheSwap
    {
        uint256 __buyTotalFee  = _buyLiquidityFee.add(_buyMarketingFee).add(_buyDevFee);    
        uint256 __sellTotalFee = _sellLiquidityFee.add(_sellMarketingFee).add(_sellDevFee);
        uint256 totalSwapableFees = __buyTotalFee.add(__sellTotalFee);

        uint256 halfLiquidityTokens = contractTokenBalance.mul(_buyLiquidityFee+_sellLiquidityFee).div(totalSwapableFees).div(2);
        uint256 swapableTokens = contractTokenBalance.sub(halfLiquidityTokens);
        swapTokensForEth(swapableTokens);

        uint256 newBalance = address(this).balance;
        uint256 ethForLiquidity = newBalance.mul(_buyLiquidityFee+_sellLiquidityFee).div(totalSwapableFees).div(2);

        if(halfLiquidityTokens>0 && ethForLiquidity>0)
        {
            addLiquidity(halfLiquidityTokens, ethForLiquidity);
        }

        uint256 ethForMarketing = newBalance.mul(_buyMarketingFee+_sellMarketingFee).div(totalSwapableFees);
        if(ethForMarketing>0)
        {
           marketingAddress.transfer(ethForMarketing);
        }

        uint256 ethForDev = newBalance.sub(ethForLiquidity).sub(ethForMarketing);
        if(ethForDev>0)
        {
            devAddress.transfer(ethForDev);
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private
    {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
        emit SwapTokensForETH(tokenAmount, path);
    }



    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );
    }


    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private
    {
        if(!takeFee) 
        {
            removeAllFee();
        }
        else
        {
            if(recipient==uniswapV2Pair)
            {
                setSellFee();
            }

            if(sender != uniswapV2Pair && recipient != uniswapV2Pair)
            {
                setWalletToWalletTransferFee();
            }
        }


        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        restoreAllFee();

    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 tTransferAmount,  uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        emit Transfer(sender, recipient, tTransferAmount);
        if(tLiquidity>0)  { emit Transfer(sender, address(this), tLiquidity); }
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 tTransferAmount, uint256 tLiquidity) = _getValues(tAmount);
	    _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        emit Transfer(sender, recipient, tTransferAmount);
        if(tLiquidity>0)  { emit Transfer(sender, address(this), tLiquidity); }
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 tTransferAmount, uint256 tLiquidity) = _getValues(tAmount);
    	_tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        emit Transfer(sender, recipient, tTransferAmount);
        if(tLiquidity>0)  { emit Transfer(sender, address(this), tLiquidity); }
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 tTransferAmount, uint256 tLiquidity) = _getValues(tAmount);
    	_tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        emit Transfer(sender, recipient, tTransferAmount);
        if(tLiquidity>0)  { emit Transfer(sender, address(this), tLiquidity); }
    }


    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tLiquidity) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount) = _getRValues(tAmount, tLiquidity, _getRate());
        return (rAmount, rTransferAmount, tTransferAmount, tLiquidity);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256) {
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tLiquidity);
        return (tTransferAmount, tLiquidity);
    }

    function _getRValues(uint256 tAmount, uint256 tLiquidity, uint256 currentRate) private pure returns (uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rLiquidity);
        return (rAmount, rTransferAmount);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
        }
    }


    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        uint256 fees = _buyLiquidityFee.add(_buyMarketingFee).add(_buyDevFee);
        return _amount.mul(fees).div(1000);
    }


    function isExcludedFromFee(address account) public view onlyOwner returns(bool)  {
        return _isExcludedFromFee[account];
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function removeAllFee() private {
        _buyLiquidityFee = 0;
        _buyMarketingFee = 0;
        _buyDevFee = 0;
    }

    function restoreAllFee() private
    {
        _buyLiquidityFee = buyFeesBackup[0];
        _buyMarketingFee = buyFeesBackup[1];
        _buyDevFee = buyFeesBackup[2];
    }

    function setSellFee() private
    {
        _buyLiquidityFee = _sellLiquidityFee;
        _buyMarketingFee = _sellMarketingFee;
        _buyDevFee = _sellDevFee;
    }


    function setWalletToWalletTransferFee() private 
    {
        _buyLiquidityFee = _tfrLiquidityFee;
        _buyMarketingFee = _tfrMarketingFee;
        _buyDevFee = _tfrDevFee;        
    }


    function setBuyFeePercentages(uint256 _liquidityFee, uint256  _marketingFee, uint256 _devFee)
    external onlyOwner()
    {
        _buyLiquidityFee = _liquidityFee;
        _buyMarketingFee = _marketingFee;
        _buyDevFee = _devFee;
        buyFeesBackup = [_buyLiquidityFee, _buyMarketingFee, _buyDevFee];
        uint256 totalFee = _liquidityFee.add(_marketingFee).add(_devFee);
        buyTotalFee = _buyLiquidityFee+_buyMarketingFee+_buyDevFee;
        require(totalFee<=250, "Too High Fee");
    }

    function setSellFeePercentages(uint256 _liquidityFee, uint256  _marketingFee, uint256 _devFee)
    external onlyOwner()
    {
        _sellLiquidityFee = _liquidityFee;
        _sellMarketingFee = _marketingFee;
        _sellDevFee = _devFee;
        uint256 totalFee = _liquidityFee.add(_marketingFee).add(_devFee);
        sellTotalFee = _sellLiquidityFee+_sellMarketingFee+_sellDevFee;
        require(totalFee<=250, "Too High Fee");
    }


    function setTransferFeePercentages(uint256 _liquidityFee, uint256  _marketingFee, uint256 _devFee)
    external onlyOwner()
    {
        _tfrLiquidityFee = _liquidityFee;
        _tfrMarketingFee = _marketingFee;
        _tfrDevFee = _devFee;
        transferTotalFee = _tfrLiquidityFee+_tfrMarketingFee+_tfrDevFee;
        uint256 totalFee = _liquidityFee.add(_marketingFee).add(_devFee);
        require(totalFee<=50, "Too High Fee");
    }


    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner()
    {
        _maxTxAmount = maxTxAmount;
        require(_maxTxAmount>=_tTotal.div(5), "Too low limit");
    }

    function setMinimumTokensBeforeSwap(uint256 _minimumTokensBeforeSwap) external onlyOwner()
    {
        minimumTokensBeforeSwap = _minimumTokensBeforeSwap;
    }

    function setMarketingAddress(address _marketingAddress) external onlyOwner()
    {
        marketingAddress = payable(_marketingAddress);
    }

    function setDevAddress(address _devAddress) external onlyOwner()
    {
        devAddress = payable(_devAddress);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner
    {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function excludeWalletsFromWhales() private
    {
        _isExcludedFromWhale[owner()]=true;
        _isExcludedFromWhale[address(this)]=true;
        _isExcludedFromWhale[uniswapV2Pair]=true;
        _isExcludedFromWhale[devAddress]=true;
        _isExcludedFromWhale[marketingAddress]=true;
    }


    function checkForWhale(address from, address to, uint256 amount)  private view
    {
        uint256 newBalance = balanceOf(to).add(amount);
        if(!_isExcludedFromWhale[from] && !_isExcludedFromWhale[to])
        {
            require(newBalance <= _walletHoldingMaxLimit, "Exceeding max tokens limit in the wallet");
        }
        if(from==uniswapV2Pair && !_isExcludedFromWhale[to])
        {
            require(newBalance <= _walletHoldingMaxLimit, "Exceeding max tokens limit in the wallet");
        }
    }

    function setExcludedFromWhale(address account, bool _enabled) public onlyOwner
    {
        _isExcludedFromWhale[account] = _enabled;
    }

    function  setWalletMaxHoldingLimit(uint256 _amount) public onlyOwner
    {
        _walletHoldingMaxLimit = _amount;
        require(_walletHoldingMaxLimit > _tTotal.div(100).mul(1), "Too less limit"); //min 1%

    }

    function rescueStuckBalance () public onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    receive() external payable {}

}
