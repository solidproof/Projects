/**
 *Submitted for verification at BscScan.com on 2022-05-20
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IUniswapV2Router {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
        function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDividendDistributor {
    function setDistributionCriteria(
        uint256 _minPeriod,
        uint256 _minDistribution
    ) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit() external payable;
    function process(uint256 gas) external;
}


abstract contract Ownable {
    address internal _owner;
    mapping(address => bool) internal authorized;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = msg.sender;
        _owner = msgSender;
        authorized[msgSender] = true;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function authorize(address account, bool _authorize) external onlyOwner{
        authorized[account] = _authorize;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender], "Ownable: caller is not authorized");
        _;
    }

    function renounceOwnership() external virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract ERC20 is IERC20 {

    mapping (address => uint256) internal _balances;

    mapping (address => mapping (address => uint256)) internal _allowances;

    uint256 internal _totalSupply;

    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;

    constructor (string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    function name() external view virtual returns (string memory) {
        return _name;
    }

    function symbol() external view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() external view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] - subtractedValue);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

contract RDividendDistributor is IDividendDistributor {

    address internal _token;
    address public _owner;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    // BSC LUNA (Wormhole)
    IERC20 REWARD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    IUniswapV2Router internal _uniswapV2Router;

    address[] internal shareholders;
    mapping(address => uint256) internal shareholderIndexes;
    mapping(address => uint256) internal shareholderClaims;

    mapping(address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 internal constant dividendsPerShareAccuracyFactor = 10**36;

    uint256 public minPeriod = 60 * 60;

    uint256 public minDistribution = 1 * (10**3);

    uint256 internal currentIndex;

    bool internal initialized;

    modifier initialization() {
        require(!initialized, "must be initialized");
        _;
        initialized = true;
    }

    modifier onlyToken() {
        require(msg.sender == _token || msg.sender == _owner, "user not authorized");
        _;
    }

    event UpdateDistributorParameters(uint256 indexed minPeriod, uint256 indexed minDistribution);
    event SharesSet(address indexed shareholder, uint256 indexed amount, uint256 indexed totalShares);
    event DividendDeposited(uint256 indexed totalDividends, uint256 indexed dividendsPerShare);

    constructor(address _router, address owner_) {
        _uniswapV2Router = IUniswapV2Router(_router);
        _token = msg.sender;
        _owner = owner_;
        require(_token != address(0), "_token cannot be zero address");
    }

    function setDistributionCriteria(uint256 minperiod, uint256 mindistribution) external override onlyToken {
        require(minperiod > 0 && mindistribution > 0, "min amounts have to be greater than zero");
        minPeriod = minperiod;
        minDistribution = mindistribution;

        emit UpdateDistributorParameters(minPeriod, minDistribution);
    }

    function setShare(address shareholder, uint256 amount) external override onlyToken {
        if (shares[shareholder].amount > 0) {
            distributeDividend(shareholder);}
        if(amount > 0 && shares[shareholder].amount == 0) {
            addShareholder(shareholder); }
        else if (amount == 0 && shares[shareholder].amount > 0) {
            removeShareholder(shareholder); }

        totalShares = totalShares - shares[shareholder].amount + amount;
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(
            shares[shareholder].amount);

        emit SharesSet(shareholder, amount, totalShares);
    }

    function deposit() external payable {
        address[] memory path =  new address[](2);
        path[0] = _uniswapV2Router.WETH();
        path[1] = address(REWARD);
        _uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            path,
            address(this),
            block.timestamp
            );
        uint256 newBalance = REWARD.balanceOf(address(this));

        totalDividends = totalDividends + newBalance;
        dividendsPerShare = dividendsPerShare +
            dividendsPerShareAccuracyFactor * newBalance / totalShares;

        emit DividendDeposited(totalDividends, dividendsPerShare);
    }

    receive() external payable {
        this.deposit{value: msg.value}();
    }

    function process(uint256 gas) external override {
        uint256 shareholderCount = shareholders.length;

        if (shareholderCount == 0) {
            return;
        }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }

            if (shouldDistribute(shareholders[currentIndex])) {
                distributeDividend(shareholders[currentIndex]);
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }

    function shouldDistribute(address shareholder) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp &&
                getUnpaidEarnings(shareholder) > minDistribution;
    }

    function distributeDividend(address shareholder) internal {
        if (shares[shareholder].amount == 0) {
            return;
        }

        uint256 amount = getUnpaidEarnings(shareholder);
        if (amount > 0) {
            totalDistributed = totalDistributed + amount;
            REWARD.transfer(shareholder, amount);
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder]
                .totalRealised + amount;
            shares[shareholder].totalExcluded = getCumulativeDividends(
                shares[shareholder].amount);
        }
    }

    function claimDividend() external {
        distributeDividend(msg.sender);
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if (shares[shareholder].amount == 0) {
            return 0;
        }

        uint256 shareholderTotalDividends = getCumulativeDividends(
            shares[shareholder].amount
        );
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if (shareholderTotalDividends <= shareholderTotalExcluded) {
            return 0;
        }

        return shareholderTotalDividends - shareholderTotalExcluded;
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share * dividendsPerShare / dividendsPerShareAccuracyFactor;
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[
            shareholders.length - 1
        ];
        shareholderIndexes[
            shareholders[shareholders.length - 1]
        ] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
}

contract LunaInu is ERC20, Ownable {

    uint256 private constant DECIMALS = 1e18;
    uint256 private constant TOTAL_SUPPLY = 1000000000000 * (DECIMALS); // 1 T tokens
    uint256 public _maxTxAmount = (TOTAL_SUPPLY * 10) / 1000;               // 1%  of total supply
    uint256 public _maxWalletToken = (TOTAL_SUPPLY * 20) / 1000;          // 2.0%  of total supply
    address public constant deadAddress = address(0x000000000000000000000000000000000000dEaD);
    mapping (address => uint256) private timeLastTrade;
    mapping (address => bool) public isExcludedFromFees;
    mapping (address => bool) public isExcludedFromDividends;
    mapping (address => bool) internal isPair;

    uint256 public rewardsFee;
    uint256 public liquidityFee;
    uint256 public marketingFee;
    uint256 public treasuryFee;
    uint256 public devFee;
    uint256 public sellFeeIncrease;
    uint256 public totalFees;

    address public marketingAddress;
    address public devAddress;
    address public treasuryAddress;
    address public liquidityAddress;

    bool internal swapping;
    uint256 private deadBlocks;
    uint256 private deadDuration;
    uint256 private launchBlock;
    uint256 private launchTime;
    uint256 private tradeCooldown;

    bool internal tradingIsEnabled = false;

    bool public intensify = false;
    bool public shouldBurnFee = false;
    uint256 public intensifyDuration;
    uint256 public intensifyStart;

    IUniswapV2Router internal uniswapV2Router;
    address public immutable uniswapV2Pair;
    RDividendDistributor internal dividendDistributor;

    uint256 public burnAmount = 0;
    bool public accumulatingForBurn = false;
    bool private inBurn = false;

    // use by default 400,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 4e5;

    uint256 swapTimes;
    uint256 minSells = 4;
    uint256 internal swapTokensAtAmount = 5 * TOTAL_SUPPLY / 10000;   // 0.05% of total supply
    uint256 internal minTokenstoSwap = 1000 * (DECIMALS);

    event Launch(uint256 indexed tradeCooldown, uint256 indexed deadBlocks, uint256 indexed deadDuration);
    event SetFees(uint256 indexed rewardsFee, uint256 indexed liquidityFee, uint256 indexed marketingFee);
    event SetTradeRestrictions(uint256 indexed _maxTxAmount, uint256 indexed maxWallet);
    event SetSwapTokensAtAmount(uint256 indexed swapTokensAtAmount);

    event UpdateDividendDistributor(address indexed newAddress, address indexed oldAddress);
    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeFromDividends(address indexed account, bool indexed shouldExclude);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived
    );

    event SendDividends(
    	uint256 Rewards
    );

    event ProcessedDividendDistributor(
    	uint256 iterations,
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	uint256 gas,
    	address indexed processor
    );

    constructor() ERC20('LunaInu', '$LUNAV2') {

        rewardsFee = uint256(0);
        liquidityFee = uint256(1);
        marketingFee = uint256(1);
        devFee = uint256(1);
        treasuryFee = uint256(1);
        sellFeeIncrease = uint256(4);
        totalFees = rewardsFee + liquidityFee + marketingFee + treasuryFee + devFee;

    	IUniswapV2Router _uniswapV2Router = IUniswapV2Router(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        dividendDistributor = new RDividendDistributor(address(_uniswapV2Router), owner());
    	marketingAddress = address(msg.sender);
        devAddress = address(msg.sender);
        treasuryAddress = address(msg.sender);
        liquidityAddress = address(deadAddress);

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        excludeFromDividends(address(this), true);
        excludeFromDividends(address(dividendDistributor), true);
        excludeFromDividends(address(uniswapV2Router), true);
        excludeFromDividends(address(uniswapV2Pair), true);

        excludeFromFees(deadAddress, true);
        excludeFromFees(address(this), true);
        excludeFromFees(owner(), true);

        _mint(owner(), TOTAL_SUPPLY);
    }

    modifier inSwap {
        swapping = true;
        _;
        swapping = false;
    }

    modifier inburn{
        inBurn = true;
        _;
        inBurn = false;
    }

    function launch(uint256 deadblocks, uint256 deadduration, uint256 _tradeCooldown) external onlyOwner{
        require(!tradingIsEnabled, "Project already launched.");
        require(deadblocks <= 20 && deadduration <= 180 && _tradeCooldown <= 180, "parameters outside allowed limits");
        deadBlocks = deadblocks;
        deadDuration = deadduration;
        tradingIsEnabled = true;
        launchBlock = block.number;
        launchTime = block.timestamp;
        tradeCooldown = _tradeCooldown;
        emit Launch(_tradeCooldown, deadblocks, deadduration);
    }

    function updateDividendDistributor(address newAddress) external onlyOwner {
        require(newAddress != address(dividendDistributor), " The dividend distributor already has that address");
        RDividendDistributor newDividendDistributor = RDividendDistributor(payable(newAddress));
        require(newDividendDistributor._owner() == address(this), " The new dividend distributor must be owned by the Test token contract");
        excludeFromDividends(address(newDividendDistributor), true);
        excludeFromDividends(address(this), true);
        excludeFromDividends(address(uniswapV2Router), true);
        emit UpdateDividendDistributor(newAddress, address(dividendDistributor));
        dividendDistributor = newDividendDistributor;
    }

    function updateUniswapV2Router(address newAddress) external onlyOwner {
        require(newAddress != address(uniswapV2Router), "Test: The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router(newAddress);
    }

    function setMinContractSells(uint256 minsells) external onlyAuthorized {
        minSells = minsells;
    }

    function setMinTokenSells(uint256 mintokens) external onlyAuthorized {
        uint256 min = mintokens * (DECIMALS);
        minTokenstoSwap = min;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(isExcludedFromFees[account] != excluded, "Test: Account is already the value of 'excluded'");
        isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function excludeFromDividends(address account, bool shouldExclude) public onlyOwner {
        isExcludedFromDividends[account] = shouldExclude;
        emit ExcludeFromDividends(account, shouldExclude);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
        require(pair != uniswapV2Pair, "Test: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) internal {
        require(isPair[pair] != value, "Test: Automated market maker pair is already set to that value");
        isPair[pair] = value;
        if(value){excludeFromDividends(pair, true);}
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateInternalAddresses(address marketingAdd, address devAdd, address treasuryAdd, address liquidityAdd) external onlyAuthorized {
        marketingAddress = marketingAdd;
        devAddress = devAdd;
        treasuryAddress = treasuryAdd;
        liquidityAddress = liquidityAdd;
    }

    function updateGasForProcessing(uint256 newValue) external onlyOwner {
        require(newValue >= 200000 && newValue <= 800000, "Test: gasForProcessing must be between 200,000 and 800,000");
        require(newValue != gasForProcessing, "Test: Cannot update gasForProcessing to same value");
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external onlyOwner{
        dividendDistributor.setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function getClaimWait() external view returns(uint256) {
        return dividendDistributor.minPeriod();
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendDistributor.totalDistributed();
    }

    function claim() external {
		dividendDistributor.claimDividend();
    }

    function getNumberOfDividendTokenHolders() external view returns(uint256) {
        return dividendDistributor.totalShares();
    }

    function setFees(uint256 marketingfee, uint256 devfee, uint256 treasuryfee, uint256 liquidityfee, uint256 rewardsfee, uint256 sellfeeIncrease) external onlyOwner{
        require(rewardsfee <= 5, "Requested rewardsFee fee not within acceptable range.");
        require(liquidityfee <= 5 , "Requested liquidity fee not within acceptable range.");
        require(marketingfee <= 5, "Requested marketing fee not within acceptable range.");
        require(devfee <= 5, "Requested marketing fee not within acceptable range.");
        require(treasuryfee <= 5, "Requested marketing fee not within acceptable range.");
        require(sellfeeIncrease <= 6, "Requested sell fee increase not within acceptable range.");
        rewardsFee = rewardsfee;
        liquidityFee = liquidityfee;
        marketingFee = marketingfee;
        devFee = devfee;
        treasuryFee = treasuryfee;
        sellFeeIncrease = sellfeeIncrease;
        totalFees = rewardsfee + liquidityfee + marketingfee + treasuryfee + devfee;
        emit SetFees(rewardsfee, liquidityfee, marketingfee);
    }

    function setTradeRestrictions(uint256 maxtx, uint256 maxwallet) external onlyOwner{
        uint256 maxTxAmount = maxtx * DECIMALS;
        uint256 maxWalletToken = maxwallet * DECIMALS;
        require(maxTxAmount >= (5 * TOTAL_SUPPLY / 1000), "Requested max transaction amount too low.");
        require(maxWalletToken >= (20 * TOTAL_SUPPLY / 1000), "Requested max allowable wallet amount too low.");
        _maxWalletToken = maxWalletToken;
        _maxTxAmount = maxTxAmount;
        emit SetTradeRestrictions(maxTxAmount, maxWalletToken);
    }

    function setSwapTokensAtAmount(uint256 swapTokensAmount) external onlyOwner{
        require(swapTokensAmount <= 2 * TOTAL_SUPPLY / 100,
        "Requested contract swap amount out of acceptable range.");
        swapTokensAtAmount = swapTokensAmount * DECIMALS;
        emit SetSwapTokensAtAmount(swapTokensAtAmount);
    }

    function checkValidTrade(address from, address to, uint256 amount) internal {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(amount <= balanceOf(from),"You are trying to transfer more than your balance");
        require(amount <= _maxTxAmount || isExcludedFromFees[from] || isExcludedFromFees[to], "TX Limit Exceeded");
        if(!isExcludedFromFees[to] && !isExcludedFromFees[from]) {
            require(tradingIsEnabled, "Project has yet to launch."); }
        if(!isExcludedFromFees[to] && !isExcludedFromFees[from] && to != uniswapV2Pair && from != owner()){
                require(balanceOf(address(to)) + amount <= _maxWalletToken, "Token purchase implies maxWallet violation.");}
        if(from == uniswapV2Pair && !isExcludedFromFees[to]){
                require(block.timestamp > timeLastTrade[to] + tradeCooldown, "Trade too frequent.");
                timeLastTrade[to] = block.timestamp; }
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        checkValidTrade(from, to, amount);
        if(shouldBurn()){doBurn(burnAmount); }
        if(shouldSwap(from, to, amount)){swapTokens(swapTokensAtAmount); }
        takeFees(from, to, amount);
        rewards(from, to);
    }


    function rewards(address from, address to) internal {
        if(!isExcludedFromDividends[from]){
            try dividendDistributor.setShare(from, balanceOf(from)) {} catch {} }
        if(!isExcludedFromDividends[to]){
            try dividendDistributor.setShare(to, balanceOf(to)) {} catch {} }
        if(tradingIsEnabled && !swapping) {
	    	try dividendDistributor.process(gasForProcessing) {} catch {} }
    }

    function takeFees(address from, address to, uint256 amount) internal {
        if(from != uniswapV2Pair && !isExcludedFromFees[from] && !isExcludedFromFees[to]){
            swapTimes = swapTimes + uint256(1);}
        uint256 fees;
        bool _burnFees = false;
        if(!isExcludedFromFees[from] && !isExcludedFromFees[to]){
           (uint256 fee, bool burnFees) = calculateFee(from);
            _burnFees = burnFees; fees = amount * fee / 100;
        if((block.number < launchBlock + deadBlocks) || (block.timestamp < launchTime + deadDuration)){
                _burnFees = false; fees = amount * 99 / 100; }
        uint256 tAmount = amount - fees;
        super._transfer(from, (_burnFees ? deadAddress : address(this)), fees);
        super._transfer(from, to, tAmount); }
        else{  super._transfer(from, to, amount); }

    }

    function rush(bool shouldburn, uint256 setminutes) external onlyAuthorized{
        require(setminutes <= 120, "Rush may not last over two hours.");
        intensify = true;
        shouldBurnFee = shouldburn;
        intensifyDuration = setminutes * 1 minutes;
        intensifyStart = block.timestamp;
    }

    function calculateFee(address from) internal returns (uint256, bool){
        uint256 fee;
        if(intensify){
            uint256 halfTime = intensifyStart  + intensifyDuration / 2;
            uint256 fullTime = intensifyStart  + intensifyDuration;
        if(block.timestamp < halfTime){
            fee = isPair[from] ? 0 : 20;
            return (fee, shouldBurnFee);}
        else if(block.timestamp < fullTime){
            fee = isPair[from] ? 5 : 15;
            return (fee, shouldBurnFee);}
        else{fee = isPair[from] ? totalFees : totalFees + sellFeeIncrease;
            intensify = false;
            return (fee, false);}}
        else{fee = isPair[from] ? totalFees : totalFees + sellFeeIncrease;
            return (fee, false);}
    }

    function shouldBurn() internal view returns (bool){
        uint256 contractTokenBalance = balanceOf(address(this));
        bool canBurn = contractTokenBalance >= burnAmount;
        return tradingIsEnabled && canBurn && accumulatingForBurn &&
        !inBurn;
    }

    function planBurn(uint256 burnNumerator, uint256 burnDenominator) external onlyAuthorized {
        uint256 burnAmt = TOTAL_SUPPLY * burnNumerator / burnDenominator;
        require(burnAmt <= 50 * TOTAL_SUPPLY / 1000, "burnAmount is limited to 5% in single transaction");
        burnAmount = burnAmt;
        accumulatingForBurn = true;
    }

    function doBurn(uint256 burnAmt) internal inburn {
        require(burnAmt <= 50 * TOTAL_SUPPLY / 1000, "burnAmount is limited to 5% in single transaction");
        super._transfer(address(this), deadAddress, burnAmt);
        accumulatingForBurn = false;
    }

    function shouldSwap(address from, address to, uint256 amount) internal view returns (bool){
        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
        bool aboveMin = amount >= minTokenstoSwap;
        bool swapTime = swapTimes >= minSells;
        return tradingIsEnabled && canSwap && !swapping && swapTime &&
        !isPair[from] && aboveMin && !isExcludedFromFees[from] && !isExcludedFromFees[to];
    }

    function rescueStuckBNB() external onlyAuthorized {
        uint256 bnbAmount = address(this).balance;
        payable(msg.sender).transfer(bnbAmount);
    }

    function rescueBEP20(address _token) external onlyAuthorized {
        uint256 tamt = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(msg.sender, tamt);
    }

    function swapTokens(uint256 tokens) internal inSwap {
        uint256 LPtokens = tokens * liquidityFee / totalFees / 2;
        uint256 swapAmount = tokens - LPtokens;
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(swapAmount);
        uint256 newBalance = address(this).balance - initialBalance;
        uint256 totalBNBFee = totalFees - (liquidityFee / 2);
        uint256 BNBForLP = newBalance * liquidityFee / totalBNBFee / 2;
        uint256 BNBForMarketing = newBalance * marketingFee / totalBNBFee;
        uint256 BNBForTreasury = newBalance * treasuryFee / totalBNBFee;
        uint256 BNBForRewards = newBalance * rewardsFee / totalBNBFee;
        uint256 BNBForDev = newBalance - BNBForLP - BNBForMarketing - BNBForTreasury - BNBForRewards;
        payable(marketingAddress).transfer(BNBForMarketing);
        payable(devAddress).transfer(BNBForDev);
        payable(treasuryAddress).transfer(BNBForTreasury);
        if(BNBForRewards > 0){
            try dividendDistributor.deposit{value: BNBForRewards}() {}catch{}
            emit SendDividends(BNBForRewards); }
        if(BNBForLP > 0){
            addLiquidity(LPtokens, BNBForLP);
            emit SwapAndLiquify(LPtokens, BNBForLP);}
        swapTimes = 0;
    }

    function swapTokensForEth(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
       uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            liquidityAddress,
            block.timestamp
        );
    }

    function buybackStuckBNB(uint256 percent) external onlyAuthorized {
        require(percent <= 100, "percent cannot be higher than 100");
        uint256 amountToBuyBack = address(this).balance * percent / 100;
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountToBuyBack}(
            0,
            path,
            deadAddress,
            block.timestamp
        );
    }

    receive() external payable {}
}