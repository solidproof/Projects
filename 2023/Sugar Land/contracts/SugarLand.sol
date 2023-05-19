// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ISRGRaffle {
    function generateTickets(address _account, uint256 _SGRAmount) external;
}

interface ISGR {
    function process_Tokens_Now(uint256 percent_Of_Tokens_To_Process) external;
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

contract SugarLand is ISGR, ERC20, Ownable {
    uint256 public constant TAX_FEE = 10_00; // 10%
    uint256 public constant PERCENT_DIVIDER = 100_00;

    uint256 public swapAmount = 10 ether;
    address public RaffleContract;
    address payable public teamWallet;

    address public router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    // address private router = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1; //Testnet 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3

    IUniswapV2Router02 private immutable pcsV2Router;
    address public immutable pcsV2Pair;
    bool public inSwapAndLiquify;
    bool public isTradeOpen = false;
    
    // Prevent processing while already processing!
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    mapping(address => bool) public isExcludedFee;

    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);

    constructor() ERC20("SugarLand", "SGRAI") {
        _mint(msg.sender, 100_000_000 * 10 ** decimals());
        teamWallet = payable(msg.sender);
        IUniswapV2Router02 _pcsV2Router = IUniswapV2Router02(router);

        pcsV2Pair = IUniswapV2Factory(_pcsV2Router.factory()).createPair(address(this), _pcsV2Router.WETH());

        // set the rest of the contract variables
        pcsV2Router = _pcsV2Router;
        isExcludedFee[msg.sender] = true;
        isExcludedFee[address(this)] = true;
    }

    // This function is required so that the contract can receive BNB from pancakeswap
    receive() external payable {}

    function setRaffleContract(address _newRaffleContract) external onlyOwner {
        RaffleContract = _newRaffleContract;
    }

    function enableTrade() external onlyOwner{
        require(isTradeOpen == false, "Trade is already open!");
        isTradeOpen = true;
    }

    function excludeFee(address user, bool value) external onlyOwner {
        require(isExcludedFee[user] != value, "Already Set");

        isExcludedFee[user] = value;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        uint256 taxAmount = 0;
        bool isExcluded = isExcludedFee[sender] || isExcludedFee[recipient];
        require(isTradeOpen || isExcluded, "Trading is not open!");

        if (!isExcluded) {
            if (_isSell(sender, recipient)) {
                taxAmount = amount * TAX_FEE / PERCENT_DIVIDER;
                // ISRGRaffle(RaffleContract).generateTickets(sender, amount);

                super._transfer(sender, RaffleContract, taxAmount);
            } else if (_isBuy(sender, recipient)) {
                taxAmount = amount * TAX_FEE / PERCENT_DIVIDER;
                ISRGRaffle(RaffleContract).generateTickets(recipient, amount);

                super._transfer(sender, RaffleContract, taxAmount);
            }
        }
        
        super._transfer(sender, recipient, amount - taxAmount);
    }

    function _isSell(address sender, address recipient) private view returns (bool) {
        return sender != address(0) && recipient == pcsV2Pair;
    }

    function _isBuy(address sender, address recipient) private view returns (bool) {
        return recipient != address(0) && sender == pcsV2Pair;
    }

    // Swapping tokens for BNB using PancakeSwap
    function swapTokensForBNB(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pcsV2Router.WETH();
        _approve(address(this), address(pcsV2Router), tokenAmount);

        pcsV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
        
    }
    
    // Send BNB to external wallet
    function sendToWallet(address payable wallet, uint256 amount) private {
        wallet.transfer(amount);
    }

    // Processing tokens from contract
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        swapTokensForBNB(contractTokenBalance);
        uint256 contractBNB = address(this).balance;
        sendToWallet(teamWallet, contractBNB);
    }

    // Manual Token Process Trigger - Enter the percent of the tokens that you'd like to send to process
    function process_Tokens_Now(uint256 percent_Of_Tokens_To_Process) external override {
        require(msg.sender == owner() || msg.sender == RaffleContract, "Invalid auth!");
        require(!inSwapAndLiquify, "Currently processing, try later.");
        if (percent_Of_Tokens_To_Process > 100) {
            percent_Of_Tokens_To_Process = 100;
        }
        uint256 tokensOnContract = balanceOf(address(this));
        require(tokensOnContract >= swapAmount, "Not enough token amount for swap");
        uint256 sendTokens = (tokensOnContract * percent_Of_Tokens_To_Process) / 100;
        swapAndLiquify(sendTokens);
    }

    function changeTeamWallet(address payable _newTeamWallet) external {
        require(msg.sender == teamWallet, "Only team could change this address");
        teamWallet = _newTeamWallet;
    }

    function changeSwapAmount(uint256 _amount) external onlyOwner {
        swapAmount = _amount;
    }
}