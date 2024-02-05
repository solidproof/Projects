/**
 *Submitted for verification at BscScan.com on 2023-12-13
*/

// ██████  ███████ ██    ██  ██████  ██      ██    ██ ███████ ██  ██████  ███    ██
// ██   ██ ██      ██    ██ ██    ██ ██      ██    ██     ██  ██ ██    ██ ████   ██
// ██████  █████   ██    ██ ██    ██ ██      ██    ██   ██    ██ ██    ██ ██ ██  ██
// ██   ██ ██       ██  ██  ██    ██ ██      ██    ██  ██     ██ ██    ██ ██  ██ ██
// ██   ██ ███████   ████    ██████  ███████  ██████  ███████ ██  ██████  ██   ████

// SAFU CONTRACT DEVELOPED BY REVOLUZION

// Revoluzion Ecosystem
// WEB: https://revoluzion.io
// DAPP: https://revoluzion.app

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/********************************************************************************************
  INTERFACE
********************************************************************************************/

interface IRouter {

    // FUNCTION

    function WETH() external pure returns (address);
        
    function factory() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external;
    
    function swapExactETHForTokensSupportingFeeOnTransferTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external payable;
    
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);

    function addLiquidityETH(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
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

interface IERC20 {
    
    // EVENT

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    // FUNCTION

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC20Metadata is IERC20 {

    // FUNCTION

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

interface IERC20Errors {
    
    // ERROR

    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    error ERC20InvalidSender(address sender);

    error ERC20InvalidReceiver(address receiver);

    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    error ERC20InvalidApprover(address approver);

    error ERC20InvalidSpender(address spender);
}

interface ICommonError {

    // ERROR

    error CannotUseAllCurrentAddress();

    error CannotUseAllCurrentValue();

    error CannotUseAllCurrentState();

    error CannotUseCurrentAddress(address current);

    error CannotUseCurrentValue(uint256 current);

    error CannotUseCurrentState(bool current);

    error InvalidAddress(address invalid);

    error InvalidValue(uint256 invalid);
}

/********************************************************************************************
  ACCESS
********************************************************************************************/

abstract contract Ownable {

    // DATA

    address private _owner;

    // MODIFIER

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    // ERROR

    error OwnableUnauthorizedAccount(address account);

    error OwnableInvalidOwner(address owner);

    // CONSTRUCTOR

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }
    
    // EVENT
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // FUNCTION

    function owner() public view virtual returns (address) {
        return _owner;
    }
    
    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }
    
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }
    
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/********************************************************************************************
  TOKEN
********************************************************************************************/

contract GrokCat is Ownable, IERC20Metadata, IERC20Errors, ICommonError {

    // DATA

    struct Fee {
        uint256 marketing;
        uint256 liquidity;
    }

    Fee public buyFee = Fee(300, 100);
    Fee public sellFee = Fee(300, 100);
    Fee public transferFee = Fee(300, 100);
    Fee public collectedFee = Fee(0, 0);
    Fee public redeemedFee = Fee(0, 0);

    IRouter public router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    
    string private constant NAME = "GrokCat";
    string private constant SYMBOL = "GrokCat";

    uint8 private constant DECIMALS = 9;

    uint256 public constant FEEDENOMINATOR = 10_000;

    uint256 private _totalSupply;
    
    uint256 public tradeStartTime = 0;
    uint256 public totalTriggerZeusBuyback = 0;
    uint256 public lastTriggerZeusTimestamp = 0;
    uint256 public totalFeeCollected = 0;
    uint256 public totalFeeRedeemed = 0;
    uint256 public minSwap = 1_000_000 gwei;

    address public projectOwner = 0x8580efc8D16E4D46F226a5581f5498986e0BA4aF;
    address public marketingReceiver = 0xA413212AF08071A932799e68eCCC000C7DB5Ea4B;
    
    address public pair;
    
    bool public tradeEnabled = false;
    bool public isFeeActive = false;
    bool public isFeeLocked = false;
    bool public isReceiverLocked = false;
    bool public isSwapEnabled = false;
    bool public inSwap = false;

    // MAPPING

    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256)) private _allowances;
    mapping(address account => bool) public isExcludeFromFees;
    mapping(address pair => bool) public isPairLP;

    // MODIFIER

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    // ERROR

    error TradeAlreadyEnabled(bool currentState, uint256 timestamp);

    error AlreadyCurrentState(string stateType, bool state);

    error InvalidTotalFee(uint256 current, uint256 max);

    error OnlyWalletAddressAllowed();
    
    error CannotWithdrawNativeToken();

    error FeeLocked();

    error ReceiverLocked();

    error TradeNotYetEnabled();

    error ProjectOwnerCannotInitiateTransferEther();
    
    // CONSTRUCTOR

    constructor() Ownable (msg.sender) {        
        _mint(msg.sender, 10_000_000_000 * 10**DECIMALS);

        pair = IFactory(router.factory()).createPair(address(this), router.WETH());
        isPairLP[pair] = true;

        isExcludeFromFees[msg.sender] = true;
        isExcludeFromFees[projectOwner] = true;
        isExcludeFromFees[address(router)] = true;
    }

    // EVENT

    event AutoRedeem(uint256 marketingFeeDistribution, uint256 liquidityFeeDistribution, uint256 amountToRedeem, address caller, uint256 timestamp);

    event TradeEnabled(address caller, uint256 timestamp);

    event Lock(string lockType, address caller, uint256 timestamp);

    event SetAddressState(string stateType, address adr, bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event UpdateState(string stateStype, bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event UpdateFee(string feeType, uint256 oldMarketingFee, uint256 oldLiquidityFee, uint256 newMarketingFee, uint256 newLiquidityFee, address caller, uint256 timestamp);

    event UpdateReceiver(string receiverType, address oldReceiver, address newReceiver, address caller, uint256 timestamp);

    event UpdateMinSwap(uint256 oldMinSwap, uint256 newMinSwap, address caller, uint256 timestamp);

    event UpdateRouter(address oldRouter, address newRouter, address caller, uint256 timestamp);


    // FUNCTION

    /* General */
    
    receive() external payable {}

    function wTokens(address tokenAddress, uint256 amount) external {
        uint256 toTransfer = amount;
        
        if (tokenAddress == address(this)) {
            revert CannotWithdrawNativeToken();
        } else if (tokenAddress == address(0)) {
            if (amount == 0) {
                toTransfer = address(this).balance;
            }
            if (msg.sender == projectOwner) {
                revert ProjectOwnerCannotInitiateTransferEther();
            }
            payable(projectOwner).transfer(toTransfer);
        } else {
            if (amount == 0) {
                toTransfer = IERC20(tokenAddress).balanceOf(address(this));
            }
            require(
                IERC20(tokenAddress).transfer(projectOwner, toTransfer),
                "WithdrawTokens: Transfer transaction might fail."
            );
        }
    }

    function enableTrading() external onlyOwner {
        if (tradeEnabled) {
            revert TradeAlreadyEnabled(tradeEnabled, tradeStartTime);
        }
        if (isFeeActive) {
            revert AlreadyCurrentState("isFeeActive", isFeeActive);
        }
        if (isSwapEnabled) {
            revert AlreadyCurrentState("isSwapEnabled", isSwapEnabled);
        }
        
        tradeEnabled = true;
        isFeeActive = true;
        isSwapEnabled = true;
        tradeStartTime = block.timestamp;

        emit TradeEnabled(msg.sender, block.timestamp);
    }

    function circulatingSupply() public view returns (uint256) {
        return totalSupply() - balanceOf(address(0xdead)) - balanceOf(address(0));
    }

    /* Redeem */

    function autoRedeem(uint256 amountToRedeem) public swapping { 
        uint256 marketingToRedeem = collectedFee.marketing - redeemedFee.marketing;
        uint256 totalToRedeem = totalFeeCollected - totalFeeRedeemed;
        
        uint256 marketingFeeDistribution = amountToRedeem * marketingToRedeem / totalToRedeem;
        uint256 liquidityFeeDistribution = amountToRedeem - marketingFeeDistribution;

        redeemedFee.marketing += marketingFeeDistribution;
        redeemedFee.liquidity += liquidityFeeDistribution;
        totalFeeRedeemed += amountToRedeem;

        uint256 initialBalance = address(this).balance;
        uint256 firstLiquidityHalf = liquidityFeeDistribution / 2;
        uint256 secondLiquidityHalf = liquidityFeeDistribution - firstLiquidityHalf;
        
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), amountToRedeem);
    
        emit AutoRedeem(marketingFeeDistribution, liquidityFeeDistribution, amountToRedeem, msg.sender, block.timestamp);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            firstLiquidityHalf,
            0,
            path,
            address(this),
            block.timestamp
        );

        router.addLiquidityETH{
            value: address(this).balance - initialBalance
        } (
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
    }

    /* Update */
    
    function lockFees() external onlyOwner {
        if (isFeeLocked) {
            revert FeeLocked();
        }
        isFeeLocked = true;
        emit Lock("isFeeLocked", msg.sender, block.timestamp);
    }
    
    function lockReceivers() external onlyOwner {
        if (isReceiverLocked) {
            revert ReceiverLocked();
        }
        isReceiverLocked = true;
        emit Lock("isReceiverLocked", msg.sender, block.timestamp);
    }

    function updateMinSwap(uint256 newMinSwap) external onlyOwner {
        if (newMinSwap > circulatingSupply() * 2_500 / FEEDENOMINATOR) {
            revert InvalidValue(newMinSwap);
        }
        if (minSwap == newMinSwap) {
            revert CannotUseCurrentValue(newMinSwap);
        }
        uint256 oldMinSwap = minSwap;
        minSwap = newMinSwap;
        emit UpdateMinSwap(oldMinSwap, newMinSwap, msg.sender, block.timestamp);
    }

    function updateFeeActive(bool newStatus) external onlyOwner {
        if (isFeeLocked) {
            revert FeeLocked();
        }
        if (isFeeActive == newStatus) {
            revert CannotUseCurrentState(newStatus);
        }
        bool oldStatus = isFeeActive;
        isFeeActive = newStatus;
        emit UpdateState("isFeeActive", oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function updateSwapEnabled(bool newStatus) external onlyOwner {
        if (isSwapEnabled == newStatus) {
            revert CannotUseCurrentState(newStatus);
        }
        bool oldStatus = isSwapEnabled;
        isSwapEnabled = newStatus;
        emit UpdateState("isSwapEnabled", oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function updateRouter(address newRouter) external onlyOwner {
        if (newRouter == address(router)) {
            revert CannotUseCurrentAddress(newRouter);
        }

        address oldRouter = address(router);
        router = IRouter(newRouter);
        isExcludeFromFees[newRouter] = true;

        emit UpdateRouter(oldRouter, newRouter, msg.sender, block.timestamp);

        pair = IFactory(router.factory()).createPair(address(this), router.WETH());
        isPairLP[pair] = true;
    }

    function updateBuyFee(uint256 newMarketingFee, uint256 newLiquidityFee) external onlyOwner {
        if (isFeeLocked) {
            revert FeeLocked();
        }
        if (newMarketingFee + newLiquidityFee > 1000) {
            revert InvalidTotalFee(newMarketingFee + newLiquidityFee, 1000);
        }
        if (newMarketingFee == buyFee.marketing && newLiquidityFee == buyFee.liquidity) {
            revert CannotUseAllCurrentValue();
        }
        uint256 oldMarketingFee = buyFee.marketing;
        uint256 oldLiquidityFee = buyFee.liquidity;
        buyFee.marketing = newMarketingFee;
        buyFee.liquidity = newLiquidityFee;
        emit UpdateFee("buyFee", oldMarketingFee, oldLiquidityFee, newMarketingFee, newLiquidityFee, msg.sender, block.timestamp);
    }

    function updateSellFee(uint256 newMarketingFee, uint256 newLiquidityFee) external onlyOwner {
        if (isFeeLocked) {
            revert FeeLocked();
        }
        if (newMarketingFee + newLiquidityFee > 1000) {
            revert InvalidTotalFee(newMarketingFee + newLiquidityFee, 1000);
        }
        if (newMarketingFee == sellFee.marketing && newLiquidityFee == sellFee.liquidity) {
            revert CannotUseAllCurrentValue();
        }
        uint256 oldMarketingFee = sellFee.marketing;
        uint256 oldLiquidityFee = sellFee.liquidity;
        sellFee.marketing = newMarketingFee;
        sellFee.liquidity = newLiquidityFee;
        emit UpdateFee("sellFee", oldMarketingFee, oldLiquidityFee, newMarketingFee, newLiquidityFee, msg.sender, block.timestamp);
    }

    function updateTransferFee(uint256 newMarketingFee, uint256 newLiquidityFee) external onlyOwner {
        if (isFeeLocked) {
            revert FeeLocked();
        }
        if (newMarketingFee + newLiquidityFee > 1000) {
            revert InvalidTotalFee(newMarketingFee + newLiquidityFee, 1000);
        }
        if (newMarketingFee == transferFee.marketing && newLiquidityFee == transferFee.liquidity) {
            revert CannotUseAllCurrentValue();
        }
        uint256 oldMarketingFee = transferFee.marketing;
        uint256 oldLiquidityFee = transferFee.liquidity;
        transferFee.marketing = newMarketingFee;
        transferFee.liquidity = newLiquidityFee;
        emit UpdateFee("transferFee", oldMarketingFee, oldLiquidityFee, newMarketingFee, newLiquidityFee, msg.sender, block.timestamp);
    }

    function updateMarketingReceiver(address newMarketingReceiver) external onlyOwner {
        if (isReceiverLocked) {
            revert ReceiverLocked();
        }
        if (newMarketingReceiver == address(0)) {
            revert InvalidAddress(address(0));
        }
        if (marketingReceiver == newMarketingReceiver) {
            revert CannotUseCurrentAddress(newMarketingReceiver);
        }
        if (newMarketingReceiver.code.length > 0) {
            revert OnlyWalletAddressAllowed();
        }
        address oldMarketingReceiver = marketingReceiver;
        marketingReceiver = newMarketingReceiver;
        emit UpdateReceiver("marketingReceiver", oldMarketingReceiver, newMarketingReceiver, msg.sender, block.timestamp);
    }

    function setPairLP(address lpPair, bool newStatus) external onlyOwner {
        if (isPairLP[lpPair] == newStatus) {
            revert CannotUseCurrentState(newStatus);
        }
        if (IPair(lpPair).token0() != address(this) && IPair(lpPair).token1() != address(this)) {
            revert InvalidAddress(lpPair);
        }
        bool oldStatus = isPairLP[lpPair];
        isPairLP[lpPair] = newStatus;
        emit SetAddressState("isPairLP", lpPair, oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function setExcludeFromFees(address user, bool newStatus) external onlyOwner {
        if (isExcludeFromFees[user] == newStatus) {
            revert CannotUseCurrentState(newStatus);
        }
        bool oldStatus = isExcludeFromFees[user];
        isExcludeFromFees[user] = newStatus;
        emit SetAddressState("isExcludeFromFees", user, oldStatus, newStatus, msg.sender, block.timestamp);
    }

    /* Fee */

    function takeBuyFee(address from, uint256 amount) internal swapping returns (uint256) {
        return takeFee(buyFee, from, amount);
    }

    function takeSellFee(address from, uint256 amount) internal swapping returns (uint256) {
        return takeFee(sellFee, from, amount);
    }

    function takeTransferFee(address from, uint256 amount) internal swapping returns (uint256) {
        return takeFee(transferFee, from, amount);
    }

    function takeFee(Fee memory feeType, address from, uint256 amount) internal swapping returns (uint256) {
        uint256 feeTotal = feeType.marketing + feeType.liquidity;
        uint256 feeAmount = amount * feeTotal / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmount;
        if (feeAmount > 0) {
            tallyFee(feeType, from, feeAmount, feeTotal);
        }
        return newAmount;
    }

    function tallyFee(Fee memory feeType, address from, uint256 amount, uint256 fee) internal swapping {
        uint256 collectMarketing = amount * feeType.marketing / fee;
        uint256 collectLiquidity = amount - collectMarketing;
        tallyCollection(collectMarketing, collectLiquidity, amount);
        
        _update(from, address(this), amount);
    }

    function tallyCollection(uint256 collectMarketing, uint256 collectLiquidity, uint256 amount) internal swapping {
        collectedFee.marketing += collectMarketing;
        collectedFee.liquidity += collectLiquidity;
        totalFeeCollected += amount;
    }

    /* Buyback */

    function triggerZeusBuyback(uint256 amount) external onlyOwner {
        if (amount > 5 ether) {
            revert InvalidValue(5 ether);
        }
        totalTriggerZeusBuyback += amount;
        lastTriggerZeusTimestamp = block.timestamp;
        buyTokens(amount, address(0xdead));
    }

    function buyTokens(uint256 amount, address to) internal swapping {
        if (msg.sender == address(0xdead)) { revert InvalidAddress(address(0xdead)); }
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amount
        } (0, path, to, block.timestamp);
    }

    /* ERC20 Standard */

    function name() public view virtual returns (string memory) {
        return NAME;
    }

    function symbol() public view virtual returns (string memory) {
        return SYMBOL;
    }

    function decimals() public view virtual returns (uint8) {
        return DECIMALS;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address provider = msg.sender;
        _transfer(provider, to, value);
        return true;
    }

    function allowance(address provider, address spender) public view virtual returns (uint256) {
        return _allowances[provider][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        address provider = msg.sender;
        _approve(provider, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    function _approve(address provider, address spender, uint256 value) internal {
        _approve(provider, spender, value, true);
    }

    function _approve(address provider, address spender, uint256 value, bool emitEvent) internal virtual {
        if (provider == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[provider][spender] = value;
        if (emitEvent) {
            emit Approval(provider, spender, value);
        }
    }

    function _spendAllowance(address provider, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(provider, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(provider, spender, currentAllowance - value, false);
            }
        }
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        if (!tradeEnabled && !isExcludeFromFees[from] && !isExcludeFromFees[to]) {
            revert TradeNotYetEnabled();
        }
        if (inSwap || isExcludeFromFees[from]) {
            return _update(from, to, value);
        }
        if (from != pair && isSwapEnabled && totalFeeCollected - totalFeeRedeemed >= minSwap && balanceOf(address(this)) >= minSwap) {
            autoRedeem(minSwap);
        }

        uint256 newValue = value;

        if (isFeeActive && !isExcludeFromFees[from] && !isExcludeFromFees[to]) {
            newValue = _beforeTokenTransfer(from, to, value);
        }

        _update(from, to, newValue);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal swapping virtual returns (uint256) {
        if (isPairLP[from] && (buyFee.marketing + buyFee.liquidity > 0)) {
            return takeBuyFee(from, amount);
        }
        if (isPairLP[to] && (sellFee.marketing + sellFee.liquidity > 0)) {
            return takeSellFee(from, amount);
        }
        if (!isPairLP[from] && !isPairLP[to] && (transferFee.marketing + transferFee.liquidity > 0)) {
            return takeTransferFee(from, amount);
        }
        return amount;
    }

    /* Override */
    
    function transferOwnership(address newOwner) public override onlyOwner {
        if (newOwner == owner()) {
            revert CannotUseCurrentAddress(newOwner);
        }
        if (newOwner == address(0xdead)) {
            revert InvalidAddress(newOwner);
        }
        projectOwner = newOwner;
        super.transferOwnership(newOwner);
    }

    /* ERC20 Extended */
    
    function increaseAllowance(address spender, uint256 value) external virtual returns (bool) {
        address provider = msg.sender;
        uint256 currentAllowance = allowance(provider, spender);
        _approve(provider, spender, currentAllowance + value, true);
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 value) external virtual returns (bool) {
        address provider = msg.sender;
        uint256 currentAllowance = allowance(provider, spender);
        if (currentAllowance < value) {
            revert ERC20InsufficientAllowance(spender, currentAllowance, value);
        }
        unchecked {
            _approve(provider, spender, currentAllowance - value, true);
        }
        return true;
    }

}