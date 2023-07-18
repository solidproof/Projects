// ██████  ███████ ██    ██  ██████  ██      ██    ██ ███████ ██  ██████  ███    ██                   
// ██   ██ ██      ██    ██ ██    ██ ██      ██    ██     ██  ██ ██    ██ ████   ██                  
// ██████  █████   ██    ██ ██    ██ ██      ██    ██   ██    ██ ██    ██ ██ ██  ██                   
// ██   ██ ██       ██  ██  ██    ██ ██      ██    ██  ██     ██ ██    ██ ██  ██ ██                   
// ██   ██ ███████   ████    ██████  ███████  ██████  ███████ ██  ██████  ██   ████    

// SAFU CONTRACT BY REVOLUZION

//Revoluzion Ecosystem
//WEB: https://revoluzion.io
//DAPP: https://revoluzion.app

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/********************************************************************************************
  INTERFACE
********************************************************************************************/

interface IERC20 {
    
    // EVENT 

    event Transfer(address indexed from, address indexed to, uint256 value);
    
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // FUNCTION

    function name() external view returns (string memory);
    
    function symbol() external view returns (string memory);
    
    function decimals() external view returns (uint8);
    
    function totalSupply() external view returns (uint256);
    
    function balanceOf(address account) external view returns (uint256);
    
    function transfer(address to, uint256 amount) external returns (bool);
    
    function allowance(address owner, address spender) external view returns (uint256);
    
    function approve(address spender, uint256 amount) external returns (bool);
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IFactory {

    // FUNCTION

    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IRouter {

    // FUNCTION

    function WETH() external pure returns (address);
        
    function factory() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external;
    
    function swapExactETHForTokensSupportingFeeOnTransferTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external payable;
    
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
}

interface IAuthError {

    // ERROR

    error InvalidOwner(address account);

    error UnauthorizedAccount(address account);

    error InvalidAuthorizedAccount(address account);

    error CurrentAuthorizedState(address account, bool state);
}

interface ICommonError {

    // ERROR

    error CannotUseCurrentAddress(address current);

    error CannotUseCurrentValue(uint256 current);

    error CannotUseCurrentState(bool current);

    error InvalidAddress(address invalid);

    error InvalidValue(uint256 invalid);
}

interface IRewardDistributor {

    // FUNCTION

    function isRewardDistributor() external pure returns (bool);
    
    function setDistributionCriteria(uint256 distribution) external;

    function setShare(address shareholder, uint256 amount) external;

    function deposit(uint256 amountToRedeem) external;

    function process(uint256 gas) external;

    function distributeReward(address shareholder) external;

}

/********************************************************************************************
  ACCESS
********************************************************************************************/

abstract contract Auth is IAuthError {
    
    // DATA

    address private _owner;

    // MAPPING

    mapping(address => bool) public authorization;

    // MODIFIER

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    modifier authorized() {
        _checkAuthorized();
        _;
    }

    // CONSTRUCCTOR

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
        authorization[initialOwner] = true;
        if (initialOwner != msg.sender) {
            authorization[msg.sender] = true;
        }
    }

    // EVENT
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event UpdateAuthorizedAccount(address authorizedAccount, address caller, bool state, uint256 timestamp);

    // FUNCTION
    
    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
    }

