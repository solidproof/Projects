/*
###############################################################
###############################################################
##########     ################################################
##########      ###############################################
##########      ###############################################
##########.   #################################################
##########    ###################        ,#####################
##########  * #################,          .####################
##########  #,#################           #####################
##########   #################           ######################
##########  #################            ######################
##########          ,#######            ############.  ########
########            #### #      (       (#######(       #######
########       *#########   *#####      *#####          #######
########################   (#######     ###/        (##########
#######################   .#      #      #       ##############
######################   ####    ###   # #     ################
#####################  ##############   (##          (#########
####################*#################   #########.,   ########
####################################### ##########     ########
##################################################   ##########
############################################## (  # ###########
########################################,     *  ##############
###############################################################
###############################################################

This is the official contract of the LastApeStanding token. This token
is the first of its kind to implement an innovative jackpot mechanism.

Every buy and sell will feed the jackpot (2%/5%). If for 10 mins, no buys are
recorded, the last buyer will receive a portion of the jackpot. This will drive
a consistent buy pressure.

The jackpot has a hard limit ($100K) that, if reached, will trigger the big bang event. A portion
of the jackpot will be cashed out to the buyback wallet. The buyback wallet will
then either burn the tokens or dedicate a portion of it towards staking.

Website: https://www.lastapestanding.com
Twitter: https://twitter.com/the_las_bsc
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./Ownable.sol";

contract LastApeStanding is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    EnumerableSet.AddressSet private _isExcludedFromFee;
    EnumerableSet.AddressSet private _isExcludedFromSwapAndLiquify;

    // 100%
    uint256 private constant MAX_PCT = 10000;
    uint256 private constant BNB_DECIMALS = 18;
    uint256 private constant USDT_DECIMALS = 18;
    address private constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // At any given time, buy and sell fees can NOT exceed 25% each
    uint256 private constant TOTAL_FEES_LIMIT = 2500;
    // We don't add to liquidity unless we have at least 1 LAS token
    uint256 private constant LIQ_SWAP_THRESH = 10**_decimals;

    // PCS takes 0.25% fee on all txs
    uint256 private constant ROUTER_FEE = 25;

    // Jackpot hard limits
    uint256 private constant JACKPOT_TIMESPAN_LIMIT_MIN = 30;
    uint256 private constant JACKPOT_TIMESPAN_LIMIT_MAX = 1200;

    uint256 private constant JACKPOT_BIGBANG_MIN = 30000 * 10**USDT_DECIMALS;
    uint256 private constant JACKPOT_BIGBANG_MAX = 250000 * 10**USDT_DECIMALS;

    uint256 private constant JACKPOT_BUYER_SHARE_MIN = 5000;
    uint256 private constant JACKPOT_BUYER_SHARE_MAX = 10000;

    uint256 private constant JACKPOT_MINBUY_MIN = 5 * 10**(BNB_DECIMALS - 2);
    uint256 private constant JACKPOT_MINBUY_MAX = 5 * 10**(BNB_DECIMALS - 1);

    uint256 private constant JACKPOT_CASHOUT_MIN = 4000;
    uint256 private constant JACKPOT_CASHOUT_MAX = 7000;

    uint256 private constant JACKPOT_BIGBANG_BUYBACK_MIN = 3000;
    uint256 private constant JACKPOT_BIGBANG_BUYBACK_MAX = 7000;

    string private constant _name = "LastApeStanding";
    string private constant _symbol = "LAS";
    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 10000000 * 10**_decimals;

    // Max wallet size initially set to 1%
    uint256 public maxWalletSize = _tTotal.div(100);

    // Buy fees
    // 1% liquidity
    uint256 public bLiquidityFee = 100;
    // 2% marketing
    uint256 public bMarketingFee = 200;
    // 2% dev
    uint256 public bDevFee = 200;
    // 2% jackpot
    uint256 public bJackpotFee = 200;

    // Sell fees
    // 1% liquidity
    uint256 public sLiquidityFee = 100;
    // 5% marketing
    uint256 public sMarketingFee = 500;
    // 2% dev
    uint256 public sDevFee = 200;
    // 5% jackpot
    uint256 public sJackpotFee = 500;

    // Fee variables for cross-method usage
    uint256 private _liquidityFee = 0;
    uint256 private _marketingFee = 0;
    uint256 private _devFee = 0;
    uint256 private _jackpotFee = 0;

    // Token distribution held by the contract
    uint256 private _liquidityTokens = 0;
    uint256 private _marketingTokens = 0;
    uint256 private _devTokens = 0;
    uint256 private _jackpotTokens = 0;

    // Jackpot related variables
    // 55.55% jackpot cashout to last buyer
    uint256 public jackpotCashout = 5555;
    // 90% of jackpot cashout to last buyer
    uint256 public jackpotBuyerShare = 9000;
    // Buys > 0.1 BNB will be eligible for the jackpot
    uint256 public jackpotMinBuy = 1 * 10**(BNB_DECIMALS - 1);
    // Jackpot time span is initially set to 10 mins
    uint256 public jackpotTimespan = 10 * 60;
    // Jackpot hard limit, BNB value
    uint256 public jackpotHardLimit = 250 * 10**(BNB_DECIMALS);
    // Jackpot hard limit buyback share
    uint256 public jackpotHardBuyback = 5000;

    address payable private _lastBuyer = payable(address(this));
    uint256 private _lastBuyTimestamp = 0;

    address private _lastAwarded = address(0);
    uint256 private _lastAwardedCash = 0;
    uint256 private _lastAwardedTokens = 0;
    uint256 private _lastAwardedTimestamp = 0;

    uint256 private _lastBigBangCash = 0;
    uint256 private _lastBigBangTokens = 0;
    uint256 private _lastBigBangTimestamp = 0;

    // The minimum transaction limit that can be set is 0.1% of the total supply
    uint256 private constant MIN_TX_LIMIT = 10;
    // Initially, max TX amount is set to the total supply
    uint256 public maxTxAmount = _tTotal;

    uint256 public numTokensSellToAddToLiquidity = 2000 * 10**_decimals;

    // Pending balances (BNB) ready to be collected
    uint256 private _pendingMarketingBalance = 0;
    uint256 private _pendingDevBalance = 0;
    uint256 private _pendingJackpotBalance = 0;

    // Total BNB/LAS collected by various mechanisms (dev, marketing, jackpot)
    uint256 private _totalMarketingFeesCollected = 0;
    uint256 private _totalDevFeesCollected = 0;
    uint256 private _totalJackpotCashedOut = 0;
    uint256 private _totalJackpotTokensOut = 0;
    uint256 private _totalJackpotBuyer = 0;
    uint256 private _totalJackpotBuyback = 0;
    uint256 private _totalJackpotBuyerTokens = 0;
    uint256 private _totalJackpotBuybackTokens = 0;

    bool public tradingOpen = false;
    // Liquidity
    bool public swapAndLiquifyEnabled = true;
    bool private _inSwapAndLiquify;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiquidity
    );
    event DevFeesCollected(uint256 bnbCollected);
    event MarketingFeesCollected(uint256 bnbCollected);
    event JackpotAwarded(
        uint256 cashedOut,
        uint256 tokensOut,
        uint256 buyerShare,
        uint256 tokensToBuyer,
        uint256 toBuyback,
        uint256 tokensToBuyback
    );
    event BigBang(uint256 cashedOut, uint256 tokensOut);

    event BuyFeesChanged(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 devFee,
        uint256 jackpotFee
    );

    event SellFeesChanged(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 devFee,
        uint256 jackpotFee
    );

    event JackpotFeaturesChanged(
        uint256 jackpotCashout,
        uint256 jackpotBuyerShare,
        uint256 jackpotMinBuy
    );

    event JackpotTimespanChanged(uint256 jackpotTimespan);

    event MaxTransferAmountChanged(uint256 maxTxAmount);

    event MaxWalletSizeChanged(uint256 maxWalletSize);

    event TokenToSellOnSwapChanged(uint256 numTokens);

    event BigBangFeaturesChanged(
        uint256 jackpotHardBuyback,
        uint256 jackpotHardLimit
    );

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    constructor(address cOwner) Ownable(cOwner) {
        _tOwned[cOwner] = _tTotal;

        uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            );

        // Exclude system addresses from fee
        _isExcludedFromFee.add(owner());
        _isExcludedFromFee.add(address(this));

        _isExcludedFromSwapAndLiquify.add(uniswapV2Pair);

        emit Transfer(address(0), cOwner, _tTotal);
    }

    receive() external payable {}

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _tOwned[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        approve(_msgSender(), spender, amount);
        return true;
    }

    function approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        transfer(sender, recipient, amount);
        approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "BEP20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "BEP20: decreased allowance below zero"
            )
        );
        return true;
    }

    function totalMarketingFeesCollected()
        external
        view
        onlyMarketing
        returns (uint256)
    {
        return _totalMarketingFeesCollected;
    }

    function totalDevFeesCollected() external view onlyDev returns (uint256) {
        return _totalDevFeesCollected;
    }

    function totalJackpotOut() external view returns (uint256, uint256) {
        return (_totalJackpotCashedOut, _totalJackpotTokensOut);
    }

    function totalJackpotBuyer() external view returns (uint256, uint256) {
        return (_totalJackpotBuyer, _totalJackpotBuyerTokens);
    }

    function totalJackpotBuyback() external view returns (uint256, uint256) {
        return (_totalJackpotBuyback, _totalJackpotBuybackTokens);
    }

    function excludeFromFee(address account) public onlyAuthorized {
        _isExcludedFromFee.add(account);
    }

    function includeInFee(address account) public onlyAuthorized {
        _isExcludedFromFee.remove(account);
    }

    function setBuyFees(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 devFee,
        uint256 jackpotFee
    ) external onlyAuthorized {
        require(
            liquidityFee.add(marketingFee).add(devFee).add(jackpotFee) <=
                TOTAL_FEES_LIMIT,
            "Total fees can not exceed the declared limit"
        );
        bLiquidityFee = liquidityFee;
        bMarketingFee = marketingFee;
        bDevFee = devFee;
        bJackpotFee = jackpotFee;

        emit BuyFeesChanged(bLiquidityFee, bMarketingFee, bDevFee, bJackpotFee);
    }

    function getBuyTax() public view returns (uint256) {
        return bLiquidityFee.add(bMarketingFee).add(bDevFee).add(bJackpotFee);
    }

    function setSellFees(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 devFee,
        uint256 jackpotFee
    ) external onlyAuthorized {
        require(
            liquidityFee.add(marketingFee).add(devFee).add(jackpotFee) <=
                TOTAL_FEES_LIMIT,
            "Total fees can not exceed the declared limit"
        );
        sLiquidityFee = liquidityFee;
        sMarketingFee = marketingFee;
        sDevFee = devFee;
        sJackpotFee = jackpotFee;

        emit SellFeesChanged(
            sLiquidityFee,
            sMarketingFee,
            sDevFee,
            sJackpotFee
        );
    }

    function getSellTax() public view returns (uint256) {
        return sLiquidityFee.add(sMarketingFee).add(sDevFee).add(sJackpotFee);
    }

    function setJackpotFeatures(
        uint256 _jackpotCashout,
        uint256 _jackpotBuyerShare,
        uint256 _jackpotMinBuy
    ) external onlyAuthorized {
        require(
            _jackpotCashout >= JACKPOT_CASHOUT_MIN &&
                _jackpotCashout <= JACKPOT_CASHOUT_MAX,
            "Jackpot cashout percentage needs to be between 40% and 70%"
        );
        require(
            _jackpotBuyerShare >= JACKPOT_BUYER_SHARE_MIN &&
                _jackpotBuyerShare <= JACKPOT_BUYER_SHARE_MAX,
            "Jackpot buyer share percentage needs to be between 50% and 100%"
        );
        require(
            _jackpotMinBuy >= JACKPOT_MINBUY_MIN &&
                _jackpotMinBuy <= JACKPOT_MINBUY_MAX,
            "Jackpot min buy needs to be between 0.05 and 0.5 BNB"
        );
        jackpotCashout = _jackpotCashout;
        jackpotBuyerShare = _jackpotBuyerShare;
        jackpotMinBuy = _jackpotMinBuy;

        emit JackpotFeaturesChanged(
            jackpotCashout,
            jackpotBuyerShare,
            jackpotMinBuy
        );
    }

    function setJackpotHardFeatures(
        uint256 _jackpotHardBuyback,
        uint256 _jackpotHardLimit
    ) external onlyAuthorized {
        require(
            _jackpotHardBuyback >= JACKPOT_BIGBANG_BUYBACK_MIN &&
                _jackpotHardBuyback <= JACKPOT_BIGBANG_BUYBACK_MAX,
            "Jackpot hard buyback percentage needs to be between 30% and 70%"
        );
        jackpotHardBuyback = _jackpotHardBuyback;

        uint256 hardLimitUsd = usdEquivalent(_jackpotHardLimit);
        require(
            hardLimitUsd >= JACKPOT_BIGBANG_MIN &&
                hardLimitUsd <= JACKPOT_BIGBANG_MAX,
            "Jackpot hard value limit for the big bang needs to be between 30K and 250K USD"
        );
        jackpotHardLimit = _jackpotHardLimit;

        emit BigBangFeaturesChanged(jackpotHardBuyback, jackpotHardLimit);
    }

    function setJackpotTimespanInSeconds(uint256 _jackpotTimespan)
        external
        onlyAuthorized
    {
        require(
            _jackpotTimespan >= JACKPOT_TIMESPAN_LIMIT_MIN &&
                _jackpotTimespan <= JACKPOT_TIMESPAN_LIMIT_MAX,
            "Jackpot timespan needs to be between 30 and 1200 seconds (20 minutes)"
        );
        jackpotTimespan = _jackpotTimespan;

        emit JackpotTimespanChanged(jackpotTimespan);
    }

    function setMaxTxAmount(uint256 txAmount) external onlyAuthorized {
        require(
            txAmount >= _tTotal.mul(MIN_TX_LIMIT).div(MAX_PCT),
            "Maximum transaction limit can't be less than 0.1% of the total supply"
        );
        maxTxAmount = txAmount;

        emit MaxTransferAmountChanged(maxTxAmount);
    }

    function setMaxWallet(uint256 amount) external onlyAuthorized {
        require(
            amount >= _tTotal.div(1000),
            "Max wallet size must be at least 0.1% of the total supply"
        );
        maxWalletSize = amount;

        emit MaxWalletSizeChanged(maxWalletSize);
    }

    function setNumTokensSellToAddToLiquidity(uint256 numTokens)
        external
        onlyAuthorized
    {
        numTokensSellToAddToLiquidity = numTokens;

        emit TokenToSellOnSwapChanged(numTokensSellToAddToLiquidity);
    }

    function isJackpotEligible(uint256 tokenAmount) public view returns (bool) {
        if (jackpotMinBuy == 0) {
            return true;
        }
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        uint256 tokensOut = uniswapV2Router
        .getAmountsOut(jackpotMinBuy, path)[1].mul(MAX_PCT.sub(ROUTER_FEE)).div(
                // We don't subtract the buy fee since the tokenAmount is pre-tax
                MAX_PCT
            );
        return tokenAmount >= tokensOut;
    }

    function usdEquivalent(uint256 bnbAmount) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = USDT;

        return uniswapV2Router.getAmountsOut(bnbAmount, path)[1];
    }

    function getUsedTokens(
        uint256 accSum,
        uint256 tokenAmount,
        uint256 tokens
    ) private pure returns (uint256, uint256) {
        if (accSum >= tokenAmount) {
            return (0, accSum);
        }
        uint256 available = tokenAmount - accSum;
        if (tokens <= available) {
            return (tokens, accSum.add(tokens));
        }
        return (available, accSum.add(available));
    }

    function getTokenShares(uint256 tokenAmount)
        private
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 accSum = 0;
        uint256 liquidityTokens = 0;
        uint256 marketingTokens = 0;
        uint256 devTokens = 0;
        uint256 jackpotTokens = 0;

        // Either 0 or 1+ LAS to prevent PCS errors on liq swap
        if (_liquidityTokens >= LIQ_SWAP_THRESH) {
            (liquidityTokens, accSum) = getUsedTokens(
                accSum,
                tokenAmount,
                _liquidityTokens
            );
            _liquidityTokens = _liquidityTokens.sub(liquidityTokens);
        }

        (marketingTokens, accSum) = getUsedTokens(
            accSum,
            tokenAmount,
            _marketingTokens
        );
        _marketingTokens = _marketingTokens.sub(marketingTokens);

        (devTokens, accSum) = getUsedTokens(accSum, tokenAmount, _devTokens);
        _devTokens = _devTokens.sub(devTokens);

        (jackpotTokens, accSum) = getUsedTokens(
            accSum,
            tokenAmount,
            _jackpotTokens
        );
        _jackpotTokens = _jackpotTokens.sub(jackpotTokens);

        return (liquidityTokens, marketingTokens, devTokens, jackpotTokens);
    }

    function setSwapAndLiquifyEnabled(bool enabled) public onlyOwner {
        swapAndLiquifyEnabled = enabled;
        emit SwapAndLiquifyEnabledUpdated(enabled);
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee.contains(account);
    }

    function isExcludedFromSwapAndLiquify(address account)
        public
        view
        returns (bool)
    {
        return _isExcludedFromSwapAndLiquify.contains(account);
    }

    function includeFromSwapAndLiquify(address account) external onlyOwner {
        _isExcludedFromSwapAndLiquify.remove(account);
    }

    function excludeFromSwapAndLiquify(address account) external onlyOwner {
        _isExcludedFromSwapAndLiquify.add(account);
    }

    function setUniswapRouter(address otherRouterAddress) external onlyOwner {
        uniswapV2Router = IUniswapV2Router02(otherRouterAddress);
    }

    function setUniswapPair(address otherPairAddress) external onlyOwner {
        require(
            otherPairAddress != address(0),
            "You must supply a non-zero address"
        );
        uniswapV2Pair = otherPairAddress;
    }

    function transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        require(to != devWallet(), "Dev wallet address cannot receive tokens");
        require(from != devWallet(), "Dev wallet address cannot send tokens");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (from != owner() && to != owner()) {
            require(
                amount <= maxTxAmount,
                "Transfer amount exceeds the maxTxAmount"
            );
        }

        if (!authorizations[from] && !authorizations[to]) {
            require(tradingOpen, "Trading is currently not open");
        }

        // Jackpot mechanism locks the swap if triggered. We should handle it as
        // soon as possible so that we could award the jackpot on a sell and on a buy
        if (!_inSwapAndLiquify && _pendingJackpotBalance >= jackpotHardLimit) {
            processBigBang();
        } else if (
            // We can't award the jackpot in swap and liquify
            // Pending balances need to be untouched (externally) for swaps
            !_inSwapAndLiquify &&
            _lastBuyer != address(0) &&
            _lastBuyer != address(this) &&
            block.timestamp.sub(_lastBuyTimestamp) >= jackpotTimespan
        ) {
            awardJackpot();
        }

        uint256 contractTokenBalance = balanceOf(address(this));

        if (contractTokenBalance >= maxTxAmount) {
            contractTokenBalance = maxTxAmount;
        }

        bool isOverMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        if (
            isOverMinTokenBalance &&
            !_inSwapAndLiquify &&
            !_isExcludedFromSwapAndLiquify.contains(from) &&
            swapAndLiquifyEnabled
        ) {
            swapAndLiquify(numTokensSellToAddToLiquidity);
        }

        bool takeFee = true;
        if (
            _isExcludedFromFee.contains(from) ||
            _isExcludedFromFee.contains(to) ||
            (uniswapV2Pair != from && uniswapV2Pair != to)
        ) {
            takeFee = false;
        }

        tokenTransfer(from, to, amount, takeFee);
    }

    function enableTrading() public onlyOwner {
        // Trading can only be enabled, so it can never be turned off
        tradingOpen = true;
    }

    function collectMarketingFees() public onlyMarketing {
        _totalMarketingFeesCollected = _totalMarketingFeesCollected.add(
            _pendingMarketingBalance
        );
        marketingWallet().transfer(_pendingMarketingBalance);
        emit MarketingFeesCollected(_pendingMarketingBalance);
        _pendingMarketingBalance = 0;
    }

    function collectDevFees() public onlyDev {
        _totalDevFeesCollected = _totalDevFeesCollected.add(_pendingDevBalance);
        devWallet().transfer(_pendingDevBalance);
        emit DevFeesCollected(_pendingDevBalance);
        _pendingDevBalance = 0;
    }

    function getJackpot() public view returns (uint256, uint256) {
        return (_pendingJackpotBalance, _jackpotTokens);
    }

    function jackpotBuyerShareAmount() public view returns (uint256, uint256) {
        uint256 bnb = _pendingJackpotBalance
            .mul(jackpotCashout)
            .div(MAX_PCT)
            .mul(jackpotBuyerShare)
            .div(MAX_PCT);
        uint256 tokens = _jackpotTokens
            .mul(jackpotCashout)
            .div(MAX_PCT)
            .mul(jackpotBuyerShare)
            .div(MAX_PCT);
        return (bnb, tokens);
    }

    function jackpotBuybackAmount() public view returns (uint256, uint256) {
        uint256 bnb = _pendingJackpotBalance
            .mul(jackpotCashout)
            .div(MAX_PCT)
            .mul(MAX_PCT.sub(jackpotBuyerShare))
            .div(MAX_PCT);
        uint256 tokens = _jackpotTokens
            .mul(jackpotCashout)
            .div(MAX_PCT)
            .mul(MAX_PCT.sub(jackpotBuyerShare))
            .div(MAX_PCT);

        return (bnb, tokens);
    }

    function getLastBuy() public view returns (address, uint256) {
        return (_lastBuyer, _lastBuyTimestamp);
    }

    function getLastAwarded()
        public
        view
        returns (
            address,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _lastAwarded,
            _lastAwardedCash,
            _lastAwardedTokens,
            _lastAwardedTimestamp
        );
    }

    function getLastBigBang()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (_lastBigBangCash, _lastBigBangTokens, _lastBigBangTimestamp);
    }

    function getPendingBalances()
        public
        view
        onlyAuthorized
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _pendingMarketingBalance,
            _pendingDevBalance,
            _pendingJackpotBalance
        );
    }

    function getPendingTokens()
        public
        view
        onlyAuthorized
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (_liquidityTokens, _marketingTokens, _devTokens, _jackpotTokens);
    }

    function processBigBang() private lockTheSwap {
        uint256 cashedOut = _pendingJackpotBalance.mul(jackpotHardBuyback).div(
            MAX_PCT
        );
        uint256 tokensOut = _jackpotTokens.mul(jackpotHardBuyback).div(MAX_PCT);

        buybackWallet().transfer(cashedOut);
        transferBasic(address(this), buybackWallet(), tokensOut);
        emit BigBang(cashedOut, tokensOut);

        _lastBigBangCash = cashedOut;
        _lastBigBangTokens = tokensOut;
        _lastBigBangTimestamp = block.timestamp;

        _pendingJackpotBalance = _pendingJackpotBalance.sub(cashedOut);
        _jackpotTokens = _jackpotTokens.sub(tokensOut);

        _totalJackpotCashedOut = _totalJackpotCashedOut.add(cashedOut);
        _totalJackpotBuyback = _totalJackpotBuyback.add(cashedOut);
        _totalJackpotTokensOut = _totalJackpotTokensOut.add(tokensOut);
        _totalJackpotBuybackTokens = _totalJackpotBuybackTokens.add(tokensOut);
    }

    function awardJackpot() private lockTheSwap {
        require(
            _lastBuyer != address(0) && _lastBuyer != address(this),
            "No last buyer detected"
        );
        uint256 cashedOut = _pendingJackpotBalance.mul(jackpotCashout).div(
            MAX_PCT
        );
        uint256 tokensOut = _jackpotTokens.mul(jackpotCashout).div(MAX_PCT);
        uint256 buyerShare = cashedOut.mul(jackpotBuyerShare).div(MAX_PCT);
        uint256 tokensToBuyer = tokensOut.mul(jackpotBuyerShare).div(MAX_PCT);
        uint256 toBuyback = cashedOut - buyerShare;
        uint256 tokensToBuyback = tokensOut - tokensToBuyer;
        _lastBuyer.transfer(buyerShare);
        transferBasic(address(this), _lastBuyer, tokensToBuyer);
        buybackWallet().transfer(toBuyback);
        transferBasic(address(this), buybackWallet(), tokensToBuyback);

        _pendingJackpotBalance = _pendingJackpotBalance.sub(cashedOut);
        _jackpotTokens = _jackpotTokens.sub(tokensOut);

        emit JackpotAwarded(
            cashedOut,
            tokensOut,
            buyerShare,
            tokensToBuyer,
            toBuyback,
            tokensToBuyback
        );

        _lastAwarded = _lastBuyer;
        _lastAwardedTimestamp = block.timestamp;
        _lastAwardedCash = buyerShare;
        _lastAwardedTokens = tokensToBuyer;

        _lastBuyer = payable(address(this));
        _lastBuyTimestamp = 0;

        _totalJackpotCashedOut = _totalJackpotCashedOut.add(cashedOut);
        _totalJackpotTokensOut = _totalJackpotTokensOut.add(tokensOut);
        _totalJackpotBuyer = _totalJackpotBuyer.add(buyerShare);
        _totalJackpotBuyerTokens = _totalJackpotBuyerTokens.add(tokensToBuyer);
        _totalJackpotBuyback = _totalJackpotBuyback.add(toBuyback);
        _totalJackpotBuybackTokens = _totalJackpotBuybackTokens.add(
            tokensToBuyback
        );
    }

    function swapAndLiquify(uint256 tokenAmount) private lockTheSwap {
        (
            uint256 liqTokens,
            uint256 marketingTokens,
            uint256 devTokens,
            uint256 jackpotTokens
        ) = getTokenShares(tokenAmount);
        uint256 toBeSwapped = liqTokens.add(marketingTokens).add(devTokens).add(
            jackpotTokens
        );
        // This variable holds the liquidity tokens that won't be converted
        uint256 pureLiqTokens = liqTokens.div(2);

        // Everything else from the tokens should be converted
        uint256 tokensForBnbExchange = toBeSwapped.sub(pureLiqTokens);

        uint256 initialBalance = address(this).balance;
        swapTokensForBnb(tokensForBnbExchange);

        // How many BNBs did we gain after this conversion?
        uint256 gainedBnb = address(this).balance.sub(initialBalance);

        // Calculate the amount of BNB that's assigned to the marketing wallet
        uint256 balanceToMarketing = gainedBnb.mul(marketingTokens).div(
            tokensForBnbExchange
        );
        _pendingMarketingBalance += balanceToMarketing;

        // Same for dev
        uint256 balanceToDev = gainedBnb.mul(devTokens).div(
            tokensForBnbExchange
        );
        _pendingDevBalance += balanceToDev;

        // Same for Jackpot
        uint256 balanceToJackpot = gainedBnb.mul(jackpotTokens).div(
            tokensForBnbExchange
        );
        _pendingJackpotBalance += balanceToJackpot;

        uint256 remainingBnb = gainedBnb
            .sub(balanceToMarketing)
            .sub(balanceToDev)
            .sub(balanceToJackpot);

        if (liqTokens >= LIQ_SWAP_THRESH) {
            // The leftover BNBs are purely for liquidity here
            // We are not guaranteed to have all the pure liq tokens to be transferred to the pair
            // This is because the uniswap router, PCS in this case, will make a quote based
            // on the current reserves of the pair, so one of the parameters will be fully
            // consumed, but the other will have leftovers.
            uint256 prevBalance = balanceOf(address(this));
            uint256 prevBnbBalance = address(this).balance;
            addLiquidity(pureLiqTokens, remainingBnb);
            uint256 usedBnbs = prevBnbBalance.sub(address(this).balance);
            uint256 usedTokens = prevBalance.sub(balanceOf(address(this)));
            // Reallocate the tokens that weren't used back to the internal liquidity tokens tracker
            if (usedTokens < pureLiqTokens) {
                _liquidityTokens += pureLiqTokens.sub(usedTokens);
            }
            // Reallocate the unused BNBs to the pending marketing wallet balance
            if (usedBnbs < remainingBnb) {
                _pendingMarketingBalance += remainingBnb.sub(usedBnbs);
            }

            emit SwapAndLiquify(tokensForBnbExchange, usedBnbs, usedTokens);
        } else {
            // We could have some dust, so we'll just add it to the pending marketing wallet balance
            _pendingMarketingBalance += remainingBnb;

            emit SwapAndLiquify(tokensForBnbExchange, 0, 0);
        }
    }

    function swapTokensForBnb(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // Approve token transfer to cover all possible scenarios
        approve(address(this), address(uniswapV2Router), tokenAmount);

        // Add the liquidity
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            lockedLiquidity(),
            block.timestamp
        );
    }

    function tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) {
            // If we're here, it means either the sender or recipient is excluded from taxes
            // Also, it could be that this is just a transfer of tokens between wallets
            _liquidityFee = 0;
            _marketingFee = 0;
            _devFee = 0;
            _jackpotFee = 0;
        } else if (recipient == uniswapV2Pair) {
            // This is a sell
            _liquidityFee = sLiquidityFee;
            _marketingFee = sMarketingFee;
            _devFee = sDevFee;
            _jackpotFee = sJackpotFee;
        } else {
            // If we're here, it must mean that the sender is the uniswap pair
            // This is a buy
            if (isJackpotEligible(amount)) {
                _lastBuyTimestamp = block.timestamp;
                _lastBuyer = payable(recipient);
            }

            _liquidityFee = bLiquidityFee;
            _marketingFee = bMarketingFee;
            _devFee = bDevFee;
            _jackpotFee = bJackpotFee;
        }

        transferStandard(sender, recipient, amount);
    }

    function transferBasic(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        _tOwned[sender] = _tOwned[sender].sub(amount);
        _tOwned[recipient] = _tOwned[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    function transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 tTransferAmount,
            uint256 tLiquidity,
            uint256 tMarketing,
            uint256 tDev,
            uint256 tJackpot
        ) = processAmount(tAmount);
        uint256 tFees = tLiquidity.add(tMarketing).add(tDev).add(tJackpot);
        if (recipient != uniswapV2Pair && recipient != DEAD) {
            require(
                isExcludedFromFee(recipient) ||
                    balanceOf(recipient).add(tTransferAmount) <= maxWalletSize,
                "Transfer amount will push this wallet beyond the maximum allowed size"
            );
        }

        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);

        takeTransactionFee(address(this), tFees);
        _liquidityTokens += tLiquidity;
        _marketingTokens += tMarketing;
        _devTokens += tDev;
        _jackpotTokens += tJackpot;

        emit Transfer(sender, recipient, tTransferAmount);
    }

    function processAmount(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tLiquidity = tAmount.mul(_liquidityFee).div(MAX_PCT);
        uint256 tMarketing = tAmount.mul(_marketingFee).div(MAX_PCT);
        uint256 tDev = tAmount.mul(_devFee).div(MAX_PCT);
        uint256 tJackpot = tAmount.mul(_jackpotFee).div(MAX_PCT);
        uint256 tTransferAmount = tAmount.sub(
            tLiquidity.add(tMarketing).add(tDev).add(tJackpot)
        );
        return (tTransferAmount, tLiquidity, tMarketing, tDev, tJackpot);
    }

    function takeTransactionFee(address to, uint256 tAmount) private {
        if (tAmount <= 0) {
            return;
        }
        _tOwned[to] = _tOwned[to].add(tAmount);
    }

    function aboutMe() public pure returns (uint256) {
        return 0xbf919525b1bd565e29ab61d33ebd2194;
    }
}
