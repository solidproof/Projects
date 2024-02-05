// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract HeroInfinityToken is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool private swapping;

    uint256 public launchTime;

    address public marketingWallet;
    address public devWallet;
    address public liquidityWallet;

    uint256 public maxTransactionAmount;
    uint256 public swapTokensAtAmount;
    uint256 public maxWallet;

    bool public limitsInEffect = true;
    bool public tradingActive = false;
    bool public swapEnabled = false;

    bool private gasLimitActive = true;
    uint256 private gasPriceLimit = 561 * 1 gwei; // do not allow over x gwei for launch

    // Anti-bot and anti-whale mappings and variables
    mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch

    mapping(address => uint256) presaleAmount; // Presale vesting
    uint256 airdropThreshold;

    bool public transferDelayEnabled = true;

    uint256 public buyTotalFees;
    uint256 public buyMarketingFee;
    uint256 public buyLiquidityFee;
    uint256 public buyDevFee;

    uint256 public sellTotalFees;
    uint256 public sellMarketingFee;
    uint256 public sellLiquidityFee;
    uint256 public sellDevFee;

    uint256 public tokensForMarketing;
    uint256 public tokensForLiquidity;
    uint256 public tokensForDev;

    /******************/

    // exlcude from fees and max transaction amount
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public _isExcludedMaxTransactionAmount;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event MarketingWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    event DevWalletUpdated(address indexed newWallet, address indexed oldWallet);

    event LiquidityWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );

    event OwnerForcedSwapBack(uint256 timestamp);

    constructor() ERC20("HeroInfinity Token", "HRI") {}

    function airdropAndLaunch(
        address newOwner,
        address router,
        uint256 liquidityAmount,
        uint256 airdropAmount,
        uint256 dailyThreshold,
        address[] memory airdropUsers,
        uint256[] memory airdropAmounts
    ) external payable onlyOwner {
        require(!tradingActive, "Trading is already enabled");
        require(airdropUsers.length == airdropAmounts.length, "Invalid arguments");

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router);

        excludeFromMaxTransaction(address(_uniswapV2Router), true);
        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
        address(this),
        _uniswapV2Router.WETH()
        );
        excludeFromMaxTransaction(address(uniswapV2Pair), true);
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        uint256 _buyMarketingFee = 6;
        uint256 _buyLiquidityFee = 4;
        uint256 _buyDevFee = 2;

        uint256 _sellMarketingFee = 8;
        uint256 _sellLiquidityFee = 14;
        uint256 _sellDevFee = 3;

        uint256 _totalSupply = 1 * 1e9 * 1e18;

        require(dailyThreshold * 1e18 > (_totalSupply * 5) / 10000); // at least 0.05% release to presalers per day
        airdropThreshold = dailyThreshold;

        maxTransactionAmount = (_totalSupply * 30) / 10000; // 0.3% maxTransactionAmountTxn
        maxWallet = (_totalSupply * 100) / 10000; // 1% maxWallet
        swapTokensAtAmount = (_totalSupply * 5) / 10000; // 0.05% swap wallet

        buyMarketingFee = _buyMarketingFee;
        buyLiquidityFee = _buyLiquidityFee;
        buyDevFee = _buyDevFee;
        buyTotalFees = buyMarketingFee + buyLiquidityFee + buyDevFee;

        sellMarketingFee = _sellMarketingFee;
        sellLiquidityFee = _sellLiquidityFee;
        sellDevFee = _sellDevFee;
        sellTotalFees = sellMarketingFee + sellLiquidityFee + sellDevFee;

        marketingWallet = newOwner;
        devWallet = newOwner;
        liquidityWallet = newOwner;

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(newOwner, true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);

        excludeFromMaxTransaction(owner(), true);
        excludeFromMaxTransaction(newOwner, true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(0xdead), true);

        _mint(address(this), liquidityAmount * 1e18);
        _mint(newOwner, _totalSupply - liquidityAmount * 1e18);

        // Add liquidity
        addLiquidity(liquidityAmount * 1e18, msg.value);

        uint256 totalAirdrops;

        //For airdrop, exclude temporary
        excludeFromFees(address(uniswapV2Pair), true);
        limitsInEffect = false;

        for (uint256 i; i < airdropUsers.length; ++i) {
        uint256 amount = airdropAmounts[i] * 1e18;
        address to = airdropUsers[i];
        require(presaleAmount[to] == 0, "airdrop duplicated");

        totalAirdrops += amount;
        _transfer(uniswapV2Pair, to, amount);
        presaleAmount[to] = amount;
        }

        excludeFromFees(address(uniswapV2Pair), false);
        limitsInEffect = true;

        require(totalAirdrops == airdropAmount * 1e18, "Wrong airdrop amount");

        IUniswapV2Pair pairInstance = IUniswapV2Pair(uniswapV2Pair);
        pairInstance.sync();

        enableTrading();
    }

    function name() public view virtual override returns (string memory) {
        require(tradingActive);
        return super.name();
    }

    function symbol() public view virtual override returns (string memory) {
        require(tradingActive);
        return super.symbol();
    }

    function decimals() public view virtual override returns (uint8) {
        return super.decimals();
    }

    function totalSupply() public view virtual override returns (uint256) {
        return super.totalSupply();
    }

    receive() external payable {}

    // once enabled, can never be turned off
    function enableTrading() private {
        require(!tradingActive, "Trading is already enabled");
        tradingActive = true;
        swapEnabled = true;
        launchTime = block.timestamp;
    }

    // remove limits after token is stable
    function removeLimits() external onlyOwner returns (bool) {
        limitsInEffect = false;
        gasLimitActive = false;
        transferDelayEnabled = false;
        return true;
    }

    // disable Transfer delay - cannot be reenabled
    function disableTransferDelay() external onlyOwner returns (bool) {
        transferDelayEnabled = false;
        return true;
    }

    // change the minimum amount of tokens to sell from fees
    function updateSwapTokensAtAmount(uint256 newAmount)
        external
        onlyOwner
        returns (bool)
    {
        require(
        newAmount >= (totalSupply() * 1) / 100000,
        "Swap amount cannot be lower than 0.001% total supply."
        );
        require(
        newAmount <= (totalSupply() * 5) / 1000,
        "Swap amount cannot be higher than 0.5% total supply."
        );
        swapTokensAtAmount = newAmount;
        return true;
    }

    function updateMaxAmount(uint256 newNum) external onlyOwner {
        require(
        newNum >= ((totalSupply() * 5) / 1000) / 1e18,
        "Cannot set maxTransactionAmount lower than 0.5%"
        );
        maxTransactionAmount = newNum * (10**18);
    }

    function excludeFromMaxTransaction(address updAds, bool isEx)
        public
        onlyOwner
    {
        _isExcludedMaxTransactionAmount[updAds] = isEx;
    }

    // only use to disable contract sales if absolutely necessary (emergency use only)
    function updateSwapEnabled(bool enabled) external onlyOwner {
        swapEnabled = enabled;
    }

    function updateBuyFees(
        uint256 _marketingFee,
        uint256 _liquidityFee,
        uint256 _devFee
    ) external onlyOwner {
        buyMarketingFee = _marketingFee;
        buyLiquidityFee = _liquidityFee;
        buyDevFee = _devFee;
        buyTotalFees = buyMarketingFee + buyLiquidityFee + buyDevFee;

        require(buyTotalFees <= 25, "Cannot set buy fee more than 25%");
    }

    function updateSellFees(
        uint256 _marketingFee,
        uint256 _liquidityFee,
        uint256 _devFee
    ) external onlyOwner {
        sellMarketingFee = _marketingFee;
        sellLiquidityFee = _liquidityFee;
        sellDevFee = _devFee;
        sellTotalFees = sellMarketingFee + sellLiquidityFee + sellDevFee;

        require(sellTotalFees <= 25, "Cannot set sell fee more than 25%");
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        require(
        pair != uniswapV2Pair,
        "The pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateMarketingWallet(address newMarketingWallet)
        external
        onlyOwner
    {
        emit MarketingWalletUpdated(newMarketingWallet, marketingWallet);
        marketingWallet = newMarketingWallet;
    }

    function updateDevWallet(address newDevWallet) external onlyOwner {
        emit DevWalletUpdated(newDevWallet, devWallet);
        devWallet = newDevWallet;
    }

    function updateliquidityWallet(address newWallet) external onlyOwner {
        emit LiquidityWalletUpdated(newWallet, liquidityWallet);
        liquidityWallet = newWallet;
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function checkVesting(address from) private {
        if (presaleAmount[from] == 0) {
        return;
        }
        uint256 daysPassed = (block.timestamp - launchTime) / 1 days;
        uint256 unlockedAmount = daysPassed * airdropThreshold * 1e18;
        if (unlockedAmount > presaleAmount[from]) {
        presaleAmount[from] = 0;
        return;
        }
        require(
        balanceOf(from) >= presaleAmount[from] - unlockedAmount,
        "Vesting period is not ended yet"
        );
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

        if (limitsInEffect) {
        if (
            from != owner() &&
            to != owner() &&
            to != address(0) &&
            to != address(0xdead) &&
            !swapping
        ) {
            if (!tradingActive) {
            require(
                _isExcludedFromFees[from] || _isExcludedFromFees[to],
                "Trading is not active."
            );
            }

            // at launch if the transfer delay is enabled, ensure the block timestamps for purchasers is set -- during launch.
            if (transferDelayEnabled) {
            if (
                to != owner() &&
                to != address(uniswapV2Router) &&
                to != address(uniswapV2Pair)
            ) {
                require(
                _holderLastTransferTimestamp[tx.origin] < block.number,
                "_transfer:: Transfer Delay enabled.  Only one purchase per block allowed."
                );
                _holderLastTransferTimestamp[tx.origin] = block.number;
            }
            }

            //when buy
            if (
            automatedMarketMakerPairs[from] &&
            !_isExcludedMaxTransactionAmount[to]
            ) {
            require(
                amount <= maxTransactionAmount,
                "Buy transfer amount exceeds the maxTransactionAmount."
            );
            require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
            }
            //when sell
            else if (
            automatedMarketMakerPairs[to] &&
            !_isExcludedMaxTransactionAmount[from]
            ) {
            require(
                amount <= maxTransactionAmount,
                "Sell transfer amount exceeds the maxTransactionAmount."
            );
            } else if (!_isExcludedMaxTransactionAmount[to]) {
            require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
            }
        }
        }

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (
        canSwap &&
        swapEnabled &&
        !swapping &&
        !automatedMarketMakerPairs[from] &&
        !_isExcludedFromFees[from] &&
        !_isExcludedFromFees[to]
        ) {
        swapping = true;

        swapBack();

        swapping = false;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
        takeFee = false;
        }

        uint256 fees = 0;
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
        // on sell
        if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
            fees = amount.mul(sellTotalFees).div(100);
            tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
            tokensForDev += (fees * sellDevFee) / sellTotalFees;
            tokensForMarketing += (fees * sellMarketingFee) / sellTotalFees;
        }
        // on buy
        else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
            fees = amount.mul(buyTotalFees).div(100);
            tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
            tokensForDev += (fees * buyDevFee) / buyTotalFees;
            tokensForMarketing += (fees * buyMarketingFee) / buyTotalFees;
        }

        if (fees > 0) {
            super._transfer(from, address(this), fees);
        }

        amount -= fees;
        }
        super._transfer(from, to, amount);

        checkVesting(from);
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
        address(this),
        block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        // add the liquidity
        uniswapV2Router.addLiquidityETH{ value: ethAmount }(
        address(this),
        tokenAmount,
        0, // slippage is unavoidable
        0, // slippage is unavoidable
        liquidityWallet,
        block.timestamp
        );
    }

    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForLiquidity +
        tokensForMarketing +
        tokensForDev;

        if (contractBalance == 0 || totalTokensToSwap == 0) {
        return;
        }

        // Halve the amount of liquidity tokens
        uint256 liquidityTokens = (contractBalance * tokensForLiquidity) /
        totalTokensToSwap /
        2;
        uint256 amountToSwapForETH = contractBalance.sub(liquidityTokens);

        uint256 initialETHBalance = address(this).balance;

        swapTokensForEth(amountToSwapForETH);

        uint256 ethBalance = address(this).balance.sub(initialETHBalance);

        uint256 ethForMarketing = ethBalance.mul(tokensForMarketing).div(
        totalTokensToSwap
        );
        uint256 ethForDev = ethBalance.mul(tokensForDev).div(totalTokensToSwap);

        uint256 ethForLiquidity = ethBalance - ethForMarketing - ethForDev;

        tokensForLiquidity = 0;
        tokensForMarketing = 0;
        tokensForDev = 0;

        (bool success, ) = address(marketingWallet).call{ value: ethForMarketing }(
        ""
        );
        (success, ) = address(devWallet).call{ value: ethForDev }("");

        if (liquidityTokens > 0 && ethForLiquidity > 0) {
        addLiquidity(liquidityTokens, ethForLiquidity);
        emit SwapAndLiquify(
            amountToSwapForETH,
            ethForLiquidity,
            tokensForLiquidity
        );
        }

        if (address(this).balance >= 1 ether) {
        (success, ) = address(marketingWallet).call{
            value: address(this).balance
        }("");
        }
    }

    // force Swap back if slippage above 49% for launch. fix router clog
    function forceSwapBack() external onlyOwner {
        uint256 contractBalance = balanceOf(address(this));
        require(
        contractBalance >= totalSupply() / 100,
        "Can only swap back if more than 1% of tokens stuck on contract"
        );
        swapBack();
        emit OwnerForcedSwapBack(block.timestamp);
    }

    function withdrawDustToken(address _token, address _to)
        external
        onlyOwner
        returns (bool _sent)
    {
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        _sent = IERC20(_token).transfer(_to, _contractBalance);
    }

    function withdrawDustETH(address _recipient) external onlyOwner {
        uint256 contractETHBalance = address(this).balance;
        (bool success, ) = _recipient.call{ value: contractETHBalance }("");
        require(
        success,
        "Address: unable to send value, recipient may have reverted"
        );
    }
}