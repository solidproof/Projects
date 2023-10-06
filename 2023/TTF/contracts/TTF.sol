/**
 *Submitted for verification at Etherscan.io on 2023-10-04
*/

/**

Website: https://www.ttfbot.io/

Twitter: https://twitter.com/TTFBot

Telegram: https://t.me/TTFBotOfficial

*/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
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

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IUniswapV2Router02 {
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

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

contract TTF is IERC20Metadata, Ownable {
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isExcludedFromMaxWalletToken;

    address payable public marketingWallet;
    address payable public devWallet;
    address payable public constant burnWallet = payable(0x000000000000000000000000000000000000dEaD);
    address payable public lpWallet;

    uint8 private constant _decimals = 9;
    uint256 private _tTotal = 10**8 * 10**_decimals;
    string private constant _name = "TTF";
    string private constant _symbol = "TTF";

    uint256 public swapMinTokens = 10**4 * 10**_decimals;

    uint256 public buyTax = 5;
    uint256 public sellTax = 20;
    uint256 public maxTransactionTax = 5;

    uint256 public marketingPct = 40;
    uint256 public devPct = 40;
    uint256 public lpPct = 20;
    uint256 public maxPct = 100;

    uint256 public maxWalletSize = (_tTotal * 2) / maxPct;

    IUniswapV2Router02 public _uniswapV2Router;
    address public uniswapV2Pair;
    bool public inSwapAndLiquify;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event UpdateLpWallet(address newLp_, address oldLpWallet);
    event UpdatedBuySellTaxes(uint256 buyTax, uint256 sellTax);
    event UpdatedPercentTaxes(uint256 marketing, uint256 dev, uint256 lp);
    event UpdatedIsExcludedFromFee(address account, bool flag);
    event UpdatedIsExcludedFromMaxWallet(address account, bool flag);
    event UpdatedMarketingAndDevWallet(address marketing, address dev);

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor(address uniswapRouterAddress, address marketing, address dev, address lpWalletAddress) {
        _tOwned[owner()] = _tTotal;

        _uniswapV2Router = IUniswapV2Router02(uniswapRouterAddress);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        marketingWallet = payable(marketing);
        devWallet = payable(dev);
        lpWallet = payable(lpWalletAddress);

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[marketingWallet] = true;
        isExcludedFromFee[devWallet] = true;
        isExcludedFromFee[burnWallet] = true;
        isExcludedFromFee[lpWallet] = true;
        isExcludedFromFee[uniswapRouterAddress] = true;

        isExcludedFromMaxWalletToken[uniswapRouterAddress] = true;
        isExcludedFromMaxWalletToken[owner()] = true;
        isExcludedFromMaxWalletToken[address(this)] = true;
        isExcludedFromMaxWalletToken[marketingWallet] = true;
        isExcludedFromMaxWalletToken[devWallet] = true;
        isExcludedFromMaxWalletToken[burnWallet] = true;
        isExcludedFromMaxWalletToken[lpWallet] = true;
        isExcludedFromMaxWalletToken[uniswapV2Pair] = true;

        emit Transfer(address(0), owner(), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _tOwned[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address theOwner, address theSpender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[theOwner][theSpender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    receive() external payable {}

    function _approve(
        address theOwner,
        address theSpender,
        uint256 amount
    ) private {
        require(
            theOwner != address(0) && theSpender != address(0),
            "Zero address."
        );
        _allowances[theOwner][theSpender] = amount;
        emit Approval(theOwner, theSpender, amount);
    }

    function setLpWallet(address newLp_) external onlyOwner {
        require(newLp_ != address(0), "TTF::Lp wallet cannot be zero address");

        address oldLpWallet = lpWallet;
        lpWallet = payable(newLp_);

        emit UpdateLpWallet(newLp_, oldLpWallet);
    }

    function setTax(
        uint256 buy,
        uint256 sell
    ) public onlyOwner {
        require(buy <= maxTransactionTax, "Buy tax cannot exceed the maximum.");
        require(sell <= maxTransactionTax, "Sell tax cannot exceed the maximum.");

        buyTax = buy;
        sellTax = sell;

        emit UpdatedBuySellTaxes(buy, sell);
    }

    function setPercentTax(
        uint256 marketing,
        uint256 dev,
        uint256 lp
    ) public onlyOwner {
        require(marketing + dev + lp == maxPct, "The sum of percentages must equal 100.");
        marketingPct = marketing;
        devPct = dev;
        lpPct = lp;

        emit UpdatedPercentTaxes(marketing, dev,lp);
    }
    function excludeFromFee(address account) external onlyOwner {
        isExcludedFromFee[account] = true;

        emit UpdatedIsExcludedFromFee(account, true);
    }

    function includeInFee(address account) external onlyOwner {
        isExcludedFromFee[account] = false;

        emit UpdatedIsExcludedFromFee(account, false);
    }

	function excludeMaxWallet(address account) external onlyOwner {
        isExcludedFromMaxWalletToken[account] = true;
        emit UpdatedIsExcludedFromMaxWallet(account, true);
    }

    function includeMaxWallet(address account) external onlyOwner {
        isExcludedFromMaxWalletToken[account] = false;
        emit UpdatedIsExcludedFromMaxWallet(account, false);
    }

    function setWallets(
        address marketing,
        address dev
    ) public onlyOwner {
        require(marketing != address(0) && dev != address(0), "Invalid wallet addresses.");
        isExcludedFromFee[marketingWallet] = false;
        isExcludedFromFee[devWallet] = false;

        marketingWallet = payable(marketing);
        devWallet = payable(dev);

        isExcludedFromFee[marketing] = true;
        isExcludedFromFee[dev] = true;

        emit UpdatedMarketingAndDevWallet(marketing, dev);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        if (!isExcludedFromMaxWalletToken[to]) {
            uint256 heldTokens = balanceOf(to);
            require(
                (heldTokens + amount) <= maxWalletSize,
                "Over wallet limit."
            );
        }

        require(
            from != address(0) && to != address(0),
            "Using 0 address!"
        );

        require(amount > 0, "Token value must be higher than zero.");

        if (
            balanceOf(address(this)) >= swapMinTokens &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair
        ) {
            swapAndDistributeTaxes();
        }

        _tokenTransfer(from, to, amount);
    }

   function multipleAirdrop(
        address[] memory _address,
        uint256[] memory _amount
    ) external onlyOwner {
        require(_address.length == _amount.length, "Arrays length mismatch");
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amount.length; i++) {
            totalAmount += _amount[i];
        }
        require(balanceOf(msg.sender) >= totalAmount * 10**decimals(), "Insufficient balance");

        for (uint256 i = 0; i < _amount.length; i++) {
            address adr = _address[i];
            uint256 amnt = _amount[i] * 10**decimals();
            _transfer(msg.sender, adr, amnt);
        }
    }

    function _sendToWallet(address payable wallet, uint256 amount) private {
        wallet.transfer(amount);
    }

    function setSwapMinTokens(uint256 minTokens) external onlyOwner {
        swapMinTokens = minTokens * 10**decimals();
        require(swapMinTokens < totalSupply(), "Min tokens for swap is too high.");
    }

    function swapAndDistributeTaxes() private lockTheSwap {
        uint256 contractTokenBalance = balanceOf(address(this));
        uint256 marketingTokensShare = (contractTokenBalance * marketingPct) / maxPct;
        uint256 devTokensShare = (contractTokenBalance * devPct) / maxPct;
        uint256 lpTokensHalfShare = (contractTokenBalance * lpPct) / (2 * maxPct);

        uint256 bnbBalanceBeforeSwap = address(this).balance;
        swapTokensForBNB(lpTokensHalfShare + marketingTokensShare + devTokensShare);
        uint256 bnbReceived = address(this).balance - bnbBalanceBeforeSwap;

        uint256 marketingSplit = (marketingPct * maxPct) / (lpPct + marketingPct + devPct);
        uint256 bnbToMarketing = (bnbReceived * marketingSplit) / maxPct;

        uint256 devSplit = (devPct * maxPct) / (lpPct + marketingPct + devPct);
        uint256 bnbToDev = (bnbReceived * devSplit) / maxPct;

        addLiquidity(lpTokensHalfShare, (bnbReceived - bnbToMarketing - bnbToDev));
        emit SwapAndLiquify(
            lpTokensHalfShare,
            (bnbReceived - bnbToMarketing - bnbToDev),
            lpTokensHalfShare
        );

        _sendToWallet(marketingWallet, bnbToMarketing);
        _sendToWallet(devWallet, address(this).balance);
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _uniswapV2Router.WETH();
        _approve(address(this), address(_uniswapV2Router), tokenAmount);
        _uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 BNBAmount) private {
        _approve(address(this), address(_uniswapV2Router), tokenAmount);
        _uniswapV2Router.addLiquidityETH{value: BNBAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            lpWallet, // Add liquidity to lp wallet
            block.timestamp
        );
    }

    function withdraw() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "TTF::Contract balance is empty");

        (bool status, ) = payable(owner()).call{value: contractBalance}("");

        require(status, "TTF::Failed to send contract balance");
    }

    function removeStuckTokens (
        address tokenAddress,
        uint256 pctOfTokens
    ) public returns (bool _sent) {
        require(
            tokenAddress != address(this),
            "Can not remove native token."
        );
        require(pctOfTokens <= 100, "Percentage must be less than or equal to 100.");
        uint256 totalRandom = IERC20(tokenAddress).balanceOf(address(this));
        uint256 removeRandom = (totalRandom * pctOfTokens) / maxPct;
        _sent = IERC20(tokenAddress).transfer(devWallet, removeRandom);
    }

    function _tokenTransfer(
        address from,
        address to,
        uint256 tAmount
    ) private {
        bool isBuy = (from == uniswapV2Pair);
        bool isSell = (to == uniswapV2Pair);
        bool isBuyOrSell = isBuy || isSell;
        bool takeFee = isBuyOrSell && !(isExcludedFromFee[from] || isExcludedFromFee[to]);

        uint256 fee = !takeFee
            ? 0
            : isBuy
                ? (tAmount * buyTax) / maxPct
                : (tAmount * sellTax) / maxPct;
        uint256 tTransferAmount = tAmount - fee;

        _tOwned[from] = _tOwned[from] - tAmount;
        _tOwned[to] = _tOwned[to] + tTransferAmount;
        _tOwned[address(this)] = _tOwned[address(this)] + fee;
        emit Transfer(from, to, tTransferAmount);
        if (to == burnWallet) _tTotal = _tTotal - tTransferAmount;
    }
}