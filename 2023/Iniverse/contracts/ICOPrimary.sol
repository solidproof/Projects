// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IBEP20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

contract ICOPrimary is ReentrancyGuard, Ownable {

    using SafeCast for int256;

    mapping (address => mapping (CurrencyType => uint256)) private TokenBought;

    enum CurrencyType {
        PRIMARYCURRENCY,
        PRIMARYUSDT,
        SECONDARYCURRENCY,
        SECONDARYUSDT
    }

	IBEP20 public immutable _token;
    IBEP20 public immutable _usdtToken;
	address payable public _wallet;
    address payable public _bridge;
	uint256 public _startPrice;
    uint256 public _endPrice;
	uint256 public _time_unit = 1 minutes;

	uint256 public usdtRaised;
    uint256 public suppliedTokens;
    uint256 public tokenHold;
	uint256 public hardCap;

	uint256 public startICOTimestamp;
	uint256 public endICOTimestamp;

    uint8 public stageCount;

	uint256 public minPurchase;
	uint256 public maxPurchase;
    bool private stopIcoRun;
	
	uint256 public availableTokens;

    AggregatorV3Interface internal immutable primaryCurrencyPriceFeed;
    AggregatorV3Interface internal immutable secondaryCurrencyPriceFeed;

	event TokensPurchased(address indexed purchaser, uint256 token_amount, uint256 usdtRaised);
    event TokensDelivered(address indexed purchaser, uint256 token_amount);
    event HardCapUpdated(uint256 newValue);
    event MaxPurchaseUpdated(uint256 newValue);
    event MinPurchaseUpdated(uint256 newValue);
    event WalletUpdated(address newWallet);

    constructor(address payable wallet, address payable bridge, address tokenAddress, address usdtAddress, address _primaryCurrencyPriceFeed, address _secondaryCurrencyPriceFeed) {
        require(wallet != address(0), "wallet is the zero address");
        require(bridge != address(0), "bridge is the zero address");
        require(tokenAddress != address(0), "token address is the zero");
        require(usdtAddress != address(0), "usdt address is the zero");
        require(_primaryCurrencyPriceFeed != address(0), "Eth primaryCurrencyPriceFeed is the zero address");
        require(_secondaryCurrencyPriceFeed != address(0), "Bsc primaryCurrencyPriceFeed is the zero address");

        _wallet = wallet;
        _bridge = bridge;
        _token = IBEP20(tokenAddress);
        _usdtToken = IBEP20(usdtAddress);
        primaryCurrencyPriceFeed = AggregatorV3Interface(_primaryCurrencyPriceFeed);
        secondaryCurrencyPriceFeed = AggregatorV3Interface(_secondaryCurrencyPriceFeed);
	}

	receive() external payable {
        buyTokensByPrimaryCurrency(_msgSender());
	}

    fallback() external payable {
        buyTokensByPrimaryCurrency(_msgSender());
    }

    function buyTokensByPrimaryCurrency(address beneficiary) public nonReentrant icoActive payable {
        uint256 usdtAmount = getPrimaryCurrencyPrice() * msg.value / ( 10 ** 8);
    	uint256 tokens = _getTokenAmountFromUSDT(usdtAmount);
        _preValidatePurchase(beneficiary, usdtAmount, tokens);
        _purchaseTokens(usdtAmount, tokens, beneficiary, CurrencyType.PRIMARYCURRENCY);
    }

    function buyTokensByPrimaryUSDT(uint256 usdtAmount) public nonReentrant icoActive {
        address beneficiary = _msgSender();
        uint256 tokens = _getTokenAmountFromUSDT(usdtAmount);
        _preValidatePurchase(beneficiary, usdtAmount, tokens);

        uint256 ourAllowance = _usdtToken.allowance(
            _msgSender(),
            address(this)
        );

        require(usdtAmount <= ourAllowance, "Make sure to add enough allowance");
        (bool success, ) = address(_usdtToken).call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                _msgSender(),
                address(this),
                usdtAmount
            )
        );
        require(success, "Token payment failed");
        _purchaseTokens(usdtAmount, tokens, beneficiary, CurrencyType.PRIMARYUSDT);
    }

    function checkIfPurchaseEnabledBySecondaryCurrency(uint256 currencyAmount, address beneficiary) public view returns (uint8) {
        uint256 usdtAmount = getSecondaryCurrencyPrice() * currencyAmount / ( 10 ** 8);
        return checkIfPurchaseEnabledBySecondaryUSDT(usdtAmount, beneficiary);
    }

    function checkIfPurchaseEnabledBySecondaryUSDT(uint256 usdtAmount, address beneficiary) public view returns (uint8) {
        uint256 tokens = _getTokenAmountFromUSDT(usdtAmount);
        if (_isIcoActive() == false) return 0;
        else if (beneficiary == address(0)) return 1;
        else if (usdtAmount == 0) return 2;
        else if (tokens < minPurchase) return 3;
        else if (getTokenBoughtFor(beneficiary) + tokens > maxPurchase) return 4;
        else if (usdtRaised + usdtAmount > hardCap) return 5;
        return 6;
    }

    function buyTokensBySecondaryCurrency(uint256 secondaryCurrencyAmount, address beneficiary) public nonReentrant icoActive onlyBridge {
        uint256 usdtAmount = getSecondaryCurrencyPrice() * secondaryCurrencyAmount / ( 10 ** 8);
    	uint256 tokens = _getTokenAmountFromUSDT(usdtAmount);
        _preValidatePurchase(beneficiary, usdtAmount, tokens);
        _purchaseTokens(usdtAmount, tokens, beneficiary, CurrencyType.SECONDARYCURRENCY);
    }

    function buyTokensBySecondaryUSDT(uint256 usdtAmount, address beneficiary) public nonReentrant icoActive onlyBridge {
        uint256 tokens = _getTokenAmountFromUSDT(usdtAmount);
        _preValidatePurchase(beneficiary, usdtAmount, tokens);
        _purchaseTokens(usdtAmount, tokens, beneficiary, CurrencyType.SECONDARYUSDT);
    }

    function _purchaseTokens(uint256 usdtAmount, uint256 tokens, address beneficiary, CurrencyType _currencyType) internal {
        usdtRaised = usdtRaised + usdtAmount;
        tokenHold = tokenHold + tokens;
        availableTokens = availableTokens - tokens;
        TokenBought[beneficiary][_currencyType] = TokenBought[beneficiary][_currencyType] + tokens;
        emit TokensPurchased(beneficiary, getTokenBoughtFor(beneficiary), usdtRaised);
    }

    function getTokenBoughtFor(address beneficiary) public view returns (uint256) {
        return TokenBought[beneficiary][CurrencyType.PRIMARYCURRENCY] + TokenBought[beneficiary][CurrencyType.PRIMARYUSDT] + TokenBought[beneficiary][CurrencyType.SECONDARYCURRENCY] + TokenBought[beneficiary][CurrencyType.SECONDARYUSDT];
    }

    function _preValidatePurchase(address beneficiary, uint256 usdtAmount, uint256 tokens) internal view {
    	require(beneficiary != address(0), "beneficiary is the zero address");
        require(usdtAmount != 0, "weiAmount is 0");
        require(tokens != 0, "trying to purchase 0 tokens");
        require(tokens >= minPurchase, 'have to send at least: minPurchase');
        require(getTokenBoughtFor(beneficiary) + tokens <= maxPurchase, 'can\'t buy more than: maxPurchase');
        require(usdtRaised + usdtAmount <= hardCap, 'Hard Cap reached');
    }

    function _getTokenAmountFromUSDT(uint256 usdtAmount) internal view returns (uint256) {
        uint256 currentPrice = _getCurrentTokenPrice();
        require(currentPrice > 0, "current price is wrongly 0");
        uint256 tokenAmount = usdtAmount * 10 ** 18 / currentPrice;
        return tokenAmount;
    }

    function getMaximumUSDTAmount() external view returns (uint256) {
        require(_startPrice > 0, "start price need to be set above 0");
        uint256 tokenAmount = maxPurchase * _startPrice / (10 ** 18);
        return tokenAmount;
    } 

    function getPrimaryCurrencyPrice() public view returns (uint256) {
        (
            /* uint80 roundID */,
            int256 price,
            /* uint256 startedAt */,
            /* uint256 timeStamp */,
            /* uint80 answeredInRound */
        ) = primaryCurrencyPriceFeed.latestRoundData();

        return price.toUint256();
    }

    function getSecondaryCurrencyPrice() public view returns (uint256) {
        (
            /* uint80 roundID */,
            int256 price,
            /* uint256 startedAt */,
            /* uint256 timeStamp */,
            /* uint80 answeredInRound */
        ) = secondaryCurrencyPriceFeed.latestRoundData();

        return price.toUint256();
    }

    function declareCurrentAvailableTokensAsSuppliedTokens() external onlyOwner {
        suppliedTokens = _token.balanceOf(address(this));
    }

    function startICO(uint duration_, uint8 stageCount_, uint256 startPrice_, uint256 endPrice_, uint minPurchase_, uint maxPurchase_, uint256 hardCap_) external onlyOwner icoNotActive() {    	
    	require(duration_ > 0, 'duration is 0');
        require(stageCount_ > 0, 'stageCount is 0');
        require(startPrice_ > 0, 'ICO startprice is 0');
        require(endPrice_ >= startPrice_, 'ICO endPrice is lower than startPrice');
        require(minPurchase_ > 0, 'minPurchase is 0');
        require(minPurchase_ < maxPurchase_, "minPurchase must be lower than maxPurchase");
        require(hardCap_ > 0, 'hardCap is 0');

    	startICOTimestamp = block.timestamp;
    	endICOTimestamp = startICOTimestamp + duration_ * _time_unit;
    	availableTokens = _token.balanceOf(address(this));
    	minPurchase = minPurchase_;
        maxPurchase = maxPurchase_;
        hardCap = hardCap_;
        stageCount = stageCount_;
        _startPrice = startPrice_;
        _endPrice = endPrice_;
        usdtRaised = 0;
        stopIcoRun = false;
    }

    function stopICO() external onlyOwner {
        endICOTimestamp = 0;
        startICOTimestamp = 0;
        availableTokens = 0;
        stopIcoRun = true;
    }

    function withdrawUsdt() external onlyOwner onlyContractHasUSDT {
        uint balance = _usdtToken.balanceOf(address(this));
        _usdtToken.transfer(_wallet, balance);
    }

    function withdrawCurrency() external onlyOwner onlyContractHasCurrency {
        payable(_wallet).transfer(address(this).balance);
    }

    function getAvailableTokenAmount() public view returns (uint256) {
        return availableTokens;
    }

    function _getCurrentTokenPrice() internal view returns (uint256) {
        uint256 timestamp = block.timestamp;

        if (endICOTimestamp > 0 && timestamp < endICOTimestamp) {
            require(endICOTimestamp > startICOTimestamp, "Exception: end date is below start time");
            uint256 duration = endICOTimestamp - startICOTimestamp;
            for (uint8 i = 0; i <= stageCount; i++) {
                if (timestamp >= startICOTimestamp + duration * i / (stageCount + 1) && timestamp < startICOTimestamp + duration * (i + 1) / (stageCount + 1)) {
                    return _startPrice + i * (_endPrice - _startPrice) / (stageCount + 1) ;
                }
            }
        }
        return _endPrice;
    }

    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        require(_token.balanceOf(address(this)) >= tokenAmount, 'No sufficient tokens to deliver in contract');
        _token.transfer(beneficiary, tokenAmount);
        emit TokensDelivered(beneficiary, tokenAmount);
    }
        
    function retakeRemainingTokens() public onlyOwner icoNotActive {
        uint256 tokenAmount = suppliedTokens - tokenHold;
        require(tokenAmount > 0, 'No Remaining tokens');
        _deliverTokens(_wallet, tokenAmount);
    }

    function invokeTokensAfterPresale() public icoNotActive nonReentrant {
        address beneficiary = _msgSender();
        uint256 tokenAmount  = getTokenBoughtFor(beneficiary);
        require(tokenAmount > 0, 'No tokens to claim');
        TokenBought[beneficiary][CurrencyType.PRIMARYCURRENCY] = 0;
        TokenBought[beneficiary][CurrencyType.PRIMARYUSDT] = 0;
        TokenBought[beneficiary][CurrencyType.SECONDARYCURRENCY] = 0;
        TokenBought[beneficiary][CurrencyType.SECONDARYUSDT] = 0;
        _deliverTokens(beneficiary, tokenAmount);
    }

    function getIcoStatus() external view returns (uint8) {
        return _isIcoActive() ? 3 : 2;
    }

    function _isIcoActive() internal view returns (bool) {
        if (endICOTimestamp > 0 && startICOTimestamp < endICOTimestamp && block.timestamp < endICOTimestamp && availableTokens > 0)
            return true;
        return false;
    }

    function getUsdtRaised() external view returns (uint256) {
        return usdtRaised;
    }

    function getToken() public view returns (IBEP20) {
    	return _token;
    }

    function getStopIcoRun() external view returns (bool) {
        return stopIcoRun;
    }

    function getHardCap() external view icoActive returns (uint256) {
        return hardCap;
    }

    function getMaxPurchase() external view icoActive returns (uint256) {
        return maxPurchase;
    }

    function getMinPurchase() external view icoActive returns (uint256) {
        return minPurchase;
    }

    function getStartTimestamp() external view icoActive returns (uint256) {
        return startICOTimestamp;
    }

    function getEndTimestamp() external view icoActive returns (uint256) {
        return endICOTimestamp;
    }

    function getStartPrice() external view icoActive returns (uint256) {
        return _startPrice;
    }

    function getEndPrice() external view icoActive returns (uint256) {
        return _endPrice;
    }

    function getStageCount() external view icoActive returns (uint8) {
        return stageCount;
    }

    function setWallet(address payable newWallet) external onlyOwner {
        require(newWallet != address(0), "Pre-Sale: newWallet is the zero address");
        _wallet = newWallet;
        emit WalletUpdated(_wallet);
    }

    function setHardCap(uint256 value) external onlyOwner icoActive {
        require(value > 0, "HardCap is incorrect");
        hardCap = value;
        emit HardCapUpdated(hardCap);
    }

    function setMaxPurchase(uint256 value) external onlyOwner icoActive {
        require(value > 0, "MaxPurchase is incorrect");
        maxPurchase = value;
        emit MaxPurchaseUpdated(maxPurchase);
    }

    function setMinPurchase(uint256 value) external onlyOwner icoActive {
        require(value > 0, "MinPurchase is incorrect");
        minPurchase = value;
        emit MinPurchaseUpdated(minPurchase);
    }

    modifier icoActive() {
    	require(endICOTimestamp > 0 && startICOTimestamp < endICOTimestamp, "ICO must be active.");
        require(block.timestamp < endICOTimestamp, "current Time should be lower than end time.");
        require(availableTokens > 0, "available tokens must exist.");
    	_;
    }

    modifier icoNotActive() {
    	require(_isIcoActive() == false, 'ICO should not be active');
    	_;
    }

    modifier onlyContractHasUSDT() {
        require(_usdtToken.balanceOf(address(this)) > 0, 'Pre-Sale: Contract has no usdt.');
    	_;
    }

    modifier onlyContractHasCurrency() {
        require(address(this).balance > 0, 'Pre-Sale: Contract has no main currency.');
        _;
    }

    modifier onlyBridge() {
        require(_bridge == _msgSender(), 'Only bridge can invoke this function.');
        _;
    }
}