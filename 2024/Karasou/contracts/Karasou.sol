/**
 *Submitted for verification at BscScan.com on 2024-04-11
*/

//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router01 {
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
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library Address {
    function sendValue(address payable recipient, uint256 amount) internal returns(bool){
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        return success; // always proceeds
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
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

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
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

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            unchecked {
                _approve(sender, _msgSender(), currentAllowance - amount);
            }
        }

        _transfer(sender, recipient, amount);

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

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
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

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

contract KARASOU is ERC20, Ownable {
    using Address for address payable;

    IUniswapV2Router02 public uniswapV2Router;
    address public  uniswapV2Pair;

    mapping (address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromMaxWallet;

    uint256 public  marketingFeeOnBuy;
    uint256 public  marketingFeeOnSell;
    uint256 public  liquidityFeeOnBuy;
    uint256 public  liquidityFeeOnSell;
    uint256 public totalBuyFees;
    uint256 public totalSellFees;
    
    address public  marketingFeeReceiver;
    address public  cexWallet;
    address public  teamWallet;
    address public  circulatingWallet;
    address public  futureDevelopmentWallet;
    uint256 public  swapTokensAtAmount;
    uint256 public  maxWalletLimit;
    bool private inSwapAndLiquify;

    bool    public swapEnabled;

    uint256 public constant TOTAL_SUPPLY = 1000000 * 10 ** 18; // Total supply of 1,000,000 tokens
    uint256 public constant CIRCULATING_SUPPLY = 30; // Percentage of total supply for circulating wallet
    uint256 public constant FUTURE_DEVELOPMENT = 27; //Percentage for future development
    uint256 public constant CEX_PERCENTAGE = 30; // Percentage of total supply for CEX wallet
    uint256 public constant TEAM_PERCENTAGE = 13; // Percentage of total supply for Team wallet

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SwapAndSendFee(uint256 tokensSwapped, uint256 bnbSend);
    event SwapTokensAtAmountUpdated(uint256 swapTokensAtAmount);
    event MarketingFeeReceiverChanged(address marketingFeeReceiver);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );
    event BuyFeesChanged(uint256 marketingFeeOnBuy, uint256 liquidityFee);
    event SellFeesChanged(uint256 marketingFeeOnSell, uint256 liquidityFee);
    event WalletExcludedFromMaxWalletLimit(address wallet, bool excluded);
    event MaxWalletLimitChanged(uint256 maxWalletLimit);

    constructor() ERC20("KARASOU", "INTELLIQUE") 
    {   
        address router;
        address pinkLock;
        
        if (block.chainid == 56) {
            router = 0x10ED43C718714eb63d5aA57B78B54704E256024E; // BSC Pancake Mainnet Router
            pinkLock = 0x407993575c91ce7643a4d4cCACc9A98c36eE1BBE; // BSC PinkLock
        } else if (block.chainid == 97) {
            router = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1; // BSC Pancake Testnet Router
            pinkLock = 0x5E5b9bE5fd939c578ABE5800a90C566eeEbA44a5; // BSC Testnet PinkLock
        } else if (block.chainid == 1 || block.chainid == 5) {
            router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // ETH Uniswap Mainnet % Testnet
            pinkLock = 0x71B5759d73262FBb223956913ecF4ecC51057641; // ETH PinkLock
        } else {
            revert();
        }

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router);
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair   = _uniswapV2Pair;

        _approve(address(this), address(uniswapV2Router), type(uint256).max);

        marketingFeeOnBuy   = 17;
        marketingFeeOnSell  = 17;
        liquidityFeeOnBuy  = 3;
        liquidityFeeOnSell = 3;

        totalBuyFees  = marketingFeeOnBuy + liquidityFeeOnBuy;
        totalSellFees = marketingFeeOnSell + liquidityFeeOnSell;

        marketingFeeReceiver    = 0x196C2e15E6620951A159c9b26EB433357fCA8D77;
        cexWallet               = 0xd5c8287E250E9c5bEECc6310D322a85F8De8caC1;
        teamWallet              = 0x99e415d4dB3AFF251E403510cAc954D76C53565e;
        circulatingWallet       = 0xc2230d74eC9b5B3872E2dbA573360a06caABA36a;
        futureDevelopmentWallet = 0x24b8953dc3CC25eA517ff921bC7c9604321f11Ba;

        //Excluding wallets from fees
        _isExcludedFromFees[owner()]                 = true;
        _isExcludedFromFees[address(0xdead)]         = true;
        _isExcludedFromFees[address(this)]           = true;
        _isExcludedFromFees[pinkLock]                = true;
        _isExcludedFromFees[circulatingWallet]       = true;
        _isExcludedFromFees[futureDevelopmentWallet] = true;
        _isExcludedFromFees[teamWallet]              = true;
        _isExcludedFromFees[cexWallet]               = true;


        //Excluding wallets from max wallet limit
        _isExcludedFromMaxWallet[owner()]                 = true;
        _isExcludedFromMaxWallet[cexWallet]               = true;
        _isExcludedFromMaxWallet[teamWallet]              = true;
        _isExcludedFromMaxWallet[address(this)]           = true;
        _isExcludedFromMaxWallet[circulatingWallet]       = true;
        _isExcludedFromMaxWallet[futureDevelopmentWallet] = true;

        uint256 circulatingAmount       = (TOTAL_SUPPLY * CIRCULATING_SUPPLY) / 100;
        uint256 cexAmount               = (TOTAL_SUPPLY * CEX_PERCENTAGE) / 100;
        uint256 teamAmount              = (TOTAL_SUPPLY * TEAM_PERCENTAGE) / 100;
        uint256 futureDevelopmentAmount = (TOTAL_SUPPLY * FUTURE_DEVELOPMENT) / 100;
        
        _mint(circulatingWallet, circulatingAmount);
        _mint(futureDevelopmentWallet, futureDevelopmentAmount);
        _mint(cexWallet, cexAmount);
        _mint(teamWallet, teamAmount);

        swapTokensAtAmount = totalSupply() / 5_000;

        swapEnabled = false;
    }

    receive() external payable {}

    function claimStuckTokens(address token) external onlyOwner {
        require(token != address(this), "Owner cannot claim contract's balance of its own tokens");
        if (token == address(0x0)) {
            payable(msg.sender).sendValue(address(this).balance);
            return;
        }
        
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner{
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    
    function changeFeeReceiver(address _marketingFeeReceiver) external onlyOwner{
        require(_marketingFeeReceiver != address(0), "Marketing Fee receiver cannot be the zero address");
        marketingFeeReceiver = _marketingFeeReceiver;

        emit MarketingFeeReceiverChanged(marketingFeeReceiver);
    }
    
    event TradingEnabled(bool tradingEnabled);

    bool public tradingEnabled;

    function enableTrading() external onlyOwner{
        require(!tradingEnabled, "Trading already enabled.");
        tradingEnabled = true;
        swapEnabled = true;

        emit TradingEnabled(tradingEnabled);
    }

    function _transfer(address from,address to,uint256 amount) internal  override {
        require(from != address(0), "Transfer from the zero address");
        require(to != address(0), "Transfer to the zero address");
        require(tradingEnabled || _isExcludedFromFees[from] || _isExcludedFromFees[to], "Trading not yet enabled!");
        if (!_isExcludedFromMaxWallet[from] && !_isExcludedFromMaxWallet[to]) {
            require(balanceOf(to) + amount <= maxWalletLimit, "Recipient's balance would exceed the max wallet limit");
        }
       
        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

		uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >= swapTokensAtAmount;

        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            to == uniswapV2Pair &&
            swapEnabled
        ) {
            inSwapAndLiquify = true;
            
            uint256 marketingShare = marketingFeeOnBuy + marketingFeeOnSell;
            uint256 liquidityShare = liquidityFeeOnBuy + liquidityFeeOnSell;
            uint256 totalShare = marketingShare + liquidityShare;
            if(totalShare > 0) {
                if(liquidityShare > 0) {
                    uint256 liquidityTokens = (contractTokenBalance * liquidityShare) / totalShare;
                    swapAndLiquify(liquidityTokens);
                }
                
                if(marketingShare > 0) {
                    uint256 marketingTokens = (contractTokenBalance * marketingShare) / totalShare;
                    swapAndSendMarketing(marketingTokens);
                } 
            }
            inSwapAndLiquify = false;
        }
        

        uint256 _totalFees;
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to] || inSwapAndLiquify) {
            _totalFees = 0;
        } else if (from == uniswapV2Pair) {
            _totalFees = marketingFeeOnBuy + liquidityFeeOnBuy;
        } else if (to == uniswapV2Pair) {
            _totalFees =  marketingFeeOnSell + liquidityFeeOnSell;
        } else {
            _totalFees = 0;
        }

        if (_totalFees > 0) {
            uint256 fees = (amount * _totalFees) / 100;
            amount = amount - fees;
            super._transfer(from, address(this), fees);
        }

        super._transfer(from, to, amount);
    }

    function setSwapTokensAtAmount(uint256 newAmount, bool _swapEnabled) external onlyOwner{
        require(newAmount > totalSupply() / 1_000_000, "SwapTokensAtAmount must be greater than 0.0001% of total supply");
        swapTokensAtAmount = newAmount;
        swapEnabled = _swapEnabled;

        emit SwapTokensAtAmountUpdated(swapTokensAtAmount);
    }
     

   function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens / 2;
        uint256 otherHalf = tokens - half;

        uint256 initialBalance = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            half,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp);
        
        uint256 newBalance = address(this).balance - initialBalance;

        uniswapV2Router.addLiquidityETH{value: newBalance}(
            address(this),
            otherHalf,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapAndSendMarketing(uint256 tokenAmount) private {
        uint256 initialBalance = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp);

        uint256 newBalance = address(this).balance - initialBalance;

        payable(marketingFeeReceiver).sendValue(newBalance);

        emit SwapAndSendFee(tokenAmount, newBalance);
    }


    function setBuyFeePercentages(uint256 _marketingFeeOnBuy,uint256 _liquidityFeeOnBuy) external onlyOwner {
        marketingFeeOnBuy = _marketingFeeOnBuy;
        liquidityFeeOnBuy = _liquidityFeeOnBuy;
        totalBuyFees =  liquidityFeeOnBuy + _marketingFeeOnBuy;
        require(totalBuyFees <= 10, "Buy fees cannot be greater than 10%");
        emit BuyFeesChanged(marketingFeeOnBuy, liquidityFeeOnBuy);
    }


    function setSellFeePercentages(uint256 _marketingFeeOnSell, uint256 _liquidityFeeOnSell) external onlyOwner {
        marketingFeeOnSell = _marketingFeeOnSell;
        liquidityFeeOnSell = _liquidityFeeOnSell;
        totalSellFees =  liquidityFeeOnSell + _marketingFeeOnSell;
        require(totalSellFees <= 10, "Buy fees cannot be greater than 10%");
        emit SellFeesChanged(marketingFeeOnBuy, liquidityFeeOnSell);
    }

    function setMaxWalletLimit(uint256 _maxWalletLimit) external onlyOwner {
        require(
            _maxWalletLimit >= (totalSupply() / 1000), // Ensure it's not less than 0.1% of the total supply
            "Max wallet limit cannot be less than 0.1% of the total supply"
        );
        maxWalletLimit = _maxWalletLimit;
        emit MaxWalletLimitChanged(maxWalletLimit);
    }

    function excludeFromMaxWalletLimit(address wallet, bool excluded) external onlyOwner {
        _isExcludedFromMaxWallet[wallet] = excluded;
        emit WalletExcludedFromMaxWalletLimit(wallet, excluded);
    }
}