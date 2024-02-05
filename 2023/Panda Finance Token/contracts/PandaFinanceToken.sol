/**
 *Submitted for verification at Etherscan.io on 2023-11-22
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
}

interface ICommonError {

    // ERROR

    error CannotUseCurrentAddress(address current);

    error CannotUseCurrentValue(uint256 current);

    error CannotUseCurrentState(bool current);

    error InvalidAddress(address invalid);

    error InvalidValue(uint256 invalid);
}

interface IStaking {

    // FUNCTION

    function deposit(uint256 amount) external;
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

    error InvalidOwner(address account);

    error UnauthorizedAccount(address account);

    // CONSTRUCTOR

    constructor(address initialOwner) {
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

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/********************************************************************************************
  TOKEN
********************************************************************************************/

contract PandaFinanc3 is Ownable, ICommonError, IERC20 {

    // DATA

    IRouter public router;

    string private constant NAME = "PandaFinanc3";
    string private constant SYMBOL = "PAF";

    uint8 private constant DECIMALS = 18;

    uint256 private _totalSupply;
    
    uint256 public constant FEEDENOMINATOR = 10_000;

    uint256 public constant BUYFEEMARKETING = 100;
    uint256 public constant SELLFEEMARKETING = 100;
    uint256 public constant TRANSFERFEEMARKETING = 0;
    uint256 public constant BUYFEESTAKING = 100;
    uint256 public constant SELLFEESTAKING = 100;
    uint256 public constant TRANSFERFEESTAKING = 0;
    uint256 public constant BUYFEEBURN = 100;
    uint256 public constant SELLFEEBURN = 100;
    uint256 public constant TRANSFERFEEBURN = 0;

    uint256 public totalMarketingFeeCollected = 0;
    uint256 public totalMarketingFeeRedeemed = 0;
    uint256 public totalStakingFeeCollected = 0;
    uint256 public totalStakingFeeRedeemed = 0;
    uint256 public totalBurnFeeCollected = 0;
    uint256 public totalBurnFeeRedeemed = 0;
    uint256 public totalFeeCollected = 0;
    uint256 public totalFeeRedeemed = 0;
    uint256 public totalTriggerZeusBuyback = 0;
    uint256 public lastTriggerZeusTimestamp = 0;
    uint256 public minSwap = 100_000 ether;

    bool private constant ISPAF = true;

    bool public tradeEnabled = false;
    bool public isFeeActive = false;
    bool public isSwapEnabled = false;
    bool public inSwap = false;
    bool public isStakingContract = false;

    address public constant ZERO = address(0);
    address public constant DEAD = address(0xdead);
    address public constant PROJECTOWNER = 0x37e25Fa9E27E12211572E555a49495B60d585f76;
    address public constant FEERECEIVER = 0xa3d552C0709A867d024AC73A6444520C1444d450;

    address public pair;
    address public stakingReceiver;
    
    // MAPPING

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isExcludeFromFees;
    mapping(address => bool) public isPairLP;

    // MODIFIER

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    // ERROR

    error InvalidTradeEnabledState(bool current);

    error InvalidFeeActiveState(bool current);

    error InvalidSwapEnabledState(bool current);

    error PresaleAlreadyFinalized(bool current);

    error InvalidStakingAddress(address staking);

    error TradeDisabled();

    error CannotUseMainPair();

    // CONSTRUCTOR

    constructor(
        address stakingAddress,
        bool isContract
    ) Ownable (msg.sender) {
        _mint(msg.sender, 11_000_000_000 * 10**DECIMALS);

        router = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        pair = IFactory(router.factory()).createPair(address(this), router.WETH());

        if (stakingAddress == ZERO) {
            revert InvalidStakingAddress(stakingAddress);
        }

        stakingReceiver = stakingAddress;
        isStakingContract = isContract;

        isPairLP[pair] = true;

        isExcludeFromFees[msg.sender] = true;
        isExcludeFromFees[PROJECTOWNER] = true;
        isExcludeFromFees[address(router)] = true;
    }

    // EVENT

    event UpdateRouter(address oldRouter, address newRouter, address caller, uint256 timestamp);

    event UpdateMinSwap(uint256 oldMinSwap, uint256 newMinSwap, address caller, uint256 timestamp);

    event UpdateFeeActive(bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event UpdateSwapEnabled(bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event AutoRedeem(uint256 marketingAmount, uint256 stakingAmount, uint256 burnAmount, uint256 amountToRedeem, address caller, uint256 timestamp);

    event EnableTrading(bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event UpdateIsStakingContract(bool oldStatus, bool newStatus, address caller, uint256 timestamp);

    event UpdateStakingReceiver(address oldReceiver, address newReceiver, address caller, uint256 timestamp);

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
    }

    /* Redeem */

    function autoRedeem(uint256 amountToRedeem) public swapping {          
        uint256 totalFee = BUYFEEMARKETING + BUYFEESTAKING + BUYFEEBURN;
        uint256 marketingRedeem = amountToRedeem * BUYFEEMARKETING / totalFee;
        uint256 stakingRedeem = amountToRedeem * BUYFEESTAKING / totalFee;
        uint256 burnRedeem = amountToRedeem - marketingRedeem - stakingRedeem;
        totalFeeRedeemed += amountToRedeem;
        totalMarketingFeeRedeemed += marketingRedeem;
        totalStakingFeeRedeemed += stakingRedeem;
        totalBurnFeeRedeemed += burnRedeem;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        if (stakingReceiver == ZERO) {
            revert InvalidStakingAddress(stakingReceiver);
        }

        if (isStakingContract) {
            _approve(address(this), address(stakingReceiver), marketingRedeem);
            IStaking(stakingReceiver).deposit(stakingRedeem);
        } else {
            _basicTransfer(address(this), stakingReceiver, stakingRedeem);
        }

        _basicTransfer(address(this), DEAD, burnRedeem);
        _approve(address(this), address(router), marketingRedeem);
        
        emit AutoRedeem(marketingRedeem, stakingRedeem, burnRedeem, amountToRedeem, msg.sender, block.timestamp);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            marketingRedeem,
            0,
            path,
            FEERECEIVER,
            block.timestamp
        );
    }

    /* Check */

    function isPandaFinanc3() external pure returns (bool) {
        return ISPAF;
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(DEAD) - balanceOf(ZERO);
    }

    /* Update */

    function updateRouter(address newRouter) external onlyOwner {
        if (address(router) == newRouter) { revert CannotUseCurrentAddress(newRouter); }
        address oldRouter = address(router);
        router = IRouter(newRouter);
        address oldPair = pair;
        
        isPairLP[oldPair] = false;
        isExcludeFromFees[oldRouter] = false;
        isExcludeFromFees[newRouter] = true;

        emit UpdateRouter(oldRouter, newRouter, msg.sender, block.timestamp);
        pair = IFactory(router.factory()).createPair(address(this), router.WETH());
        isPairLP[pair] = true;
    }

    function updateMinSwap(uint256 newMinSwap) external onlyOwner {
        if (minSwap == newMinSwap) { revert CannotUseCurrentValue(newMinSwap); }
        uint256 oldMinSwap = minSwap;
        minSwap = newMinSwap;
        emit UpdateMinSwap(oldMinSwap, newMinSwap, msg.sender, block.timestamp);
    }

    function updateFeeActive(bool newStatus) external onlyOwner {
        if (isFeeActive == newStatus) { revert CannotUseCurrentState(newStatus); }
        bool oldStatus = isFeeActive;
        isFeeActive = newStatus;
        emit UpdateFeeActive(oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function updateSwapEnabled(bool newStatus) external onlyOwner {
        if (isSwapEnabled == newStatus) { revert CannotUseCurrentState(newStatus); }
        bool oldStatus = isSwapEnabled;
        isSwapEnabled = newStatus;
        emit UpdateSwapEnabled(oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function updateIsStakingContract(bool newStatus) external onlyOwner {
        if (isStakingContract == newStatus) { revert CannotUseCurrentState(newStatus); }
        bool oldStatus = isStakingContract;
        isStakingContract = newStatus;
        emit UpdateIsStakingContract(oldStatus, newStatus, msg.sender, block.timestamp);
    }

    function updateStakingReceiver(address newReceiver) external onlyOwner {
        if (stakingReceiver == newReceiver) { revert CannotUseCurrentAddress(newReceiver); }
        address oldReceiver = stakingReceiver;
        stakingReceiver = newReceiver;
        emit UpdateStakingReceiver(oldReceiver, newReceiver, msg.sender, block.timestamp);
    }

    function setExcludeFromFees(address user, bool status) external onlyOwner {
        if (isExcludeFromFees[user] == status) { revert CannotUseCurrentState(status); }
        isExcludeFromFees[user] = status;
    }

    function setPairLP(address lpPair, bool status) external onlyOwner {
        if (lpPair == pair) { revert CannotUseMainPair(); }
        if (isPairLP[lpPair] == status) { revert CannotUseCurrentState(status); }
        if (IPair(lpPair).token0() != address(this) && IPair(lpPair).token1() != address(this)) { revert InvalidAddress(lpPair); }
        isPairLP[lpPair] = status;
    }

    /* Fee */

    function takeBuyFee(address from, uint256 amount) internal swapping returns (uint256) {
        uint256 feeAmountMarketing = amount * BUYFEEMARKETING / FEEDENOMINATOR;
        uint256 feeAmountStaking = amount * BUYFEESTAKING / FEEDENOMINATOR;
        uint256 feeAmountBurn = amount * BUYFEEBURN / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmountMarketing - feeAmountStaking - feeAmountBurn;
        if ((feeAmountMarketing + feeAmountStaking + feeAmountBurn) > 0) {
            tallyCollection(from, feeAmountMarketing, feeAmountStaking, feeAmountBurn);
        }
        return newAmount;
    }

    function takeSellFee(address from, uint256 amount) internal swapping returns (uint256) {
        uint256 feeAmountMarketing = amount * SELLFEEMARKETING / FEEDENOMINATOR;
        uint256 feeAmountStaking = amount * SELLFEESTAKING / FEEDENOMINATOR;
        uint256 feeAmountBurn = amount * SELLFEEBURN / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmountMarketing - feeAmountStaking - feeAmountBurn;
        if ((feeAmountMarketing + feeAmountStaking + feeAmountBurn) > 0) {
            tallyCollection(from, feeAmountMarketing, feeAmountStaking, feeAmountBurn);
        }
        return newAmount;
    }

    function takeTransferFee(address from, uint256 amount) internal swapping returns (uint256) {
        uint256 feeAmountMarketing = amount * TRANSFERFEEMARKETING / FEEDENOMINATOR;
        uint256 feeAmountStaking = amount * TRANSFERFEESTAKING / FEEDENOMINATOR;
        uint256 feeAmountBurn = amount * TRANSFERFEEBURN / FEEDENOMINATOR;
        uint256 newAmount = amount - feeAmountMarketing - feeAmountStaking - feeAmountBurn;
        if ((feeAmountMarketing + feeAmountStaking + feeAmountBurn) > 0) {
            tallyCollection(from, feeAmountMarketing, feeAmountStaking, feeAmountBurn);
        }
        return newAmount;
    }

    function tallyCollection(address from, uint256 collectFeeMarketing, uint256 collectFeeStaking, uint256 collectFeeBurn) internal swapping {
        uint256 collectFee = collectFeeMarketing + collectFeeStaking + collectFeeBurn;
        totalMarketingFeeCollected += collectFeeMarketing;
        totalStakingFeeCollected += collectFeeStaking;
        totalBurnFeeCollected += collectFeeBurn;
        totalFeeCollected += collectFee;
        _basicTransfer(from, address(this), collectFee);
    }

    /* Buyback */

    function triggerZeusBuyback(uint256 amount) external onlyOwner {
        totalTriggerZeusBuyback += amount;
        lastTriggerZeusTimestamp = block.timestamp;
        buyTokens(amount, DEAD);
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

    function _basicTransfer(address from, address to, uint256 amount) internal returns (bool) {
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

        if (!tradeEnabled && !isExcludeFromFees[from] && !isExcludeFromFees[to]) { revert TradeDisabled(); }

        if (inSwap || isExcludeFromFees[from]) {
            return _basicTransfer(from, to, amount);
        }

        if (from != pair && isSwapEnabled && balanceOf(address(this)) >= minSwap && totalFeeCollected - totalFeeRedeemed >= minSwap) {
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

        return true;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal swapping virtual returns (uint256) {
        if (isPairLP[from] && ((BUYFEEMARKETING + BUYFEESTAKING + BUYFEEBURN) > 0)) {
            return takeBuyFee(from, amount);
        }
        if (isPairLP[to] && ((SELLFEEMARKETING + SELLFEESTAKING + SELLFEEBURN) > 0)) {
            return takeSellFee(from, amount);
        }
        if (!isPairLP[from] && !isPairLP[to] && ((TRANSFERFEEMARKETING + TRANSFERFEESTAKING + TRANSFERFEEBURN) > 0)) {
            return takeTransferFee(from, amount);
        }
        return amount;
    }
}