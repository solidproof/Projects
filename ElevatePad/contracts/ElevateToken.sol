// SPDX-License-Identifier: MIT                                                                               
                                                    
pragma solidity 0.8.17;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ERC20 is Context, IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if(currentAllowance != type(uint256).max){
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            unchecked {
                _approve(sender, _msgSender(), currentAllowance - amount);
            }
        }

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _createInitialSupply(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() external virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IDexRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
    function addLiquidityETH(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IDexFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract Elevate is ERC20, Ownable {

    uint256 public maxTxnAmount;

    IDexRouter public immutable dexRouter;
    address public immutable lpPairEth;

    bool private swapping;
    uint256 public swapTokensAtAmount;

    address public impactAddress;
    address public crfAddress;
    address public operationsAddress;
    address public liquidityAddress;
    address public treasuryAddress;

    uint256 public tradingActiveBlock = 0; // 0 means trading is not active
    mapping (address => bool) public restrictedWallets;

    bool public limitsInEffect = true;
    bool public tradingActive = false;
    bool public swapEnabled = false;
    
    uint256 public buyTotalFees;
    uint256 public buyLiquidityFee;
    uint256 public buyImpactFee;
    uint256 public buyCRFFee;
    uint256 public buyOperationsFee;
    uint256 public buyTreasuryFee;

    uint256 public sellTotalFees;
    uint256 public sellImpactFee;
    uint256 public sellLiquidityFee;
    uint256 public sellCRFFee;
    uint256 public sellOperationsFee;
    uint256 public sellTreasuryFee;

    uint256 constant FEE_DIVISOR = 10000;

    uint256 public tokensForImpact;
    uint256 public tokensForLiquidity;
    uint256 public tokensForCRF;
    uint256 public tokensForOperations;
    uint256 public tokensForTreasury;
    
    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) public _isExcludedMaxTransactionAmount;

    mapping (address => bool) public automatedMarketMakerPairs;

    // Events

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event EnabledTrading();
    event RemovedLimits();
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event UpdatedMaxTxnAmount(uint256 newAmount);
    event UpdatedBuyFee(uint256 newAmount);
    event UpdatedSellFee(uint256 newAmount);
    event UpdatedImpactAddress(address indexed newWallet);
    event UpdatedLiquidityAddress(address indexed newWallet);
    event UpdatedCRFAddress(address indexed newWallet);
    event UpdatedOperationsAddress(address indexed newWallet);
    event UpdatedTreasuryAddress(address indexed newWallet);
    event MaxTransactionExclusion(address _address, bool excluded);
    event OwnerForcedSwapBack(uint256 timestamp);
    event TransferForeignToken(address token, uint256 amount);

    constructor() ERC20("Elevate", "ELEV") {

        address _dexRouter;

        // automatically detect router/desired stablecoin
        if(block.chainid == 1){
            _dexRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // ETH: Uniswap V2
        } else if(block.chainid == 5){
            _dexRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Goerli ETH: Uniswap V2
        } else if(block.chainid == 97){
            _dexRouter = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1; // BNB Chain: PCS V2
        } else {
            revert("Chain not configured");
        }

        address newOwner = msg.sender; // can leave alone if owner is deployer.

        dexRouter = IDexRouter(_dexRouter);

        // create pair

        lpPairEth = IDexFactory(dexRouter.factory()).createPair(address(this), dexRouter.WETH());
        setAutomatedMarketMakerPair(address(lpPairEth), true);

        uint256 totalSupply = 5 * 1e9 * 1e18;
        
        maxTxnAmount = totalSupply * 25 / 10000;
        swapTokensAtAmount = totalSupply * 25 / 100000;

        buyImpactFee = 0;
        buyLiquidityFee = 100;
        buyCRFFee = 100;
        buyOperationsFee = 100;
        buyTreasuryFee = 100;
        buyTotalFees = buyImpactFee + buyLiquidityFee + buyCRFFee + buyOperationsFee + buyTreasuryFee;


        sellImpactFee = 0;
        sellLiquidityFee = 100;
        sellCRFFee = 100;
        sellOperationsFee = 100;
        sellTreasuryFee = 100;
        sellTotalFees = sellImpactFee + sellLiquidityFee + sellCRFFee + sellOperationsFee + sellTreasuryFee;

        // update these!
        impactAddress = address(newOwner);
        liquidityAddress = address(newOwner);
        operationsAddress = address(newOwner);
        crfAddress = address(newOwner);
        treasuryAddress = address(newOwner);

        _excludeFromMaxTransaction(newOwner, true);
        _excludeFromMaxTransaction(address(this), true);
        _excludeFromMaxTransaction(address(0xdead), true);
        _excludeFromMaxTransaction(address(impactAddress), true);
        _excludeFromMaxTransaction(address(liquidityAddress), true);
        _excludeFromMaxTransaction(address(operationsAddress), true);
        _excludeFromMaxTransaction(address(crfAddress), true);
        _excludeFromMaxTransaction(address(dexRouter), true);

        excludeFromFees(newOwner, true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);
        excludeFromFees(address(impactAddress), true);
        excludeFromFees(address(liquidityAddress), true);
        excludeFromFees(address(operationsAddress), true);
        excludeFromFees(address(crfAddress), true);
        excludeFromFees(address(dexRouter), true);

        _createInitialSupply(address(newOwner), totalSupply);
        transferOwnership(newOwner);

        _approve(address(this), address(dexRouter), type(uint256).max);
        _approve(address(newOwner), address(dexRouter), totalSupply);
    }

    receive() external payable {}

    // Owner Functions

    function enableTrading() external onlyOwner {
        require(tradingActiveBlock == 0, "enableTrading already called");
        tradingActive = true;
        swapEnabled = true;
        tradingActiveBlock = block.number;
        emit EnabledTrading();
    }

    function pauseTrading() external onlyOwner {
        require(tradingActiveBlock > 0, "enableTrading first");
        require(tradingActive, "Trading paused");
        tradingActive = false;
    }

    function unpauseTrading() external onlyOwner {
        require(tradingActiveBlock > 0, "enableTrading first");
        require(!tradingActive, "Trading unpaused");
        tradingActive = true;
    }

    function manageRestrictedWallets(address[] calldata wallets,  bool restricted) external onlyOwner {
        for(uint256 i = 0; i < wallets.length; i++){
            restrictedWallets[wallets[i]] = restricted;
        }
    }
    
    function removeLimits() external onlyOwner {
        limitsInEffect = false;
        maxTxnAmount = totalSupply();
        emit RemovedLimits();
    }

    function updateMaxTxnAmount(uint256 newNum) external onlyOwner {
        require(newNum >= (totalSupply() * 1 / 1000)/1e18, "too low");
        maxTxnAmount = newNum * (10**18);
        emit UpdatedMaxTxnAmount(maxTxnAmount);
    }

    // change the minimum amount of tokens to sell from fees
    function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
  	    require(newAmount >= totalSupply() * 1 / 1000000, "too low");
  	    require(newAmount <= totalSupply() * 1 / 1000, "too high");
  	    swapTokensAtAmount = newAmount;
  	}
    
    function transferForeignToken(address _token, address _to) external onlyOwner returns (bool _sent) {
        require(_token != address(0), "zero address");
        require(_token != address(this), "Can't withdraw native tokens");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        _sent = IERC20(_token).transfer(_to, _contractBalance);
        emit TransferForeignToken(_token, _contractBalance);
    }

    // withdraw ETH if stuck or someone sends to the address
    function withdrawStuckETH() external onlyOwner {
        bool success;
        (success,) = address(msg.sender).call{value: address(this).balance}("");
    }

    function setImpactAddress(address _impactAddress) external onlyOwner {
        require(_impactAddress != address(0), "zero address");
        impactAddress = payable(_impactAddress);
        emit UpdatedImpactAddress(_impactAddress);
    }

    function setCRFAddress(address _crfAddress) external onlyOwner {
        require(_crfAddress != address(0), "zero address");
        crfAddress = payable(_crfAddress);
        emit UpdatedCRFAddress(_crfAddress);
    }
    
    function setLiquidityAddress(address _liquidityAddress) external onlyOwner {
        require(_liquidityAddress != address(0), "zero address");
        liquidityAddress = payable(_liquidityAddress);
        emit UpdatedLiquidityAddress(_liquidityAddress);
    }

    function setOperationsAddress(address _operationsAddress) external onlyOwner {
        require(_operationsAddress != address(0), "zero address");
        operationsAddress = payable(_operationsAddress);
        emit UpdatedOperationsAddress(_operationsAddress);
    }

    function setTreasuryAddress(address _treasuryAddress) external onlyOwner {
        require(_treasuryAddress != address(0), "zero address");
        treasuryAddress = payable(_treasuryAddress);
        emit UpdatedTreasuryAddress(_treasuryAddress);
    }

    function forceSwapBack() external onlyOwner {
        require(balanceOf(address(this)) >= swapTokensAtAmount, "Amount not high enough");
        swapping = true;
        swapBackEth();
        swapping = false;
        emit OwnerForcedSwapBack(block.timestamp);
    }
    
    function airdropToWallets(address[] memory wallets, uint256[] memory amountsInTokens) external onlyOwner {
        require(wallets.length == amountsInTokens.length, "length mismatch");
        require(wallets.length < 600, "600 max");
        for(uint256 i = 0; i < wallets.length; i++){
            address wallet = wallets[i];
            uint256 amount = amountsInTokens[i];
            super._transfer(msg.sender, wallet, amount);
        }
    }
    
    function excludeFromMaxTransaction(address updAds, bool isEx) external onlyOwner {
        if(!isEx){
            require(updAds != lpPairEth, "pair cannot be removed");
        }
        _isExcludedMaxTransactionAmount[updAds] = isEx;
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != lpPairEth || value, "pair cannot be removed");
        automatedMarketMakerPairs[pair] = value;
        _excludeFromMaxTransaction(pair, value);
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateBuyFees(uint256 _impactFee, uint256 _liquidityFee, uint256 _crfFee, uint256 _operationsFee, uint256 _treasuryFee) external onlyOwner {
        buyImpactFee = _impactFee;
        buyLiquidityFee = _liquidityFee;
        buyCRFFee = _crfFee;
        buyOperationsFee = _operationsFee;
        buyTreasuryFee = _treasuryFee;
        buyTotalFees = buyImpactFee + buyLiquidityFee + buyCRFFee + buyOperationsFee + buyTreasuryFee;
        require(buyTotalFees <= 1000, "Fees too high");
        emit UpdatedBuyFee(buyTotalFees);
    }

    function updateSellFees(uint256 _impactFee, uint256 _liquidityFee, uint256 _crfFee, uint256 _operationsFee, uint256 _treasuryFee) external onlyOwner {
        sellImpactFee = _impactFee;
        sellLiquidityFee = _liquidityFee;
        sellCRFFee = _crfFee;
        sellOperationsFee = _operationsFee;
        sellTreasuryFee = _treasuryFee;
        sellTotalFees = sellImpactFee + sellLiquidityFee + sellCRFFee + sellOperationsFee + sellTreasuryFee;
        require(sellTotalFees <= 1000, "Fees too high");
        emit UpdatedSellFee(sellTotalFees);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    // private / internal functions

    function _transfer(address from, address to, uint256 amount) internal override {

        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        // transfer of 0 is allowed, but triggers no logic.  In case of staking where a staking pool is paying out 0 rewards.
        if(amount == 0){
            super._transfer(from, to, 0);
            return;
        }

        require(!restrictedWallets[from] && !restrictedWallets[to], "blocked address");
        
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]){
            super._transfer(from, to, amount);
            return;
        }
        
        require(tradingActive, "Trading is not active.");

        

        if(limitsInEffect){
            //on buy or sell
            if ((automatedMarketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) || (automatedMarketMakerPairs[to] && !_isExcludedMaxTransactionAmount[from])) {
                require(amount <= maxTxnAmount, "max tx exceeded");
            }
        }

        if(balanceOf(address(this)) >= swapTokensAtAmount && swapEnabled && !swapping && automatedMarketMakerPairs[to]) {
            swapping = true;
            swapBackEth();
            swapping = false;
        }

        uint256 fees = 0;

        // only take fees on buys/sells, do not take on wallet transfers
        // on sell
        if (automatedMarketMakerPairs[to] && sellTotalFees > 0){
            fees = amount * sellTotalFees / FEE_DIVISOR;
            tokensForLiquidity += fees * sellLiquidityFee / sellTotalFees;
            tokensForImpact += fees * sellImpactFee / sellTotalFees;
            tokensForCRF += fees * sellCRFFee / sellTotalFees;
            tokensForOperations += fees * sellOperationsFee / sellTotalFees;
            tokensForTreasury += fees * sellTreasuryFee / sellTotalFees;
        }

        // on buy
        else if(automatedMarketMakerPairs[from] && buyTotalFees > 0) {
            fees = amount * buyTotalFees / FEE_DIVISOR;
            tokensForImpact += fees * buyImpactFee / buyTotalFees;
            tokensForLiquidity += fees * buyLiquidityFee / buyTotalFees;
            tokensForCRF += fees * buyCRFFee / buyTotalFees;
            tokensForOperations += fees * buyOperationsFee / buyTotalFees;
            tokensForTreasury += fees * buyTreasuryFee / buyTotalFees;
        }
        
        if(fees > 0){    
            super._transfer(from, address(this), fees);
        }
        
        amount -= fees;

        super._transfer(from, to, amount);
    }

    function swapBackEth() private {
        bool success;

        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForLiquidity + tokensForImpact + tokensForCRF + tokensForOperations + tokensForTreasury;
        
        if(contractBalance == 0 || totalTokensToSwap == 0) {return;}

        if(contractBalance > swapTokensAtAmount * 10){
            contractBalance = swapTokensAtAmount * 10;
        }
        
        // Halve the amount of liquidity tokens
        uint256 liquidityTokens = contractBalance * tokensForLiquidity / totalTokensToSwap / 2;
        
        swapTokensForEth(contractBalance - liquidityTokens);
        
        uint256 ethBalance = address(this).balance;
        uint256 ethForLiquidity = ethBalance;

        uint256 ethForImpact = ethBalance * tokensForImpact / (totalTokensToSwap - (tokensForLiquidity/2));
        uint256 ethForCRF = ethBalance * tokensForCRF / (totalTokensToSwap - (tokensForLiquidity/2));
        uint256 ethForOperations = ethBalance * tokensForOperations / (totalTokensToSwap - (tokensForLiquidity/2));
        uint256 ethForTreasury = ethBalance * tokensForTreasury / (totalTokensToSwap - (tokensForLiquidity/2));

        ethForLiquidity -= ethForImpact + ethForCRF + ethForOperations + ethForTreasury;
            
        tokensForLiquidity = 0;
        tokensForImpact = 0;
        tokensForCRF = 0;
        tokensForOperations = 0;
        tokensForTreasury = 0;
        
        if(liquidityTokens > 0 && ethForLiquidity > 0){
            addLiquidityEth(liquidityTokens, ethForLiquidity);
        }

        if(ethForCRF > 0){
            (success, ) = crfAddress.call{value: ethForCRF}("");
        }

        if(ethForOperations > 0){
            (success, ) = operationsAddress.call{value: ethForOperations}("");
        }

         if(ethForTreasury > 0){
            (success, ) = treasuryAddress.call{value: ethForTreasury}("");
        }

        if(address(this).balance > 0){
            (success, ) = impactAddress.call{value: address(this).balance}("");
        }
    }

    function addLiquidityEth(uint256 tokenAmount, uint256 ethAmount) private {
        // add the liquidity
        dexRouter.addLiquidityETH{value: ethAmount}(address(this), tokenAmount, 0, 0, address(liquidityAddress), block.timestamp);
    }

    function swapTokensForEth(uint256 tokenAmount) private {

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WETH();

        // make the swap
        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
    }

    function _excludeFromMaxTransaction(address updAds, bool isExcluded) private {
        _isExcludedMaxTransactionAmount[updAds] = isExcluded;
        emit MaxTransactionExclusion(updAds, isExcluded);
    }

    //views

    function getTier(address account) external view returns (uint256){
        uint256 accountBalance = balanceOf(account);
        uint256 supply = totalSupply();
        if(accountBalance * 1e18 / supply >= 0.00075 ether){
            return 5;
        }
        if(accountBalance * 1e18 / supply >= 0.00060 ether){
            return 4;
        }
        if(accountBalance * 1e18 / supply >= 0.00045 ether){
            return 3;
        }
        if(accountBalance * 1e18 / supply >= 0.00030 ether){
            return 2;
        }
        if(accountBalance * 1e18 / supply >= 0.00015 ether){
            return 1;
        }
        return 0;
    }
}