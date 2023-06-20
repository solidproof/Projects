// Submitted for verification at BscScan.com on 2023-xx-xx
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IDividendDistributor {
    function setShare(
        address _shareholder,
        uint256 _amountNew,
        bool _processPool1Active,
        bool _processPool2Active,
        uint256 _payoutPool1ShareholderCount,
        uint256 _payoutPool2ShareholderCount
        ) external;

    function transferTokenFromPool2ToPool1(
        address _pool1Token,
        address _poolDistributorAddress,
        address _pool1Wallet
        ) external;

    function processPool1(
        uint256 _gas,
        address _processPool1Token,
        uint256 _payoutPool1CurrentTokenAmount,
        uint256 _payoutPool1ShareholderCount,
        address _poolDistributorAddress,
        uint256 _payoutPool1DividendsPerShare
        ) external;

    function processPool2(
        uint256 _gas,
        uint256 _payoutPool2ShareholderCount,
        uint256 _payoutPool2DividendsPerShare
        ) external;
}

contract CommunityInvestmentFundContract is ERC20, Ownable {
    using SafeMath for uint256;

    ERC20 internal WBNB = ERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c); /* main chain */
    uint256 public constant MAX_FEE = 5;
    uint8 private constant _decimals = 18;

    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public liquidityWallet;
    address public marketingWallet = address(0xf2db82c24246c45140083524B7237942E42b2c3E);
    address public pool1Wallet = address(0x76d8930a2753Bb1011B50db3B0104Ee37118eB91);
    DividendDistributor internal poolDistributor;
    address public poolDistributorAddress;
    address public processPool1Token;

    mapping (address => bool) private excludedFromFees;
    mapping (address => bool) private excludedFromDividends;
    mapping (address => bool) public canTransferBeforeTradingIsEnabled;
    mapping (address => bool) public automatedMarketMakerPairs;

    bool public tradingIsEnabled = false;
    bool public isOnlyTradeFee = true;

    uint256 public payoutGas = 500000;
    uint256 public swapFeeTokensMinAmount = 10000 * (10**18);
    bool private feesSwapping;

    uint256 public payoutPool1CurrentTokenAmount;
    uint256 public processPool1StartTime;
    bool public processPool1Trigger;
    bool public processPool1Active;

    uint256 public payoutPool2MinAmountWBNB = 5 * (10**18);
    uint256 public payoutPool2Percent = 20;
    uint256 public pool2BalanceWBNB;
    uint256 public payoutPool2CurrentWBNB;
    bool public isSaveParameterForPayout = true;
    bool public processPool2Active;

    uint256 public payoutPool1ShareholderCount;
    uint256 public payoutPool2ShareholderCount;
    uint256 public payoutPool1DividendsPerShare;
    uint256 public payoutPool2DividendsPerShare;
    uint256 public totalSharesAtCurrentPayoutPool1;
    uint256 public totalSharesAtCurrentPayoutPool2;

    uint256 public buyLiquidityFee = 2;
    uint256 public buyMarketingFee = 1;
    uint256 public buyPool1Fee = 5;
    uint256 public buyPool2Fee = 2;
    uint256 public buyPool3Fee = 0;
    uint256 public sellLiquidityFee = 0;
    uint256 public sellMarketingFee = 0;
    uint256 public sellPool1Fee = 5;
    uint256 public sellPool2Fee = 0;
    uint256 public sellPool3Fee = 5;
    uint256 public txLiquidityFee = 0;
    uint256 public txMarketingFee = 0;
    uint256 public txPool1Fee = 0;
    uint256 public txPool2Fee = 0;
    uint256 public txPool3Fee = 0;
    uint256 private collectedAmountLiquidityFee;
    uint256 private collectedAmountMarketingFee;
    uint256 private collectedAmountPool1Fee;
    uint256 private collectedAmountPool2Fee;
    uint256 private collectedAmountPool3Fee;
    uint256 private collectedAmountPool3FeeOld;

    event isExcludeFromDividends(address indexed account, bool isExcluded);
    event UpdateDividendDistributor(address indexed newAddress, address indexed oldAddress);
    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);
    event MarketingWalletUpdated(address indexed newMarketingWallet, address indexed oldMarketingWallet);
    event Pool1WalletUpdated(address indexed newPool1Wallet, address indexed oldPool1Wallet);
    event SetSwapFeeTokensMinAmount(uint256 newSwapFeeTokensMinAmount);
    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event PayoutGasUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event PayoutPool2PercentUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event PayoutPool2MinAmountWBNBUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event LaunchExecuted(bool newStatus);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    

    constructor() ERC20("CommunityInvestmentFund", "COIF"){
        poolDistributor = new DividendDistributor();
        poolDistributorAddress = address(poolDistributor);

        liquidityWallet = owner();

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); /* main chain */

        /*  _mint is an internal function in ERC20.sol that is only called here, and CANNOT be called ever again, _totalSupply = 100_000_000 * (10**_decimals) */
        _mint(owner(), 100_000_000 * (10**_decimals));

        approve(address(_uniswapV2Router), totalSupply());

        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        approve(_uniswapV2Pair, totalSupply());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        excludedFromDividends[poolDistributorAddress] = true;
        excludedFromDividends[address(_uniswapV2Pair)] = true;
        excludedFromDividends[address(_uniswapV2Router)] = true;
        excludedFromDividends[address(this)] = true;

        excludeFromFees(liquidityWallet, true);
        excludeFromFees(marketingWallet, true);
        excludeFromFees(pool1Wallet, true);
        excludeFromFees(poolDistributor.pool3Wallet(), true);
        excludeFromFees(poolDistributor.ecosystemWallet(), true);
        excludeFromFees(address(this), true);

        canTransferBeforeTradingIsEnabled[owner()] = true;
    }

    receive() external payable { }

    function updateDividendDistributor(address _newAddress) public onlyOwner {
        require(_newAddress != address(0), "Error: Address cannot be zero");
        require(_newAddress != address(poolDistributor), "Error: Dividend distributor already has that address");
        DividendDistributor newPoolDistributor = DividendDistributor(payable(_newAddress));
        require(newPoolDistributor.owner() == address(this), "Error: The new dividend distributor must be owned by the token contract");

        emit UpdateDividendDistributor(_newAddress, poolDistributorAddress);
        poolDistributor = newPoolDistributor;
        poolDistributorAddress = address(poolDistributor);
        excludedFromDividends[poolDistributorAddress] = true;
    }

    function setLiquidityWallet(address _newLiquidityWallet) public onlyOwner {
        require(_newLiquidityWallet != address(0), "Error: Address cannot be zero");
        require(_newLiquidityWallet != liquidityWallet, "Error: The liquidityWallet is already this address");
        excludeFromFees(_newLiquidityWallet, true);
        emit LiquidityWalletUpdated(_newLiquidityWallet, liquidityWallet);
        liquidityWallet = _newLiquidityWallet;
    }

    function setMarketingWallet(address _newMarketingWallet) public onlyOwner {
        require(_newMarketingWallet != address(0), "Error: Address cannot be zero");
        require(_newMarketingWallet != marketingWallet, "Error: The marketingWallet is already this address");
        excludeFromFees(_newMarketingWallet, true);
        emit MarketingWalletUpdated(_newMarketingWallet, marketingWallet);
        marketingWallet = _newMarketingWallet;
    }

    function setPool1Wallet(address _newPool1Wallet) public onlyOwner {
        require(_newPool1Wallet != address(0), "Error: Address cannot be zero");
        require(_newPool1Wallet != pool1Wallet, "Error: The pool1Wallet is already this address");
        excludeFromFees(_newPool1Wallet, true);
        emit Pool1WalletUpdated(_newPool1Wallet, pool1Wallet);
        pool1Wallet = _newPool1Wallet;
    }

    function setPool3Wallet(address _newPool3Wallet) public onlyOwner {
        require(_newPool3Wallet != address(0), "Error: Address cannot be zero");
        poolDistributor.updatePool3Wallet(_newPool3Wallet);
        excludeFromFees(_newPool3Wallet, true);
    }

    function setPool3BurnAddress(address _newPool3BurnAddress) public onlyOwner {
        require(_newPool3BurnAddress != address(0), "Error: Address cannot be zero");
        poolDistributor.updatePool3BurnAddress(_newPool3BurnAddress);
    }

    function setTeamWallet(address _newTeamWallet) public onlyOwner {
        require(_newTeamWallet != address(0), "Error: Address cannot be zero");
        poolDistributor.updateTeamWallet(_newTeamWallet);
    }

    function setLongTermGrowthWallet(address _newLongTermGrowthWallet) public onlyOwner {
        require(_newLongTermGrowthWallet != address(0), "Error: Address cannot be zero");
        poolDistributor.updateLongTermGrowthWallet(_newLongTermGrowthWallet);
    }

    function setEcosystemWallet(address _newEcosystemWallet) public onlyOwner {
        require(_newEcosystemWallet != address(0), "Error: Address cannot be zero");
        poolDistributor.updateEcosystemWallet(_newEcosystemWallet);
    }

    function setTeamLockAddress(address _newTeamLockAddress) public onlyOwner {
        require(_newTeamLockAddress != address(0), "Error: Address cannot be zero");
        poolDistributor.updateTeamLockAddress(_newTeamLockAddress);
    }

    function setLongTermGrowthLockAddress(address _newLongTermGrowthLockAddress) public onlyOwner {
        require(_newLongTermGrowthLockAddress != address(0), "Error: Address cannot be zero");
        poolDistributor.updateLongTermGrowthLockAddress(_newLongTermGrowthLockAddress);
    }

    function setEcosystemLockAddress(address _newEcosystemLockAddress) public onlyOwner {
        require(_newEcosystemLockAddress != address(0), "Error: Address cannot be zero");
        poolDistributor.updateEcosystemLockAddress(_newEcosystemLockAddress);
    }

    function setSwapFeeTokensMinAmount(uint256 _swapMinAmount) public onlyOwner {
        require(_swapMinAmount <= (10**18), "Error: use the value without 10**18, e.g. 10000 for 10000 tokens");
        swapFeeTokensMinAmount = _swapMinAmount.mul(10**18);
        emit SetSwapFeeTokensMinAmount(swapFeeTokensMinAmount);
    }

    function updateUniswapV2Router(address _newAddress) public onlyOwner {
        require(_newAddress != address(uniswapV2Router), "Error: The router already has that address");
        emit UpdateUniswapV2Router(_newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(_newAddress);
        excludeFromDividends(_newAddress,true);
    }

    function excludeFromFees(address _account, bool _excluded) public onlyOwner {
        excludedFromFees[_account] = _excluded;
        emit ExcludeFromFees(_account, _excluded);
    }

    function isExcludedFromFees(address _account) public view returns(bool) {
        return excludedFromFees[_account];
    }

    function excludeMultipleAccountsFromFees(address[] calldata _accounts, bool _excluded) public onlyOwner {
        for(uint256 i = 0; i < _accounts.length; i++) {
            excludedFromFees[_accounts[i]] = _excluded;
        }
        emit ExcludeMultipleAccountsFromFees(_accounts, _excluded);
    }

    function setAutomatedMarketMakerPair(address _pair, bool _value) public onlyOwner {
        require(_pair != uniswapV2Pair, "Error: The PancakeSwap V2 pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(_pair, _value);
    }

    function _setAutomatedMarketMakerPair(address _pair, bool _value) private {
        require(automatedMarketMakerPairs[_pair] != _value, "Error: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[_pair] = _value;

        if(_value) {
            excludeFromDividends(_pair,true);
        }
        emit SetAutomatedMarketMakerPair(_pair, _value);
    }

    function excludeFromDividends(address _account, bool _excluded) public onlyOwner {
    	require(_account != address(this), "Token contract is excluded from dividends, it cannot be changed");
        excludedFromDividends[_account] = _excluded;

        if(_excluded){
            poolDistributor.setShare(_account, 0, processPool1Active, processPool2Active, payoutPool1ShareholderCount, payoutPool2ShareholderCount);
        }else{
            poolDistributor.setShare(_account, balanceOf(_account), processPool1Active, processPool2Active, payoutPool1ShareholderCount, payoutPool2ShareholderCount);
        }
        emit isExcludeFromDividends(_account,_excluded);
    }

    function isExcludedFromDividends(address _account) public view returns(bool) {
        return excludedFromDividends[_account];
    }

    function updateBuyFees(
        uint8 _newBuyLiquidityFee,
        uint8 _newBuyMarketingFee,
        uint8 _newBuyPool1Fee,
        uint8 _newBuyPool2Fee,
        uint8 _newBuyPool3Fee) public onlyOwner {
        require(
            (_newBuyLiquidityFee <= MAX_FEE)&&
            (_newBuyMarketingFee <= MAX_FEE)&&
            (_newBuyPool1Fee <= MAX_FEE)&&
            (_newBuyPool2Fee <= MAX_FEE)&&
            (_newBuyPool3Fee <= MAX_FEE), "Error: new desired fee over max limit");
        buyLiquidityFee = _newBuyLiquidityFee;
        buyMarketingFee = _newBuyMarketingFee;
        buyPool1Fee = _newBuyPool1Fee;
        buyPool2Fee = _newBuyPool2Fee;
        buyPool3Fee = _newBuyPool3Fee;
    }

    function updateSellFees(
        uint8 _newSellLiquidityFee,
        uint8 _newSellMarketingFee,
        uint8 _newSellPool1Fee,
        uint8 _newSellPool2Fee,
        uint8 _newSellPool3Fee) public onlyOwner {
        require(
            (_newSellLiquidityFee <= MAX_FEE)&&
            (_newSellMarketingFee <= MAX_FEE)&&
            (_newSellPool1Fee <= MAX_FEE)&&
            (_newSellPool2Fee <= MAX_FEE)&&
            (_newSellPool3Fee <= MAX_FEE), "Error: new desired fee over max limit");
        sellLiquidityFee = _newSellLiquidityFee;
        sellMarketingFee = _newSellMarketingFee;
        sellPool1Fee = _newSellPool1Fee;
        sellPool2Fee = _newSellPool2Fee;
        sellPool3Fee = _newSellPool3Fee;
    }

    function updateTxFees(
        uint8 _newTxLiquidityFee,
        uint8 _newTxMarketingFee,
        uint8 _newTxPool1Fee,
        uint8 _newTxPool2Fee,
        uint8 _newTxPool3Fee) public onlyOwner {
        require(
            (_newTxLiquidityFee <= MAX_FEE)&&
            (_newTxMarketingFee <= MAX_FEE)&&
            (_newTxPool1Fee <= MAX_FEE)&&
            (_newTxPool2Fee <= MAX_FEE)&&
            (_newTxPool3Fee <= MAX_FEE), "Error: new desired fee over max limit");
        txLiquidityFee = _newTxLiquidityFee;
        txMarketingFee = _newTxMarketingFee;
        txPool1Fee = _newTxPool1Fee;
        txPool2Fee = _newTxPool2Fee;
        txPool3Fee = _newTxPool3Fee;
    }

    function setTradeFeeStatus(bool _status) public onlyOwner {
        require(isOnlyTradeFee != _status, "Error: isOnlyTradeFee already has the value _status");
        isOnlyTradeFee = _status;
    }

    function setPayoutGas(uint256 _gas) public onlyOwner {
        require(_gas < 750000, "Error: gas must be under 750000");
        require(_gas != payoutGas, "Error: Cannot update payoutGas to the same value");
        emit PayoutGasUpdated(_gas, payoutGas);
        payoutGas = _gas;
    }

    function setPayoutPool2Percent(uint256 _payoutPool2Percent) public onlyOwner {
        require(_payoutPool2Percent <= 100, "Error: payoutPool2Percent has to be <= 100");
        require(payoutPool2Percent != _payoutPool2Percent, "Error: Cannot update payoutPool2Percent to the same value");
        require(!processPool2Active, "Error: process pool2 payout is active, wait till end");
        poolDistributor.updatePayoutPool2TimeNext();
        emit PayoutPool2PercentUpdated(_payoutPool2Percent, payoutPool2Percent);
        payoutPool2Percent = _payoutPool2Percent;
    }

    function setPayoutPool2MinAmountWBNB(uint256 _payoutPool2MinAmountWBNB) public onlyOwner {
        require(_payoutPool2MinAmountWBNB <= (10**18), "Error: use the value without 10**18, e.g. 5 for 5 BNB");
        require(!processPool2Active, "Error: process pool2 payout is active, wait till end");
        poolDistributor.updatePayoutPool2TimeNext();
        emit PayoutPool2MinAmountWBNBUpdated(_payoutPool2MinAmountWBNB, payoutPool2MinAmountWBNB.div(10**18));
        payoutPool2MinAmountWBNB = _payoutPool2MinAmountWBNB.mul(10**18);
    }

    function setMinimumBalanceForDividends(uint256 _newMinimumBalance) public onlyOwner {
        require((!processPool1Active && !processPool2Active), "Error: process pool1 payout or pool2 payout is active, wait till end");
        poolDistributor.updateMinimumTokenBalanceForDividends(_newMinimumBalance);
    }

    function setPayoutPool2FrequencySec(uint256 _newPayoutPool2FrequencySec) public onlyOwner {
        require(!processPool2Active, "Error: process pool2 payout is active, wait till end");
        poolDistributor.updatePayoutPool2FrequencySec(_newPayoutPool2FrequencySec);
    }

    function triggerPool1Payout(address _token, uint256 _startTime) public onlyOwner {
        require(!processPool1Active, "Pool 1 payout already active, wait till end");
        require(ERC20(_token).balanceOf(poolDistributorAddress)>0, "First transfer tokens for payout from pool1 to poolDistributorAddress");
        processPool1Trigger = true;
        processPool1Token = address(_token);
        processPool1StartTime = _startTime;
    }

    function getCurrentInfoAboutPool1() public view returns (
        bool processPool1Trigger_,
        bool processPool1Active_,
        bool payoutPool1ProcessFinished_,
        address processPool1Token_,
        uint256 processPool1StartTime_,
        uint256 payoutPool1CurrentTokenAmount_,
        uint256 payoutPool1DividendsPerShare_,
        uint256 totalSharesAtCurrentPayoutPool1_,
        uint256 payoutPool1ShareholderCount_,
        uint256 currentIndexPool1_ ) {
        processPool1Trigger_ = processPool1Trigger;
        processPool1Active_ = processPool1Active;
        payoutPool1ProcessFinished_ = poolDistributor.payoutPool1ProcessFinished();
        processPool1Token_ = processPool1Token;
        processPool1StartTime_ = processPool1StartTime;
        payoutPool1CurrentTokenAmount_ = payoutPool1CurrentTokenAmount;
        payoutPool1DividendsPerShare_ = payoutPool1DividendsPerShare;
        totalSharesAtCurrentPayoutPool1_ = totalSharesAtCurrentPayoutPool1;
        payoutPool1ShareholderCount_ = payoutPool1ShareholderCount;
        currentIndexPool1_ = poolDistributor.currentIndexPool1();
    }

    function getCurrentInfoAboutPool2() public view returns (
        bool processPool2Active_,
        bool payoutPool2ProcessFinished_,
        bool isSaveParameterForPayout_,
        uint256 payoutPool2MinAmountWBNB_,
        uint256 pool2BalanceWBNB_,
        uint256 payoutPool2CurrentWBNB_,
        uint256 payoutPool2DividendsPerShare_,
        uint256 totalSharesAtCurrentPayoutPool2_,
        uint256 payoutPool2ShareholderCount_,
        uint256 currentIndexPool2_,
        uint256 payoutPool2Time_,
        uint256 payoutPool2TimeNext_,
        uint256 secondsUntilNextPayout_) {
        processPool2Active_ = processPool2Active;
        payoutPool2ProcessFinished_ = poolDistributor.payoutPool2ProcessFinished();
        isSaveParameterForPayout_ = isSaveParameterForPayout;
        payoutPool2MinAmountWBNB_ = payoutPool2MinAmountWBNB;
        pool2BalanceWBNB_ = pool2BalanceWBNB;
        payoutPool2CurrentWBNB_ = payoutPool2CurrentWBNB;
        payoutPool2DividendsPerShare_ = payoutPool2DividendsPerShare;
        totalSharesAtCurrentPayoutPool2_ = totalSharesAtCurrentPayoutPool2;
        payoutPool2ShareholderCount_ = payoutPool2ShareholderCount;
        currentIndexPool2_ = poolDistributor.currentIndexPool2();
        (payoutPool2Time_, payoutPool2TimeNext_, secondsUntilNextPayout_) = poolDistributor.getInfoAboutPool2();
    }

    function getAccountDividendsInfoForPool2(address _account)
        public view returns (
            address account_,
            int256 index_,
            uint256 lastPayoutTimePool2_,
            uint256 sharesAmount_,
            uint256 sharesAmountExcludedPool2_,
            uint256 withdrawnDividendsPool2WBNB_,
            uint256 unpaidDividendsFromPool2_) {
        require(!processPool2Active, "Error: process pool2 payout is active, wait till end");
        return poolDistributor.getAccountInfoForPool2(_account, poolDistributorAddress);
    }

	function getAccountDividendsInfoForPool2AtIndex(uint256 _index)
        public view returns (
            address account_,
            int256 index_,
            uint256 lastPayoutTimePool2_,
            uint256 sharesAmount_,
            uint256 sharesAmountExcludedPool2_,
            uint256 withdrawnDividendsPool2WBNB_,
            uint256 unpaidDividendsFromPool2_) {
        require(!processPool2Active, "Error: process pool2 payout is active, wait till end");
    	return poolDistributor.getAccountInfoForPool2AtIndex(_index, poolDistributorAddress);
    }

    function launch() public onlyOwner {
  	 require(!tradingIsEnabled, "Error: Lauch already executed and trading is already enabled");
	  tradingIsEnabled = true;
      emit LaunchExecuted(tradingIsEnabled);
      poolDistributor.updatePayoutPool2TimeNext();
  	}

    function setCanTransferBeforeTradingIsEnabled(address _wallet, bool _enabled) public onlyOwner {
        excludeFromDividends(_wallet, _enabled);
        excludeFromFees(_wallet, _enabled);
        canTransferBeforeTradingIsEnabled[_wallet] = _enabled;
    }

    function transferERC20TokenFromPool2ToPool1(address _pool1Token) public onlyOwner {
        poolDistributor.transferTokenFromPool2ToPool1(_pool1Token, poolDistributorAddress, pool1Wallet);
    }

    function transferERC20TokenFromContractAddressToPool1(address _tokenERC20) public onlyOwner {
            ERC20 tokenERC20 = ERC20(_tokenERC20);
            uint256 amount = tokenERC20.balanceOf(address(this));
            tokenERC20.transfer(pool1Wallet, amount);
    }

    function transferBNBFromContractAddressToPool1() public onlyOwner {
            address payable pool1WalletBNB = payable(pool1Wallet);
            pool1WalletBNB.transfer(address(this).balance);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "Error: transfer from the zero address");
        require(to != address(0), "Error: transfer to the zero address");
        require(amount > 0, "Error: Transfer amount must be greater than zero");

        if(!tradingIsEnabled) {
            require(canTransferBeforeTradingIsEnabled[from], "Error: This account cannot send tokens until trading is enabled");
        }

        if(
            tradingIsEnabled &&
            (balanceOf(address(this))>=swapFeeTokensMinAmount) &&
            !feesSwapping &&
            !automatedMarketMakerPairs[from] &&
            !excludedFromFees[from] &&
            !excludedFromFees[to]
        ) {
            feesSwapping = true;
            distributeCollectedFees(
                collectedAmountLiquidityFee,
                collectedAmountMarketingFee,
                collectedAmountPool1Fee,
                collectedAmountPool2Fee,
                collectedAmountPool3Fee
            );
            feesSwapping = false;
        }

        bool takeFee = tradingIsEnabled;
        if(excludedFromFees[from] || excludedFromFees[to]) {
            takeFee = false;
        } else if(isOnlyTradeFee && !automatedMarketMakerPairs[from] && !automatedMarketMakerPairs[to]) {
            takeFee = false;
            } else if(automatedMarketMakerPairs[from] && (to == address(uniswapV2Router)) ) {
                takeFee = false;
            }

        if(takeFee) {
            uint256 liquidityFee;
            uint256 marketingFee;
            uint256 pool1Fee;
            uint256 pool2Fee;
            uint256 pool3Fee;
            uint256 finalFee;
            if (!automatedMarketMakerPairs[from] && !automatedMarketMakerPairs[to]) {
                liquidityFee = amount.mul(txLiquidityFee).div(100);
                marketingFee = amount.mul(txMarketingFee).div(100);
                pool1Fee = amount.mul(txPool1Fee).div(100);
                pool2Fee = amount.mul(txPool2Fee).div(100);
                pool3Fee = amount.mul(txPool3Fee).div(100);
            } else {
                bool isSell = automatedMarketMakerPairs[to] ? true : false;

                liquidityFee = isSell ? amount.mul(sellLiquidityFee).div(100) : amount.mul(buyLiquidityFee).div(100);
                marketingFee = isSell ? amount.mul(sellMarketingFee).div(100) : amount.mul(buyMarketingFee).div(100);
                pool1Fee = isSell ? amount.mul(sellPool1Fee).div(100) : amount.mul(buyPool1Fee).div(100);
                pool2Fee = isSell ? amount.mul(sellPool2Fee).div(100) : amount.mul(buyPool2Fee).div(100);
                pool3Fee = isSell ? amount.mul(sellPool3Fee).div(100) : amount.mul(buyPool3Fee).div(100);
            }
            finalFee = liquidityFee.add(marketingFee).add(pool1Fee).add(pool2Fee).add(pool3Fee);

            collectedAmountLiquidityFee = collectedAmountLiquidityFee.add(liquidityFee);
            collectedAmountMarketingFee = collectedAmountMarketingFee.add(marketingFee);
            collectedAmountPool1Fee = collectedAmountPool1Fee.add(pool1Fee);
            collectedAmountPool2Fee = collectedAmountPool2Fee.add(pool2Fee);
            collectedAmountPool3Fee = collectedAmountPool3Fee.add(pool3Fee);
        	amount = amount.sub(finalFee);
            super._transfer(from, address(this), finalFee);
        }
        super._transfer(from, to, amount);

        if(!excludedFromDividends[from]){ try poolDistributor.setShare(from, balanceOf(from), processPool1Active, processPool2Active, payoutPool1ShareholderCount, payoutPool2ShareholderCount) {} catch {} }
        if(!excludedFromDividends[to]){ try poolDistributor.setShare(to, balanceOf(to), processPool1Active, processPool2Active, payoutPool1ShareholderCount, payoutPool2ShareholderCount) {} catch {} }

        if (processPool2Active){
            try poolDistributor.processPool2(payoutGas, payoutPool2ShareholderCount, payoutPool2DividendsPerShare) {} catch {}
            if (poolDistributor.payoutPool2ProcessFinished()) {
                isSaveParameterForPayout = true;
                processPool2Active = false;
            }
        } else {
            if (processPool1Active) {
                try poolDistributor.processPool1(payoutGas,
                                                processPool1Token,
                                                payoutPool1CurrentTokenAmount,
                                                payoutPool1ShareholderCount,
                                                poolDistributorAddress,
                                                payoutPool1DividendsPerShare) {} catch {}

                if(poolDistributor.payoutPool1ProcessFinished()) {
                    processPool1Active = false;
                }
            } else {
                if (processPool1Trigger && (block.timestamp >= processPool1StartTime)) {
                    payoutPool1ShareholderCount = poolDistributor.getNumberOfTokenHolders();
                    payoutPool1CurrentTokenAmount = ERC20(processPool1Token).balanceOf(poolDistributorAddress);
                    payoutPool1DividendsPerShare = payoutPool1CurrentTokenAmount.mul(poolDistributor.dividendsPerShareAccuracyFactor()).div(poolDistributor.totalShares());
                    totalSharesAtCurrentPayoutPool1 = poolDistributor.totalShares();
                    processPool1Active = true;
                    processPool1Trigger = false;
                } else {
                    if (block.timestamp > poolDistributor.payoutPool2TimeNext()){
                        pool2BalanceWBNB = WBNB.balanceOf(poolDistributorAddress);
                        if (((pool2BalanceWBNB) > payoutPool2MinAmountWBNB) && (isSaveParameterForPayout)){
                            payoutPool2CurrentWBNB = pool2BalanceWBNB.mul(payoutPool2Percent).div(100);
                            payoutPool2ShareholderCount = poolDistributor.getNumberOfTokenHolders();
                            payoutPool2DividendsPerShare = payoutPool2CurrentWBNB.mul(poolDistributor.dividendsPerShareAccuracyFactor()).div(poolDistributor.totalShares());
                            totalSharesAtCurrentPayoutPool2 = poolDistributor.totalShares();
                            isSaveParameterForPayout = false;
                            processPool2Active = true;
                        }
                    }
                }
            }
        }
    }

    function distributeCollectedFees(
        uint256 _collectedAmountLiquidityFee,
        uint256 _collectedAmountMarketingFee,
        uint256 _collectedAmountPool1Fee,
        uint256 _collectedAmountPool2Fee,
        uint256 _collectedAmountPool3Fee
        ) private {
        uint256 _collectedAmountLiquidityFeeDist = _collectedAmountLiquidityFee;
        uint256 _collectedAmountMarketingFeeDist = _collectedAmountMarketingFee;
        uint256 _collectedAmountPool1FeeDist = _collectedAmountPool1Fee;
        uint256 _collectedAmountPool2FeeDist = _collectedAmountPool2Fee;
        uint256 _collectedAmountPool3FeeDist = _collectedAmountPool3Fee;

        if(_collectedAmountLiquidityFeeDist > 0) {
            swapAndLiquify(_collectedAmountLiquidityFeeDist);
        }

        if(_collectedAmountMarketingFeeDist > 0) {

            swapAndSendFeeWBNB(_collectedAmountMarketingFeeDist, marketingWallet);
        }

        if(_collectedAmountPool1FeeDist > 0) {
            swapAndSendFeeWBNB(_collectedAmountPool1FeeDist, pool1Wallet);
        }

        if(_collectedAmountPool2FeeDist > 0) {
            swapAndSendFeeWBNB(_collectedAmountPool2FeeDist, poolDistributorAddress);
        }

        uint256 restTokens = balanceOf(address(this));
        if(restTokens > 0) {
            super._transfer(address(this), poolDistributor.pool3BurnAddress(), restTokens);
            if(!excludedFromDividends[poolDistributor.pool3BurnAddress()]) {
                try poolDistributor.setShare(poolDistributor.pool3BurnAddress(),
                                            balanceOf(poolDistributor.pool3BurnAddress()),
                                            processPool1Active,
                                            processPool2Active,
                                            payoutPool1ShareholderCount,
                                            payoutPool2ShareholderCount) {} catch {}
            }
        }
        collectedAmountLiquidityFee = 0;
        collectedAmountMarketingFee = 0;
        collectedAmountPool1Fee = 0;
        collectedAmountPool2Fee = 0;
        collectedAmountPool3FeeOld = _collectedAmountPool3FeeDist;
        collectedAmountPool3Fee = 0;
    }

    function swapAndLiquify(uint256 _tokens) private {
        uint256 half = _tokens.div(2);
        uint256 otherHalf = _tokens.sub(half);
        uint256 initialBalance = address(this).balance;

        swapTokensForBNB(half);

        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForBNB(uint256 _tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), _tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapAndSendFeeWBNB(uint256 _tokenAmount, address _to) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), _tokenAmount);

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokenAmount,
            0,
            path,
            _to,
            block.timestamp
        );
    }

    function addLiquidity(uint256 _tokenAmount, uint256 _bnbAmount) private {
        _approve(address(this), address(uniswapV2Router), _tokenAmount);

        (uint256 amountToken, uint256 amountETH, ) = uniswapV2Router.addLiquidityETH{value: _bnbAmount}(
            address(this),
            _tokenAmount,
            0,
            0,
            liquidityWallet,
            block.timestamp
        );
        require(amountToken > 0 && amountETH > 0, "Failed to add liquidity");
    }

    function getCollectedFeeAmounts() public view returns (
        uint256 collectedAmountLiquidityFee_,
        uint256 collectedAmountMarketingFee_,
        uint256 collectedAmountPool1Fee_,
        uint256 collectedAmountPool2Fee_,
        uint256 collectedAmountPool3Fee_,
        uint256 collectedAmountPool3FeeOld_) {
        collectedAmountLiquidityFee_ = collectedAmountLiquidityFee;
        collectedAmountMarketingFee_ = collectedAmountMarketingFee;
        collectedAmountPool1Fee_ = collectedAmountPool1Fee;
        collectedAmountPool2Fee_ = collectedAmountPool2Fee;
        collectedAmountPool3Fee_ = collectedAmountPool3Fee;
        collectedAmountPool3FeeOld_ = collectedAmountPool3FeeOld;
    }
}

