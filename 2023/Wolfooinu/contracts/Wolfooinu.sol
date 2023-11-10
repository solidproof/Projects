// ██████  ███████ ██    ██  ██████  ██      ██    ██ ███████ ██  ██████  ███    ██                   
// ██   ██ ██      ██    ██ ██    ██ ██      ██    ██     ██  ██ ██    ██ ████   ██                  
// ██████  █████   ██    ██ ██    ██ ██      ██    ██   ██    ██ ██    ██ ██ ██  ██                   
// ██   ██ ██       ██  ██  ██    ██ ██      ██    ██  ██     ██ ██    ██ ██  ██ ██                   
// ██   ██ ███████   ████    ██████  ███████  ██████  ███████ ██  ██████  ██   ████    

// SAFU CONTRACT BY REVOLUZION

// Revoluzion Ecosystem
// WEB: https://revoluzion.io
// DAPP: https://revoluzion.app

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

interface IPair {

    // FUNCTION

    function token0() external view returns (address);

    function token1() external view returns (address);
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

    function addLiquidityETH(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
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
    address public immutable reward;

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
        address rewardAddress,
        address newOwner, 
        address routerAddress
    ) Auth (newOwner) {
        if (tokenAddress == address(0)) { revert InvalidAddress(address(0)); }
        if (rewardAddress == address(0)) { revert InvalidAddress(address(0)); }
        token = tokenAddress;
        reward = rewardAddress;

        router = IRouter(routerAddress);
        shareholderClaims[newOwner] = 0;
        
        _transferOwnership(newOwner);
    }

    // EVENT

    event UpdateRouter(address oldRouter, address newRouter, uint256 timestamp);

    event UpdateMaxContinuousDistribution(uint256 oldMaxContinuousDistribution, uint256 newMaxContinuousDistribution, uint256 timestamp);

    event TotalSharesUpdates(uint256 initialTotal, uint256 totalShares, uint256 timestamp);

    // FUNCTION

    /* General */

    receive() external payable {}
    
