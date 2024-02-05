// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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


// pragma solidity >=0.5.0;

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
 // pragma solidity >=0.6.2;

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

// pragma solidity >=0.6.2;

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

contract ShiB is Context,ERC20,Ownable {
    mapping(address => bool) private isBlackList;
    mapping(address => bool) private liquidityPool;
    mapping(address => bool) private isExcludedFromFee;

    uint8 public buyTaxGamePool;
    uint8 public buyTaxStakingPool;
    uint8 public buyTaxMkt;
    uint8 public buyTaxBurn;

    uint8 public sellTaxGamePool;
    uint8 public sellTaxStakingPool;
    uint8 public sellTaxMkt;
    uint8 public sellTaxBurn;



    address private marketingPool;
    address private gamePool;
    address private stakingPool;

    bool inSwapAndLiquify;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    /**
     * constructor
     */
    constructor() ERC20("ShiB", "ShiB") {
        uint256 _total = 10 ** 9 * 10 ** 18;
        _mint(_msgSender(), _total);
        //set taxs
        buyTaxGamePool = 2;
        buyTaxStakingPool = 2;
        buyTaxMkt = 0;
        buyTaxBurn = 0;

        sellTaxGamePool = 1;
        sellTaxStakingPool = 1;
        sellTaxMkt = 2;
        sellTaxBurn = 1;

        marketingPool = 0x6e447ea51254964c4a07Ee37e63D0952f8283c53;
        gamePool = 0x0EEAaF7726A9C91B5107C66E95c779402e7dF4B9;
        stakingPool = 0xff97A65D50723588E0F57CbAFe9Fd5b386E64426;

        //mainnet
        address routerV2 = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        if(block.chainid == 97)
        {
            //testnet
            routerV2 = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
        }

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(routerV2);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        //bnb pool
        liquidityPool[uniswapV2Pair] = true;
    }

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function excludeFromFee(address _address) public onlyOwner {
        isExcludedFromFee[_address] = true;
    }

    function includeInFee(address _address) public onlyOwner {
        isExcludedFromFee[_address] = false;
    }

    function setBlacklist(address _address, bool _status) external onlyOwner {
        isBlackList[_address]= _status;
    }

    function setLiquidityPoolStatus(address _lpAddress, bool _status) external onlyOwner {
        liquidityPool[_lpAddress] = _status;
    }

    function setMarketingPool(address _marketingPool) external onlyOwner {
        marketingPool = _marketingPool;
    }

    function setGamePool(address _gamePool) external onlyOwner {
        gamePool = _gamePool;
    }

    function setStakingPool(address _stakingPool) external onlyOwner {
        stakingPool = _stakingPool;
    }

    function setSellTaxes(uint8 _gamePool, uint8 _stakingPool, uint8 _mktFee, uint8 _burn) external onlyOwner {
        require(_gamePool + _stakingPool + _mktFee + _burn <= 10, "Sell Tax cannot be greater than 10");
        sellTaxGamePool = _gamePool;
        sellTaxStakingPool = _stakingPool;
        sellTaxMkt = _mktFee;
        sellTaxBurn = _burn;
    }

    function setBuyTaxes(uint8 _gamePool, uint8 _stakingPool, uint8 _mktFee, uint8 _burn) external onlyOwner {
        require(_gamePool + _stakingPool + _mktFee + _burn <= 10, "Buy Tax cannot be greater than 10");
        buyTaxGamePool = _gamePool;
        buyTaxStakingPool = _stakingPool;
        buyTaxMkt = _mktFee;
        buyTaxBurn = _burn;
    }

  function _transfer(address sender, address receiver, uint256 amount) internal virtual override {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(receiver != address(0), "ERC20: transfer to the zero address");
    require(amount > 0, "Transfer amount must be greater than zero");

    require(!isBlackList[sender],"User blacklisted");

    uint256 taxAmount = 0;

    if(liquidityPool[sender] == true) {
      //buyTax = buyTaxGamePool+buyTaxStakingPool+buyTaxMkt+buyTaxBurn;
      taxAmount = (amount * uint256(buyTaxGamePool + buyTaxStakingPool + buyTaxMkt + buyTaxBurn)) / 100;
    } else if(liquidityPool[receiver] == true) {
      //sellTax = sellTaxGamePool+sellTaxStakingPool+sellTaxMkt+sellTaxBurn;
      taxAmount = (amount * uint256(sellTaxGamePool + sellTaxStakingPool + sellTaxMkt + sellTaxBurn)) / 100;
    }

    if(isExcludedFromFee[sender] || isExcludedFromFee[receiver] || sender == address(this) || receiver == address(this) || inSwapAndLiquify) {
      taxAmount = 0;
    }

    if(taxAmount > 0 && !inSwapAndLiquify) {

        if(liquidityPool[receiver])
        {
            //game
            if(sellTaxGamePool > 0)
            {
                super._transfer(sender, gamePool, amount * uint256(sellTaxGamePool) / 100);
            }

            //staking
            if(sellTaxStakingPool > 0)
            {
                super._transfer(sender, stakingPool, amount * uint256(sellTaxStakingPool) / 100);
            }

            //mkt
            if(sellTaxMkt > 0)
            {
                uint256 tokenToSwap = amount * uint256(sellTaxMkt) / 100;
                if(receiver == uniswapV2Pair)
                {
                    swapTokensForEth(sender, tokenToSwap);
                }
                else
                {
                    super._transfer(sender, marketingPool, tokenToSwap);
                }

            }

            //burn
            if(sellTaxBurn > 0)
            {
                _burn(sender, amount * uint256(sellTaxBurn) / 100);
            }
        }
        else if(liquidityPool[sender])
        {
            //game
            if(buyTaxGamePool > 0)
            {
                super._transfer(sender, gamePool, amount * uint256(buyTaxGamePool) / 100);
            }

            //staking
            if(buyTaxStakingPool > 0)
            {
                super._transfer(sender, stakingPool, amount * uint256(buyTaxStakingPool) / 100);
            }

            //mkt
            if(buyTaxMkt > 0)
            {
                super._transfer(sender, stakingPool, amount * uint256(buyTaxMkt) / 100);
            }

            //burn
            if(buyTaxBurn > 0)
            {
                _burn(sender, amount * uint256(buyTaxBurn) / 100);
            }
        }

    }
    super._transfer(sender, receiver, amount - taxAmount);
  }

  function swapTokensForEth(address sender, uint256 tokenAmount) private lockTheSwap  {
        // transfer to contract and swap to bnb
        super._transfer(sender, address(this), tokenAmount);

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), balanceOf(address(this)));

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            balanceOf(address(this)),
            0, // accept any amount of ETH
            path,
            marketingPool,
            block.timestamp
        );
    }
}