contract DividendDistributor is IDividendDistributor, Ownable {
    using SafeMath for uint256;

    struct Share {
        uint256 amount;
        uint256 amountExcludedBuyPool1;
        uint256 amountExcludedBuyPool2;
        uint256 withdrawnDividendsWBNB;
    }

    ERC20 internal WBNB = ERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c); /* main chain */

    address public pool3Wallet = address(0x6a06D4C3799D050A2F1d286c526adF28276Ebe8D);
    address public pool3BurnAddress;
    address public teamWallet = address(0x0ceF20D3955b63cDcDc566F1cCa698C8E2189425);
    address public longTermGrowthWallet = address(0x521e0823E6905ca6BE44797De7679AC007B4F1Ed);
    address public ecosystemWallet = address(0x5bFc6665c6397ca4bFdee5D4f4806B75ec64807a);
    address public teamLockAddress;
    address public longTermGrowthLockAddress;
    address public ecosystemLockAddress;

    address[] internal shareholders;
    address[] internal payoutPool1Tokens;
    mapping (address => uint256) payoutPool1TokensIndexes;
    mapping (address => uint256) payoutPool1TokensAmount;
    mapping (address => Share) public shares;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderPayoutTimePool1;
    mapping (address => uint256) shareholderPayoutTimePool2;

    uint256 public totalShares;
    uint256 public dividendsPerShareAccuracyFactor;
    uint256 public totalDistributedWBNB;
    uint256 internal payoutPool2Time;
    uint256 public payoutPool2TimeNext;
    uint256 public payoutPool2FrequencySec;
    bool public payoutPool1ProcessFinished = true;
    bool public payoutPool2ProcessFinished = true;
    uint256 public minimumTokenBalanceForDividends;
    uint256 public currentIndexPool1;
    uint256 public currentIndexPool2;

    event PayoutPool2FrequencySecUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event Pool3WalletUpdated(address indexed newPool3Wallet, address indexed oldPool3Wallet);
    event Pool3BurnAddressUpdated(address indexed newPool3BurnAddress, address indexed oldPool3BurnAddress);
    event TeamWalletUpdated(address indexed newTeamWallet, address indexed oldTeamWallet);
    event LongTermGrowthWalletUpdated(address indexed newLongTermGrowthWallet, address indexed oldLongTermGrowthWallet);
    event EcosystemWalletUpdated(address indexed newEcosystemWallet, address indexed oldEcosystemWallet);
    event TeamLockAddressUpdated(address indexed newTeamLockAddress, address indexed oldTeamLockAddress);
    event LongTermGrowthLockAddressUpdated(address indexed newLongTermGrowthLockAddress, address indexed oldLongTermGrowthLockAddress);
    event EcosystemLockAddressUpdated(address indexed newEcosystemLockAddress, address indexed oldEcosystemLockAddress);

    constructor() {
        minimumTokenBalanceForDividends = 100 * (10**18);
        payoutPool2FrequencySec = 60*60*24*7*2;
        dividendsPerShareAccuracyFactor = 10**36;
    }

    function setShare(
        address _shareholder,
        uint256 _amountNew,
        bool _processPool1Active,
        bool _processPool2Active,
        uint256 _payoutPool1ShareholderCount,
        uint256 _payoutPool2ShareholderCount)
        external override onlyOwner {
        if(_amountNew >= minimumTokenBalanceForDividends){
            if(shares[_shareholder].amount == 0) {
                addShareholder(_shareholder);
            }

            if (_processPool1Active){
                if (shareholderIndexes[_shareholder] < _payoutPool1ShareholderCount) {
                    if (currentIndexPool1 < shareholderIndexes[_shareholder]) {
                        if(shares[_shareholder].amount < _amountNew){
                            shares[_shareholder].amountExcludedBuyPool1 = _amountNew.sub(shares[_shareholder].amount);
                        }
                    }
                }
            }

            if (_processPool2Active){
                if (shareholderIndexes[_shareholder] < _payoutPool2ShareholderCount) {
                    if (currentIndexPool2 < shareholderIndexes[_shareholder]) {
                        if(shares[_shareholder].amount < _amountNew) {
                            shares[_shareholder].amountExcludedBuyPool2 = _amountNew.sub(shares[_shareholder].amount);
                        }
                    }
                }
            }

            totalShares = totalShares.sub(shares[_shareholder].amount).add(_amountNew);
            shares[_shareholder].amount = _amountNew;

        } else {
            if(shares[_shareholder].amount > 0) {
                removeShareholder(_shareholder);
                totalShares = totalShares.sub(shares[_shareholder].amount);
                shares[_shareholder].amount = 0;
            } else {
                /* no changes */
            }
        }
    }

    function addShareholder(address _shareholder) internal {
        shareholderIndexes[_shareholder] = shareholders.length;
        shareholders.push(_shareholder);
    }

    function removeShareholder(address _shareholder) internal {
        shareholders[shareholderIndexes[_shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[_shareholder];
        shareholders.pop();
        delete shareholderIndexes[_shareholder];
        shares[_shareholder].amountExcludedBuyPool1 = 0;
        shares[_shareholder].amountExcludedBuyPool2 = 0;
    }

    function transferTokenFromPool2ToPool1(
        address _pool1Token,
        address _poolDistributorAddress,
        address _pool1Wallet
        ) external override onlyOwner {
            ERC20 pool1TokenERC20 = ERC20(_pool1Token);
            uint256 amount = pool1TokenERC20.balanceOf(_poolDistributorAddress);
            pool1TokenERC20.transfer(_pool1Wallet, amount);
    }

    function processPool1(
        uint256 _gas,
        address _processPool1Token,
        uint256 _payoutPool1CurrentTokenAmount,
        uint256 _payoutPool1ShareholderCount,
        address _poolDistributorAddress,
        uint256 _payoutPool1DividendsPerShare
        ) external override onlyOwner {
        uint256 shareholderCount = shareholders.length;
        if(shareholderCount == 0) { return; }
        if(_payoutPool1ShareholderCount < shareholderCount) {
            shareholderCount = _payoutPool1ShareholderCount;
        }
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;
        ERC20 processPool1TokenERC20 = ERC20(_processPool1Token);

        payoutPool1ProcessFinished = false;

        while(gasUsed < _gas && iterations <= shareholderCount) {
            if(currentIndexPool1 >= shareholderCount){
                currentIndexPool1 = 0;
                payoutPool1ProcessFinished = true;
                if(payoutPool1TokensAmount[_processPool1Token] > 0) {
                    payoutPool1TokensAmount[_processPool1Token] = payoutPool1TokensAmount[_processPool1Token].add(_payoutPool1CurrentTokenAmount.sub(processPool1TokenERC20.balanceOf(_poolDistributorAddress)));
                } else {
                    payoutPool1TokensIndexes[_processPool1Token] = payoutPool1Tokens.length;
                    payoutPool1Tokens.push(_processPool1Token);
                    payoutPool1TokensAmount[_processPool1Token] = _payoutPool1CurrentTokenAmount.sub(processPool1TokenERC20.balanceOf(_poolDistributorAddress));
                }
                return;
            }
            payoutDividendsPool1(
                shareholders[currentIndexPool1],
                _processPool1Token,
                _poolDistributorAddress,
                _payoutPool1DividendsPerShare
                );

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndexPool1++;
            iterations++;
        }
    }

    function processPool2(
        uint256 _gas,
        uint256 _payoutPool2ShareholderCount,
        uint256 _payoutPool2DividendsPerShare
        ) external override onlyOwner {
        uint256 shareholderCount = shareholders.length;
        if(shareholderCount == 0) { return; }
        if(_payoutPool2ShareholderCount < shareholderCount) {
            shareholderCount = _payoutPool2ShareholderCount;
        }
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;
        payoutPool2ProcessFinished = false;

        while(gasUsed < _gas && iterations <= shareholderCount) {
            if(currentIndexPool2 >= shareholderCount){
                currentIndexPool2 = 0;
                payoutPool2Time = block.timestamp;
                payoutPool2TimeNext =  payoutPool2Time + payoutPool2FrequencySec;
                payoutPool2ProcessFinished = true;
                return;
            }

            payoutDividendsPool2(shareholders[currentIndexPool2], _payoutPool2DividendsPerShare);

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndexPool2++;
            iterations++;
        }
    }

    function payoutDividendsPool1(
        address _shareholder,
        address _processPool1Token,
        address _poolDistributorAddress,
        uint256 _payoutPool1DividendsPerShare
        ) internal {
        if(shares[_shareholder].amount == 0){ return; }
        uint256 amount = ((shares[_shareholder].amount).sub(shares[_shareholder].amountExcludedBuyPool1)).mul(_payoutPool1DividendsPerShare).div(dividendsPerShareAccuracyFactor);
        ERC20 processPool1TokenERC20 = ERC20(_processPool1Token);
        if(amount > processPool1TokenERC20.balanceOf(_poolDistributorAddress)) {
            amount = processPool1TokenERC20.balanceOf(_poolDistributorAddress);
        }

        if(amount > 0){
            if (_shareholder==pool3BurnAddress) {
                processPool1TokenERC20.transfer(pool3Wallet, amount);
            }
            else if (_shareholder==teamLockAddress) {
                processPool1TokenERC20.transfer(teamWallet, amount);
            }
            else if (_shareholder==longTermGrowthLockAddress) {
                processPool1TokenERC20.transfer(longTermGrowthWallet, amount);
            }
            else if (_shareholder==ecosystemLockAddress) {
                processPool1TokenERC20.transfer(ecosystemWallet, amount);
            }
            else {
                processPool1TokenERC20.transfer(_shareholder, amount);
            }
            shareholderPayoutTimePool1[_shareholder] = block.timestamp;
        }
        shares[_shareholder].amountExcludedBuyPool1 = 0;
    }

    function payoutDividendsPool2(
        address _shareholder,
        uint256 _payoutPool2DividendsPerShare
        ) internal {
        if(shares[_shareholder].amount == 0){ return; }
        uint256 amount = ((shares[_shareholder].amount).sub(shares[_shareholder].amountExcludedBuyPool2)).mul(_payoutPool2DividendsPerShare).div(dividendsPerShareAccuracyFactor);
        if(amount > 0){
            totalDistributedWBNB = totalDistributedWBNB.add(amount);
            if (_shareholder==pool3BurnAddress) {
                WBNB.transfer(pool3Wallet, amount);
            }
            else if (_shareholder==teamLockAddress) {
                WBNB.transfer(teamWallet, amount);
            }
            else if (_shareholder==longTermGrowthLockAddress) {
                WBNB.transfer(longTermGrowthWallet, amount);
            }
            else if (_shareholder==ecosystemLockAddress) {
                WBNB.transfer(ecosystemWallet, amount);
            }
            else {
                WBNB.transfer(_shareholder, amount);
            }
            shareholderPayoutTimePool2[_shareholder] = block.timestamp;
            shares[_shareholder].withdrawnDividendsWBNB = (shares[_shareholder].withdrawnDividendsWBNB).add(amount);
        }
        shares[_shareholder].amountExcludedBuyPool2 = 0;
    }

    function getInfoAboutPool1AtIndex(uint256 _index) external view returns (
        uint256 amountDifferentTokensPayoutsPool1_,
        address tokenPayoutPool1_,
        uint256 amountPayoutPool1_,
        uint256 indexPayoutPool1_) {
        tokenPayoutPool1_ = payoutPool1Tokens[_index];
        require((payoutPool1TokensAmount[tokenPayoutPool1_] > 0), "Error: no pool 1 payout with this token yet");
        amountDifferentTokensPayoutsPool1_ = payoutPool1Tokens.length;
        amountPayoutPool1_ = payoutPool1TokensAmount[tokenPayoutPool1_];
        indexPayoutPool1_ = _index;
    }

    function getInfoAboutPool1AtToken(address _processPool1Token) external view returns (
        uint256 amountDifferentTokensPayoutsPool1_,
        address tokenPayoutPool1_,
        uint256 amountPayoutPool1_,
        uint256 indexPayoutPool1_) {
        require((payoutPool1TokensAmount[_processPool1Token] > 0), "Error: no pool 1 payout with this token yet");
        amountDifferentTokensPayoutsPool1_ = payoutPool1Tokens.length;
        tokenPayoutPool1_ = _processPool1Token;
        amountPayoutPool1_ = payoutPool1TokensAmount[_processPool1Token];
        indexPayoutPool1_ = payoutPool1TokensIndexes[_processPool1Token];
    }

    function getInfoAboutPool2() external view returns (
            uint256 payoutPool2Time_,
            uint256 payoutPool2TimeNext_,
            uint256 secondsUntilNextPayout_) {
            payoutPool2Time_ = payoutPool2Time;
            payoutPool2TimeNext_ = payoutPool2TimeNext;
            secondsUntilNextPayout_ = payoutPool2TimeNext_ > block.timestamp ?
                                      payoutPool2TimeNext_.sub(block.timestamp) :
                                      0;
    }

    function getAccountInfoForPool2(address _accountAddress, address _poolDistributorAddress) public view returns (
            address account_,
            int256 index_,
            uint256 lastPayoutTimePool2_,
            uint256 sharesAmount_,
            uint256 sharesAmountExcludedPool2_,
            uint256 withdrawnDividendsPool2WBNB_,
            uint256 unpaidDividendsFromPool2_) {
        account_ = _accountAddress;
        if(shares[_accountAddress].amount == 0) {
            index_ = -1;
        }
        else {
            index_ = int(shareholderIndexes[_accountAddress]);
        }
        lastPayoutTimePool2_ = shareholderPayoutTimePool2[_accountAddress];
        sharesAmount_ = shares[_accountAddress].amount;
        sharesAmountExcludedPool2_ = shares[_accountAddress].amountExcludedBuyPool2;
        withdrawnDividendsPool2WBNB_ = shares[_accountAddress].withdrawnDividendsWBNB;
        unpaidDividendsFromPool2_ = getUnpaidDividendsFromPool2(_accountAddress, _poolDistributorAddress);
    }

    function getAccountInfoForPool2AtIndex(uint256 _index, address _poolDistributorAddress) external view returns (
            address account_,
            int256 index_,
            uint256 lastPayoutTimePool2_,
            uint256 sharesAmount_,
            uint256 sharesAmountExcludedPool2_,
            uint256 withdrawnDividendsPool2WBNB_,
            uint256 unpaidDividendsFromPool2_) {
    	if(_index >= (shareholders.length)) {
            return (0x0000000000000000000000000000000000000000, -1, 0, 0, 0, 0, 0);
        }

        address _account = shareholders[_index];
        return getAccountInfoForPool2(_account, _poolDistributorAddress);
    }

    function getUnpaidDividendsFromPool2(address _shareholder, address _poolDistributorAddress) public view returns (uint256) {
        if(shares[_shareholder].amount == 0){ return 0; }
        uint256 _divPerShare = (WBNB.balanceOf(_poolDistributorAddress)).mul(dividendsPerShareAccuracyFactor).div(totalShares);
        return (shares[_shareholder].amount).mul(_divPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function updatePayoutPool2FrequencySec(uint256 _newPayoutPool2FrequencySec) external onlyOwner {
        emit PayoutPool2FrequencySecUpdated(_newPayoutPool2FrequencySec, payoutPool2FrequencySec);
        payoutPool2FrequencySec = _newPayoutPool2FrequencySec;
        updatePayoutPool2TimeNext();
    }

    function updatePayoutPool2TimeNext() public onlyOwner {
        payoutPool2TimeNext =  block.timestamp + payoutPool2FrequencySec;
    }

    function updateMinimumTokenBalanceForDividends(uint256 _newMinimumBalance) external onlyOwner {
        require(_newMinimumBalance <= (10**18), "Error: use the value without 10**18, e.g. 100 tokens");
        minimumTokenBalanceForDividends = _newMinimumBalance.mul(10**18);
    }

    function getNumberOfTokenHolders() external view returns(uint256) {
        return shareholders.length;
    }

    function updatePool3Wallet(address _newPool3Wallet) external onlyOwner {
        require(_newPool3Wallet != pool3Wallet, "Error: The pool3Wallet is already this address");
        emit Pool3WalletUpdated(_newPool3Wallet, pool3Wallet);
        pool3Wallet = _newPool3Wallet;
    }

    function updatePool3BurnAddress(address _newPool3BurnAddress) external onlyOwner {
        require(_newPool3BurnAddress != pool3BurnAddress, "Error: The pool3BurnAddress is already this address");
        emit Pool3BurnAddressUpdated(_newPool3BurnAddress, pool3BurnAddress);
        pool3BurnAddress = _newPool3BurnAddress;
    }

    function updateTeamWallet(address _newTeamWallet) external onlyOwner {
        require(_newTeamWallet != teamWallet, "Error: The teamWallet is already this address");
        emit TeamWalletUpdated(_newTeamWallet, teamWallet);
        teamWallet = _newTeamWallet;
    }

    function updateLongTermGrowthWallet(address _newLongTermGrowthWallet) external onlyOwner {
        require(_newLongTermGrowthWallet != longTermGrowthWallet, "Error: The longTermGrowthWallet is already this address");
        emit LongTermGrowthWalletUpdated(_newLongTermGrowthWallet, longTermGrowthWallet);
        longTermGrowthWallet = _newLongTermGrowthWallet;
    }

    function updateEcosystemWallet(address _newEcosystemWallet) external onlyOwner {
        require(_newEcosystemWallet != ecosystemWallet, "Error: The ecosystemWallet is already this address");
        emit EcosystemWalletUpdated(_newEcosystemWallet, ecosystemWallet);
        ecosystemWallet = _newEcosystemWallet;
    }

    function updateTeamLockAddress(address _newTeamLockAddress) external onlyOwner {
        require(_newTeamLockAddress != teamLockAddress, "Error: The teamLockAddress is already this address");
        emit TeamLockAddressUpdated(_newTeamLockAddress, teamLockAddress);
        teamLockAddress = _newTeamLockAddress;
    }

    function updateLongTermGrowthLockAddress(address _newLongTermGrowthLockAddress) external onlyOwner {
        require(_newLongTermGrowthLockAddress != longTermGrowthLockAddress, "Error: The longTermGrowthLockAddress is already this address");
        emit LongTermGrowthLockAddressUpdated(_newLongTermGrowthLockAddress, longTermGrowthLockAddress);
        longTermGrowthLockAddress = _newLongTermGrowthLockAddress;
    }

    function updateEcosystemLockAddress(address _newEcosystemLockAddress) external onlyOwner {
        require(_newEcosystemLockAddress != ecosystemLockAddress, "Error: The ecosystemLockAddress is already this address");
        emit EcosystemLockAddressUpdated(_newEcosystemLockAddress, ecosystemLockAddress);
        ecosystemLockAddress = _newEcosystemLockAddress;
    }
}