    function rescue(address tokenAdr) external onlyOwner {
        address beneficiary = token;
        if (tokenAdr != token && tokenAdr != reward && tokenAdr != address(0)) {
            beneficiary = msg.sender;
        }
        if (tokenAdr == address(0)) {
            payable(beneficiary).transfer(address(this).balance);
            return;
        }
        IERC20(tokenAdr).transfer(beneficiary, IERC20(tokenAdr).balanceOf(address(this)));
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

    function updateRouter(address newRouter) external onlyOwner {
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
        IERC20(reward).transferFrom(token, address(this), amount);
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
            require(IERC20(reward).transfer(shareholder, amount), "Distribute Reward: There's something wrong with transfer function.");
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
            require(IERC20(reward).transfer(shareholder, amount), "Tally Reward: There's something wrong with transfer function.");
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

contract WolfooInu is Auth, ICommonError, IERC20 {

    // DATA

    struct Fee {
        uint256 reward;
        uint256 liquidity;
        uint256 marketing;
    }

    IRouter public router;

    IRewardDistributor public distributor;

    string private constant NAME = "Wolfoo Inu";
    string private constant SYMBOL = "WOLFOO";

    uint8 private constant DECIMALS = 9;

    uint256 private _totalSupply;
    
    uint256 public constant FEEDENOMINATOR = 10_000;

    uint256 public totalFeeCollected = 0;
    uint256 public totalFeeRedeemed = 0;
    uint256 public distributorGas = 30_000;
    uint256 public minSwap = 10_000 gwei;

    Fee public buyFee = Fee(200, 200, 300);
    Fee public sellFee = Fee(200, 200, 300);
    Fee public transferFee = Fee(0, 0, 0);
    Fee public collectedFee = Fee(0, 0, 0);
    Fee public redeemedFee = Fee(0, 0, 0);

    bool private constant ISWOLFOO = true;

    bool public tradeEnabled = false;
    bool public isRewardActive = false;
    bool public isFeeActive = false;
    bool public isFeeLocked = false;
    bool public isSwapEnabled = false;
    bool public inSwap = false;

    address public constant PROJECTOWNER = 0x33138fF0c72F8E46F28AE2e1b6f3A850D877defA;

    address public marketingReceiver = 0x33138fF0c72F8E46F28AE2e1b6f3A850D877defA;
    address public rewardToken = 0x55d398326f99059fF775485246999027B3197955;

    address public pair;
    
    // MAPPING

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isExcludeFromFees;
    mapping(address => bool) public isRewardExempt;
    mapping(address => bool) public isPairLP;

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

    error InvalidSwapEnabledState(bool current);

    error FeeLocked();

    error TradeEnabled();

    error TradeDisabled();

    error OwnerCannotDumpBeforeTrade();

    error CannotUseAllCurrentValue();

    // CONSTRUCTOR

    constructor() Auth (msg.sender) {
        _mint(msg.sender, 1_000_000_000 * 10**DECIMALS);

        router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IFactory(router.factory()).createPair(address(this), router.WETH());

        isPairLP[pair] = true;

        distributor = new RewardDistributor(address(this), rewardToken, msg.sender, address(router));

        isExcludeFromFees[msg.sender] = true;
        isExcludeFromFees[PROJECTOWNER] = true;
        isExcludeFromFees[address(router)] = true;
        isExcludeFromFees[address(distributor)] = true;

        isRewardExempt[pair] = true;
        isRewardExempt[address(0xdead)] = true;
        isRewardExempt[address(0)] = true;
        isRewardExempt[address(this)] = true;
        isRewardExempt[address(distributor)] = true;

        authorize(address(distributor));
    }

    // EVENT

    event UpdateRouter(address oldRouter, address newRouter, address caller, uint256 timestamp);

    event UpdateDistributor(address oldDistributor, address newDistributor, address caller, uint256 timestamp);

    event UpdateMinSwap(uint256 oldMinSwap, uint256 newMinSwap, address caller, uint256 timestamp);

    event UpdateDistributorGas(uint256 oldDistributorGas, uint256 newDistributorGas, address caller, uint256 timestamp);

    event UpdateRewardActive(bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event UpdateFeeActive(bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event UpdateFee(string feeType, uint256 oldMarketingFee, uint256 oldLiquidityFee, uint256 oldRewardFee, uint256 newMarketingFee, uint256 newLiquidityFee, uint256 newRewardFee, address caller, uint256 timestamp);

    event UpdateSwapEnabled(bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event UpdateMarketingReceiver(address oldReceiver, address newReceiver, address caller, uint256 timestamp);

    event AutoRedeem(uint256 marketingFeeDistribution, uint256 liquidityFeeDistribution, uint256 rewardFeeDistribution, uint256 amountToRedeem, address caller, uint256 timestamp);

    event EnableTrade(address caller, uint256 timestamp);

    event LockFee(address caller, uint256 timestamp);

    event SetPairLP(address pairAddress, bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    // FUNCTION

    /* General */

    receive() external payable {}

    function rescue(address tokenAdr) external onlyOwner {
        if (tokenAdr != address(this) && tokenAdr != rewardToken) {
            if (tokenAdr == address(0)) {
                payable(msg.sender).transfer(address(this).balance);
                return;
            }
            IERC20(tokenAdr).transfer(msg.sender, IERC20(tokenAdr).balanceOf(address(this)));
        }
    }

    function enableTrading() external onlyOwner {
        if (tradeEnabled) { revert InvalidTradeEnabledState(tradeEnabled); }
        if (isFeeActive) { revert InvalidFeeActiveState(isFeeActive); }
        if (isSwapEnabled) { revert InvalidSwapEnabledState(isSwapEnabled); }
        tradeEnabled = true;
        isFeeActive = true;
        isSwapEnabled = true;
        isRewardActive = true;
        emit EnableTrade(msg.sender, block.timestamp);
    }

    function lockFees() external onlyOwner {
        if (isFeeLocked) { revert FeeLocked(); }
        isFeeLocked = true;
        emit LockFee(msg.sender, block.timestamp);
    }

    /* Reward */

    function claimReward() external {
        if (!distributor.isRewardDistributor()) { revert InvalidRewardDistributor(distributor); }
        try distributor.distributeReward(msg.sender) {} catch {}
    }

    /* Redeem */

    function autoRedeem(uint256 amountToRedeem) public swapping {  
        uint256 marketingToRedeem = collectedFee.marketing - redeemedFee.marketing;
        uint256 liquidityToRedeem = collectedFee.liquidity - redeemedFee.liquidity;
        uint256 totalToRedeem = totalFeeCollected - totalFeeRedeemed;

        uint256 marketingFeeDistribution = amountToRedeem * marketingToRedeem / totalToRedeem;
        uint256 liquidityFeeDistribution = amountToRedeem * liquidityToRedeem / totalToRedeem;
        uint256 rewardFeeDistribution = amountToRedeem - marketingFeeDistribution - liquidityFeeDistribution;
        
        redeemedFee.marketing += marketingFeeDistribution;
        redeemedFee.liquidity += liquidityFeeDistribution;
        redeemedFee.reward += rewardFeeDistribution;
        totalFeeRedeemed += amountToRedeem;

        uint256 initialBalance = address(this).balance;
        uint256 firstLiquidityHalf = liquidityFeeDistribution / 2;
        uint256 secondLiquidityHalf = liquidityFeeDistribution - firstLiquidityHalf;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), amountToRedeem);
    
        emit AutoRedeem(marketingFeeDistribution, liquidityFeeDistribution, rewardFeeDistribution, amountToRedeem, msg.sender, block.timestamp);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            firstLiquidityHalf,
            0,
            path,
            address(this),
            block.timestamp
        );
        
        router.addLiquidityETH{
            value: address(this).balance - initialBalance
        }(
            address(this),
            secondLiquidityHalf,
            0,
            0,
            address(0xdead),
            block.timestamp + 1_200
        );

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            marketingFeeDistribution,
            0,
            path,
            marketingReceiver,
            block.timestamp
        );

        address[] memory path2 = new address[](3);
        path2[0] = address(this);
        path2[1] = router.WETH();
        path2[2] = address(rewardToken);

        router.swapExactTokensForTokens(
            rewardFeeDistribution,
            0,
            path2,
            address(this),
            block.timestamp
        );

        IERC20(rewardToken).approve(address(distributor), IERC20(rewardToken).balanceOf(address(this)));

        try distributor.deposit(IERC20(rewardToken).balanceOf(address(this))) {} catch {}
    }

    /* Check */

    function isWolfoo() external pure returns (bool) {
        return ISWOLFOO;
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(0xdead)) - balanceOf(address(0));
    }

    /* Update */

    function updateRewardContingencyAllowance(address account, uint256 amount) external onlyOwner {
        if (account == address(0)) { revert InvalidAddress(address(0)); }
        if (account == address(0xdead)) { revert InvalidAddress(address(0xdead)); }
        if (account != address(router) && account != address(distributor)) { revert InvalidAddress(account); }
        if (amount == 0) {
            IERC20(rewardToken).approve(account, type(uint256).max);
            return;
        }
        IERC20(rewardToken).approve(account, amount);
    }

    function resetRewardContingencyAllowance(address account) external onlyOwner {
        if (account == address(0)) { revert InvalidAddress(address(0)); }
        if (account == address(0xdead)) { revert InvalidAddress(address(0xdead)); }
        if (account != address(router) && account != address(distributor)) { revert InvalidAddress(account); }
        IERC20(rewardToken).approve(account, 0);
    }

    function updateRouter(address newRouter) external onlyOwner {
        if (address(router) == newRouter) { revert CannotUseCurrentAddress(newRouter); }
        address oldRouter = address(router);
        router = IRouter(newRouter);
        
        isExcludeFromFees[newRouter] = true;

        emit UpdateRouter(oldRouter, newRouter, msg.sender, block.timestamp);
        pair = IFactory(router.factory()).createPair(address(this), router.WETH());
        isPairLP[pair] = true;
    }

    function updateDistributor(address newDistributor) external onlyOwner {
        if (address(distributor) == newDistributor) { revert CannotUseCurrentAddress(newDistributor); }
        address oldDistributor = address(distributor);
        distributor = IRewardDistributor(newDistributor);
        
        isExcludeFromFees[newDistributor] = true;
        isRewardExempt[newDistributor] = true;

        emit UpdateDistributor(oldDistributor, newDistributor, msg.sender, block.timestamp);
    }

    function updateMinSwap(uint256 newMinSwap) external onlyOwner {
        if (minSwap == newMinSwap) { revert CannotUseCurrentValue(newMinSwap); }
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

    function updateBuyFee(uint256 newMarketingFee, uint256 newLiquidityFee, uint256 newRewardFee) external onlyOwner {
        if (isFeeLocked) { revert FeeLocked(); }
        if (newMarketingFee + newLiquidityFee + newRewardFee > 1000) { revert InvalidTotalFee(newMarketingFee + newLiquidityFee + newRewardFee, 1000); }
        if (newMarketingFee == buyFee.marketing && newLiquidityFee == buyFee.liquidity && newRewardFee == buyFee.reward) { revert CannotUseAllCurrentValue(); }
        uint256 oldMarketingFee = buyFee.marketing;
        uint256 oldLiquidityFee = buyFee.liquidity;
        uint256 oldRewardFee = buyFee.reward;
        buyFee.marketing = newMarketingFee;
        buyFee.liquidity = newLiquidityFee;
        buyFee.reward = newRewardFee;
        emit UpdateFee("buyFee", oldMarketingFee, oldLiquidityFee, oldRewardFee, newMarketingFee, newLiquidityFee, newRewardFee, msg.sender, block.timestamp);
    }

    function updateSellFee(uint256 newMarketingFee, uint256 newLiquidityFee, uint256 newRewardFee) external onlyOwner {
        if (isFeeLocked) { revert FeeLocked(); }
        if (newMarketingFee + newLiquidityFee + newRewardFee > 1000) { revert InvalidTotalFee(newMarketingFee + newLiquidityFee + newRewardFee, 1000); }
        if (newMarketingFee == sellFee.marketing && newLiquidityFee == sellFee.liquidity && newRewardFee == sellFee.reward) { revert CannotUseAllCurrentValue(); }
        uint256 oldMarketingFee = sellFee.marketing;
        uint256 oldLiquidityFee = sellFee.liquidity;
        uint256 oldRewardFee = sellFee.reward;
        sellFee.marketing = newMarketingFee;
        sellFee.liquidity = newLiquidityFee;
        sellFee.reward = newRewardFee;
        emit UpdateFee("sellFee", oldMarketingFee, oldLiquidityFee, oldRewardFee, newMarketingFee, newLiquidityFee, newRewardFee, msg.sender, block.timestamp);
    }

    function updateTransferFee(uint256 newMarketingFee, uint256 newLiquidityFee, uint256 newRewardFee) external onlyOwner {
        if (isFeeLocked) { revert FeeLocked(); }
        if (newMarketingFee + newLiquidityFee + newRewardFee > 1000) { revert InvalidTotalFee(newMarketingFee + newLiquidityFee + newRewardFee, 1000); }
        if (newMarketingFee == transferFee.marketing && newLiquidityFee == transferFee.liquidity && newRewardFee == transferFee.reward) { revert CannotUseAllCurrentValue(); }
        uint256 oldMarketingFee = transferFee.marketing;
        uint256 oldLiquidityFee = transferFee.liquidity;
        uint256 oldRewardFee = transferFee.reward;
        transferFee.marketing = newMarketingFee;
        transferFee.liquidity = newLiquidityFee;
        transferFee.reward = newRewardFee;
        emit UpdateFee("transferFee", oldMarketingFee, oldLiquidityFee, oldRewardFee, newMarketingFee, newLiquidityFee, newRewardFee, msg.sender, block.timestamp);
    }

    function updateFeeActive(bool newStatus) external authorized {
        if (isFeeLocked) { revert FeeLocked(); }
        if (isFeeActive == newStatus) { revert CannotUseCurrentState(newStatus); }
        bool oldStatus = isFeeActive;
        isFeeActive = newStatus;
        emit UpdateFeeActive(oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function updateRewardActive(bool newStatus) external authorized {
        if (isRewardActive == newStatus) { revert CannotUseCurrentState(newStatus); }
        bool oldStatus = isFeeActive;
        isFeeActive = newStatus;
        emit UpdateRewardActive(oldStatus, newStatus, msg.sender, block.timestamp);
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
    
    function setPairLP(address lpPair, bool newStatus) external onlyOwner {
        if (isPairLP[lpPair] == newStatus) { revert CannotUseCurrentState(newStatus); }
        if (IPair(lpPair).token0() != address(this) && IPair(lpPair).token1() != address(this)) { revert InvalidAddress(lpPair); }
        if (newStatus && !isRewardExempt[lpPair]) {
            isRewardExempt[lpPair] = true;
        }
        bool oldStatus = isPairLP[lpPair];
        isPairLP[lpPair] = newStatus;
        emit SetPairLP(lpPair, oldStatus, newStatus, msg.sender, block.timestamp);
    }

    /* Fee */

    function takeBuyFee(address from, uint256 amount) internal swapping returns (uint256) {
        uint256 feeTotal = buyFee.marketing + buyFee.liquidity + buyFee.reward;
        uint256 feeAmount = amount * feeTotal / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmount;
        tallyBuyFee(from, feeAmount, feeTotal);
        return newAmount;
    }

    function takeSellFee(address from, uint256 amount) internal swapping returns (uint256) {
        uint256 feeTotal = sellFee.marketing + sellFee.liquidity + sellFee.reward;
        uint256 feeAmount = amount * feeTotal / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmount;
        tallySellFee(from, feeAmount, feeTotal);
        return newAmount;
    }

    function takeTransferFee(address from, uint256 amount) internal swapping returns (uint256) {
        uint256 feeTotal = transferFee.marketing + transferFee.liquidity + transferFee.reward;
        uint256 feeAmount = amount * feeTotal / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmount;
        tallyTransferFee(from, feeAmount, feeTotal);
        return newAmount;
    }

    function tallyBuyFee(address from, uint256 amount, uint256 fee) internal swapping {
        uint256 collectMarketing = amount * buyFee.marketing / fee;
        uint256 collectLiquidity = amount * buyFee.liquidity / fee;
        uint256 collectReward = amount - collectMarketing - collectLiquidity;
        tallyCollection(collectMarketing, collectLiquidity, collectReward, amount);
        
        _balances[from] -= amount;
        _balances[address(this)] += amount;
    }

    function tallySellFee(address from, uint256 amount, uint256 fee) internal swapping {
        uint256 collectMarketing = amount * sellFee.marketing / fee;
        uint256 collectLiquidity = amount * sellFee.liquidity / fee;
        uint256 collectReward = amount - collectMarketing - collectLiquidity;
        tallyCollection(collectMarketing, collectLiquidity, collectReward, amount);
        
        _balances[from] -= amount;
        _balances[address(this)] += amount;
    }

    function tallyTransferFee(address from, uint256 amount, uint256 fee) internal swapping {
        uint256 collectMarketing = amount * transferFee.marketing / fee;
        uint256 collectLiquidity = amount * transferFee.liquidity / fee;
        uint256 collectReward = amount - collectMarketing - collectLiquidity;
        tallyCollection(collectMarketing, collectLiquidity, collectReward, amount);

        _balances[from] -= amount;
        _balances[address(this)] += amount;
    }

    function tallyCollection(uint256 collectMarketing, uint256 collectLiquidity, uint256 collectReward, uint256 amount) internal swapping {
        collectedFee.marketing += collectMarketing;
        collectedFee.liquidity += collectLiquidity;
        collectedFee.reward += collectReward;
        totalFeeCollected += amount;
    }

    /* Buyback */

    function triggerZeusBuyback(uint256 amount) external authorized {
        if (amount > 5 ether) { revert InvalidValue(5 ether); }
        buyTokens(amount, address(0xdead));
    }

    function buyTokens(uint256 amount, address to) internal swapping {
        if (msg.sender == address(0xdead)) { revert InvalidAddress(address(0xdead)); }
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amount
        }(0, path, to, block.timestamp);
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
        if (account == address(0)) { revert InvalidAddress(account); }

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _approve(address provider, address spender, uint256 amount) internal virtual {
        if (provider == address(0)) { revert InvalidAddress(provider); }
        if (spender == address(0)) { revert InvalidAddress(spender); }

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
        if (from == address(0)) { revert InvalidAddress(from); }
        if (to == address(0)) { revert InvalidAddress(to); }
        
        if (!tradeEnabled && !isExcludeFromFees[from] && !isExcludeFromFees[to]) {
            revert TradeDisabled();
        }

        if (!tradeEnabled && from == owner()) {
            revert OwnerCannotDumpBeforeTrade();
        }

        if (inSwap || isExcludeFromFees[from]) {
            return _basicTransfer(from, to, amount);
        }

        if (from != pair && isSwapEnabled && totalFeeCollected - totalFeeRedeemed >= minSwap && balanceOf(address(this)) >= minSwap) {
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
        if (isPairLP[from] && (buyFee.marketing + buyFee.liquidity + buyFee.reward > 0)) {
            return takeBuyFee(from, amount);
        }
        if (isPairLP[to] && (sellFee.marketing + sellFee.liquidity + sellFee.reward > 0)) {
            return takeSellFee(from, amount);
        }
        if (!isPairLP[from] && !isPairLP[to] && (transferFee.marketing + transferFee.liquidity + transferFee.reward > 0)) {
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