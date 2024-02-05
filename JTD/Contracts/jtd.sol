/**
 *Submitted for verification at BscScan.com on 2022-07-05
*/

/*
JTD - audit corrections, test deployment
*/

// Code written by MrGreenCrypto
// SPDX-License-Identifier: None

pragma solidity 0.8.15;

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken,uint256 amountETH,uint256 liquidity);

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

    function getAmountsOut(
            uint256 amountIn,
            address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

interface IDEXPair {
    function sync() external;
}

contract JoinTheDiamonds is IBEP20 {
    string private constant _name = "JoinTheDiamondsAudit";
    string private constant _symbol = "JTDAudit";
    uint8 private constant _decimals = 9;
    uint256 private constant _totalSupply = 1_000_000_000 * (10**_decimals);

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public addressWithoutLimits;
    mapping(address => bool) public addressNotGettingRewards;
    mapping(address => uint256) private shareholderIndexes;
    mapping(address => Share) private shares;
    mapping(address => uint256) private lastSell;

    uint256 public tax = 6;
    uint256 private liq = 2;
    uint256 private marketing = 3;
    uint256 private diamond = 1;
    uint256 private initialJeetTax = 10; // will be changed to 33 % in the final version
    uint256 public timeUntilJeetTaxDecrease = 10 minutes; // will be changed to 5 days in the final version
    uint256 public jeetTax = 10; // will be changed to 33 % in the final version
    uint256 private taxDivisor = 100;
    uint256 public sellMultiplier = 2;
    uint256 private tokensFromJeetTax;
    uint256 public buys;
    uint256 public sells;
    uint256 private partyNumber;
    uint256 private buysToStopEvent = 3; // will be changed to something between 20 and 50 in the final version
    uint256 private buysUntilEvent = 3; // will be changed to something between 50 and 200 in the final version
    uint256 private launchTime;
    uint256 private totalShares;
    uint256 private totalRewards;
    uint256 private totalDistributed;
    uint256 private rewardsPerShare;
    uint256 private constant veryLargeNumber = 10**36;
    uint256 private busdBalanceBefore;
    uint256 private rewardsToSendPerTx = 5;
    uint256 private constant minTokensForRewards = 500_000 * (10**_decimals);
    uint256 private lastRewardsTime;
    uint256 private timeBetweenRewards = 20 minutes;
    uint256 private currentIndex;
    uint256 private minPartySell = 0.01 ether; // will be changed to something between 1 and 10 in the final version
    uint256 private minPartyBuy = 0.01 ether; // will be changed to something between 1 and 10 in the final version
    uint256 private sellDelay = 20;
    uint256 public maxWallet = _totalSupply / 50;
    uint256 public maxSell = _totalSupply / 100;


    bool private jeetTaxActive = true;
    bool public letTheJeetsOutParty;
    bool private isSwapping;

    IDEXRouter private router = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IBEP20 private constant BUSD = IBEP20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    address private constant CEO = 0xe6497e1F2C5418978D5fC2cD32AA23315E7a41Fb;
    address private constant WETH = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public marketingWallet = 0xe6497e1F2C5418978D5fC2cD32AA23315E7a41Fb;
    address public diamondVaultAddress = 0xe6497e1F2C5418978D5fC2cD32AA23315E7a41Fb;
    address public pair;
    address[] private shareholders;
    address[] private pathForBuyingBUSD = new address[](2);
    address[] private pathForSellingJTD = new address[](2);
    address[] private pathForEstimatingBUSDvalue= new address[](3);

    event PartyStarted(uint256 partyNo);
    event PartyReview(uint256 partyNo, uint256 buys, uint256 sells, bool crashed);
    event PartyBuy(uint256 amount, uint256 amountInBusd, uint256 buysLeftToCrash, uint256 sellsLeft);
    event Buy(uint256 amount, uint256 amountInBusd, uint256 buysLeftToParty);
    event ContractSell(uint256 rewards);

    struct Share {uint256 amount;uint256 totalExcluded;uint256 totalRealised;}

    modifier onlyOwner() {if(msg.sender != CEO) return; _;}
    modifier contractSelling() {isSwapping = true; _; isSwapping = false;}

    constructor() {
        pathForBuyingBUSD[0] = WETH;
        pathForBuyingBUSD[1] = address(BUSD);
        pathForSellingJTD[0] = address(this);
        pathForSellingJTD[1] = WETH;
        pathForEstimatingBUSDvalue[0] = address(this);
        pathForEstimatingBUSDvalue[1] = WETH;
        pathForEstimatingBUSDvalue[2] = address(BUSD);

        pair = IDEXFactory(IDEXRouter(router).factory()).createPair(WETH, address(this));
        _allowances[address(this)][address(router)] = type(uint256).max;

        addressNotGettingRewards[pair] = true;
        addressWithoutLimits[CEO] = true;
        addressWithoutLimits[address(this)] = true;

        _balances[address(this)] = _totalSupply;
        emit Transfer(address(0), address(this), _totalSupply);
    }

    receive() external payable {}
    function name() public pure override returns (string memory) {return _name;}
    function totalSupply() public pure override returns (uint256) {return _totalSupply;}
    function decimals() public pure override returns (uint8) {return _decimals;}
    function symbol() public pure override returns (string memory) {return _symbol;}
    function balanceOf(address account) public view override returns (uint256) {return _balances[account];}
    function allowance(address holder, address spender) public view override returns (uint256) {return _allowances[holder][spender];}
    function approveMax(address spender) public returns (bool) {return approve(spender, type(uint256).max);}

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function valueInBusd(uint256 tokensToCalculate) public view returns (uint256){
        return router.getAmountsOut(tokensToCalculate, pathForEstimatingBUSDvalue)[2];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount ) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            require(_allowances[sender][msg.sender] >= amount, "Insufficient Allowance");
            _allowances[sender][msg.sender] -= amount;
        }

        return _transferFrom(sender, recipient, amount);
    }

    function rewardBalance(address holder) external view returns (uint256){
        return getUnpaidEarnings(holder);
    }

    function claim(address claimer) external {
        if (getUnpaidEarnings(claimer) > 0) distributeRewards(claimer);
    }

    function _lowGasTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _lowGasTransfer(sender, recipient, amount);
        if (!addressNotGettingRewards[sender]) setShare(sender);
        if (!addressNotGettingRewards[recipient]) setShare(recipient);
        process();
        return true;
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        if (isSwapping) return _lowGasTransfer(sender, recipient, amount);

        if(addressWithoutLimits[sender] || addressWithoutLimits[recipient]) return _basicTransfer(sender, recipient, amount);

        if (launchTime > block.timestamp) return true;

        if (conditionsToSwapAreMet(sender)) letTheContractSell();

        amount = jeetTaxActive ? takeJeetTax (sender, recipient, amount) : takeTax(sender, recipient, amount);
        return _basicTransfer(sender, recipient, amount);
    }

    function takeTax(address sender, address recipient, uint256 amount) internal returns (uint256) {
        uint256 taxAmount = (amount * tax * sellMultiplier) / taxDivisor;
        if (recipient == pair) require(amount <= maxSell, "Exceeds max sell");

        if (sender == pair) {
            require(_balances[recipient] + amount <= maxWallet, "Exceeds max wallet");
            taxAmount /= sellMultiplier;
        }

        if (taxAmount > 0) _lowGasTransfer(sender, address(this), taxAmount);
        return amount - taxAmount;
    }

    function takeJeetTax(address sender, address recipient, uint256 amount) internal returns (uint256) {
        uint256 taxAmount = (amount * tax * sellMultiplier) / taxDivisor;

        if (recipient == pair){
            require(amount <= maxSell, "Exceeds max sell");
            uint256 jeetTaxAmount = amount * jeetTax / 100;

            if (letTheJeetsOutParty) {
                if(sells <= jeetTax) jeetTaxAmount = amount * (jeetTax - sells) / 100;
                if(lastSell[sender] + sellDelay <= block.timestamp && valueInBusd(amount) > minPartySell) sells++;
                if (sells >= jeetTax) stopLettingTheJeetsOut();
            }

            taxAmount += jeetTaxAmount;
            tokensFromJeetTax += jeetTaxAmount;
            lastSell[sender] = block.timestamp;
        }

        if (sender == pair) {
            require(_balances[recipient] + amount <= maxWallet, "Exceeds max wallet");

            if (letTheJeetsOutParty){
                if(valueInBusd(amount) >= minPartyBuy) buys++;
                emit PartyBuy(amount, valueInBusd(amount), buysToStopEvent - buys, jeetTax - sells);
                if (buys >= buysToStopEvent) stopLettingTheJeetsOut();
                return amount;
            } else {
                buys++;
                taxAmount /= sellMultiplier;
                emit Buy(amount, valueInBusd(amount), buysUntilEvent - buys);
                if(buys >= buysUntilEvent) letTheJeetsOut();
            }
        }

        if (taxAmount > 0) _lowGasTransfer(sender, address(this), taxAmount);

        return amount - taxAmount;
    }

    function letTheJeetsOut() internal {
        letTheJeetsOutParty = true;
        partyNumber++;
        sells = 0;
        buys = 0;
        emit PartyStarted(partyNumber);
    }

    function stopLettingTheJeetsOut() internal {
        emit PartyReview(partyNumber, buys, sells, jeetTax > sells ? true : false);
        letTheJeetsOutParty = false;
        sells = 0;
        buys = 0;

        if (jeetTaxActive && (block.timestamp - launchTime) / timeUntilJeetTaxDecrease >= initialJeetTax) {
            jeetTaxActive = false;
            initialJeetTax = 0;
            jeetTax = 0;
            return;
        }

        jeetTax = initialJeetTax - ((block.timestamp - launchTime) / timeUntilJeetTaxDecrease);
    }

    function conditionsToSwapAreMet(address sender) internal view returns (bool) {
        bool shouldSell = letTheJeetsOutParty;
        if (!jeetTaxActive) shouldSell = true;
        return sender != pair && !isSwapping && shouldSell;
    }

    function letTheContractSell() internal {
        uint256 tokensThatTheContractWillSell = (_balances[address(this)] - tokensFromJeetTax ) * (tax - liq) / tax + tokensFromJeetTax;

        if(tokensThatTheContractWillSell > 0){
            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokensThatTheContractWillSell,
                0,
                pathForSellingJTD,
                address(this),
                block.timestamp
            );
        }

        uint256 bnbToRewards = (address(this).balance * tokensFromJeetTax) / tokensThatTheContractWillSell;
        tokensFromJeetTax = 0;
        swapForBUSDRewards(bnbToRewards);

        _lowGasTransfer(address(this), pair, _balances[address(this)]);
        IDEXPair(pair).sync();

        payable(diamondVaultAddress).transfer((address(this).balance * diamond) / tax);
        payable(marketingWallet).transfer(address(this).balance);
    }

    function swapForBUSDRewards(uint256 bnbForRewards) internal {
        if (bnbForRewards == 0) return;
        busdBalanceBefore = BUSD.balanceOf(address(this));

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: bnbForRewards
        }(
            0,
            pathForBuyingBUSD,
            address(this),
            block.timestamp
        );

        uint256 newBusdBalance = BUSD.balanceOf(address(this));

        uint256 amount = newBusdBalance - busdBalanceBefore;
        totalRewards += amount;
        rewardsPerShare = rewardsPerShare + veryLargeNumber * amount / totalShares;
        emit ContractSell(amount);
    }

    function setShare(address shareholder) internal {
        if (shares[shareholder].amount >= minTokensForRewards) distributeRewards(shareholder);

        if (shares[shareholder].amount == 0 && _balances[shareholder] >= minTokensForRewards) addShareholder(shareholder);

        if (shares[shareholder].amount >= minTokensForRewards && _balances[shareholder] < minTokensForRewards) {
            totalShares = totalShares - shares[shareholder].amount;
            shares[shareholder].amount = 0;
            removeShareholder(shareholder);
            return;
        }

        if (_balances[shareholder] >= minTokensForRewards) {
            totalShares = totalShares - shares[shareholder].amount + _balances[shareholder];
            shares[shareholder].amount = _balances[shareholder];
            shares[shareholder].totalExcluded = getTotalRewardsOf(shares[shareholder].amount);
        }
    }

    function process() internal {
        uint256 shareholderCount = shareholders.length;
        if (shareholderCount <= rewardsToSendPerTx) return;
        if(currentIndex == 0) lastRewardsTime = block.timestamp;
        if(lastRewardsTime + timeBetweenRewards > block.timestamp) return;

        for (uint256 rewardsSent = 0; rewardsSent < rewardsToSendPerTx; rewardsSent++) {
            if (currentIndex >= shareholderCount) currentIndex = 0;
            distributeRewards(shareholders[currentIndex]);
            currentIndex++;
        }
    }

    function distributeRewards(address shareholder) internal {
        uint256 amount = getUnpaidEarnings(shareholder);
        if (amount < 1 ether) return;

        BUSD.transfer(shareholder, amount);
        totalDistributed = totalDistributed + amount;
        shares[shareholder].totalRealised =
            shares[shareholder].totalRealised +
            amount;
        shares[shareholder].totalExcluded = getTotalRewardsOf(
            shares[shareholder].amount
        );
    }

    function getUnpaidEarnings(address shareholder) internal view returns (uint256) {
        uint256 shareholderTotalRewards = getTotalRewardsOf(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;
        if (shareholderTotalRewards <= shareholderTotalExcluded) return 0;
        return shareholderTotalRewards - shareholderTotalExcluded;
    }

    function getTotalRewardsOf(uint256 share) internal view returns (uint256) {
        return (share * rewardsPerShare) / veryLargeNumber;
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length - 1];
        shareholderIndexes[shareholders[shareholders.length - 1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }

    function sellForRewards() external onlyOwner {
        letTheContractSell();
    }

    function setWallets(address marketingAddress, address diamondAddress) external onlyOwner {
        require(marketingAddress != address(0) && diamondAddress != address(0), "Have to be valid addresses");
        marketingWallet = marketingAddress;
        diamondVaultAddress = diamondAddress;
    }

    function setLetTheJeetsOutEventParameters(
        uint256 _buysToStopEvent,
        uint256 _buysUntilEvent,
        uint256 _minPartyBuyInBusd,
        uint256 _minPartySellInBusd,
        uint256 sellDelayInSeconds
    ) external onlyOwner {
        require(
            _buysToStopEvent >= 10 &&
            _buysUntilEvent >= 10 &&
            _minPartySellInBusd < 100 &&
            _minPartyBuyInBusd < 100 &&
            sellDelayInSeconds < 360
        , "Safety feature");

        buysToStopEvent = _buysToStopEvent;
        buysUntilEvent = _buysUntilEvent;
        minPartySell = _minPartySellInBusd;
        minPartyBuy = _minPartyBuyInBusd;
        sellDelay = sellDelayInSeconds;
    }

    function setRewardParameters(uint256 _rewardsToSendPerTx, uint256 minutesBetweenRewards) external onlyOwner {
        require(_rewardsToSendPerTx < 20, "May cost too much gas");
        require(minutesBetweenRewards < 1440, "Can't let holders wait too long");
        rewardsToSendPerTx = _rewardsToSendPerTx;
        timeBetweenRewards = minutesBetweenRewards * 1 minutes;
    }

    function setWalletParameters(uint256 _maxWallet, uint256 _maxSell) external onlyOwner {
        require(
            _maxWallet >= _totalSupply / 100 &&
            _maxSell >= _totalSupply / 100
        , "Safety feature");

        maxWallet = _maxWallet;
        maxSell = _maxSell;
    }



    function jeetTaxRevival(uint256 _initialJeetTax, uint256 _hoursUntilJeetTaxDecrease) external onlyOwner {
        timeUntilJeetTaxDecrease = _hoursUntilJeetTaxDecrease * 1 hours;
        initialJeetTax = _initialJeetTax;
        launchTime = block.timestamp;
        jeetTaxActive = true;
        require(initialJeetTax < 40, "Let the jeets out if they want");
        require(timeUntilJeetTaxDecrease > 0, "Safety feature to avoid division by 0");
    }

    function setTax(
        uint256 newTax,
        uint256 newTaxDivisor,
        uint256 newLiq,
        uint256 newMarketing,
        uint256 newDiamond,
        uint256 newSellMultiplier
    ) external onlyOwner {
        tax = newTax;
        taxDivisor = newTaxDivisor;
        liq = newLiq;
        marketing = newMarketing;
        diamond = newDiamond;
        sellMultiplier = newSellMultiplier;
        require(tax <= taxDivisor / 10 && sellMultiplier * tax >= 20, "Can't make a honeypot");
    }

    function setAddressWithoutTax(address unTaxedAddress, bool status) external onlyOwner {
        addressWithoutLimits[unTaxedAddress] = status;
    }

    function setAddressNotGettingRewards(address _addressNotGettingRewards, bool status) external onlyOwner {
        addressNotGettingRewards[_addressNotGettingRewards] = status;
    }

    function addBNBToRewardsManually() external payable {
        if (msg.value > 0) swapForBUSDRewards(msg.value);
    }

    function rescueAnyToken(address token) external onlyOwner {
        require(token != address(this), "Can't rescue JTD");
        IBEP20(token).transfer(msg.sender, IBEP20(token).balanceOf(address(this)));
    }

    function rescueBnb() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function launch() external payable onlyOwner {
        router.addLiquidityETH{value: msg.value}(
            address(this),
            _balances[address(this)],
            0,
            0,
            msg.sender,
            block.timestamp
        );
        launchTime = block.timestamp;
    }
}