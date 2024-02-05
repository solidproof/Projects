// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Metate is Context, ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 private _uniswapV2Router;

    mapping (address => uint) private _cooldown;

    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) private _isExcludedMaxTransactionAmount;
    mapping (address => bool) private _isBlacklisted;

    bool public tradingOpen;
    bool private _swapping;
    bool public swapEnabled = false;
    bool public cooldownEnabled = false;
    bool public feesEnabled = true;

    string private constant _name = "Metate";
    string private constant _symbol = "CHI";

    uint8 private constant _decimals = 18;

    uint256 private constant _totalSupply = 1e11 * (10**_decimals);

    uint256 public maxBuyAmount = _totalSupply;
    uint256 public maxSellAmount = _totalSupply;
    uint256 public maxWalletAmount = _totalSupply;

    uint256 public tradingOpenBlock = 0;
    uint256 private _blocksToBlacklist = 0;
    uint256 private _cooldownBlocks = 1;

    uint256 public constant FEE_DIVISOR = 1000;

    uint256 private _totalFees;
    uint256 private _bbceFee;
    uint256 private _opsFee;
    uint256 private _devFee;
    uint256 private _liqFee;

    uint256 public buyBBCEFee = 30;
    uint256 private _previousBuyBBCEFee = buyBBCEFee;
    uint256 public buyOpsFee = 30;
    uint256 private _previousBuyOpsFee = buyOpsFee;
    uint256 public buyDevFee = 20;
    uint256 private _previousBuyDevFee = buyDevFee;
    uint256 public buyLiqFee = 10;
    uint256 private _previousBuyLiqFee = buyLiqFee;

    uint256 public sellBBCEFee = 30;
    uint256 private _previousSellBBCEFee = sellBBCEFee;
    uint256 public sellOpsFee = 30;
    uint256 private _previousSellOpsFee = sellOpsFee;
    uint256 public sellDevFee = 30;
    uint256 private _previousSellDevFee = sellDevFee;
    uint256 public sellLiqFee = 10;
    uint256 private _previousSellLiqFee = sellLiqFee;

    uint256 private _tokensForBBCE;
    uint256 private _tokensForOps;
    uint256 private _tokensForDev;
    uint256 private _tokensForLiq;
    uint256 private _swapTokensAtAmount = 0;

    address payable private _bbCEWallet;
    address payable private _opsWallet;
    address payable private _devWallet1;
    address payable private _devWallet2;
    address payable private _liqWallet;

    address private _uniswapV2Pair;
    address private DEAD = 0x000000000000000000000000000000000000dEaD;
    address private ZERO = 0x0000000000000000000000000000000000000000;
    
    constructor (address payable bbCEWallet, address payable opsWallet, address payable devWallet1, address payable devWallet2, address payable liqWallet) ERC20(_name, _symbol) {
        _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(_uniswapV2Router), _totalSupply);
        _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        IERC20(_uniswapV2Pair).approve(address(_uniswapV2Router), type(uint).max);

        _bbCEWallet = bbCEWallet;
        _opsWallet = opsWallet;
        _devWallet1 = devWallet1;
        _devWallet2 = devWallet2;
        _liqWallet = liqWallet;

        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[DEAD] = true;
        _isExcludedFromFees[_bbCEWallet] = true;
        _isExcludedFromFees[_opsWallet] = true;
        _isExcludedFromFees[_devWallet1] = true;
        _isExcludedFromFees[_devWallet2] = true;
        _isExcludedFromFees[_liqWallet] = true;

        _isExcludedMaxTransactionAmount[owner()] = true;
        _isExcludedMaxTransactionAmount[address(this)] = true;
        _isExcludedMaxTransactionAmount[DEAD] = true;
        _isExcludedMaxTransactionAmount[_bbCEWallet] = true;
        _isExcludedMaxTransactionAmount[_opsWallet] = true;
        _isExcludedMaxTransactionAmount[_devWallet1] = true;
        _isExcludedMaxTransactionAmount[_devWallet2] = true;
        _isExcludedMaxTransactionAmount[_liqWallet] = true;

        _mint(owner(), _totalSupply);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != ZERO, "ERC20: transfer from the zero address");
        require(to != ZERO, "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        bool takeFee = true;
        bool shouldSwap = false;
        if (from != owner() && to != owner() && to != ZERO && to != DEAD && !_swapping) {
            require(!_isBlacklisted[from] && !_isBlacklisted[to]);

            if(!tradingOpen) require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "Trading is not allowed yet.");

            if (cooldownEnabled) {
                if (to != address(_uniswapV2Router) && to != address(_uniswapV2Pair)) {
                    require(_cooldown[tx.origin] < block.number - _cooldownBlocks && _cooldown[to] < block.number - _cooldownBlocks, "Transfer delay enabled. Try again later.");
                    _cooldown[tx.origin] = block.number;
                    _cooldown[to] = block.number;
                }
            }

            if (from == _uniswapV2Pair && to != address(_uniswapV2Router) && !_isExcludedMaxTransactionAmount[to]) {
                require(amount <= maxBuyAmount, "Transfer amount exceeds the maxBuyAmount.");
                require(balanceOf(to) + amount <= maxWalletAmount, "Exceeds maximum wallet token amount.");
            }
            
            if (to == _uniswapV2Pair && from != address(_uniswapV2Router) && !_isExcludedMaxTransactionAmount[from]) {
                require(amount <= maxSellAmount, "Transfer amount exceeds the maxSellAmount.");
                shouldSwap = true;
            }
        }

        if(_isExcludedFromFees[from] || _isExcludedFromFees[to] || !feesEnabled) takeFee = false;

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = (contractTokenBalance > _swapTokensAtAmount) && shouldSwap;

        if (canSwap && swapEnabled && !_swapping && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            _swapping = true;
            swapBack();
            _swapping = false;
        }

        _tokenTransfer(from, to, amount, takeFee, shouldSwap);
    }

    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap =  _tokensForBBCE.add(_tokensForOps).add(_tokensForDev).add(_tokensForLiq);
        bool success;
        
        if (contractBalance == 0 || totalTokensToSwap == 0) return;

        if (contractBalance > _swapTokensAtAmount.mul(5)) contractBalance = _swapTokensAtAmount.mul(5);

        uint256 liquidityTokens = contractBalance.mul(_tokensForLiq).div(totalTokensToSwap).div(2);
        uint256 amountToSwapForETH = contractBalance.sub(liquidityTokens);

        uint256 initialETHBalance = address(this).balance;

        swapTokensForETH(amountToSwapForETH);
        
        uint256 ethBalance = address(this).balance.sub(initialETHBalance);
        uint256 ethForBBCE = ethBalance.mul(_tokensForBBCE).div(totalTokensToSwap);
        uint256 ethForOps = ethBalance.mul(_tokensForOps).div(totalTokensToSwap);
        uint256 ethForDev = ethBalance.mul(_tokensForDev).div(totalTokensToSwap);
        uint256 ethForLiq = ethBalance.sub(ethForBBCE).sub(ethForOps).sub(ethForDev);
        
        _tokensForBBCE = 0;
        _tokensForOps = 0;
        _tokensForDev = 0;
        _tokensForLiq = 0;

        if(liquidityTokens > 0 && ethForLiq > 0) _addLiquidity(liquidityTokens, ethForLiq);

        (success,) = address(_bbCEWallet).call{value: ethForBBCE}("");
        (success,) = address(_devWallet1).call{value: ethForDev.div(2)}("");
        (success,) = address(_devWallet2).call{value: ethForDev.div(2)}("");
        (success,) = address(_opsWallet).call{value: address(this).balance}("");
    }

    function swapTokensForETH(uint256 tokenAmount) private {
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

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        _approve(address(this), address(_uniswapV2Router), tokenAmount);
        _uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            _liqWallet,
            block.timestamp
        );
    }
        
    function sendETHToFee(uint256 amount) private {
        _bbCEWallet.transfer(amount.div(4));
        _opsWallet.transfer(amount.div(4));
        _devWallet1.transfer(amount.div(4));
        _devWallet2.transfer(amount.div(4));
    }

    function isBlacklisted(address wallet) external view returns (bool) {
        return _isBlacklisted[wallet];
    }

    function openTrading(uint256 blocks) public onlyOwner() {
        require(!tradingOpen, "Trading is already open");
        swapEnabled = true;
        cooldownEnabled = true;
        maxSellAmount = _totalSupply.mul(1).div(100);
        _swapTokensAtAmount = _totalSupply.mul(5).div(10000);
        tradingOpen = true;
        tradingOpenBlock = block.number;
        _blocksToBlacklist = blocks;
    }

    function setCooldownEnabled(bool onoff) public onlyOwner {
        cooldownEnabled = onoff;
    }

    function setSwapEnabled(bool onoff) public onlyOwner {
        swapEnabled = onoff;
    }

    function setFeesEnabled(bool onoff) public onlyOwner {
        feesEnabled = onoff;
    }

    function setMaxBuyAmount(uint256 _maxBuyAmount) public onlyOwner {
        require(_maxBuyAmount >= (totalSupply().mul(1).div(1000)), "Max buy amount cannot be lower than 0.1% total supply.");
        maxBuyAmount = _maxBuyAmount;
    }

    function setMaxSellAmount(uint256 _maxSellAmount) public onlyOwner {
        require(_maxSellAmount >= (totalSupply().mul(1).div(1000)), "Max sell amount cannot be lower than 0.1% total supply.");
        maxSellAmount = _maxSellAmount;
    }
    
    function setMaxWalletAmount(uint256 _maxWalletAmount) public onlyOwner {
        require(_maxWalletAmount >= (totalSupply().mul(1).div(1000)), "Max wallet amount cannot be lower than 0.1% total supply.");
        maxWalletAmount = _maxWalletAmount;
    }
    
    function setSwapTokensAtAmount(uint256 swapTokensAtAmount) public onlyOwner {
        require(swapTokensAtAmount >= (totalSupply().mul(1).div(100000)), "Swap amount cannot be lower than 0.001% total supply.");
        require(swapTokensAtAmount <= (totalSupply().mul(5).div(1000)), "Swap amount cannot be higher than 0.5% total supply.");
        _swapTokensAtAmount = swapTokensAtAmount;
    }

    function setBBCEWallet(address bbCEWallet) public onlyOwner {
        require(bbCEWallet != ZERO, "_bbCEWallet address cannot be 0");
        _isExcludedFromFees[_bbCEWallet] = false;
        _isExcludedMaxTransactionAmount[_bbCEWallet] = false;
        _bbCEWallet = payable(bbCEWallet);
        _isExcludedFromFees[_bbCEWallet] = true;
        _isExcludedMaxTransactionAmount[_bbCEWallet] = true;
    }

    function setOpsWallet(address opsWallet) public onlyOwner {
        require(opsWallet != ZERO, "_opsWallet address cannot be 0");
        _isExcludedFromFees[_opsWallet] = false;
        _isExcludedMaxTransactionAmount[_opsWallet] = false;
        _opsWallet = payable(opsWallet);
        _isExcludedFromFees[_opsWallet] = true;
        _isExcludedMaxTransactionAmount[_opsWallet] = true;
    }

    function setDevWallet1(address devWallet1) public onlyOwner {
        require(devWallet1 != ZERO, "_devWallet1 address cannot be 0");
        _isExcludedFromFees[_devWallet1] = false;
        _isExcludedMaxTransactionAmount[_devWallet1] = false;
        _devWallet1 = payable(devWallet1);
        _isExcludedFromFees[_devWallet1] = true;
        _isExcludedMaxTransactionAmount[_devWallet1] = true;
    }

    function setDevWallet2(address devWallet2) public onlyOwner {
        require(devWallet2 != ZERO, "_devWallet2 address cannot be 0");
        _isExcludedFromFees[_devWallet2] = false;
        _isExcludedMaxTransactionAmount[_devWallet2] = false;
        _devWallet2 = payable(devWallet2);
        _isExcludedFromFees[_devWallet2] = true;
        _isExcludedMaxTransactionAmount[_devWallet2] = true;
    }

    function setLiqWallet(address liqWallet) public onlyOwner {
        require(liqWallet != ZERO, "_liqWallet address cannot be 0");
        _isExcludedFromFees[_liqWallet] = false;
        _isExcludedMaxTransactionAmount[_liqWallet] = false;
        _liqWallet = payable(liqWallet);
        _isExcludedFromFees[_liqWallet] = true;
        _isExcludedMaxTransactionAmount[_liqWallet] = true;
    }

    function setExcludedFromFees(address[] memory accounts, bool isEx) public onlyOwner {
        for (uint i = 0; i < accounts.length; i++) _isExcludedFromFees[accounts[i]] = isEx;
    }
    
    function setExcludeFromMaxTransaction(address[] memory accounts, bool isEx) public onlyOwner {
        for (uint i = 0; i < accounts.length; i++) _isExcludedMaxTransactionAmount[accounts[i]] = isEx;
    }
    
    function setBlacklisted(address[] memory accounts, bool isBL) public onlyOwner {
        for (uint i = 0; i < accounts.length; i++) {
            if(accounts[i] != _uniswapV2Pair) _isBlacklisted[accounts[i]] = isBL;
        }
    }

    function setBuyFee(uint256 _buyBBCEFee, uint256 _buyOpsFee, uint256 _buyDevFee, uint256 _buyLiqFee) public onlyOwner {
        require(_buyBBCEFee.add(_buyOpsFee).add(_buyDevFee).add(_buyLiqFee) <= 200, "Must keep buy taxes below 20%");
        buyBBCEFee = _buyBBCEFee;
        buyOpsFee = _buyOpsFee;
        buyDevFee = _buyDevFee;
        buyLiqFee = _buyLiqFee;
    }

    function setSellFee(uint256 _sellBBCEFee, uint256 _sellOpsFee, uint256 _sellDevFee, uint256 _sellLiqFee) public onlyOwner {
        require(_sellBBCEFee.add(_sellOpsFee).add(_sellDevFee).add(_sellLiqFee) <= 200, "Must keep sell taxes below 20%");
        sellBBCEFee = _sellBBCEFee;
        sellOpsFee = _sellOpsFee;
        sellDevFee = _sellDevFee;
        sellLiqFee = _sellLiqFee;
    }

    function setCooldownBlocks(uint256 blocks) public onlyOwner {
        require(blocks >= 0 && blocks <= 10, "Invalid blocks count.");
        _cooldownBlocks = blocks;
    }

    function removeAllFee() private {
        if (buyBBCEFee == 0 && buyOpsFee == 0 && buyDevFee == 0 && buyLiqFee == 0 && sellBBCEFee == 0 && sellOpsFee == 0 && sellDevFee == 0 && sellLiqFee == 0) return;

        _previousBuyBBCEFee = buyBBCEFee;
        _previousBuyOpsFee = buyOpsFee;
        _previousBuyDevFee = buyDevFee;
        _previousBuyLiqFee = buyLiqFee;
        _previousSellBBCEFee = sellBBCEFee;
        _previousSellOpsFee = sellOpsFee;
        _previousSellDevFee = sellDevFee;
        _previousSellLiqFee = sellLiqFee;
        
        buyBBCEFee = 0;
        buyOpsFee = 0;
        buyDevFee = 0;
        buyLiqFee = 0;
        sellBBCEFee = 0;
        sellOpsFee = 0;
        sellDevFee = 0;
        sellLiqFee = 0;
    }
    
    function restoreAllFee() private {
        buyBBCEFee = _previousBuyBBCEFee;
        buyOpsFee = _previousBuyOpsFee;
        buyDevFee = _previousBuyDevFee;
        buyLiqFee = _previousBuyLiqFee;
        sellBBCEFee = _previousSellBBCEFee;
        sellOpsFee = _previousSellOpsFee;
        sellDevFee = _previousSellDevFee;
        sellLiqFee = _previousSellLiqFee;
    }
        
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee, bool isSell) private {
        if (!takeFee) removeAllFee();
        else amount = _takeFees(sender, amount, isSell);

        super._transfer(sender, recipient, amount);
        
        if (!takeFee) restoreAllFee();
    }

    function _takeFees(address sender, uint256 amount, bool isSell) private returns (uint256) {
        if(tradingOpenBlock + _blocksToBlacklist >= block.number) _setBot();
        else if (isSell) _setSell();
        else _setBuy();
        
        uint256 fees;
        if (_totalFees > 0) {
            fees = amount.mul(_totalFees).div(FEE_DIVISOR);
            _tokensForBBCE += fees * _bbceFee / _totalFees;
            _tokensForOps += fees * _opsFee / _totalFees;
            _tokensForDev += fees * _devFee / _totalFees;
            _tokensForLiq += fees * _devFee / _totalFees;
        }

        if (fees > 0) super._transfer(sender, address(this), fees);

        return amount -= fees;
    }

    function _setBot() private {
        _bbceFee = 222;
        _opsFee = 222;
        _devFee = 222;
        _liqFee = 222;
        _totalFees = _bbceFee.add(_opsFee).add(_devFee).add(_liqFee);
    }

    function _setSell() private {
        _bbceFee = sellBBCEFee;
        _opsFee = sellOpsFee;
        _devFee = sellDevFee;
        _liqFee = sellLiqFee;
        _totalFees = _bbceFee.add(_opsFee).add(_devFee).add(_liqFee);
    }

    function _setBuy() private {
        _bbceFee = buyBBCEFee;
        _opsFee = buyOpsFee;
        _devFee = buyDevFee;
        _liqFee = buyLiqFee;
        _totalFees = _bbceFee.add(_opsFee).add(_devFee).add(_liqFee);
    }
    
    function unclog() public onlyOwner {
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForETH(contractBalance);
    }
    
    function distributeFees() public onlyOwner {
        uint256 contractETHBalance = address(this).balance;
        sendETHToFee(contractETHBalance);
    }

    function withdrawStuckETH() public onlyOwner {
        bool success;
        (success,) = address(msg.sender).call{value: address(this).balance}("");
    }

    function withdrawStuckTokens(address tkn) public onlyOwner {
        require(tkn != address(this), "Cannot withdraw own token");
        require(IERC20(tkn).balanceOf(address(this)) > 0, "No tokens");
        uint amount = IERC20(tkn).balanceOf(address(this));
        IERC20(tkn).transfer(msg.sender, amount);
    }

    function removeLimits() public onlyOwner {
        maxBuyAmount = _totalSupply;
        maxSellAmount = _totalSupply;
        maxWalletAmount = _totalSupply;
        cooldownEnabled = false;
    }

    receive() external payable {}
    fallback() external payable {}

}
