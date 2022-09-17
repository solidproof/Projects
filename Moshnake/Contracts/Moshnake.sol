// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";


import "./DividendTokenDividendTracker.sol";

interface IPancakeRouter01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IPancakePair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface IPancakeFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;

    function INIT_CODE_PAIR_HASH() external view returns (bytes32);
}

interface IPancakeCaller {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) external;
}
contract Moshnake is Initializable,  ERC20Upgradeable, ERC20PermitUpgradeable, ERC20VotesUpgradeable, OwnableUpgradeable {
    IPancakeCaller public pancakeCaller;
    
    uint8 private _decimals;
    address public baseTokenForPair;
    address public pancakeswapV2Router;
    address public pancakeswapV2Pair;

    bool private swapping;

    address public dividendTracker;

    address public rewardToken;

    uint256 public swapTokensAtAmount;

    uint16 public sellBurnFee;
    uint16 public buyBurnFee;

    uint16 public sellLiquidityFee;
    uint16 public buyLiquidityFee;

    uint16 public sellOperationFee;
    uint16 public buyOperationFee;

    address public _operationWalletAddress;
    uint256 public gasForProcessing;
    uint256 public maxWallet;
    uint256 public maxTransactionAmount;
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public isExcludedFromMaxTransactionAmount;
    uint256 private _liquidityFeeTokens;
    uint256 public _burnFeeTokens;

    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateDividendTracker(
        address indexed newAddress,
        address indexed oldAddress
    );

    event UpdatePancakeswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event UpdateSwapTokensAtAmount(uint256 swapTokensAtAmount);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event OperationWalletUpdated(
        address indexed newOperationWallet,
        address indexed oldOperationWallet
    );
    event ExcludedFromMaxTransactionAmount(address account, bool isExcluded);


    event GasForProcessingUpdated(
        uint256 indexed newValue,
        uint256 indexed oldValue
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event DistributeDividends(uint256 tokensSwapped);

    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    event UpdateLiquidityFee(
        uint16 sellLiquidityFee,
        uint16 buyLiquidityFee
    );
    event UpdateOperationFee(
        uint16 sellOperationFee,
        uint16 buyOperationFee
    );
    event UpdateBurnFee(
        uint16 sellBurnFee,
        uint16 buyBurnFee
    );  
    event UpdateMaxWallet(uint256 maxWallet);
    event UpdateMaxTransactionAmount(uint256 maxTransactionAmount);

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 _maxWallet,
        uint256 _maxTransactionAmount,
        address[5] memory addrs, // reward, router, operation wallet, lp wallet, dividendTracker, base Token
        address _pancakeswapV2Caller,
        uint16[6] memory feeSettings, // rewards, liquidity, operation
        uint256 minimumTokenBalanceForDividends_
    ) initializer public {
        __ERC20_init(name_, symbol_);
        __Ownable_init();
        __ERC20Permit_init(name_);
        __ERC20Votes_init();
        _decimals = decimals_;
        rewardToken = addrs[0];
        _operationWalletAddress = addrs[2];
        pancakeCaller=IPancakeCaller(_pancakeswapV2Caller);
        baseTokenForPair=addrs[4];
        sellLiquidityFee = feeSettings[0];
        buyLiquidityFee = feeSettings[1];
        sellOperationFee = feeSettings[2];
        buyOperationFee = feeSettings[3];
        sellBurnFee = feeSettings[4];
        buyBurnFee = feeSettings[5];
        require(sellLiquidityFee+sellOperationFee+sellBurnFee <= 300, "Total Sell Fee <= 30%");
        require(buyLiquidityFee+buyOperationFee+buyBurnFee <= 300, "Total Sell Fee <= 30%");
        swapTokensAtAmount = totalSupply_/(10000);

        gasForProcessing = 300000;

        dividendTracker = payable(Clones.clone(addrs[3]));
        DividendTokenDividendTracker(dividendTracker).initialize(
            rewardToken,
            minimumTokenBalanceForDividends_
        );
        require(_maxTransactionAmount>0, "Max transaction Amount >0");
        require(_maxWallet>0, "Max Wallet > 0");
        maxWallet=_maxWallet;
        maxTransactionAmount=_maxTransactionAmount;
        pancakeswapV2Router = addrs[1];
        pancakeswapV2Pair = IPancakeFactory(IPancakeRouter02(pancakeswapV2Router).factory())
            .createPair(address(this), baseTokenForPair);
        _setAutomatedMarketMakerPair(pancakeswapV2Pair, true);

        DividendTokenDividendTracker(dividendTracker).excludeFromDividends(dividendTracker);
        DividendTokenDividendTracker(dividendTracker).excludeFromDividends(address(this));
        DividendTokenDividendTracker(dividendTracker).excludeFromDividends(owner());
        DividendTokenDividendTracker(dividendTracker).excludeFromDividends(address(0xdead));
        DividendTokenDividendTracker(dividendTracker).excludeFromDividends(pancakeswapV2Router);
        excludeFromFees(owner(), true);
        excludeFromFees(_operationWalletAddress, true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true); 
        isExcludedFromMaxTransactionAmount[address(0xdead)]=true;
        isExcludedFromMaxTransactionAmount[address(this)]=true;
        isExcludedFromMaxTransactionAmount[_operationWalletAddress]=true;
        isExcludedFromMaxTransactionAmount[owner()]=true;     
        _mint(owner(), totalSupply_);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._burn(account, amount);
    }
    receive() external payable {}

    function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
        swapTokensAtAmount = amount;
        emit UpdateSwapTokensAtAmount(swapTokensAtAmount);
    }

    function updateDividendTracker(address newAddress) public onlyOwner {
        require(
            newAddress != dividendTracker,
            "The dividend tracker already has that address"
        );
        require(newAddress!=address(0), "No Zero address");
        address newDividendTracker =payable(newAddress);

        require(
            DividendTokenDividendTracker(newDividendTracker).owner() == address(this),
            "The new dividend tracker must be owned by the DIVIDENEDTOKEN token contract"
        );

        DividendTokenDividendTracker(newDividendTracker).excludeFromDividends(newDividendTracker);
        DividendTokenDividendTracker(newDividendTracker).excludeFromDividends(address(this));
        DividendTokenDividendTracker(newDividendTracker).excludeFromDividends(owner());
        DividendTokenDividendTracker(newDividendTracker).excludeFromDividends(pancakeswapV2Router);
        DividendTokenDividendTracker(newDividendTracker).excludeFromDividends(pancakeswapV2Pair);

        emit UpdateDividendTracker(newAddress, dividendTracker);

        dividendTracker = newDividendTracker;
    }

    function updatePancakeswapV2Pair(address _baseTokenForPair) external onlyOwner
    {
        require(_baseTokenForPair!=address(0), "No Zero address");
        baseTokenForPair=_baseTokenForPair;
        pancakeswapV2Pair = IPancakeFactory(IPancakeRouter02(pancakeswapV2Router).factory()).createPair(
            address(this),
            baseTokenForPair
        );
        _setAutomatedMarketMakerPair(pancakeswapV2Pair, true);
    }
    function updatePancakeswapV2Router(address newAddress) public onlyOwner {
        require(newAddress!=address(0), "No Zero address");
        require(
            newAddress != pancakeswapV2Router,
            "The router already has that address"
        );
        emit UpdatePancakeswapV2Router(newAddress, pancakeswapV2Router);
        pancakeswapV2Pair = IPancakeFactory(IPancakeRouter02(newAddress).factory())
            .createPair(address(this), baseTokenForPair);
        pancakeswapV2Router = newAddress;
        if (!DividendTokenDividendTracker(dividendTracker).isExcludedFromDividends(pancakeswapV2Router))
            DividendTokenDividendTracker(dividendTracker).excludeFromDividends(pancakeswapV2Router);
        _setAutomatedMarketMakerPair(pancakeswapV2Pair, true);
    }

    function updateMaxWallet(uint256 _maxWallet) external onlyOwner {
        require(_maxWallet>0, "Max Wallet>0");
        maxWallet = _maxWallet;
        emit UpdateMaxWallet(maxWallet);
    }

    function updateMaxTransactionAmount(uint256 _maxTransactionAmount)
        external
        onlyOwner
    {
        require(_maxTransactionAmount>0, "Max Transaction Amount>0");
        maxTransactionAmount = _maxTransactionAmount;
        emit UpdateMaxTransactionAmount(maxTransactionAmount);
    }   

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function setOperationWallet(address payable wallet) external onlyOwner {
        excludeFromFees(_operationWalletAddress, false);      
        isExcludedFromMaxTransactionAmount[_operationWalletAddress]=false;
        address tmp=_operationWalletAddress;
        _operationWalletAddress = wallet;
        excludeFromFees(_operationWalletAddress, true);      
        isExcludedFromMaxTransactionAmount[_operationWalletAddress]=true;
        emit OperationWalletUpdated(_operationWalletAddress, tmp);
    }

    function updateLiquidityFee(
        uint16 _sellLiquidityFee,
        uint16 _buyLiquidityFee
    ) external onlyOwner {
        require(
            _sellLiquidityFee+sellOperationFee+sellBurnFee <= 300,
            "sell fee <= 30%"
        );
        require(
            _buyLiquidityFee+buyOperationFee+buyBurnFee <= 300,
            "buy fee <= 30%"
        );
       
        sellLiquidityFee = _sellLiquidityFee;
        buyLiquidityFee = _buyLiquidityFee;
        emit UpdateLiquidityFee(
            sellLiquidityFee,
            buyLiquidityFee
        );
    }

    function updateOperationFee(
        uint16 _sellOperationFee,
        uint16 _buyOperationFee
    ) external onlyOwner {
        require(
            _sellOperationFee+sellLiquidityFee+sellBurnFee <= 300,
            "sell fee <= 30%"
        );
        require(
            _buyOperationFee+buyLiquidityFee+buyBurnFee <= 300,
            "buy fee <= 30%"
        );       
        sellOperationFee = _sellOperationFee;
        buyOperationFee = _buyOperationFee;
        emit UpdateOperationFee(
            sellOperationFee,
            buyOperationFee
        );
    }

    function updateBurnFee(
        uint16 _sellBurnFee,
        uint16 _buyBurnFee
    ) external onlyOwner {
        require(
            _sellBurnFee+(sellLiquidityFee)+(sellOperationFee) <= 300,
            "sell fee <= 30%"
        );
        require(
            _buyBurnFee+(buyLiquidityFee)+(buyOperationFee) <= 300,
            "buy fee <= 30%"
        );
        
        sellBurnFee = _sellBurnFee;
        buyBurnFee = _buyBurnFee;
        emit UpdateBurnFee(sellBurnFee, buyBurnFee);
    }


    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        require(
            pair != pancakeswapV2Pair,
            "The main pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            automatedMarketMakerPairs[pair] != value,
            "Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[pair] = value;
        isExcludedFromMaxTransactionAmount[pair] = value;
        if (value && !DividendTokenDividendTracker(dividendTracker).isExcludedFromDividends(pair)) {
            DividendTokenDividendTracker(dividendTracker).excludeFromDividends(pair);
        }

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function excludeFromMaxTransactionAmount(address account, bool isEx)
        external
        onlyOwner
    {
        isExcludedFromMaxTransactionAmount[account] = isEx;
        emit ExcludedFromMaxTransactionAmount(account, isEx);
    }

    function burnFromFee() external onlyOwner {
        _burn(address(this), _burnFeeTokens);
        _burnFeeTokens=0;
    }
    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(
            newValue >= 200000 && newValue <= 500000,
            "gasForProcessing must be between 200,000 and 500,000"
        );
        require(
            newValue != gasForProcessing,
            "Cannot update gasForProcessing to same value"
        );
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        DividendTokenDividendTracker(dividendTracker).updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns (uint256) {
        return DividendTokenDividendTracker(dividendTracker).claimWait();
    }

    function updateMinimumTokenBalanceForDividends(uint256 amount)
        external
        onlyOwner
    {
        DividendTokenDividendTracker(dividendTracker).updateMinimumTokenBalanceForDividends(amount);
    }

    function getMinimumTokenBalanceForDividends()
        external
        view
        returns (uint256)
    {
        return DividendTokenDividendTracker(dividendTracker).minimumTokenBalanceForDividends();
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return DividendTokenDividendTracker(dividendTracker).totalDividendsDistributed();
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(address account)
        public
        view
        returns (uint256)
    {
        return DividendTokenDividendTracker(dividendTracker).withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(address account)
        public
        view
        returns (uint256)
    {
        return DividendTokenDividendTracker(dividendTracker).balanceOf(account);
    }

    function excludeFromDividends(address account) external onlyOwner {
        DividendTokenDividendTracker(dividendTracker).excludeFromDividends(account);
    }

    function isExcludedFromDividends(address account)
        public
        view
        returns (bool)
    {
        return DividendTokenDividendTracker(dividendTracker).isExcludedFromDividends(account);
    }

    function getAccountDividendsInfo(address account)
        external
        view
        returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return DividendTokenDividendTracker(dividendTracker).getAccount(account);
    }

    function getAccountDividendsInfoAtIndex(uint256 index)
        external
        view
        returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return DividendTokenDividendTracker(dividendTracker).getAccountAtIndex(index);
    }

    function processDividendTracker(uint256 gas) external {
        (
            uint256 iterations,
            uint256 claims,
            uint256 lastProcessedIndex
        ) = DividendTokenDividendTracker(dividendTracker).process(gas);
        emit ProcessedDividendTracker(
            iterations,
            claims,
            lastProcessedIndex,
            false,
            gas,
            msg.sender
        );
    }

    function claim() external {
        DividendTokenDividendTracker(dividendTracker).processAccount(payable(msg.sender), false);
    }

    function getLastProcessedIndex() external view returns (uint256) {
        return DividendTokenDividendTracker(dividendTracker).getLastProcessedIndex();
    }

    function getNumberOfDividendTokenHolders() external view returns (uint256) {
        return DividendTokenDividendTracker(dividendTracker).getNumberOfTokenHolders();
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }


        bool canSwap = _liquidityFeeTokens >= swapTokensAtAmount;

        if (
            canSwap &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            from != owner() &&
            to != owner()
        ) {
            swapping = true;  
            swapAndLiquify(_liquidityFeeTokens);       
            _liquidityFeeTokens=0;
            swapping = false;
        }

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }
        uint256 _liquidityFee;
        uint256 _operationFee;
        uint256 _burnFee;
        if (takeFee) {
            if (automatedMarketMakerPairs[from]) {
                _burnFee = amount*(buyBurnFee)/(1000);
                _liquidityFee = amount*(buyLiquidityFee)/(1000);
                _operationFee = amount*(buyOperationFee)/(1000);
            }
            else if (automatedMarketMakerPairs[to]) {
                _burnFee = amount*(sellBurnFee)/(1000);
                _liquidityFee = amount*(sellLiquidityFee)/(1000);
                _operationFee = amount*(sellOperationFee)/(1000);
            }
            _liquidityFeeTokens = _liquidityFeeTokens+_liquidityFee;
            _burnFeeTokens = _burnFeeTokens+_burnFee;
            uint256 _feeTotal=_burnFee+_liquidityFee;
            _transfer(address(this), _operationWalletAddress, _operationFee);    
            amount=amount-(_feeTotal+_operationFee);
            if(_feeTotal>0)
                super._transfer(from, address(this), _feeTotal);
        }
        
        super._transfer(from, to, amount);

        try
            DividendTokenDividendTracker(dividendTracker).setBalance(payable(from), balanceOf(from))
        {} catch {}
        try DividendTokenDividendTracker(dividendTracker).setBalance(payable(to), balanceOf(to)) {} catch {}

        if (!swapping) {
            if (!isExcludedFromMaxTransactionAmount[from]) {
                require(
                    amount < maxTransactionAmount,
                    "ERC20: exceeds transfer limit"
                );
            }
            if (!isExcludedFromMaxTransactionAmount[to]) {
                require(
                    balanceOf(to) < maxWallet,
                    "ERC20: exceeds max wallet limit"
                );
            }
            uint256 gas = gasForProcessing;

            try DividendTokenDividendTracker(dividendTracker).process(gas) returns (
                uint256 iterations,
                uint256 claims,
                uint256 lastProcessedIndex
            ) {
                emit ProcessedDividendTracker(
                    iterations,
                    claims,
                    lastProcessedIndex,
                    true,
                    gas,
                    msg.sender
                );
            } catch {}
        }
    }


    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens/(2);
        uint256 otherHalf = tokens-(half);

        uint256 initialBalance = baseTokenForPair==IPancakeRouter02(pancakeswapV2Router).WETH() ? address(this).balance 
            : IERC20Upgradeable(baseTokenForPair).balanceOf(address(this));

        swapTokensForBaseToken(half); 
        uint256 newBalance = baseTokenForPair==IPancakeRouter02(pancakeswapV2Router).WETH() ? address(this).balance-initialBalance
            : IERC20Upgradeable(baseTokenForPair).balanceOf(address(this))-initialBalance;

        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForBaseToken(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = baseTokenForPair;

        if (path[1] == IPancakeRouter02(pancakeswapV2Router).WETH()){
            _approve(address(this), pancakeswapV2Router, tokenAmount);
            IPancakeRouter02(pancakeswapV2Router).swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0, // accept any amount of BaseToken
                path,
                address(this),
                block.timestamp
            );
        }else{
            _approve(address(this), address(pancakeCaller), tokenAmount);
            pancakeCaller.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    pancakeswapV2Router,
                    tokenAmount,
                    0, // accept any amount of BaseToken
                    path,
                    block.timestamp
                );
        }
    }

    function addLiquidity(uint256 tokenAmount, uint256 baseTokenAmount) private {
        _approve(address(this), pancakeswapV2Router, tokenAmount);
        if (baseTokenForPair == IPancakeRouter02(pancakeswapV2Router).WETH()) 
            IPancakeRouter02(pancakeswapV2Router).addLiquidityETH{value: baseTokenAmount}(
                address(this),
                tokenAmount,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                address(0xdead),
                block.timestamp
            );
        else{
            IERC20Upgradeable(baseTokenForPair).approve(pancakeswapV2Router, baseTokenAmount);
            IPancakeRouter02(pancakeswapV2Router).addLiquidity(
                address(this),
                baseTokenForPair,
                tokenAmount,
                baseTokenAmount,
                0,
                0,
                address(0xdead),
                block.timestamp
            );    
        }
                
    }

    function distributeDividends(uint256 amount) external {
        bool success = IERC20Upgradeable(rewardToken).transferFrom(
            msg.sender,
            dividendTracker,
            amount
        );

        if (success) {
            DividendTokenDividendTracker(dividendTracker).distributeCAKEDividends(amount);
            emit DistributeDividends(amount);
        }
    }
}
