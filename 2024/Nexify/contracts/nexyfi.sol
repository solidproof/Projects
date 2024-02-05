/**
 *Submitted for verification at Etherscan.io on 2024-01-23
*/

// SPDX-License-Identifier: MIT

/*              $$$                
                $XXXXX             
     $$$           XX$$$$$         
     $$$$$$         $$$$$$$     ________  __    __  __      __  ________  ______  
     $$$$$$$$$      $$$$$$$    /        |/  |  /  |/  \    /  |/        |/      |    
     $$$$$$$$$$$$$  $$$$$$$    $$$$$$$$/ $$ |  $$ |$$  \  /$$/ $$$$$$$$/ $$$$$$/     
     $$$$$$$$$$$$$$$$$$$$$$    $$ |__    $$  \/$$/  $$  \/$$/  $$ |__      $$ |      
     $$$$$$$$$$$$$$$$$$$$$$    $$    |    $$  $$<    $$  $$/   $$    |     $$ |      
     $$$$$$$  $$$$$$$$$$$$$    $$$$$/      $$$$  \    $$$$/    $$$$$/      $$ |      
     $$$$$$$     $$$$$$$$$$    $$ |_____  $$ /$$  |    $$ |    $$ |       _$$ |_     
     $$$$$$$         $$$$$$    $$       |$$ |  $$ |    $$ |    $$ |      / $$   |    
      $$$$$$$           $$$    $$$$$$$$/ $$/   $$/     $$/     $$/       $$$$$$/    
         $$$$$$                   	
             $$$ 		   FAST - SECURE - SAFE - IN-DEPTH ANALYSIS
--------------------------------------------------------------------------------------			
 -WEBSITE:    https://www.nexyfi.com
 -TWITTER:    https://www.x.com/nexyfi
 -TELEGRAM:   https://t.me/Nexyfi_Portal
 -KYC:        https://github.com/solidproof/projects/tree/main/2024/Nexify
 -BOT HUB:    https://t.me/Nexyfi_Bot
 -AUDIT:      https://bit.ly/Nexyfi-Audit
 -WHITEPAPER: https://docs.nexyfi.com
--------------------------------------------------------------------------------------
*/

pragma solidity 0.8.19;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
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
        return c;
    }

}

contract Ownable is Context {
    address private _owner;
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

}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
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

contract NexyFi is Context , IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    address payable private _taxReceiver;
    address private constant deadAddress = address(0xdead);

    uint256 private _initialBTax=30;
    uint256 private _initialSTax=30;
    uint256 private _finalBTax=15;
    uint256 private _finalSTax=20;
    uint256 private _reduceBTaxAt=30;
    uint256 private _reduceSTaxAt=45;
    uint256 private _preventSwap=40;
    uint256 private _Count=0;

    uint8 private constant _decimals = 9;
    uint256 private constant _tSupply = 100000000 * 10**_decimals;
    string private constant _name = unicode"NexyFi";
    string private constant _symbol = unicode"NEXY";
    uint256 public _maxTxAmount = 1000000 * 10**_decimals;
    uint256 public _maxWalletSize = 1000000 * 10**_decimals;
    uint256 public _taxSwapThreshold= 100000 * 10**_decimals;
    uint256 public _maxTaxSwap= 1000000 * 10**_decimals;

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private limitEffect = true;
    bool private inSwap = false;
    bool private swapEnabled = false;

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () {
        _taxReceiver = payable(0x4F83896670682AA78B9afc2BC108ffaE7fAfCf62);
        _balances[_msgSender()] = _tSupply;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[deadAddress]= true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_taxReceiver] = true;
        
        emit Transfer(address(0), _msgSender(), _tSupply);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
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

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount=0;

        if (from != owner() && to != owner()) { 

            if (!tradingOpen) {
                require( 
                  _isExcludedFromFee[from] || _isExcludedFromFee[to],
                  "trading is not yet open"
                );
            }

            if (from == uniswapV2Pair && to != address(uniswapV2Router) && ! _isExcludedFromFee[to] ) {
                if (limitEffect) {
                    require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                    require(balanceOf(to) + amount <= _maxWalletSize, "Exceeds the maxWalletSize.");
                } 
                _Count++;
            }
            
            if ( to == uniswapV2Pair && from!= address(this) ){
                taxAmount = amount.mul 
                ((_Count>_reduceSTaxAt)
                    ?_finalSTax:_initialSTax).div(100
                );
            } else if (from == uniswapV2Pair && to!= address(this) ){
                taxAmount = amount.mul
                ((_Count>_reduceBTaxAt)
                    ?_finalBTax:_initialBTax).div(100
                );
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (
                !inSwap && 
                to == uniswapV2Pair && 
                swapEnabled && 
                contractTokenBalance>_taxSwapThreshold && 
                _Count>_preventSwap
            ){
                swapTokensForEth(min(amount,min(contractTokenBalance,_maxTaxSwap)));
                uint256 contractETHBalance = address(this).balance;
                if(contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        if(taxAmount>0){
          _balances[address(this)]=_balances[address(this)].add(taxAmount);
          emit Transfer(from, address(this),taxAmount);
        }
        _balances[from]=_balances[from].sub(amount);
        _balances[to]=_balances[to].add(amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }

    function sendETHToFee(uint256 amount) private {
        _taxReceiver.transfer(amount);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256){
      return (a>b)?b:a;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
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
    }

    function addliquidity() external onlyOwner() {
        require(!tradingOpen,"Liquidity is already added");
        uint256 tokenAmount = balanceOf(address(this)).sub(_tSupply.mul(_finalSTax).div(100));
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(uniswapV2Router), _tSupply);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this), 
            uniswapV2Router.WETH()
        );
        uniswapV2Router.addLiquidityETH{value: address(this).balance} (
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max); 
    }

    function removeLimits () external onlyOwner returns (bool){
        limitEffect = false;
        return true;
    }
    
    function setFinalTax (uint256 _value) external onlyOwner returns (bool) {
        _finalBTax = _value;
        _finalSTax = _value;
        require(_value <= 5,"Tax cannot be greater than 5");
        return true;
    }

    function startTrading() external onlyOwner returns (bool) {
        require(!tradingOpen,"trading is already open");
        swapEnabled = true;
        tradingOpen = true;
        return true;
    }

    function clearstuckETH() external returns (bool) {
        require(tradingOpen,"trading is not yet open");
        uint256 ethBalance=address(this).balance;
        if(ethBalance>0){
          _taxReceiver.transfer(ethBalance);
        }
        return true;
    }
    receive() external payable {}
}