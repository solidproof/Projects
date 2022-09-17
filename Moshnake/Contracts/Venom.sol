// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

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

interface ITreasury {   
    function distributeDividends(uint256 amount) external;
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

contract Venom is Initializable,  ERC20Upgradeable, OwnableUpgradeable {
    IPancakeCaller public pancakeCaller;
    mapping(address => bool) public isBlacklisted;
    address public treasuryAddress; // treasury CA
    bool public isTreasuryContract;
    uint16 constant maxFeeLimit = 300;
    uint8 private _decimals;
    address public baseTokenForPair;
    //anti sniper storages
    uint256 private _gasPriceLimit;
    bool public tradingActive;
    bool public limitsInTrade;
    mapping(address => bool) public isExcludedFromFee;

    // these values are pretty much arbitrary since they get overwritten for every txn, but the placeholders make it easier to work with current contract.
    
    uint16 public buyRewardFee;
    uint16 public buyLiquidityFee;
    uint16 public buyBurnFee;

    uint16 public sellRewardFee;
    uint16 public sellLiquidityFee;
    uint16 public sellBurnFee;


    mapping(address => bool) public isExcludedMaxTransactionAmount;

    // Anti-bot and anti-whale mappings and variables
    mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch
    

    uint256 private _liquidityTokensToSwap;
    uint256 public _burnFeeTokens;
    uint256 private _rewardFeeTokens;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    uint256 public minimumFeeTokensToTake;
    uint256 public maxTransactionAmount;
    uint256 public maxWallet;

    IPancakeRouter02 public pancakeRouter;
    address public pancakePair;

    bool private inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;
    event LogAddToBlacklist(address[] indexed isBlacklisted);
    event LogRemoveFromBlacklist(address[] indexed notBlacklisted);
    event TradingActivated();
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event UpdateMaxTransactionAmount(uint256 maxTransactionAmount);
    event UpdateMaxWallet(uint256 maxWallet);
    event UpdateMinimumTokensBeforeFeeTaken(uint256 minimumFeeTokensToTake);
    event SetAutomatedMarketMakerPair(address pair, bool value);
    event ExcludedMaxTransactionAmount(
        address indexed account,
        bool isExcluded
    );
    event ExcludedFromFee(address account, bool isExcludedFromFee);
    event UpdateBuyFee(
        uint256 buyRewardFee,
        uint256 buyLiquidityFee,
        uint256 buyBurnFee
    );
    event UpdateSellFee(
        uint256 sellRewardFee,
        uint256 sellLiquidityFee,
        uint256 sellBurnFee
    );
  
    event UpdateTreasuryAddress(address treasuryAddress, bool isTreasuryContract);
    event SwapAndLiquify(
        uint256 tokensAutoLiq,
        uint256 baseTokenAutoLiq
    );
    event RewardTaken(uint256 rewardFeeTokens);
    event BurnFeeTaken(uint256 burnFeeTokens);
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 __decimals,
        address _pancakeV2RouterAddress,
        address _treasuryAddress,
        address _tokenForPair,
        address _pancakeCaller,
        uint256[4] memory _uint_params,
        uint16[6] memory _uint16_params        
    ) initializer public {
        __ERC20_init(name_, symbol_);
        __Ownable_init();
        _decimals=__decimals;
        pancakeCaller=IPancakeCaller(_pancakeCaller);
        _mint(msg.sender, _uint_params[0] * (10**__decimals));
        require(_treasuryAddress!=address(0), "No allowed Zero address for treasury");
        require(_tokenForPair!=address(0), "No allowed Zero address for pair");
        treasuryAddress = _treasuryAddress;   
        _gasPriceLimit = _uint_params[1] * 1 gwei;    
        baseTokenForPair=_tokenForPair;
        buyLiquidityFee = _uint16_params[0];
        buyRewardFee = _uint16_params[1];
        buyBurnFee = _uint16_params[2];
        require(maxFeeLimit>=buyLiquidityFee+buyRewardFee+buyBurnFee,"buy fee <= 30%");
        
        sellLiquidityFee = _uint16_params[3];
        sellRewardFee = _uint16_params[4];
        sellBurnFee = _uint16_params[5];        
        require(maxFeeLimit>=sellLiquidityFee+sellRewardFee+sellBurnFee,"sell fee <= 30%");

        minimumFeeTokensToTake = _uint_params[0] * (10**__decimals)/10000;
        maxTransactionAmount = _uint_params[2]*(10**__decimals);
        maxWallet = _uint_params[3]*(10**__decimals);
        require(maxWallet>0,"max wallet > 0");
        require(maxTransactionAmount>0,"maxTransactionAmount > 0");
        require(minimumFeeTokensToTake>0,"minimumFeeTokensToTake > 0");
       
        pancakeRouter = IPancakeRouter02(_pancakeV2RouterAddress);

        pancakePair = IPancakeFactory(pancakeRouter.factory()).createPair(
            address(this),
            baseTokenForPair
        );

        isExcludedFromFee[_msgSender()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[_treasuryAddress] = true;
        isExcludedFromFee[address(0xDead)] = true;
        excludeFromMaxTransaction(_msgSender(), true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(_treasuryAddress, true);
        excludeFromMaxTransaction(address(0xDead), true);
        _setAutomatedMarketMakerPair(pancakePair, true);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    function enableTrading() external onlyOwner {
        require(!tradingActive, "already enabled");
        tradingActive = true;
        swapAndLiquifyEnabled = true;
        limitsInTrade=true;
        emit TradingActivated();
    }

    function updatePancakePair(address _baseTokenForPair) external onlyOwner
    {
        require(_baseTokenForPair!=address(0), "No allowed Zero address for pair");
        baseTokenForPair=_baseTokenForPair;
        pancakePair = IPancakeFactory(pancakeRouter.factory()).createPair(
            address(this),
            baseTokenForPair
        );
        _setAutomatedMarketMakerPair(pancakePair, true);
    }

    function setSwapAndLiquifyEnabled(bool _enabled)
        public
        onlyOwner
    {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function updateMaxTransactionAmount(uint256 _maxTransactionAmount)
        external
        onlyOwner
    {
        maxTransactionAmount = _maxTransactionAmount*(10**_decimals);
        require(maxTransactionAmount>0,"maxTransactionAmount > 0");
        emit UpdateMaxTransactionAmount(_maxTransactionAmount);
    }

    function updateMaxWallet(uint256 _maxWallet) external onlyOwner {
        maxWallet = _maxWallet*(10**_decimals);
        require(maxWallet>0,"maxWallet > 0");
        emit UpdateMaxWallet(_maxWallet);
    }

    function updateMinimumTokensBeforeFeeTaken(uint256 _minimumFeeTokensToTake)
        external
        onlyOwner
    {
        minimumFeeTokensToTake = _minimumFeeTokensToTake*(10**_decimals);
        require(minimumFeeTokensToTake>0,"minimumFeeTokensToTake > 0");
        emit UpdateMinimumTokensBeforeFeeTaken(_minimumFeeTokensToTake);
    }


    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        require(
            pair != pancakePair,
            "The pair cannot be removed"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        excludeFromMaxTransaction(pair, value);

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateGasPriceLimit(uint256 gas) external onlyOwner {
        require(gas>5, "gas price > 5");
        _gasPriceLimit = gas * 1 gwei;
    }
   
   
  
    function excludeFromMaxTransaction(address updAds, bool isEx)
        public
        onlyOwner
    {
        isExcludedMaxTransactionAmount[updAds] = isEx;
        emit ExcludedMaxTransactionAmount(updAds, isEx);
    }

    function excludeFromFee(address account) external onlyOwner {
        isExcludedFromFee[account] = true;
        emit ExcludedFromFee(account, true);
    }

    function includeInFee(address account) external onlyOwner {
        isExcludedFromFee[account] = false;
        emit ExcludedFromFee(account, false);
    }

    function updateBuyFee(
        uint16 _buyRewardFee,
        uint16 _buyLiquidityFee,
        uint16 _buyBurnFee
    ) external onlyOwner {
        buyRewardFee = _buyRewardFee;
        buyLiquidityFee = _buyLiquidityFee;
        buyBurnFee = _buyBurnFee;
        require(
            _buyRewardFee + _buyLiquidityFee + _buyBurnFee <= maxFeeLimit,
            "Total Buy Fee <= 30%"
        );
        emit UpdateBuyFee(_buyRewardFee, _buyLiquidityFee, _buyBurnFee);
    }

    function updateSellFee(
        uint16 _sellRewardFee,
        uint16 _sellLiquidityFee,
        uint16 _sellBurnFee
    ) external onlyOwner {
        sellRewardFee = _sellRewardFee;
        sellLiquidityFee = _sellLiquidityFee;
        sellBurnFee = _sellBurnFee;
        require(
            _sellRewardFee + _sellLiquidityFee + _sellBurnFee <= maxFeeLimit,
            "Total Sell Fee <= 30%"
        );
        emit UpdateSellFee(sellRewardFee, sellLiquidityFee, sellBurnFee);
    }
    function removeLimits()
        external
        onlyOwner
    {
        limitsInTrade = false;
    }

    function updateTreasuryAddress(address _treasuryAddress, bool _isTreasuryContract) external onlyOwner {
        require(_treasuryAddress!=address(0), "No allowed Zero address for treasury");
        isExcludedFromFee[treasuryAddress] = false;
        excludeFromMaxTransaction(treasuryAddress, false);
        treasuryAddress = _treasuryAddress;
        isExcludedFromFee[_treasuryAddress] = true;
        excludeFromMaxTransaction(_treasuryAddress, true);
        isTreasuryContract=_isTreasuryContract;
        emit UpdateTreasuryAddress(_treasuryAddress, _isTreasuryContract);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!isBlacklisted[from] && !isBlacklisted[to], "blacklisted!");
        if (!tradingActive) {
            require(
                isExcludedFromFee[from] || isExcludedFromFee[to],
                "Trading is not active yet."
            );
        }

        if (to != address(0) && to != address(0xDead) && !inSwapAndLiquify && limitsInTrade) {
            // only use to prevent sniper buys in the first blocks.
            if (automatedMarketMakerPairs[from]) {
                require(
                    tx.gasprice <= _gasPriceLimit,
                    "Gas price exceeds limit."
                );
            }
            if (
                    to != address(pancakeRouter) && to != address(pancakePair)
                ){
                require(
                    _holderLastTransferTimestamp[tx.origin] < block.number,
                    "_transfer:: Transfer Delay enabled.  Only one transfer per block allowed."
                );
                _holderLastTransferTimestamp[tx.origin] = block.number;
            }    
            //when buy
            if (
                automatedMarketMakerPairs[from] &&
                !isExcludedMaxTransactionAmount[to]
            ) {
                require(
                    amount <= maxTransactionAmount,
                    "Buy transfer amount exceeds the maxTransactionAmount."
                );
                require(
                    amount + balanceOf(to) <= maxWallet,
                    "Cannot exceed max wallet"
                );
            }
            //when sell
            else if (
                automatedMarketMakerPairs[to] &&
                !isExcludedMaxTransactionAmount[from]
            ) {
                require(
                    amount <= maxTransactionAmount,
                    "Sell transfer amount exceeds the maxTransactionAmount."
                );
            }
        }
        
        bool overMinimumTokenBalance = balanceOf(address(this)) >=
            minimumFeeTokensToTake;

        // Take Fee
        if (
            !inSwapAndLiquify &&
            swapAndLiquifyEnabled &&
            balanceOf(pancakePair) > 0 &&
            overMinimumTokenBalance &&
            automatedMarketMakerPairs[to]
        ) {
            takeFee();
        }

        uint256 _rewardFee;
        uint256 _liquidityFee;
        uint256 _burnFee;
        // If any account belongs to isExcludedFromFee account then remove the fee
        if (!inSwapAndLiquify && !isExcludedFromFee[from] && !isExcludedFromFee[to]) {           
            // Buy
            if (automatedMarketMakerPairs[from]) {
                _rewardFee = amount*buyRewardFee/1000;
                _liquidityFee = amount*buyLiquidityFee/1000;
                _burnFee = amount*buyBurnFee/1000;
            }
            // Sell
            else if (automatedMarketMakerPairs[to]) {
                _rewardFee = amount*sellRewardFee/1000;
                _liquidityFee = amount*sellLiquidityFee/1000;
                _burnFee = amount*sellBurnFee/1000;
            }
        }
        uint256 _feeTotal = _rewardFee+_liquidityFee+_burnFee;
        uint256 _transferAmount = amount-_feeTotal;
        super._transfer(from, to, _transferAmount);
        
        if (_feeTotal > 0) {
            super._transfer(
                from,
                address(this),
                _feeTotal
            );
            _liquidityTokensToSwap=_liquidityTokensToSwap+_liquidityFee;
            _burnFeeTokens=_burnFeeTokens+_burnFee;
            _rewardFeeTokens=_rewardFeeTokens+_rewardFee;
        }

    }


    function addToBlacklist(address[] memory _isBlacklisted)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _isBlacklisted.length; i++) {
            isBlacklisted[_isBlacklisted[i]] = true;
        }
        emit LogAddToBlacklist(_isBlacklisted);
    }

    function removeFromBlacklist(address[] memory _notBlacklisted)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _notBlacklisted.length; i++) {
            isBlacklisted[_notBlacklisted[i]] = false;
        }
        emit LogRemoveFromBlacklist(_notBlacklisted);
    }
    function takeFee() private lockTheSwap {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensTaken=_liquidityTokensToSwap+_rewardFeeTokens+_burnFeeTokens;
        if (totalTokensTaken == 0 || contractBalance <totalTokensTaken) {
            return;
        }

        // Halve the amount of liquidity tokens
        uint256 tokensForLiquidity = _liquidityTokensToSwap / 2;
        if (tokensForLiquidity > 0) {            
            uint256 initialBaseTokenBalance = baseTokenForPair==pancakeRouter.WETH() ? address(this).balance 
                : IERC20Upgradeable(baseTokenForPair).balanceOf(address(this));
            swapTokensForBaseToken(tokensForLiquidity);
            uint256 baseTokenBalance = baseTokenForPair==pancakeRouter.WETH() ? address(this).balance-initialBaseTokenBalance
                : IERC20Upgradeable(baseTokenForPair).balanceOf(address(this))-initialBaseTokenBalance;        
            if (baseTokenBalance > 0) {
                addLiquidity(tokensForLiquidity, baseTokenBalance);
                emit SwapAndLiquify(
                    tokensForLiquidity,
                    baseTokenBalance
                );
            }
        }

        if(isTreasuryContract){
            ITreasury treasury=ITreasury(treasuryAddress);
            _approve(address(this), address(treasury), _rewardFeeTokens);
            treasury.distributeDividends(_rewardFeeTokens);
        }else{
            super._transfer(
                address(this),
                treasuryAddress,
                _rewardFeeTokens
            );
        }
        
        emit RewardTaken(_rewardFeeTokens);    

        super._transfer(
                address(this),
                address(0xDead),
                _burnFeeTokens
            );
        emit BurnFeeTaken(_burnFeeTokens); 

        _liquidityTokensToSwap = 0;
        _burnFeeTokens=0;
        _rewardFeeTokens=0;
    }

    function swapTokensForBaseToken(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = baseTokenForPair;        
        if (path[1] == pancakeRouter.WETH()){
            _approve(address(this), address(pancakeRouter), tokenAmount);
            pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0, // accept any amount of BaseToken
                path,
                address(this),
                block.timestamp
            );
        }else{
            _approve(address(this), address(pancakeCaller), tokenAmount);
            pancakeCaller.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    address(pancakeCaller),
                    tokenAmount,
                    0, // accept any amount of BaseToken
                    path,
                    block.timestamp
                );
        }
    }

    function addLiquidity(uint256 tokenAmount, uint256 baseTokenAmount) private {
        _approve(address(this), address(pancakeRouter), tokenAmount);
        IERC20Upgradeable(baseTokenForPair).approve(address(pancakeRouter), baseTokenAmount);
        if (baseTokenForPair == pancakeRouter.WETH()) 
            pancakeRouter.addLiquidityETH{value: baseTokenAmount}(
                address(this),
                tokenAmount,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                address(0xdead),
                block.timestamp
            );
        else
            pancakeRouter.addLiquidity(
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

    receive() external payable {}
}
