pragma solidity 0.8.11;
//SPDX-License-Identifier: none

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract CRI3X is Context, ERC20, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;

	bool private trading;
    bool private starting;
    bool private alreadyStarted;
    bool private stakingAllowed;
    bool private lpAdded;
    bool public sendTokens;
    bool public swapping;

	address public productionWallet;
    address public marketingWallet;
    address public CribXWallet;

    uint256 public swapTokensAtAmount;

    uint256 private _buyProductionFee;
    uint256 private _buyMarketingFee;
    uint256 private _buyCribXFee;
    uint256 private _buyLPFee;

    uint256 private _sellProductionFee;
    uint256 private _sellMarketingFee;
    uint256 private _sellCribXFee;
    uint256 private _sellLPFee;

    uint256 private blacklistFee;

    uint256 public _maxWallet;
    uint256 public _maxBuy;
    uint256 public _maxSell;

    uint256 public totalBuyFees;
    uint256 public totalSellFees;

    mapping (address => bool) private _isExcludedFromFees;

    mapping (address => bool) public automatedMarketMakerPairs;
    mapping (address => bool) public _isBlacklisted;
    mapping (address => bool) public _canAddLiquidity;

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event blacklist(address indexed account, bool isBlacklisted);
    event addLiquidityAddress(address indexed account, bool enabled);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event allowStaking(bool _enabled);
    event sendTokensUpdated(bool _enabled);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event WalletUpdated(address indexed newMarketingWallet, address indexed oldMarketingWallet);
    event UpdateSwapAmount(uint256 amount, uint256 swapTokensAtAmount);
    event UpdateMaxWallet(uint256 newMaxWallet, uint256 _maxWallet);
    event UpdateMaxBuySell(
        uint256 newMaxBuy,
        uint256 _maxBuy,
        uint256 newMaxSell,
        uint256 _maxSell
    );
    event UpdateBuyFees(
        uint256 newBuyProductionFee,
        uint256 _buyProductionFee,
        uint256 newBuyMarketingFee,
        uint256 _buyMarketingFee,
        uint256 newBuyCribXFee,
        uint256 _buyCribXFee,
        uint256 newBuyLPFee,
        uint256 _buyLPFee
    );
    event UpdateSellFees(
        uint256 newSellProductionFee,
        uint256 _sellProductionFee,
        uint256 newSellMarketingFee,
        uint256 _sellMarketingFee,
        uint256 newSellCribXFee,
        uint256 _sellCribXFee,
        uint256 newBuyLPFee,
        uint256 _buyLPFee
    );
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );

    constructor(address payable _productionWallet, address payable _marketingWallet, address payable _CribXWallet) ERC20 ("CRI3X", "CRI3X") {

        blacklistFee = 99;

        alreadyStarted = false;
        stakingAllowed = false;
        trading = false;
        lpAdded = false;
        sendTokens = true;

        swapTokensAtAmount = 2500000 * (10**18);
        _maxWallet = 5000000 * (10**18);
        _maxBuy = 2500000 * (10**18);
        _maxSell = 2500000 * (10**18);

        totalBuyFees = _buyProductionFee.add(_buyMarketingFee).add(_buyCribXFee).add(_buyLPFee);
        totalSellFees = _sellProductionFee.add(_sellMarketingFee).add(_sellCribXFee).add(_sellLPFee);

        productionWallet = payable(_productionWallet);
        marketingWallet = payable(_marketingWallet);
        CribXWallet = payable(_CribXWallet);

    	IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    	//0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3 Testnet
    	//0x10ED43C718714eb63d5aA57B78B54704E256024E BSC Mainnet
    	//0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D Ropsten
    	//0xCDe540d7eAFE93aC5fE6233Bee57E1270D3E330F BakerySwap
         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        // exclude from paying fees
        excludeFromFees(owner(), true);
        excludeFromFees(marketingWallet, true);
        excludeFromFees(productionWallet, true);
        excludeFromFees(CribXWallet, true);
        excludeFromFees(address(this), true);
        
        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 1000000000 * (10**18));
    }

    receive() external payable {

  	}

	function updateSwapAmount(uint256 amount) public onlyOwner {
	    swapTokensAtAmount = amount * (10**18);
        
        emit UpdateSwapAmount(amount, swapTokensAtAmount);
	}
    
    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapV2Router), "CRI3X: The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "CRI3X: Account is already the value of 'excluded'");
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function addToBlacklist(address account, bool isBlacklisted) public onlyOwner {
        require(_isBlacklisted[account] != isBlacklisted, "CRI3X: Account is already the value of 'elon'");
        _isBlacklisted[account] = isBlacklisted;

        emit blacklist(account, isBlacklisted);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "CRI3X: The Uniswap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, "CRI3X: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateMarketingWallet(address newMarketingWallet) public onlyOwner {
    	require(newMarketingWallet != address(0), "ERC20: transfer to the zero address");
        require(newMarketingWallet != marketingWallet, "CRI3X: The marketing wallet is already this address");
        excludeFromFees(newMarketingWallet, true);
        emit WalletUpdated(newMarketingWallet, marketingWallet);
        marketingWallet = newMarketingWallet;
    }

    function updateProductionWallet(address newProductionWallet) public onlyOwner {
    	require(newProductionWallet != address(0), "ERC20: transfer to the zero address");
        require(newProductionWallet != productionWallet, "CRI3X: The marketing wallet is already this address");
        excludeFromFees(newProductionWallet, true);
        emit WalletUpdated(newProductionWallet, productionWallet);
        productionWallet = newProductionWallet;
    }

    function updateCribXWallet(address newCribXWallet) public onlyOwner {
    	require(newCribXWallet != address(0), "ERC20: transfer to the zero address");
        require(newCribXWallet != CribXWallet, "CRI3X: The Cri3X wallet is already this address");
        excludeFromFees(newCribXWallet, true);
        emit WalletUpdated(newCribXWallet, CribXWallet);
        CribXWallet = newCribXWallet;
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function allowStakingAddress(bool enabled) public onlyOwner {
        stakingAllowed = enabled;
        emit allowStaking(enabled);
    }

    function SendTokensToCribX(bool enabled) public onlyOwner {
        sendTokens = enabled;
        emit sendTokensUpdated(enabled);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (to == uniswapV2Pair && !trading) {
            if (!stakingAllowed) {
            require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "You do not have permission to add liquidity");
            }
        }

        if (from != owner() && to != owner() && to != address(0) && to != address(0xdead) && to != uniswapV2Pair && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) 
        {
            require(trading == true, "Trading is not yet enabled");
            require(amount <= _maxBuy, "Transfer amount exceeds the maxTxAmount.");
            uint256 contractBalanceRecipient = balanceOf(to);
            require(contractBalanceRecipient + amount <= _maxWallet, "Exceeds maximum wallet token amount.");
        }

        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if(!swapping && automatedMarketMakerPairs[to] && from != address(uniswapV2Router) && from != owner() && to != owner() && !_isExcludedFromFees[to] && !_isExcludedFromFees[from])
        {
            require(trading == true, "Trading is not yet enabled");

            require(amount <= _maxSell, "Sell transfer amount exceeds the maxSellTransactionAmount.");
        }

		uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
		
		if(canSwap && !swapping && automatedMarketMakerPairs[to] && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) {
		    
		    contractTokenBalance = swapTokensAtAmount;
		    uint256 swapTokens;
            uint256 swapTokensAmount;
            uint256 half = (contractTokenBalance.mul(_sellLPFee).div(totalSellFees)).div(2);
            contractTokenBalance -= half;
            
            swapping = true;

            if (totalSellFees > 0 && !sendTokens) {
                
            swapTokens = contractTokenBalance;
            swapTokensForEth(swapTokens);
            swapTokensAmount = totalSellFees;

            uint256 CribXAmount = address(this).balance.mul(_sellCribXFee).div(swapTokensAmount);
            (bool success, ) = CribXWallet.call{value: CribXAmount}("");
            require(success, "Failed to send Cri3X amount");
            }

            else if (totalSellFees > 0 && sendTokens) {
                swapTokens = contractTokenBalance;
                uint256 CribXAmount = swapTokens.mul(_sellCribXFee).div(100);
                swapTokens = swapTokens.sub(CribXAmount);
                swapTokensAmount = totalSellFees.sub(_sellCribXFee);

                swapTokensForEth(swapTokens);
                super._transfer(address(this), CribXWallet, CribXAmount);

            }

            if (_sellProductionFee > 0) {
            uint256 productionAmount = address(this).balance.mul(_sellProductionFee).div(swapTokensAmount);
            (bool success, ) = productionWallet.call{value: productionAmount}("");
            require(success, "Failed to send production amount");
            }

            if (_sellLPFee > 0) {
                uint256 newBalance = address(this).balance.mul(_sellLPFee).div(totalSellFees);
            
                // add liquidity to uniswap
                addLiquidity(half, newBalance);

                emit SwapAndLiquify(contractTokenBalance, newBalance, half);   
            }
            
            if (_sellMarketingFee > 0) {
            uint256 marketingAmount = address(this).balance;
            (bool success, ) = marketingWallet.call{value: marketingAmount}("");
            require(success, "Failed to send marketing amount");
            }
			
            swapping = false;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
            super._transfer(from, to, amount);
        }

        else if(!automatedMarketMakerPairs[to] && !automatedMarketMakerPairs[from] && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            takeFee = false;
            super._transfer(from, to, amount);
        }

        if(takeFee) {
            uint256 BuyFees = amount.mul(totalBuyFees).div(100);
            uint256 SellFees = amount.mul(totalSellFees).div(100);
            uint256 BlacklistFee = amount.mul(blacklistFee).div(100);

            if(_isBlacklisted[to] && automatedMarketMakerPairs[from]) {
                amount = amount.sub(BlacklistFee);
                super._transfer(from, address(this), BlacklistFee);
                super._transfer(from, to, amount);
            }

            // if sell
            else if(automatedMarketMakerPairs[to] && totalSellFees > 0) {
                amount = amount.sub(SellFees);
                super._transfer(from, address(this), SellFees);
                super._transfer(from, to, amount);
            }

            // if buy transfer
            else if(automatedMarketMakerPairs[from] && totalBuyFees > 0) {
                amount = amount.sub(BuyFees);
                super._transfer(from, address(this), BuyFees);
                super._transfer(from, to, amount);
                
                if(starting && !_isBlacklisted[to] && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
                _isBlacklisted[to] = true;
                }
                }

            else {
                super._transfer(from, to, amount);
            }
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private {

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
       uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function addLP() external onlyOwner() {
        require(!lpAdded, "This project is already launched");
        updateBuyFees(0,0,0,0);
        updateSellFees(0,0,0,0);

		trading = false;

        updateMaxWallet(1000000000);
        updateMaxBuySell((1000000000), (1000000000));

        lpAdded = true;
    }
    
	function letsGoLive() external onlyOwner() {
        updateBuyFees(10,2,1,1);
        updateSellFees(10,2,1,1);

        updateMaxWallet(5000000);
        updateMaxBuySell(2500000, 2500000);

        starting = false;
        if(!trading) {
            trading = true;
        }
        
        if(!stakingAllowed) {
            stakingAllowed = true;
        }
    }

    function letsBegin() external onlyOwner() {
        require(!alreadyStarted, "This project is already launched");
        _buyMarketingFee = 25;
        _buyProductionFee = 25;
        _buyCribXFee = 25;
        _buyLPFee = 24;
        updateSellFees(10,2,1,1);

        updateMaxWallet(5000000);
        updateMaxBuySell(2500000, 2500000);

		trading = true;
        starting = true;
        alreadyStarted = true;
        stakingAllowed = true;
    }

    function updateBuyFees(uint256 newBuyProductionFee, uint256 newBuyMarketingFee, uint256 newBuyCribXFee, uint256 newBuyLPFee) public onlyOwner {
        require(newBuyProductionFee.add(newBuyMarketingFee).add(newBuyCribXFee).add(newBuyLPFee) <= 25, "Total buy taxes cannot exceed 25%");
        _buyProductionFee = newBuyProductionFee;
        _buyMarketingFee = newBuyMarketingFee;
        _buyCribXFee = newBuyCribXFee;
        _buyLPFee = newBuyLPFee;
        
        totalFees();

        emit UpdateBuyFees(newBuyProductionFee, _buyProductionFee, newBuyMarketingFee, _buyMarketingFee, newBuyCribXFee, _buyCribXFee, newBuyLPFee, _buyLPFee);
    }

    function updateSellFees(uint256 newSellProductionFee, uint256 newSellMarketingFee, uint256 newSellCribXFee, uint256 newSellLPFee) public onlyOwner {
        require(newSellProductionFee.add(newSellMarketingFee).add(newSellCribXFee).add(newSellLPFee) <= 25, "Total sell taxes cannot exceed 25%");
        _sellProductionFee = newSellProductionFee;
        _sellMarketingFee = newSellMarketingFee;
        _sellCribXFee = newSellCribXFee;
        _sellLPFee = newSellLPFee;
        
        totalFees();

        emit UpdateSellFees(newSellProductionFee, _sellProductionFee, newSellMarketingFee, _sellMarketingFee, newSellCribXFee, _sellCribXFee, newSellLPFee, _sellLPFee);
    }

    function updateMaxWallet(uint256 newMaxWallet) public onlyOwner {
        require(newMaxWallet >= 5000000, "Cannot lower max wallet below .5% of total supply");
        _maxWallet = newMaxWallet * (10**18);

        emit UpdateMaxWallet(newMaxWallet, _maxWallet);
    }

    function updateMaxBuySell(uint256 newMaxBuy, uint256 newMaxSell) public onlyOwner {
        require(newMaxBuy >= 2500000, "Cannot lower max buy below .25% of total supply");
        require(newMaxSell >= 2500000, "Cannot lower max sell below .25% of total supply");
        _maxBuy = newMaxBuy * (10**18);
        _maxSell = newMaxSell * (10**18);

        emit UpdateMaxBuySell(newMaxBuy, _maxBuy, newMaxSell, _maxSell);
    }

    function totalFees() private {
        totalBuyFees = _buyProductionFee.add(_buyMarketingFee).add(_buyCribXFee).add(_buyLPFee);
        totalSellFees = _sellProductionFee.add(_sellMarketingFee).add(_sellCribXFee).add(_sellLPFee);
    }

    function withdrawRemainingETH(address account, uint256 percent) public onlyOwner {
        require(percent > 0 && percent <= 100, "Must be a valid percent");
        require(account != address(0), "ERC20: transfer to the zero address");
        uint256 percentage = percent.div(100);
        uint256 balance = address(this).balance.mul(percentage);
        
        (bool success, ) = account.call{value: balance}("");
        require(success, "Failed to send withdraw ETH");
    }

    function withdrawRemainingToken(address account, uint256 amount) public onlyOwner {
        require(amount <= balanceOf(address(this)), "Amount cannot exceed tokens in contract");
        super._transfer(address(this), account, amount);
    }

    function withdrawRemainingERC20Token(address token, address account) public onlyOwner {
        ERC20 Token = ERC20(token);
        uint256 balance = Token.balanceOf(address(this));
        Token.transfer(account, balance);
    }

    function burnTokenManual(uint256 amount) public onlyOwner {
        require(amount <= balanceOf(address(this)), "Amount cannot exceed tokens in contract");
        _burn(address(this), amount);
    }
}