    function _checkAuthorized() internal view virtual {
        if (!authorization[msg.sender]) {
            revert UnauthorizedAccount(msg.sender);
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert InvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function authorize(address account) public virtual onlyOwner {
        if (account == address(0) || account == address(0xdead)) {
            revert InvalidAuthorizedAccount(account);
        }
        _authorization(account, msg.sender, true);
    }

    function unauthorize(address account) public virtual onlyOwner {
        if (account == address(0) || account == address(0xdead)) {
            revert InvalidAuthorizedAccount(account);
        }
        _authorization(account, msg.sender, false);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function _authorization(address account, address caller, bool state) internal virtual {
        if (authorization[account] == state) {
            revert CurrentAuthorizedState(account, state);
        }
        authorization[account] = state;
        emit UpdateAuthorizedAccount(account, caller, state, block.timestamp);
    }
}

/********************************************************************************************
  REWARD
********************************************************************************************/

contract RewardDistributor is Auth, ICommonError, IRewardDistributor {

    // DATA

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    IRouter public router;

    bool private constant ISREWARDDISTRIBUTOR = true;

    uint256 public minDistribution = 1 gwei;
    uint256 public maxContinuousDistribution = 10;
    uint256 public rewardsPerShare = 0;
    uint256 public currentIndex = 0;
    uint256 public totalShares = 0;
    uint256 public totalRewards = 0; 
    uint256 public totalDistributed = 0;

    uint256 public constant ACCURACY = 1_000_000_000_000_000_000 ether;

    address[] public shareholders;

    address public immutable token;

    // MAPPING

    mapping(address => Share) public shares;
    mapping(address => uint256) public shareholderIndexes;
    mapping(address => uint256) public shareholderClaims;

    // MODIFIER

    modifier onlyToken() {
        require(msg.sender == token);
        _;
    }

    // CONSTRUCTOR 

    constructor (
        address tokenAddress,
        address newOwner, 
        address routerAddress
    ) Auth (newOwner) {
        if (tokenAddress == address(0)) { revert InvalidAddress(address(0)); }
        token = tokenAddress;
        _transferOwnership(newOwner);

        router = IRouter(routerAddress);
        shareholderClaims[newOwner] = 0;
    }

    // EVENT

    event UpdateRouter(address oldRouter, address newRouter, uint256 timestamp);

    event UpdateMaxContinuousDistribution(uint256 oldMaxContinuousDistribution, uint256 newMaxContinuousDistribution, uint256 timestamp);

    event TotalSharesUpdates(uint256 initialTotal, uint256 totalShares, uint256 timestamp);

    // FUNCTION

    /* General */

    receive() external payable {}
    
    function wNative() external onlyOwner {
        address beneficiary = token;
        payable(beneficiary).transfer(address(this).balance);
    }

    function isRewardDistributor() external override pure returns (bool) {
        return ISREWARDDISTRIBUTOR;
    } 

    /* Update */

    function updateMaxContinuousDistribution(uint256 newMaxContinuousDistribution) external authorized {
        require(maxContinuousDistribution <= 20, "Update Max Continuous Distribution: Max distribution for reward should be lesser or equal to 20 at one time.");
        if (newMaxContinuousDistribution == maxContinuousDistribution) { revert CannotUseCurrentValue(newMaxContinuousDistribution); }
        uint256 oldMaxContinuousDistribution = maxContinuousDistribution;
        maxContinuousDistribution = newMaxContinuousDistribution;
        emit UpdateMaxContinuousDistribution(oldMaxContinuousDistribution, newMaxContinuousDistribution, block.timestamp);
    }

    function updateRouter(address newRouter) external authorized {
        if (address(router) == newRouter) { revert CannotUseCurrentAddress(newRouter); }
        address oldRouter = address(router);
        router = IRouter(newRouter);
        emit UpdateRouter(oldRouter, newRouter, block.timestamp);
    }

    function setDistributionCriteria(uint256 distributionMin) external override authorized {
        if (minDistribution == distributionMin) { revert CannotUseCurrentValue(distributionMin); }
        minDistribution = distributionMin;
    }

    /* Check */

    function shouldDistribute(address shareholder) internal view returns (bool) {
        return getUnpaidEarnings(shareholder) > minDistribution;
    }

    function getCumulativeRewards(uint256 share) internal view returns (uint256) {
        return share * rewardsPerShare / ACCURACY;
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if (shares[shareholder].amount == 0) {
            return 0;
        }

        uint256 shareholderTotalRewards = getCumulativeRewards(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if (shareholderTotalRewards <= shareholderTotalExcluded) {
            return 0;
        }

        return shareholderTotalRewards - shareholderTotalExcluded;
    }

    /* Reward */

    function deposit(uint256 amount) external override {
        totalRewards = totalRewards + amount;
        rewardsPerShare = rewardsPerShare + (ACCURACY * amount / totalShares);
        IERC20(token).transferFrom(address(token), address(this), amount);
    }

    function process(uint256 gas) external override {
        uint256 shareholderCount = shareholders.length;

        if (shareholderCount == 0) {
            return;
        }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;

        while (gasUsed < gas && iterations < maxContinuousDistribution && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex -= shareholderCount;
            }

            if (shouldDistribute(shareholders[currentIndex])) {
                distributeReward(shareholders[currentIndex]);
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            iterations++;
        }
        
    }

    function distributeReward(address shareholder) public {
        if (shares[shareholder].amount == 0) {
            return;
        }

        uint256 amount = getUnpaidEarnings(shareholder);
        
        if (amount > 0) {
            totalDistributed += amount;
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised + amount;
            shares[shareholder].totalExcluded = getCumulativeRewards(shares[shareholder].amount);
            require(IERC20(token).transfer(shareholder, amount), "Distribute Reward: There's something wrong with transfer function.");
        }
    }

    function tallyReward(uint256 initialShares, uint256 amount, address shareholder) internal {
        if (initialShares == 0) {
            return;
        }

        if (amount > 0) {
            totalDistributed += amount;
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised + amount;
            shares[shareholder].totalExcluded = getCumulativeRewards(initialShares);
            require(IERC20(token).transfer(shareholder, amount), "Tally Reward: There's something wrong with transfer function.");
        }
    }

    function claimReward() external {
        distributeReward(msg.sender);
    }

    /* Shares */
    
    function setShare(address shareholder, uint256 amount) external override onlyToken {
        uint256 initialShares = shares[shareholder].amount;
        uint256 unpaid = getUnpaidEarnings(shareholder);

        if (amount > 0 && shares[shareholder].amount == 0) {
            addShareholder(shareholder);
        } else if (amount == 0 && shares[shareholder].amount > 0) {
            removeShareholder(shareholder);
        }

        uint256 initialTotal = totalShares;
        totalShares = totalShares - shares[shareholder].amount + amount;
        emit TotalSharesUpdates(initialTotal, totalShares, block.timestamp);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeRewards(shares[shareholder].amount);

        if (initialShares > 0) {
            tallyReward(initialShares, unpaid, shareholder);
        }
    } 

    /* Shareholders */

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length - 1];
        shareholderIndexes[shareholders[shareholders.length - 1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
}

/********************************************************************************************
  TOKEN
********************************************************************************************/

contract EverRise2 is Auth, ICommonError, IERC20 {

    // DATA

    IRouter public router;

    IRewardDistributor public immutable distributor;

    string private constant NAME = "EverRise 2.0";
    string private constant SYMBOL = "RISE2.0";

    uint8 private constant DECIMALS = 18;

    uint256 private _totalSupply;
    
    uint256 public constant FEEDENOMINATOR = 10_000;
    uint256 public constant TRIGGERZEUSCOOLDOWN = 12 hours;

    uint256 public buyMarketingFee = 100;
    uint256 public buyBuybackFee = 100;
    uint256 public buyRewardFee = 100;
    uint256 public sellMarketingFee = 100;
    uint256 public sellBuybackFee = 100;
    uint256 public sellRewardFee = 100;
    uint256 public transferMarketingFee = 0;
    uint256 public transferBuybackFee = 0;
    uint256 public transferRewardFee = 0;
    uint256 public marketingFeeCollected = 0;
    uint256 public buybackFeeCollected = 0;
    uint256 public rewardFeeCollected = 0;
    uint256 public totalFeeCollected = 0;
    uint256 public marketingFeeRedeemed = 0;
    uint256 public buybackFeeRedeemed = 0;
    uint256 public rewardFeeRedeemed = 0;
    uint256 public totalFeeRedeemed = 0;
    uint256 public totalTriggerZeusBuyback = 0;
    uint256 public lastTriggerZeusTimestamp = 0;
    uint256 public distributorGas = 30_000;
    uint256 public minSwap = 100 ether;

    bool private constant ISRISE2 = true;

    bool public tradeEnabled = false;
    bool public presaleFinalized = false;
    bool public isRewardActive = false;
    bool public isFeeActive = false;
    bool public isFeeLocked = false;
    bool public isSwapEnabled = false;
    bool public inSwap = false;

    address public immutable projectOwner;

    address public constant ZERO = address(0);
    address public constant DEAD = address(0xdead);

    address public marketingReceiver = 0x60968dF59FDD7865aBb1fd837cD06504c6a1a65a;

    address public pair;
    address public presaleAddress;
    address public presaleFactory;
    
    // MAPPING

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isExcludeFromFees;
    mapping(address => bool) public isRewardExempt;

    // MODIFIER

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    // ERROR

    error InvalidRewardDistributor(IRewardDistributor distributorAddres);

    error InvalidTotalFee(uint256 current, uint256 max);

    error InvalidTradeEnabledState(bool current);

    error InvalidFeeActiveState(bool current);

    error InvalidRewardActiveState(bool current);

    error InvalidSwapEnabledState(bool current);

    error PresaleAlreadyFinalized(bool current);

    error TriggerZeusBuybackInCooldown(uint256 timeleft);

    error FeeLocked();

    // CONSTRUCTOR

    constructor(
        address routerAddress,
        address projectOwnerAddress
    ) Auth (msg.sender) {
        _mint(msg.sender, 100_000_000_000 * 10**DECIMALS);
        if (projectOwnerAddress == ZERO) { revert InvalidAddress(projectOwnerAddress); }
        projectOwner = projectOwnerAddress;

        distributor = new RewardDistributor(address(this), msg.sender, routerAddress);
        router = IRouter(routerAddress);
        pair = IFactory(router.factory()).createPair(address(this), router.WETH());

        isExcludeFromFees[msg.sender] = true;
        isExcludeFromFees[projectOwner] = true;
        isExcludeFromFees[address(router)] = true;
        isExcludeFromFees[address(distributor)] = true;

        isRewardExempt[pair] = true;
        isRewardExempt[DEAD] = true;
        isRewardExempt[ZERO] = true;
        isRewardExempt[address(this)] = true;
        isRewardExempt[address(distributor)] = true;

        authorize(address(distributor));
    }

    // EVENT

    event UpdateRouter(address oldRouter, address newRouter, address caller, uint256 timestamp);

    event UpdateMinSwap(uint256 oldMinSwap, uint256 newMinSwap, address caller, uint256 timestamp);

    event UpdateDistributorGas(uint256 oldDistributorGas, uint256 newDistributorGas, address caller, uint256 timestamp);

    event UpdateFeeActive(bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event UpdateBuyFee(uint256 oldBuyMarketingFee, uint256 oldBuyBuybackFee, uint256 oldBuyRewardFee, uint256 newBuyMarketingFee, uint256 newBuyBuybackFee, uint256 newBuyRewardFee, address caller, uint256 timestamp);

    event UpdateSellFee(uint256 oldSellMarketingFee, uint256 oldSellBuybackFee, uint256 oldSellRewardFee, uint256 newSellMarketingFee, uint256 newSellBuybackFee, uint256 newSellRewardFee, address caller, uint256 timestamp);

    event UpdateTransferFee(uint256 oldTransferMarketingFee, uint256 oldTransferBuybackFee, uint256 oldTransferRewardFee, uint256 newTransferMarketingFee, uint256 newTransferBuybackFee, uint256 newTransferRewardFee, address caller, uint256 timestamp);

    event UpdateSwapEnabled(bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event UpdateMarketingReceiver(address oldMarketingReceiver, address newMarketingReceiver, address caller, uint256 timestamp);
        
    event AutoRedeem(uint256 marketingFeeDistribution, uint256 buybackFeeDistribution, uint256 rewardFeeDistribution, uint256 amountToRedeem, address caller, uint256 timestamp);

    event SetPresaleAddress(address adr, address caller, uint256 timestamp);

    event SetPresaleFactory(address adr, address caller, uint256 timestamp);

    // FUNCTION

    /* General */

    receive() external payable {}

    function enableTrading() external onlyOwner {
        if (tradeEnabled) { revert InvalidTradeEnabledState(tradeEnabled); }
        if (isFeeActive) { revert InvalidFeeActiveState(isFeeActive); }
        if (isSwapEnabled) { revert InvalidSwapEnabledState(isSwapEnabled); }
        tradeEnabled = true;
        isFeeActive = true;
        isSwapEnabled = true;
        presaleFinalized = true;
        isRewardActive = true;
    }

    function finalizePresale() external authorized {
        if (presaleFinalized) { revert PresaleAlreadyFinalized(presaleFinalized); }
        if (isFeeActive) { revert InvalidFeeActiveState(isFeeActive); }
        if (isSwapEnabled) { revert InvalidSwapEnabledState(isSwapEnabled); }
        isFeeActive = true;
        isSwapEnabled = true;
        presaleFinalized = true;
    }

    function lockFees() external onlyOwner {
        if (isFeeLocked) { revert FeeLocked(); }
        isFeeLocked = true;
    }

    /* Reward */

    function claimReward() external {
        if (!distributor.isRewardDistributor()) { revert InvalidRewardDistributor(distributor); }
        try distributor.distributeReward(msg.sender) {} catch {}
    }

    /* Redeem */

    function redeemAllMarketingFee() external {
        uint256 amountToRedeem = marketingFeeCollected - marketingFeeRedeemed;
        
        _redeemMarketingFee(amountToRedeem);
    }

    function redeemPartialMarketingFee(uint256 amountToRedeem) external {
        require(amountToRedeem <= marketingFeeCollected - marketingFeeRedeemed, "Redeem Partial Marketing Fee: Insufficient marketing fee collected.");
        
        _redeemMarketingFee(amountToRedeem);
    }

    function _redeemMarketingFee(uint256 amountToRedeem) internal swapping { 
        marketingFeeRedeemed += amountToRedeem;
        totalFeeRedeemed += amountToRedeem;
 
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), amountToRedeem);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToRedeem,
            0,
            path,
            marketingReceiver,
            block.timestamp
        );
    }

    function redeemAllBuybackFee() external {
        uint256 amountToRedeem = buybackFeeCollected - buybackFeeRedeemed;
        
        _redeemBuybackFee(amountToRedeem);
    }

    function redeemPartialBuybackFee(uint256 amountToRedeem) external {
        require(amountToRedeem <= buybackFeeCollected - buybackFeeRedeemed, "Redeem Partial Buyback Fee: Insufficient marketing fee collected.");
        
        _redeemBuybackFee(amountToRedeem);
    }

    function _redeemBuybackFee(uint256 amountToRedeem) internal swapping { 
        buybackFeeRedeemed += amountToRedeem;
        totalFeeRedeemed += amountToRedeem;

        _basicTransfer(address(this), DEAD, amountToRedeem);
    }

    function redeemAllRewardFee() external {
        uint256 amountToRedeem = rewardFeeCollected - rewardFeeRedeemed;
        
        _redeemRewardFee(amountToRedeem);
    }

    function redeemPartialRewardFee(uint256 amountToRedeem) external {
        require(amountToRedeem <= rewardFeeCollected - rewardFeeRedeemed, "Redeem Partial Reward Fee: Insufficient reward fee collected.");
        
        _redeemRewardFee(amountToRedeem);
    }

    function _redeemRewardFee(uint256 amountToRedeem) internal swapping {        
        if (!distributor.isRewardDistributor()) { revert InvalidRewardDistributor(distributor); }
        rewardFeeRedeemed += amountToRedeem;
        totalFeeRedeemed += amountToRedeem;

        _approve(address(this), address(router), amountToRedeem);

        try distributor.deposit(amountToRedeem) {} catch {}
    }

    function autoRedeem(uint256 amountToRedeem) public swapping {  
        uint256 marketingToRedeem = marketingFeeCollected - marketingFeeRedeemed;
        uint256 buybackToRedeem = buybackFeeCollected - buybackFeeRedeemed;
        uint256 totalToRedeem = totalFeeCollected - totalFeeRedeemed;

        uint256 marketingFeeDistribution = amountToRedeem * marketingToRedeem / totalToRedeem;
        uint256 buybackFeeDistribution = amountToRedeem * buybackToRedeem / totalToRedeem;
        uint256 rewardFeeDistribution = amountToRedeem - marketingFeeDistribution - buybackFeeDistribution;
        
        marketingFeeRedeemed += marketingFeeDistribution;
        buybackFeeRedeemed += buybackFeeDistribution;
        rewardFeeRedeemed += rewardFeeDistribution;
        totalFeeRedeemed += amountToRedeem;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), amountToRedeem);
        
        emit AutoRedeem(marketingFeeDistribution, buybackFeeDistribution, rewardFeeDistribution, amountToRedeem, msg.sender, block.timestamp);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            marketingFeeDistribution,
            0,
            path,
            marketingReceiver,
            block.timestamp
        );

        _basicTransfer(address(this), DEAD, buybackFeeRedeemed);

        try distributor.deposit(rewardFeeDistribution) {} catch {}
    }

    /* Check */

    function isRise2() external pure returns (bool) {
        return ISRISE2;
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(DEAD) - balanceOf(ZERO);
    }

    /* Update */

    function updateRewardContingencyAllowance(uint256 amount) external onlyOwner {
        _approve(address(this), address(distributor), amount);
        _approve(address(this), address(router), amount);
    }

    function updateRewardContingencyMaxAllowance() external onlyOwner {
        _approve(address(this), address(distributor), type(uint256).max);
        _approve(address(this), address(router), type(uint256).max);
    }

    function resetRewardContingencyAllowance() external onlyOwner {
        _approve(address(this), address(distributor), 0);
        _approve(address(this), address(router), 0);
    }

    function updateRouter(address newRouter) external onlyOwner {
        if (address(router) == newRouter) { revert CannotUseCurrentAddress(newRouter); }
        address oldRouter = address(router);
        router = IRouter(newRouter);
        
        isExcludeFromFees[newRouter] = true;

        emit UpdateRouter(oldRouter, newRouter, msg.sender, block.timestamp);
        pair = IFactory(router.factory()).createPair(address(this), router.WETH());
    }

    function updateMinSwap(uint256 newMinSwap) external onlyOwner {
        if (minSwap == newMinSwap) { revert CannotUseCurrentValue(newMinSwap); }
        if (minSwap < 100 * 10**DECIMALS) { revert InvalidValue(100 * 10**DECIMALS); }
        uint256 oldMinSwap = minSwap;
        minSwap = newMinSwap;
        emit UpdateMinSwap(oldMinSwap, newMinSwap, msg.sender, block.timestamp);
    }

    function updateDistributorGas(uint256 newDistributorGas) external authorized {
        if (distributorGas == newDistributorGas) { revert CannotUseCurrentValue(newDistributorGas); }
        if (distributorGas < 10_000) { revert InvalidValue(10_000); }
        if (distributorGas > 750_000) { revert InvalidValue(750_000); }
        uint256 oldDistributorGas = distributorGas;
        distributorGas = newDistributorGas;
        emit UpdateDistributorGas(oldDistributorGas, newDistributorGas, msg.sender, block.timestamp);
    }

    function updateBuyFee(uint256 newMarketingFee, uint256 newBuybackFee, uint256 newRewardFee) external onlyOwner {
        if (isFeeLocked) { revert FeeLocked(); }
        if (newMarketingFee + newBuybackFee + newRewardFee > 1000) { revert InvalidTotalFee(newMarketingFee + newBuybackFee + newRewardFee, 1000); }
        uint256 oldMarketingFee = buyMarketingFee;
        uint256 oldBuybackFee = buyBuybackFee;
        uint256 oldRewardFee = buyRewardFee;
        buyMarketingFee = newMarketingFee;
        buyBuybackFee = oldBuybackFee;
        buyRewardFee = newRewardFee;
        emit UpdateBuyFee(oldMarketingFee, oldRewardFee, oldBuybackFee, newMarketingFee, oldBuybackFee, newRewardFee, msg.sender, block.timestamp);
    }

    function updateSellFee(uint256 newMarketingFee, uint256 newBuybackFee, uint256 newRewardFee) external onlyOwner {
        if (isFeeLocked) { revert FeeLocked(); }
        if (newMarketingFee + newBuybackFee + newRewardFee > 1000) { revert InvalidTotalFee(newMarketingFee + newBuybackFee + newRewardFee, 1000); }
        uint256 oldMarketingFee = sellMarketingFee;
        uint256 oldBuybackFee = sellBuybackFee;
        uint256 oldRewardFee = sellRewardFee;
        sellMarketingFee = newMarketingFee;
        sellBuybackFee = newBuybackFee;
        sellRewardFee = newRewardFee;
        emit UpdateSellFee(oldMarketingFee, oldRewardFee, oldBuybackFee, newMarketingFee, oldBuybackFee, newRewardFee, msg.sender, block.timestamp);
    }

    function updateTransferFee(uint256 newMarketingFee, uint256 newBuybackFee, uint256 newRewardFee) external onlyOwner {
        if (isFeeLocked) { revert FeeLocked(); }
        if (newMarketingFee + newBuybackFee + newRewardFee > 1000) { revert InvalidTotalFee(newMarketingFee + newBuybackFee + newRewardFee, 1000); }
        uint256 oldMarketingFee = transferMarketingFee;
        uint256 oldBuybackFee = transferBuybackFee;
        uint256 oldRewardFee = transferRewardFee;
        transferMarketingFee = newMarketingFee;
        transferBuybackFee = newBuybackFee;
        transferRewardFee = newRewardFee;
        emit UpdateTransferFee(oldMarketingFee, oldRewardFee, oldBuybackFee, newMarketingFee, oldBuybackFee, newRewardFee, msg.sender, block.timestamp);
    }

    function updateFeeActive(bool newStatus) external authorized {
        if (isFeeActive == newStatus) { revert CannotUseCurrentState(newStatus); }
        bool oldStatus = isFeeActive;
        isFeeActive = newStatus;
        emit UpdateFeeActive(oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function updateSwapEnabled(bool newStatus) external authorized {
        if (isSwapEnabled == newStatus) { revert CannotUseCurrentState(newStatus); }
        bool oldStatus = isSwapEnabled;
        isSwapEnabled = newStatus;
        emit UpdateSwapEnabled(oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function updateMarketingReceiver(address newMarketingReceiver) external onlyOwner {
        if (marketingReceiver == newMarketingReceiver) { revert CannotUseCurrentAddress(newMarketingReceiver); }
        address oldMarketingReceiver = marketingReceiver;
        marketingReceiver = newMarketingReceiver;
        emit UpdateMarketingReceiver(oldMarketingReceiver, newMarketingReceiver, msg.sender, block.timestamp);
    }

    function setPresaleFactory(address adr) external authorized {
        if (presaleFinalized) { revert PresaleAlreadyFinalized(presaleFinalized); }
        if (adr == ZERO) { revert InvalidAddress(ZERO); }
        if (adr == presaleFactory) { revert CannotUseCurrentAddress(presaleFactory); }
        presaleFactory = adr;
        isExcludeFromFees[adr] = true;
        isRewardExempt[adr] = true;
        emit SetPresaleFactory(adr, msg.sender, block.timestamp);
    }

    function setPresaleAddress(address adr) external authorized {
        if (presaleFinalized) { revert PresaleAlreadyFinalized(presaleFinalized); }
        if (adr == ZERO) { revert InvalidAddress(ZERO); }
        if (adr == presaleAddress) { revert CannotUseCurrentAddress(presaleAddress); }
        presaleAddress = adr;
        isExcludeFromFees[adr] = true;
        isRewardExempt[adr] = true;
        emit SetPresaleAddress(adr, msg.sender, block.timestamp);
    }

    function setExcludeFromFees(address user, bool status) external authorized {
        if (isExcludeFromFees[user] == status) { revert CannotUseCurrentState(status); }
        isExcludeFromFees[user] = status;
    }

    function setExemptFromReward(address user, bool status) external authorized {
        if (isRewardExempt[user] == status) { revert CannotUseCurrentState(status); }
        isRewardExempt[user] = status;
    }
    
    function setDistributionCriteria(uint256 distributionMin) external authorized {
        if (!distributor.isRewardDistributor()) { revert InvalidRewardDistributor(distributor); }
        try distributor.setDistributionCriteria(distributionMin) {} catch {}
    }

    /* Fee */

    function takeBuyFee(address from, uint256 amount) internal swapping returns (uint256) {
        uint256 feeTotal = buyMarketingFee + buyBuybackFee + buyRewardFee;
        uint256 feeAmount = amount * feeTotal / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmount;
        tallyBuyFee(from, feeAmount, feeTotal);
        return newAmount;
    }

    function takeSellFee(address from, uint256 amount) internal swapping returns (uint256) {
        uint256 feeTotal = sellMarketingFee + sellBuybackFee + sellRewardFee;
        uint256 feeAmount = amount * feeTotal / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmount;
        tallySellFee(from, feeAmount, feeTotal);
        return newAmount;
    }

    function takeTransferFee(address from, uint256 amount) internal swapping returns (uint256) {
        uint256 feeTotal = transferMarketingFee + sellBuybackFee + transferRewardFee;
        uint256 feeAmount = amount * feeTotal / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmount;
        tallyTransferFee(from, feeAmount, feeTotal);
        return newAmount;
    }

    function tallyBuyFee(address from, uint256 amount, uint256 fee) internal swapping {
        uint256 collectMarketing = amount * buyMarketingFee / fee;
        uint256 collectBuyback = amount * buyBuybackFee / fee;
        uint256 collectReward = amount - collectMarketing - collectBuyback;
        tallyCollection(collectMarketing, collectBuyback, collectReward, amount);
        
        _balances[from] -= amount;
        _balances[address(this)] += amount;
    }

    function tallySellFee(address from, uint256 amount, uint256 fee) internal swapping {
        uint256 collectMarketing = amount * sellMarketingFee / fee;
        uint256 collectBuyback = amount * sellBuybackFee / fee;
        uint256 collectReward = amount - collectMarketing - collectBuyback;
        tallyCollection(collectMarketing, collectBuyback, collectReward, amount);
        
        _balances[from] -= amount;
        _balances[address(this)] += amount;
    }

    function tallyTransferFee(address from, uint256 amount, uint256 fee) internal swapping {
        uint256 collectMarketing = amount * transferMarketingFee / fee;
        uint256 collectBuyback = amount * transferBuybackFee / fee;
        uint256 collectReward = amount - collectMarketing - collectBuyback;
        tallyCollection(collectMarketing, collectBuyback, collectReward, amount);

        _balances[from] -= amount;
        _balances[address(this)] += amount;
    }

    function tallyCollection(uint256 collectMarketing, uint256 collectBuyback, uint256 collectReward, uint256 amount) internal swapping {
        marketingFeeCollected += collectMarketing;
        buybackFeeCollected += collectBuyback;
        rewardFeeCollected += collectReward;
        totalFeeCollected += amount;
    }

    /* Buyback */

    function triggerZeusBuyback(uint256 amount) external authorized {
        if (amount > 5 ether) { revert InvalidValue(5 ether); }
        if (block.timestamp - lastTriggerZeusTimestamp < TRIGGERZEUSCOOLDOWN) { revert TriggerZeusBuybackInCooldown(block.timestamp - lastTriggerZeusTimestamp); }
        buyTokens(amount, DEAD);
        totalTriggerZeusBuyback += amount;
        lastTriggerZeusTimestamp = block.timestamp;
    }

    function buyTokens(uint256 amount, address to) internal swapping {
        if (msg.sender == DEAD) { revert InvalidAddress(DEAD); }
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amount
        } (0, path, to, block.timestamp);
    }

    /* ERC20 Standard */

    function name() external view virtual override returns (string memory) {
        return NAME;
    }
    
    function symbol() external view virtual override returns (string memory) {
        return SYMBOL;
    }
    
    function decimals() external view virtual override returns (uint8) {
        return DECIMALS;
    }
    
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 amount) external virtual override returns (bool) {
        address provider = msg.sender;
        return _transfer(provider, to, amount);
    }
    
    function allowance(address provider, address spender) public view virtual override returns (uint256) {
        return _allowances[provider][spender];
    }
    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address provider = msg.sender;
        _approve(provider, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        return _transfer(from, to, amount);
    }
    
    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        address provider = msg.sender;
        _approve(provider, spender, allowance(provider, spender) + addedValue);
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        address provider = msg.sender;
        uint256 currentAllowance = allowance(provider, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(provider, spender, currentAllowance - subtractedValue);
        }

        return true;
    }
    
    function _mint(address account, uint256 amount) internal virtual {
        if (account == ZERO) { revert InvalidAddress(account); }

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _approve(address provider, address spender, uint256 amount) internal virtual {
        if (provider == ZERO) { revert InvalidAddress(provider); }
        if (spender == ZERO) { revert InvalidAddress(spender); }

        _allowances[provider][spender] = amount;
        emit Approval(provider, spender, amount);
    }
    
    function _spendAllowance(address provider, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(provider, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(provider, spender, currentAllowance - amount);
            }
        }
    }

    /* Additional */

    function _basicTransfer(address from, address to, uint256 amount ) internal returns (bool) {
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
        return true;
    }
    
    /* Overrides */
 
    function _transfer(address from, address to, uint256 amount) internal virtual returns (bool) {
        if (from == ZERO) { revert InvalidAddress(from); }
        if (to == ZERO) { revert InvalidAddress(to); }
        
        if (!tradeEnabled) {
            require(msg.sender == projectOwner || msg.sender == presaleFactory || msg.sender == owner() || msg.sender == presaleAddress, "ERC20: Only operator, owner or presale addresses can call this function since trading is not yet enabled.");

            if (from == owner()) {
                require(to != pair, "ERC20: Owner and operator are not allowed to sell if trading is not yet enabled.");
            }
        }

        if (inSwap || isExcludeFromFees[from]) {
            return _basicTransfer(from, to, amount);
        }

        if (from != pair && isSwapEnabled && totalFeeCollected - totalFeeRedeemed >= minSwap) {
            autoRedeem(minSwap);
        }

        uint256 newAmount = amount;

        if (isFeeActive && !isExcludeFromFees[from] && !isExcludeFromFees[to]) {
            newAmount = _beforeTokenTransfer(from, to, amount);
        }

        require(_balances[from] >= newAmount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = _balances[from] - newAmount;
            _balances[to] += newAmount;
        }

        emit Transfer(from, to, newAmount);

        if (isRewardActive) {
            _afterTokenTransfer(from, to);
        }

        return true;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal swapping virtual returns (uint256) {
        if (from == pair && (buyMarketingFee + buyRewardFee > 0)) {
            return takeBuyFee(from, amount);
        }
        if (to == pair && (sellMarketingFee + sellRewardFee > 0)) {
            return takeSellFee(from, amount);
        }
        if (from != pair && to != pair && (transferMarketingFee + transferRewardFee > 0)) {
            return takeTransferFee(from, amount);
        }
        return amount;
    }

    function _afterTokenTransfer(address from, address to) internal virtual {
        if (!distributor.isRewardDistributor()) { revert InvalidRewardDistributor(distributor); }

        if (!isRewardExempt[from]) {
            try distributor.setShare(from, _balances[from]) {} catch {}
        }
        if (!isRewardExempt[to]) {
            try distributor.setShare(to, _balances[to]) {} catch {}
        }

        try distributor.process(distributorGas) {} catch {}
    }

}