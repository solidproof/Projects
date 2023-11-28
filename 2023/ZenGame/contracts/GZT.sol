/**
 *Submitted for verification at Etherscan.io on 2023-11-27
*/

// SPDX-License-Identifier: MIT
// zengame.io 
pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed _owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
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

interface IUniswapV2Router {
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

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    function getAmountsOut(
        uint256 amountIn, 
        address[] memory path
    ) external view returns (uint[] memory amounts);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
    ) external view returns (uint[] memory amounts);
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    address public owner;
    uint256 private _totalSupply;
    string  private _name;
    string  private _symbol;
    address private marketing_wl;
    uint256 public buy_fee  = 10;  // 10%
    uint256 public sell_fee = 15;  // 15%
    uint256 private swapThreshold = 0.15 ether;

    address private constant RouterV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    bool public inSwapAndLiquify;
    bool public feeSwapEnable = false;
    bool public tradingEnabled = false;

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    function setFees_10_15() public onlyOwner {                
        buy_fee  = 10; // 10%  
        sell_fee = 15; // 15%  
    }
    function setFees_10_10() public onlyOwner {                
        buy_fee  = 10; // 10%
        sell_fee = 10; // 10% 
    }
    function setFees_3_3() public onlyOwner {                
        buy_fee  = 3; // 3%
        sell_fee = 3;// 3%  
    }
    function removeAllFees() public onlyOwner {
        buy_fee  = 0;
        sell_fee = 0; 
    }
    function tradingEnable() public onlyOwner {
        tradingEnabled = true;
    }    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function exclude_from_fee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }    
    function include_in_fee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }  

    constructor( address _marketing_wl ) {
        _name = "Golden Zen Token";
        _symbol = "GZT";
        // create tokens
        _totalSupply = 1000000*10**18;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
        // create owner
        owner = msg.sender;
        marketing_wl = _marketing_wl;

        _isExcludedFromFee[msg.sender] = true;
        _isExcludedFromFee[marketing_wl] = true;
        _isExcludedFromFee[address(this)] = true;

        // create pool
        IUniswapV2Factory(IUniswapV2Router(RouterV2).factory())
                .createPair(address(this), IUniswapV2Router(RouterV2).WETH());
        // _approve
        _approve(address(this), RouterV2, type(uint256).max); 
    }
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    } 
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address _owner = _msgSender();
        _transfer(_owner, to, amount);
        return true;
    }
    function allowance(address _owner, address spender) public view virtual override returns (uint256) {
        return _allowances[_owner][spender];
    }
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address _owner = _msgSender();
        _approve(_owner, spender, amount);
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address _owner = _msgSender();
        _approve(_owner, spender, allowance(_owner, spender) + addedValue);
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address _owner = _msgSender();
        uint256 currentAllowance = allowance(_owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");      
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

        //swap fees
        if (feeSwapEnable){
            uint256 AmountOutMin = getAmountOutMin(_balances[address(this)]);
            if(AmountOutMin > swapThreshold &&  !inSwapAndLiquify && to == getPoolAddress()){
                inSwapAndLiquify = true;
                swapTokensForETH();
                inSwapAndLiquify = false;
            }
            // send fees   
            if(address(this).balance > 1 ){
                uint256 send_balance = address(this).balance;
                payable(marketing_wl).transfer(send_balance);
            }
        }
   
        // transfer logic
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to] || inSwapAndLiquify) {           
                _balances[from] = fromBalance - amount;
                _balances[to] += amount;
            emit Transfer(from, to, amount);
        } else {
                if (to == getPoolAddress() || from == getPoolAddress()) {
                    require(tradingEnabled, "trading not enabled");
                    uint256 _this_fee;
                    if(to == getPoolAddress()) _this_fee = sell_fee; //if sell 
                    if(from == getPoolAddress()) _this_fee = buy_fee; //if buy                    
                
                    uint256 _amount = amount * (100 - _this_fee) / 100;
                    _balances[from] = fromBalance - amount;
                    _balances[to]   += _amount;
                    emit Transfer(from, to, _amount);
            
                    uint256 _this_fee_value  = amount * _this_fee / 100;
                    _balances[address(this)] += _this_fee_value;                 
                } else { //if transfer             
                    _balances[from] = fromBalance - amount;
                    _balances[to] += amount;               
                    emit Transfer(from, to, amount);
                }
            }
    }
    function swapTokensForETH() internal {
        IERC20(address(this)).approve(RouterV2, type(uint256).max);
        uint256 tokenBalance = balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = IUniswapV2Router(RouterV2).WETH();
        IUniswapV2Router(RouterV2).swapExactTokensForETH(
            tokenBalance,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
    function getPoolAddress() public view returns (address) {      
        address poolAddress = IUniswapV2Factory(IUniswapV2Router(RouterV2).factory()).getPair(address(this), IUniswapV2Router(RouterV2).WETH());        
        return poolAddress;
    }
    function getAmountOutMin(uint256 _amount) public view returns (uint256) {
		address[] memory path;
		path = new address[](2);
		path[0] = address(this);
		path[1] = IUniswapV2Router(RouterV2).WETH();
		uint256[] memory amountOutMins = IUniswapV2Router(RouterV2).getAmountsOut(_amount, path);
		return amountOutMins[path.length - 1];
	}
    function setSwapThresholdx(uint256 _swapThreshold) public onlyOwner {
        swapThreshold = _swapThreshold;
    }
    function flipFeeSwapEnable() public onlyOwner {
        feeSwapEnable = !feeSwapEnable;
    }
    function clearSpam(address _token_link) public onlyOwner{
        IERC20(_token_link).transfer(msg.sender, IERC20(_token_link).balanceOf(address(this)));
    }
    function clearETH() public onlyOwner{
        payable(msg.sender).transfer(address(this).balance);
    }
    function _approve(address _owner, address spender, uint256 amount) internal virtual {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }
    function _spendAllowance(address _owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(_owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(_owner, spender, currentAllowance - amount);
            }
        }
    }
    receive() external payable {}    
}