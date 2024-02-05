// SPDX-License-Identifier: MIT
//9ecc02a53f8032a599c51cbc7f7c474835c40cb0e92543f7995708cce9e06df9
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

    
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
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
contract SWORD is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _excludedFromFee;

    uint256 private  _tTotal = 100000000 * 10**18;
    
    uint256 private liquidityFee = 5;

    address private marketingWallet;
    address private treasuryWallet; 

    address public SWORD_PROTOCOL;

    string private _name;
    string private _symbol;
    uint8 private _decimals = 18;
    uint256 private _maxTotal;

    uint256 public minTokensBeforeSwap = 50000 * 10**18;

    uint256 public replenishTimer;
   
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool public addLiquidityEnabled = true;
    bool public isReplenishmentEnabled = false;

    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );
    
    event SwapTokensForETH(
        uint256 amountIn,
        address[] path
    );
  
    address public BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    event uniSwapRouterUpdated(address indexed operator, address indexed router, address indexed pair);


    constructor (address marketingAddr, address treasuryAddr, address swordProtocol) Ownable(msg.sender)  {
        _name = "SWORD";
        _symbol = "SWORD";
        _balances[_msgSender()] = _tTotal;

        marketingWallet = marketingAddr;
        treasuryWallet = treasuryAddr;

        SWORD_PROTOCOL = swordProtocol;

        excludeFromFee(_msgSender());
        excludeFromFee(address(this));
        excludeFromFee(SWORD_PROTOCOL);

        replenishTimer = block.timestamp;



        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

       


        emit Transfer(address(0), _msgSender(), _tTotal);
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

    function burnFrom(uint256 amount) public {
        require(_msgSender() != address(0), "ERC20: cannot permit zero address");
        _tTotal = _tTotal.sub(amount);
        _balances[_msgSender()] = _balances[_msgSender()].sub(amount);
        emit Transfer(address(0), _msgSender(), amount);
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function isExcludedFromFee(address addr) public view returns(bool) {
        return _excludedFromFee[addr];
    }

    function excludeFromFee(address addr) public onlyOwner {
        _excludedFromFee[addr] = true;
    }

    function includeInFee(address addr) public onlyOwner {
        _excludedFromFee[addr] = false;
    }

    function liquidityEnabled(bool _bool) public onlyOwner {
        addLiquidityEnabled = _bool;
    }

    function replenishmentEnabled(bool _bool) public onlyOwner {
        isReplenishmentEnabled = _bool;
    }

    function getLockedEther() public view returns(uint256){
        address wethAddr = uniswapV2Router.WETH();

        uint256 lockedEther = IERC20(wethAddr).balanceOf(uniswapV2Pair);

        return lockedEther;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    receive() external payable {}
    
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _takeLiquidity(uint256 amount) private returns(uint256) {
        uint256 liquidityAmount = amount.mul(liquidityFee).div(100);
        _balances[address(this)] = _balances[address(this)].add(liquidityAmount);
        

        return liquidityAmount;
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this), // The contract
            block.timestamp
        );
        
        emit SwapTokensForETH(tokenAmount, path);
    }

    function syncPair() private {
        IUniswapV2Pair(uniswapV2Pair).sync();
    }

    function transferToProtocol() private {
        uint256 pairBalance = balanceOf(uniswapV2Pair);

        uint256 portion = pairBalance.div(100); // 1% of uniswap pair token balance

        _balances[uniswapV2Pair] = _balances[uniswapV2Pair].sub(portion);
        _balances[SWORD_PROTOCOL] = _balances[SWORD_PROTOCOL].add(portion);
        
        syncPair();

        emit Transfer(uniswapV2Pair, SWORD_PROTOCOL, portion);
    }

    function replenishProtocol() public {
        if(replenishTimer <= block.timestamp && isReplenishmentEnabled) {

            transferToProtocol();

            replenishTimer = replenishTimer.add(24 hours); // replenishment once a day
        }
    }


    function distributeFee() public {

        uint256 balance = address(this).balance;

        if(balance > 0) {
            uint256 marketingFee = balance.mul(8).div(10);
            uint256 treasuryFee = balance.sub(marketingFee);

            payable(marketingWallet).transfer(marketingFee);
            payable(treasuryWallet).transfer(treasuryFee);
        }

    }


    function takeFee(address sender, uint256 amount) private returns(uint256) {

        uint256 liquidityAmount = 0;

        if(addLiquidityEnabled) {

            liquidityAmount = _takeLiquidity(amount);

            uint256 contractTokenBalance = _balances[address(this)];

            if( contractTokenBalance > minTokensBeforeSwap && sender != uniswapV2Pair) {

                swapTokensForEth(contractTokenBalance);
            }

            emit Transfer(sender, address(this), liquidityAmount);

        }

        return liquidityAmount;
    }
      
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        
        if (isExcludedFromFee(sender) || isExcludedFromFee(recipient)) {
            _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
            _balances[recipient] = _balances[recipient].add(amount);
            
            emit Transfer(sender, recipient, amount);

        } else {

            uint256 feeAmount = 0;
            
            if(recipient == uniswapV2Pair || sender == uniswapV2Pair) {
                

                feeAmount = takeFee(sender,amount);

                distributeFee();
            }




            
            uint256 sendAmount = amount.sub(feeAmount);
        
            _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
            _balances[recipient] = _balances[recipient].add(sendAmount);

            emit Transfer(sender, recipient, sendAmount);
            
        }

    }
}