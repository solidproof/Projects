// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router02.sol";
import "./WinBinaryTokenDividendTracker.sol";
import "./BaseToken.sol";

contract WinBinary is ERC20, Ownable, BaseToken {
    using SafeMath for uint256;

    uint256 public constant VERSION = 1;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool private swapping;

    WinBinaryTokenDividendTracker public dividendTracker;

    address public rewardToken;
    uint256 constant FEE_DENOMINATOR = 10000;


    uint256 private constant BNB_DECIMALS = 18;
    uint256 private constant BUSD_DECIMALS = 18;

    uint256 public maxJackpotLimitMultiplier = 10;

    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // mainnet
    // address constant BUSD = 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7; // testnet
    uint256 private constant MAX_PCT = 10000;
    // PCS takes 0.25% fee on all txs
    uint256 private constant ROUTER_FEE = 25;

    // 55.55% jackpot cashout to last buyer
    uint256 public jackpotCashout = 5555;
    // 90% of jackpot cashout to last buyer
    uint256 public jackpotBuyerShare = 9000;
    // Buys > 10 BUSD will be eligible for the jackpot
    uint256 public jackpotMinBuy = 10 * 10**(BUSD_DECIMALS);
    // Jackpot time span is initially set to 5 mins
    uint256 public jackpotTimespan = 5 * 60;
    // Jackpot hard limit, BUSD value
    uint256 public jackpotHardLimit = 50000 * 10**(BUSD_DECIMALS);
    // Jackpot hard limit buyback share
    uint256 public jackpotHardBuyback = 5000;

    uint256 public _jackpotTokens = 0;
    uint256 public _pendingJackpotBalance = 0;

    address private _lastBuyer = address(this);
    uint256 private _lastBuyTimestamp = 0;
    uint256 private _lastBuyBUSDValue = 0;

    address private _lastAwarded = address(0);
    uint256 private _lastAwardedCash = 0;
    uint256 private _lastAwardedTokens = 0;
    uint256 private _lastAwardedTimestamp = 0;

    uint256 private _lastBigBangCash = 0;
    uint256 private _lastBigBangTokens = 0;
    uint256 private _lastBigBangTimestamp = 0;

    uint256 private _totalJackpotCashedOut = 0;
    uint256 private _totalJackpotTokensOut = 0;
    uint256 private _totalJackpotBuyer = 0;
    uint256 private _totalJackpotBuyback = 0;
    uint256 private _totalJackpotBuyerTokens = 0;
    uint256 private _totalJackpotBuybackTokens = 0;

    address public buybackWallet = 0x3291A5dd2a67dF2eE4C9051A4fcbA013d04d75c3;
    address public tresuryReceiver = 0xEf92730E2d9c298c3144BD9dBFe61EF3eaE0AF3D;

    uint256 public swapTokensAtAmount;

    uint256 public tokenRewardsFee;
    uint256 public liquidityFee;
    uint256 public jackpotFee;
    uint256 public burnFee;
    uint256 public tresuryFee;
    uint256 public totalFees;

    uint256 public gasForProcessing;

    // exlcude from fees and max transaction amount
    mapping(address => bool) private _isExcludedFromFees;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateDividendTracker(
        address indexed newAddress,
        address indexed oldAddress
    );

    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(
        address indexed newLiquidityWallet,
        address indexed oldLiquidityWallet
    );

    event GasForProcessingUpdated(
        uint256 indexed newValue,
        uint256 indexed oldValue
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event TresuryReceived(
        address indexed receiver,
        uint256 indexed amount
    );

    event SendDividends(uint256 tokensSwapped, uint256 amount);

    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    event JackpotAwarded(address indexed receiver, uint256 amount);
    event BigBang(uint256 cashedOut, uint256 tokensOut);
    event JackpotFund(uint256 busdSent, uint256 tokenAmount);

    modifier lockTheSwap() {
        swapping = true;
        _;
        swapping = false;
    }

    constructor(
        uint256 totalSupply_,
        address[3] memory addrs, // reward, router, dividendTracker
        uint256[5] memory feeSettings, // rewards, liquidity, jackpot, burn, tresury
        uint256 minimumTokenBalanceForDividends_
    ) ERC20("WinBinary", "WINB") {
        rewardToken = addrs[0];
        tokenRewardsFee = feeSettings[0];
        liquidityFee = feeSettings[1];
        jackpotFee = feeSettings[2];
        burnFee = feeSettings[3];
        tresuryFee = feeSettings[4];

        totalFees = tokenRewardsFee
            .add(liquidityFee)
            .add(jackpotFee)
            .add(burnFee)
            .add(tresuryFee);
        require(totalFees <= 2500, "WINB: Total fee is over 25%");
        swapTokensAtAmount = 100 ether; // Swap at 100 WINB
        // use by default 300,000 gas to process auto-claiming dividends
        gasForProcessing = 300000;

        dividendTracker = WinBinaryTokenDividendTracker(
            payable(Clones.clone(addrs[2]))
        );
        dividendTracker.initialize(
            rewardToken,
            minimumTokenBalanceForDividends_
        );

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(addrs[1]);
        // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), BUSD);
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;
        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);


        // exclude from receiving dividends
        dividendTracker.excludeFromDividends(address(dividendTracker));
        dividendTracker.excludeFromDividends(address(this));
        dividendTracker.excludeFromDividends(tresuryReceiver);
        dividendTracker.excludeFromDividends(buybackWallet);
        dividendTracker.excludeFromDividends(address(0xdead));
        dividendTracker.excludeFromDividends(address(_uniswapV2Router));
        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(tresuryReceiver), true);
        excludeFromFees(address(buybackWallet), true);
        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(tresuryReceiver, totalSupply_);
        // Transfer ownership
        _transferOwnership(tresuryReceiver);

        emit TokenCreated(tresuryReceiver, address(this), TokenType.baby, VERSION);
    }

    function getLastBuy()
        external
        view
        returns (
            address lastBuyer,
            uint256 lastBuyBUSDValue,
            uint256 lastBuyTimestamp
        )
    {
        return (_lastBuyer, _lastBuyBUSDValue, _lastBuyTimestamp);
    }

    function getLastAwardedJackpot()
        external
        view
        returns (
            address lastAwarded,
            uint256 lastAwardedCash,
            uint256 lastAwardedTokens,
            uint256 lastAwardedTimestamp
        )
    {
        return (
            _lastAwarded,
            _lastAwardedCash,
            _lastAwardedTokens,
            _lastAwardedTimestamp
        );
    }

    function getPendingJackpotBalance()
        external
        view
        returns (uint256 pendingJackpotBalance)
    {
        return (_pendingJackpotBalance);
    }

    function getPendingJackpotTokens()
        external
        view
        returns (uint256 pendingJackpotTokens)
    {
        return _jackpotTokens;
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

    function getJackpot()
        public
        view
        returns (uint256 jackpotTokens, uint256 pendingJackpotAmount)
    {
        return (_jackpotTokens, _pendingJackpotBalance);
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

    function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
        swapTokensAtAmount = amount;
    }

    function setMaxJackpotLimitMultiplier(uint256 _maxJackpotLimitMultiplier)
        external
        onlyOwner
    {
        maxJackpotLimitMultiplier = _maxJackpotLimitMultiplier;
    }

    function setTokenRewardsFee(uint256 value) external onlyOwner {
        tokenRewardsFee = value;
        totalFees = tokenRewardsFee
            .add(liquidityFee)
            .add(jackpotFee)
            .add(burnFee)
            .add(tresuryFee);
        require(totalFees <= 25, "Total fee is over 25%");
    }

    function setLiquidityFee(uint256 value) external onlyOwner {
        liquidityFee = value;
        totalFees = liquidityFee
            .add(tokenRewardsFee)
            .add(jackpotFee)
            .add(burnFee)
            .add(tresuryFee);
        require(totalFees <= 25, "Total fee is over 25%");
    }

    function setJackpotFee(uint256 value) external onlyOwner {
        jackpotFee = value;
        totalFees = jackpotFee
            .add(liquidityFee)
            .add(tokenRewardsFee)
            .add(burnFee)
            .add(tresuryFee);
        require(totalFees <= 25, "Total fee is over 25%");
    }

    function setBurnFee(uint256 value) external onlyOwner {
        burnFee = value;
        uint256 totalSellFees = burnFee
            .add(liquidityFee)
            .add(tokenRewardsFee)
            .add(jackpotFee)
            .add(tresuryFee);
        require(totalSellFees <= 25, "Total fee is over 25%");
    }

    function setTresuryFee(uint256 value) external onlyOwner {
        tresuryFee = value;
        totalFees = tresuryFee
            .add(liquidityFee)
            .add(tokenRewardsFee)
            .add(jackpotFee)
            .add(burnFee);
        require(totalFees <= 25, "Total fee is over 25%");
    }

    function setJackpotHardBuyback(uint256 _hardBuyback) external onlyOwner {
        jackpotHardBuyback = _hardBuyback;
    }

    function setBuyBackWallet(address _wallet) external onlyOwner {
        buybackWallet = _wallet;
    }

    function setTresuryReceiver(address _receiver) external onlyOwner {
        tresuryReceiver = _receiver;
    }

    function setJackpotMinBuy(uint256 _minBuy) external onlyOwner {
        jackpotMinBuy = _minBuy;
    }

    function setJackpotTimespan(uint256 _timespan) external onlyOwner {
        jackpotTimespan = _timespan;
    }

    function setJackpotHardLimit(uint256 _hardlimit) external onlyOwner {
        jackpotHardLimit = _hardlimit;
    }

    function getBUSDValue(uint256 amount) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = BUSD;
        uint256 value = uniswapV2Router.getAmountsOut(amount, path)[1];
        return value;
    }

    function shouldAwardJackpot() public view returns (bool) {
        return
            _lastBuyer != address(0) &&
            _lastBuyer != address(this) &&
            block.timestamp.sub(_lastBuyTimestamp) >= jackpotTimespan;
    }

    function isJackpotEligible(uint256 tokenAmount) public view returns (bool) {
        if (jackpotMinBuy == 0) {
            return true;
        }
        address[] memory path = new address[](2);
        path[0] = BUSD;
        path[1] = address(this);

        uint256 tokensOut = uniswapV2Router
        .getAmountsOut(jackpotMinBuy, path)[1].mul(MAX_PCT.sub(ROUTER_FEE)).div(
                // We don't subtract the buy fee since the tokenAmount is pre-tax
                MAX_PCT
            );
        return tokenAmount >= tokensOut;
    }

    function processBigBang() internal lockTheSwap {
        uint256 cashedOut = _pendingJackpotBalance.mul(jackpotHardBuyback).div(
            MAX_PCT
        );
        uint256 tokensOut = _jackpotTokens.mul(jackpotHardBuyback).div(MAX_PCT);
        _lastBigBangTokens = tokensOut;

        IERC20(BUSD).transfer(buybackWallet, cashedOut);
        super._transfer(address(this), buybackWallet, tokensOut);

        emit BigBang(cashedOut, tokensOut);

        _lastBigBangCash = cashedOut;
        _lastBigBangTimestamp = block.timestamp;

        _pendingJackpotBalance = _pendingJackpotBalance.sub(cashedOut);
        _jackpotTokens = _jackpotTokens;

        _totalJackpotCashedOut = _totalJackpotCashedOut.add(cashedOut);
        _totalJackpotBuyback = _totalJackpotBuyback.add(cashedOut);
        _totalJackpotTokensOut = _totalJackpotTokensOut.add(tokensOut);
        _totalJackpotBuybackTokens = _totalJackpotBuybackTokens.add(tokensOut);
    }

    function fundJackpot(uint256 tokenAmount, uint256 busdAmount)
        external
        onlyOwner
    {
        require(
            balanceOf(msg.sender) >= tokenAmount,
            "You don't have enough tokens to fund the jackpot"
        );
        bool isTransferBUSDSuccess = IERC20(BUSD).transferFrom(
            msg.sender,
            address(this),
            busdAmount
        );
        if (isTransferBUSDSuccess) {
            _pendingJackpotBalance = _pendingJackpotBalance.add(busdAmount);
        }
        if (tokenAmount > 0) {
            super._transfer(msg.sender, address(this), tokenAmount);
            _jackpotTokens = _jackpotTokens.add(tokenAmount);
        }

        emit JackpotFund(busdAmount, tokenAmount);
    }

    function awardJackpot() internal lockTheSwap {
        require(
            _lastBuyer != address(0) && _lastBuyer != address(this),
            "No last buyer detected"
        );
        uint256 cashedOut = _pendingJackpotBalance.mul(jackpotCashout).div(
            MAX_PCT
        );
        if (cashedOut > _lastBuyBUSDValue.mul(maxJackpotLimitMultiplier)) {
            cashedOut = _lastBuyBUSDValue.mul(maxJackpotLimitMultiplier);
        }
        uint256 tokensOut = _jackpotTokens.mul(jackpotCashout).div(MAX_PCT);
        uint256 buyerShare = cashedOut.mul(jackpotBuyerShare).div(MAX_PCT);
        uint256 tokensToBuyer = tokensOut.mul(jackpotBuyerShare).div(MAX_PCT);
        uint256 toBuyback = cashedOut - buyerShare;
        uint256 tokensToBuyback = tokensOut - tokensToBuyer;

        IERC20(BUSD).transfer(_lastBuyer, buyerShare);
        super._transfer(address(this), _lastBuyer, tokensToBuyer);
        IERC20(BUSD).transfer(buybackWallet, toBuyback);
        super._transfer(address(this), buybackWallet, tokensToBuyback);

        _pendingJackpotBalance = _pendingJackpotBalance.sub(cashedOut);
        _jackpotTokens = _jackpotTokens.sub(tokensOut);

        _lastAwarded = _lastBuyer;
        _lastAwardedCash = cashedOut;
        _lastAwardedTimestamp = block.timestamp;
        _lastAwardedTokens = tokensToBuyer;

        emit JackpotAwarded(_lastBuyer, cashedOut);

        _lastBuyer = payable(address(this));
        _lastBuyTimestamp = 0;
        _lastBuyBUSDValue = 0;

        _totalJackpotCashedOut = _totalJackpotCashedOut.add(cashedOut);
        _totalJackpotTokensOut = _totalJackpotTokensOut.add(tokensOut);
        _totalJackpotBuyer = _totalJackpotBuyer.add(buyerShare);
        _totalJackpotBuyerTokens = _totalJackpotBuyerTokens.add(tokensToBuyer);
        _totalJackpotBuyback = _totalJackpotBuyback.add(toBuyback);
        _totalJackpotBuybackTokens = _totalJackpotBuybackTokens.add(
            tokensToBuyback
        );
    }

    function updateDividendTracker(address newAddress) public onlyOwner {
        require(
            newAddress != address(dividendTracker),
            "WINB: The dividend tracker already has that address"
        );

        WinBinaryTokenDividendTracker newDividendTracker = WinBinaryTokenDividendTracker(
                payable(newAddress)
            );

        require(
            newDividendTracker.owner() == address(this),
            "WINB: The new dividend tracker must be owned by the WINB token contract"
        );

        newDividendTracker.excludeFromDividends(address(newDividendTracker));
        newDividendTracker.excludeFromDividends(address(this));
        newDividendTracker.excludeFromDividends(owner());
        newDividendTracker.excludeFromDividends(address(uniswapV2Router));

        emit UpdateDividendTracker(newAddress, address(dividendTracker));

        dividendTracker = newDividendTracker;
    }

    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(
            newAddress != address(uniswapV2Router),
            "WINB: The router already has that address"
        );
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
        address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Pair = _uniswapV2Pair;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(
            _isExcludedFromFees[account] != excluded,
            "WINB: Account is already the value of 'excluded'"
        );
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        require(
            pair != uniswapV2Pair,
            "WINB: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            automatedMarketMakerPairs[pair] != value,
            "WINB: Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[pair] = value;

        if (value) {
            dividendTracker.excludeFromDividends(pair);
        }

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(
            newValue >= 200000 && newValue <= 500000,
            "WINB: gasForProcessing must be between 200,000 and 500,000"
        );
        require(
            newValue != gasForProcessing,
            "WINB: Cannot update gasForProcessing to same value"
        );
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        dividendTracker.updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns (uint256) {
        return dividendTracker.claimWait();
    }

    function updateMinimumTokenBalanceForDividends(uint256 amount)
        external
        onlyOwner
    {
        dividendTracker.updateMinimumTokenBalanceForDividends(amount);
    }

    function getMinimumTokenBalanceForDividends()
        external
        view
        returns (uint256)
    {
        return dividendTracker.minimumTokenBalanceForDividends();
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed();
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(address account)
        public
        view
        returns (uint256)
    {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(address account)
        public
        view
        returns (uint256)
    {
        return dividendTracker.balanceOf(account);
    }

    function excludeFromDividends(address account) external onlyOwner {
        dividendTracker.excludeFromDividends(account);
    }

    function isExcludedFromDividends(address account)
        public
        view
        returns (bool)
    {
        return dividendTracker.isExcludedFromDividends(account);
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
        return dividendTracker.getAccount(account);
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
        return dividendTracker.getAccountAtIndex(index);
    }

    function processDividendTracker(uint256 gas) external {
        (
            uint256 iterations,
            uint256 claims,
            uint256 lastProcessedIndex
        ) = dividendTracker.process(gas);
        emit ProcessedDividendTracker(
            iterations,
            claims,
            lastProcessedIndex,
            false,
            gas,
            tx.origin
        );
    }

    function claim() external {
        dividendTracker.processAccount(payable(msg.sender), false);
    }

    function getLastProcessedIndex() external view returns (uint256) {
        return dividendTracker.getLastProcessedIndex();
    }

    function getNumberOfDividendTokenHolders() external view returns (uint256) {
        return dividendTracker.getNumberOfTokenHolders();
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

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (
            canSwap &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            from != owner() &&
            to != owner()
        ) {
            swapping = true;
            uint256 totalFeesExceptBurnFee = totalFees.sub(burnFee);
            uint256 swapTokens = contractTokenBalance.mul(liquidityFee).div(
                totalFeesExceptBurnFee
            );
            swapAndLiquify(swapTokens);

            uint256 jackpotTokens = contractTokenBalance.mul(jackpotFee).div(
                totalFeesExceptBurnFee
            );
            uint256 tresuryTokens = contractTokenBalance.mul(tresuryFee).div(
                totalFeesExceptBurnFee
            );
            uint256 balanceBefore = IERC20(BUSD).balanceOf(address(this));
            swapTokensForTokens(jackpotTokens.add(tresuryTokens), BUSD);

            uint256 amountBUSDReceived = IERC20(BUSD)
                .balanceOf(address(this))
                .sub(balanceBefore);
            uint256 amountBUSDToFundJackpot = amountBUSDReceived
                .mul(jackpotFee)
                .div(jackpotFee.add(tresuryFee));
            uint256 amountBUSDToFundTresury = amountBUSDReceived
                .mul(tresuryFee)
                .div(jackpotFee.add(tresuryFee));
            emit TresuryReceived(tresuryReceiver, amountBUSDToFundTresury);
            _jackpotTokens = 0;
            _pendingJackpotBalance = _pendingJackpotBalance.add(
                amountBUSDToFundJackpot
            );
            IERC20(BUSD).transfer(tresuryReceiver, amountBUSDToFundTresury);

            uint256 sellTokens = balanceOf(address(this));
            swapAndSendDividends(sellTokens);

            swapping = false;
        }

        if (_pendingJackpotBalance >= jackpotHardLimit) {
            processBigBang();
        } else if (shouldAwardJackpot()) {
            awardJackpot();
        }

        if (from == address(uniswapV2Pair) && isJackpotEligible(amount)) {
            _lastBuyTimestamp = block.timestamp;
            _lastBuyer = to;
            _lastBuyBUSDValue = getBUSDValue(amount);
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if (
            takeFee &&
            (automatedMarketMakerPairs[from] || automatedMarketMakerPairs[to])
        ) {
            uint256 totalFeesTokens = amount.mul(totalFees).div(
                FEE_DENOMINATOR
            );
            _jackpotTokens = _jackpotTokens.add(
                totalFeesTokens.mul(jackpotFee).div(totalFees)
            );
            uint256 burnTokens = totalFeesTokens.mul(burnFee).div(totalFees);
            super._burn(from, burnTokens);
            amount = amount.sub(totalFeesTokens);
            super._transfer(
                from,
                address(this),
                totalFeesTokens.sub(burnTokens)
            );
        }

        super._transfer(from, to, amount);

        try
            dividendTracker.setBalance(payable(from), balanceOf(from))
        {} catch {}
        try dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}

        if (!swapping) {
            uint256 gas = gasForProcessing;

            try dividendTracker.process(gas) returns (
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
                    tx.origin
                );
            } catch {}
        }
    }

    function swapAndLiquify(uint256 tokens) private {
        // split the contract balance into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = IERC20(BUSD).balanceOf(address(this));

        // swap tokens for ETH
        swapTokensForTokens(half, BUSD); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much BUSD did we just swap into?
        uint256 newBalance = IERC20(BUSD).balanceOf(address(this)).sub(
            initialBalance
        );

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForTokens(uint256 tokenAmount, address tokenOut)
        private
    {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = BUSD;
        path[2] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uint256 wethBalanceBefore = IERC20(uniswapV2Router.WETH()).balanceOf(
            address(this)
        );
        // make the swap to WETH
        uniswapV2Router.swapExactTokensForTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
        uint256 wethSwapAmount = IERC20(uniswapV2Router.WETH())
            .balanceOf(address(this))
            .sub(wethBalanceBefore);
        /// swap to BUSD
        address[] memory path1 = new address[](2);
        path1[0] = uniswapV2Router.WETH();
        path1[1] = tokenOut;
        IERC20(uniswapV2Router.WETH()).approve(
            address(uniswapV2Router),
            wethSwapAmount
        );
        uniswapV2Router.swapExactTokensForTokens(
            wethSwapAmount,
            0,
            path1,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 busdAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        IERC20(BUSD).approve(address(uniswapV2Router), busdAmount);

        // add the liquidity
        uniswapV2Router.addLiquidity(
            address(this),
            BUSD,
            tokenAmount,
            busdAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );
    }

    function swapAndSendDividends(uint256 tokens) private {
        uint256 cakeBalanceBefore = IERC20(rewardToken).balanceOf(
            address(this)
        );
        swapTokensForTokens(tokens, address(rewardToken));
        uint256 cakeBalanceAfter = IERC20(rewardToken).balanceOf(address(this));
        uint256 dividends = cakeBalanceAfter.sub(cakeBalanceBefore);
        bool success = IERC20(rewardToken).transfer(
            address(dividendTracker),
            dividends
        );

        if (success) {
            dividendTracker.distributeCAKEDividends(dividends);
            emit SendDividends(tokens, dividends);
        }
    }

    function burn(uint256 amount) public {
        require(
            balanceOf(msg.sender) >= amount,
            "ERC20: burn: insufficient balance"
        );
        super._burn(msg.sender, amount);
        try
            dividendTracker.setBalance(
                payable(msg.sender),
                balanceOf(msg.sender)
            )
        {} catch {}
    }

    receive() external payable {}
}