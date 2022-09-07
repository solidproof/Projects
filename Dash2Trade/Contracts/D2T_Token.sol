// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

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

interface IUniswapV2Factory {
  event PairCreated(address indexed token0, address indexed token1, address pair, uint);

  function getPair(address tokenA, address tokenB) external view returns (address pair);
  function allPairs(uint) external view returns (address pair);
  function allPairsLength() external view returns (uint);

  function feeTo() external view returns (address);
  function feeToSetter() external view returns (address);

  function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract D2T is Ownable, ERC20 {

    using SafeMath for uint256;

    address public uniswapV2Pair;
    IUniswapV2Router02 public router;
    uint256 public treasuryFee;
    address public treasuryAddress;

    uint256 public constant FEE_PRECISION = 1000;
    uint256 public immutable MAX_SUPPLY;
    address private constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    mapping (address => bool) private _isExcludedFromFee;

    bool private swapping;
    uint256 public swapAmountThreshold = 1 * 10 ** 18;

    modifier Swapping {
      swapping = true;
      _;
      swapping = false;
    }

    constructor(address _router, uint256 _supply) ERC20("Dash2Trade", "D2T") {

        router = IUniswapV2Router02(_router);
        uniswapV2Pair = IUniswapV2Factory(router.factory())
        .createPair(address(this), USDT_ADDRESS);

        MAX_SUPPLY = _supply.mul(10 ** 18);

        treasuryFee = 40;

        _isExcludedFromFee[msg.sender] = true;
        _isExcludedFromFee[address(this)] = true;

        _approve(address(this), address(router), uint256(int(-1)));

    }

    receive() payable external {}

    function updatePair(address _new) external onlyOwner {
        require(_new != address(0), "Null address");

        uniswapV2Pair = _new;
    }

    function updateFee(
        uint256 _treasury
    ) external onlyOwner {
        distributeFee();

        treasuryFee = _treasury;
    }

    function updateFeeAddress(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Null address");
        treasuryAddress = _treasury;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (
          !_isExcludedFromFee[from] && !_isExcludedFromFee[to]
        ) {  

          if (to == uniswapV2Pair) { //Selling

            uint256 _feeAmount = amount.mul(treasuryFee).div(FEE_PRECISION);

            super._transfer(from, address(this), _feeAmount);
            
            amount = amount.sub(_feeAmount);
          } else {
            uint256 contractTokenBalance = balanceOf(address(this));

            bool swapAmountOk = contractTokenBalance >= swapAmountThreshold;

            if (swapAmountOk && !swapping) {
                distributeFee();
            }
          }
        }

        super._transfer(from, to, amount);
    }

    function distributeFee() private Swapping {
      uint256 tokenBalance = balanceOf(address(this));
      swapTokensForUSDT(tokenBalance);
    }

    function swapTokensForUSDT(uint256 tokenAmount) private {

        if (tokenAmount == 0) return;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = USDT_ADDRESS;

        _approve(address(this), address(router), tokenAmount);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of USDT
            path,
            treasuryAddress,
            block.timestamp
        );
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        require(totalSupply() <= MAX_SUPPLY, "Exceed max supply");

        _mint(_to, _amount);
    }

    function burn(address _from ,uint256 _amount) public onlyOwner {
        _burn(_from, _amount);
    }

    function setExcludedFromFee(address _addr, bool _bExcluded) public onlyOwner {
        require(_isExcludedFromFee[_addr] != _bExcluded, "Already set");

        _isExcludedFromFee[_addr] = _bExcluded;
    }

    function isExcludedFromFee(address _addr) public view returns (bool) {
        return _isExcludedFromFee[_addr];
    }
}
