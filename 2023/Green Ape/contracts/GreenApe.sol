// SPDX-License-Identifier: MIT

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

       function transferOwnership(address newOwner) public virtual onlyOwner() {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
      
       function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
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

contract GreenApe is Context, IERC20, Ownable {
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    uint8 private  constant _decimals = 9;
    uint256 private  constant _tTotal = 11111111 * 10**_decimals;
    string private  constant _name = "GreenApe";
    string private  constant _symbol = "APE";
    
    //ExcludeFromFee function, used temporary by locks or presale
    mapping (address => bool) public _isExcludedFromFee;
    bool public tradingOpen = false;

     //Contract Update Information
    string public constant Contract_Version = "0.8.19";
    string public constant Contract_Dev = "Team Anoop SAFU DEV || NFA,DYOR";
    string public constant Contract_Edition = "Contract For Presale";
    address public constant deadWallet = 0x000000000000000000000000000000000000dEaD;

    // Events
    event TradingOpenUpdated();
    event ETHBalanceRecovered();
    event ERC20TokensRecovered(uint256 indexed _amount);
    event ExcludeFromFeeUpdated(address indexed account);
    event includeFromFeeUpdated(address indexed account);
   
    constructor () {
           if (block.chainid == 56){
     uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
     }
      else if(block.chainid == 1 || block.chainid == 4 || block.chainid == 3 || block.chainid == 5){
          uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
      }
      else if(block.chainid == 42161){
           uniswapV2Router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
      }
      else if (block.chainid == 97){
     uniswapV2Router = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
     }
    else {
         revert("Wrong Chain Id");
        }
    uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        
        _balances[_msgSender()] = _tTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[deadWallet] = true;
        _isExcludedFromFee[0x407993575c91ce7643a4d4cCACc9A98c36eE1BBE] = true; // BSC PinkSale Lock
        _isExcludedFromFee[0x5E5b9bE5fd939c578ABE5800a90C566eeEbA44a5] = true; // Tesnet PinkSale Lock
        _isExcludedFromFee[0xeBb415084Ce323338CFD3174162964CC23753dFD] = true; // Arbitrum PinkSale Lock
        _isExcludedFromFee[0x71B5759d73262FBb223956913ecF4ecC51057641] = true; // ETH PinkSale Lock
       
        emit Transfer(address(0), _msgSender(), _tTotal);
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
        return _tTotal;
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
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), currentAllowance - amount);
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
        require(amount <= balanceOf(from),"You are trying to transfer more than your balance");
        
         if (!_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            require(tradingOpen,"wait for trading to open");
            
        }

        _balances[from] = _balances[from] - (amount);
        _balances[to] = _balances[to] + (amount);
        emit Transfer(from, to, amount);
        
    }

  function excludeFromFee(address _address) external onlyOwner {
        require(_isExcludedFromFee[_address] != true,"Account is already excluded");
        _isExcludedFromFee[_address] = true;
       emit ExcludeFromFeeUpdated(_address);
    }
   
    function includeFromFee(address _address) external onlyOwner {
        require(_isExcludedFromFee[_address] != false,"Account is already excluded");
        _isExcludedFromFee[_address] = false;
       emit includeFromFeeUpdated(_address);
    }

    function enableTrading() external onlyOwner() {
        require(!tradingOpen,"trading is already open");
        tradingOpen = true;
      emit TradingOpenUpdated();
    }

    receive() external payable {}

   function recoverERC20FromContract(address _tokenAddy, uint256 _amount) external onlyOwner {
        require(_tokenAddy != address(this), "Owner can't claim contract's balance of its own tokens");
        require(_amount > 0, "Amount should be greater than zero");
        require(_amount <= IERC20(_tokenAddy).balanceOf(address(this)), "Insufficient Amount");
        IERC20(_tokenAddy).transfer(owner(), _amount);
      emit ERC20TokensRecovered(_amount); 
    }
 
 function recoverETHfromContract() external {
        uint256 contractETHBalance = address(this).balance;
        if (contractETHBalance > 0) {
        payable(address(owner())).transfer(contractETHBalance);
       emit ETHBalanceRecovered();
    }
  }
}