// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./ERC20.sol";
import "./Ownable.sol";
import "./DividendTracker.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Pair.sol";


contract MetaverseDao is ERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    bool private inSwap = false;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => uint256) private _balances;
    address private _owner;
    address public pdcWbnbPair;
    address public usdtWbnbPair;

    string public _name = "Metaverse-DAO";
    string public _symbol = "METADAO";
    address public router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address public usdt = 0x55d398326f99059fF775485246999027B3197955;
    address public WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    
    uint256 public _maxTotal = 35 * 10 ** 7 * 10 ** 18 ;
    uint256 public _total = 0;
    uint256 private _maxSell = 1 * 10 ** 5 * 10 ** 18;
    uint256 public minimumAmountToSwap = 30 * 10 ** 18;
    uint8 private _decimals = 18;
    uint256 public gasForProcessing = 300000;
    uint256 public highestSellTaxRate = 45;
    bool public enableFee = true;
    bool public isAutoDividend = true;
    uint256 constant internal priceMagnitude = 2 ** 64;
    uint256 public basePrice;
    uint256 public basePriceTimeInterval = 4320;
    uint256 public basePricePreMin = 180;
    uint256 public lastBasePriceTimestamp;
    uint256 public startTimestamp;
    uint256 public sellRateUpper = 100;
    uint256 public sellRateBelow = 200;
    uint256 public fixSellSlippage = 0;
    uint256 public currentSellRate = 0;

    address public _divReceiver;
    address public _developReceiver = 0x47d5866c21226848db6c5ae73C263F070EFe1F5b;
    address public _consultantReceiver = 0x7DA66c7DC804D6E44f570Ca7054D2460f150c88c;
    address public _operateReceiver = 0x2434F7B2B5B042a050F31C3E2D891EB1Dfe478dB;
    address public _raiseReceiver = 0x0F3F2660e0357f9C4170ae02DDCBB157908c87eF;

    DividendTracker public dividendTracker;
    IUniswapV2Router02 public uniswapV2Router;

    constructor() ERC20("Metaverse-DAO", "METADAO") public {

        address _blackhole = 0x000000000000000000000000000000000000dEaD;
        _owner = msg.sender;
        dividendTracker = new DividendTracker();
        _divReceiver = address(dividendTracker);
        _allowances[address(this)][router] = uint256(2 ** 256 -1);
        WBNB = IUniswapV2Router02(router).WETH();
        startTimestamp = block.timestamp;
        uniswapV2Router = IUniswapV2Router02(router);

        _mint(_owner, _maxTotal);

        uint256 raiseAmount = _maxTotal.mul(10).div(100);
        _transferStandard(_owner, _raiseReceiver, raiseAmount.mul(20).div(100));

        uint256 operateAmount = _maxTotal.mul(8).div(100);
        _transferStandard(_owner, _operateReceiver, operateAmount.mul(20).div(100));

        uint256 consultantAmount = _maxTotal.mul(2).div(100);
        _transferStandard(_owner, _consultantReceiver, consultantAmount.mul(20).div(100));

        dividendTracker.excludeFromDividends(_blackhole);
        dividendTracker.excludeFromDividends(address(this));
        dividendTracker.excludeFromDividends(owner());
        dividendTracker.excludeFromDividends(_divReceiver);
        dividendTracker.excludeFromDividends(router);

        _isExcludedFromFee[_divReceiver] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_blackhole] = true;
        _isExcludedFromFee[router] = true;
        _isExcludedFromFee[owner()] = true;

        try dividendTracker.setBalance(payable(_consultantReceiver), balanceOf(_consultantReceiver)) {}  catch {}
        try dividendTracker.setBalance(payable(_operateReceiver), balanceOf(_operateReceiver)) {}  catch {}
        try dividendTracker.setBalance(payable(_raiseReceiver), balanceOf(_raiseReceiver)) {}  catch {}
    }

    function _mint(address account, uint256 amount) internal override {
        require(account != address(0), "ERC20: mint to the zero address.");
        require(_total.add(amount) <= _maxTotal, "reach maximum.");

        _total = _total.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}
    
    function transfer(address recipient, uint256 amount) public override returns(bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public override returns(bool){
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance."));
        return true;
    }
    
    function _transfer(address from, address to, uint256 amount) internal override {
        
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(from != to, "Sender and reciever must be different");
        require(amount > 0, "Transfer amount must be greater than zero");

        if(to == pdcWbnbPair && enableFee && from != _divReceiver && from != _owner) {
            require(amount <= _maxSell, "sell amount reach maximum.");
        }
        
        checkLps();
        
        if((from == pdcWbnbPair || to == pdcWbnbPair) && enableFee) { 
            _updateBasePrice();
            currentSellRate = _getSellTaxRate();
        }

        if(to == pdcWbnbPair){
            if(!inSwap && enableFee){
                inSwap = true;
                if(from != _divReceiver && isAutoDividend){
                    _swapDividend();
                }
                inSwap = false;
            }
        }

        if (_isExcludedFromFee[from] || _isExcludedFromFee[to] || !enableFee) {
            _transferWithoutFee(from, to, amount);
        } else {
            if (from == pdcWbnbPair) {
                _transferBuyStandard(from, to, amount);
            } else if (to == pdcWbnbPair) {
                _transferSellStandard(from, to, amount);
            } else {
                _transferStandard(from, to, amount);
            }
        }

        
        try dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try dividendTracker.setBalance(payable(to), balanceOf(to)) {}  catch {}
        
        if((from == pdcWbnbPair || to == pdcWbnbPair) && !inSwap && isAutoDividend) {
    	    uint256 gas = gasForProcessing;
            try dividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
        		emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
        	} catch {}
        }
    }
    
    function _approve(address owner, address spender, uint256 amount) internal override {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transferBuyStandard(address sender, address recipient, uint256 amount) private {

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    function _transferSellStandard(address from, address to, uint256 amount) private {
        uint256 totalFee = _distributeSellFees(from, amount);

        uint256 transferAmount = amount.sub(totalFee);
        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(transferAmount);

        emit Transfer(from, to, transferAmount);
    }

    function _distributeSellFees(address from, uint256 amount) private returns (uint256 totalFee) {
        uint256 divFee = _getSellFees(amount);

        _balances[_divReceiver] = _balances[_divReceiver].add(divFee);
        emit Transfer(from, _divReceiver, divFee);

        return divFee;
    }

    function _getSellFees(uint256 amount) private view returns (uint256 divFee) {
        uint256 amountOutWbnb = _getAmountOutWbnb(amount);
        uint256 amountOutWbnbAfterFee = amountOutWbnb.sub(amountOutWbnb.mul(currentSellRate).div(10000));
        uint256 amountInPd = _getAmountInPd(amountOutWbnbAfterFee);
        uint256 fee = amount.sub(amountInPd);
        divFee = fee;
    }

    function _getSellTaxRate() public view returns (uint256) {
        if(fixSellSlippage > 0){
            return _convertToSellSlippage(fixSellSlippage);
        }

        uint256 rate = _getBasePriceRate();
        if (rate == 0 || rate == 1000) {
            return _convertToSellSlippage(100);
        }
        uint256 diff;
        uint256 rateToReturn;
        if (rate > 1000) {
            diff = rate.sub(1000);
            rateToReturn = diff.mul(sellRateUpper).div(100).add(100);
            if (rateToReturn > highestSellTaxRate.mul(10)) {
                return _convertToSellSlippage(highestSellTaxRate.mul(10));
            } else {
                return _convertToSellSlippage(rateToReturn);
            }
        }

        diff = uint256(1000).sub(rate);
        rateToReturn = diff.mul(sellRateBelow).div(100).add(100);
        if (rateToReturn > highestSellTaxRate.mul(10)) {
            return _convertToSellSlippage(highestSellTaxRate.mul(10));
        } else {
            return _convertToSellSlippage(rateToReturn);
        }
    }
    
    function getSellTaxRate() public view returns (uint256) {
        if(fixSellSlippage > 0){
            return (fixSellSlippage);
        }

        uint256 rate = _getBasePriceRate();
        if (rate == 0 || rate == 1000) {
            return (100);
        }
        uint256 diff;
        uint256 rateToReturn;
        if (rate > 1000) {
            diff = rate.sub(1000);
            rateToReturn = diff.mul(sellRateUpper).div(100).add(100);
            if (rateToReturn > highestSellTaxRate.mul(10)) {
                return (highestSellTaxRate.mul(10));
            } else {
                return (rateToReturn);
            }
        }

        diff = uint256(1000).sub(rate);
        rateToReturn = diff.mul(sellRateBelow).div(100).add(100);
        if (rateToReturn > highestSellTaxRate.mul(10)) {
            return (highestSellTaxRate.mul(10));
        } else {
            return (rateToReturn);
        }
    }

    function _convertToSellSlippage(uint256 taxRate) private pure returns(uint256) {
        return uint256(10000).sub(uint256(10000000).div(uint256(1000).add(taxRate)));
    }

    function _transferStandard(address from, address to, uint256 amount) private {
        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(amount);

        emit Transfer(from, to, amount);
    }

    function _transferWithoutFee(address sender, address recipient, uint256 amount) private {
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }
    
    function checkLps() private {
        //create a uniswap pair for this new token
        address _pdcWbnbPair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(this), WBNB);
        if (pdcWbnbPair != _pdcWbnbPair) {
            pdcWbnbPair = _pdcWbnbPair;
            dividendTracker.excludeFromDividends(address(_pdcWbnbPair));
        }
        
        address _usdtWbnbPair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(usdt), WBNB);
        if (usdtWbnbPair != _usdtWbnbPair) {
             usdtWbnbPair = _usdtWbnbPair;
             dividendTracker.excludeFromDividends(address(_usdtWbnbPair));
        }
    }
    
    function _updateBasePrice() private {
        (uint256 _pdcReserve, uint256 _wbnbReserve) = _getPdcWbnbReserves();
        if(_pdcReserve <= 0 || _wbnbReserve <= 0) return;

        uint256 currentPrice = getLpPriceNow();
        if(lastBasePriceTimestamp == 0) {
            lastBasePriceTimestamp = block.timestamp;
            basePrice = currentPrice;
            return;
        }

        uint256 lastTimeMin = lastBasePriceTimestamp.div(60);
        uint256 currentTimeMin = block.timestamp.div(60);
        if(lastTimeMin == currentTimeMin) return;

        uint256 startMin = startTimestamp.div(60);
        uint256 minSinceBegin = currentTimeMin.sub(startMin).add(1);
        uint256 timeInterval = basePriceTimeInterval;
        
        if (currentTimeMin > lastTimeMin) {
            uint256 minSinceLast = currentTimeMin.sub(lastTimeMin);
            if (minSinceBegin > timeInterval) {
                if (minSinceLast > timeInterval) {
                    basePrice = currentPrice;
                } else {
                    basePrice = basePrice.mul(timeInterval.sub(minSinceLast)).div(timeInterval).add(currentPrice.mul(minSinceLast).div(timeInterval));
                }
            } else {
                uint256 denominator = minSinceBegin.add(basePricePreMin);
                basePrice = basePrice.mul(denominator.sub(minSinceLast)).div(denominator).add(currentPrice.mul(minSinceLast).div(denominator));
            }
        }

        lastBasePriceTimestamp = block.timestamp;
    }
    
    function getLpPriceNow() public view returns(uint256) {
        (uint112 pwreserve0, uint112 pwreserve1, ) = IUniswapV2Pair(pdcWbnbPair).getReserves();
        if(pwreserve0 == 0 || pwreserve1 == 0){
            return 0;
        }
        address pwtoken0 = IUniswapV2Pair(pdcWbnbPair).token0();
        uint256 pdPriceInWbnb;
        if(pwtoken0 == address(this)){
            pdPriceInWbnb = uint256(pwreserve1).mul(priceMagnitude).div(uint256(pwreserve0));
        } else {
            pdPriceInWbnb = uint256(pwreserve0).mul(priceMagnitude).div(uint256(pwreserve1));
        }

        (uint112 uwreserve0, uint112 uwreserve1, ) = IUniswapV2Pair(usdtWbnbPair).getReserves();
        if(uwreserve0 == 0 || uwreserve1 == 0){
            return 0;
        }
        address uwtoken0 = IUniswapV2Pair(usdtWbnbPair).token0();
        uint256 wbnbPriceInUsdt;
        if(uwtoken0 == WBNB){
            wbnbPriceInUsdt = uint256(uwreserve1).mul(priceMagnitude).div(uint256(uwreserve0));
        } else {
            wbnbPriceInUsdt = uint256(uwreserve0).mul(priceMagnitude).div(uint256(uwreserve1));
        }

        return pdPriceInWbnb.mul(wbnbPriceInUsdt).div(priceMagnitude);
    }

    function _getBasePriceRate() public view returns (uint256) {
        uint256 basePriceNow = getBasePriceNow();
        if (basePriceNow == 0) return 0;
        uint256 lpPrice = getLpPriceNow();
        if (lpPrice == 0) return 0;
        return lpPrice.mul(1000).div(basePriceNow);
    }

    function getBasePriceNow() public view returns(uint256) {
        uint256 _currentLpPrice = getLpPriceNow();
        if (basePrice == 0) return _currentLpPrice;
        uint256 lastTimeMin = lastBasePriceTimestamp.div(60);
        uint256 currentTimeMin = block.timestamp.div(60);
        uint256 timeInterval = basePriceTimeInterval;
        if (currentTimeMin == lastTimeMin) {
            return basePrice;
        } else {
            uint256 startMin = uint256(startTimestamp).div(60);
            uint256 minSinceBegin = currentTimeMin.sub(startMin).add(1);
            uint256 minSinceLast = currentTimeMin.sub(lastTimeMin);
            if (minSinceBegin > timeInterval) {
                if(minSinceLast > timeInterval) {
                    return _currentLpPrice;
                } else {
                    return basePrice.mul(timeInterval.sub(minSinceLast)).div(timeInterval).add(_currentLpPrice.mul(minSinceLast).div(timeInterval));
                }
            } else {
                uint256 denominator = minSinceBegin.add(basePricePreMin);
                return basePrice.mul(denominator.sub(minSinceLast)).div(denominator).add(_currentLpPrice.mul(minSinceLast).div(denominator));
            }
        }
    }
    
    function _getPdcWbnbReserves() private view returns(uint256 _pdcReserve, uint256 _wbnbReserve) {
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pdcWbnbPair).getReserves();
        address token0 = IUniswapV2Pair(pdcWbnbPair).token0();
        if(token0 == address(this)){
            _pdcReserve = uint256(reserve0);
            _wbnbReserve = uint256(reserve1);
        } else {
            _pdcReserve = uint256(reserve1);
            _wbnbReserve = uint256(reserve0);
        }
    }

    function _getWbnbUsdtReserves() private view returns(uint256 _wbnbReserve, uint256 _usdtReserve) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(usdtWbnbPair).getReserves();
        address token0 = IUniswapV2Pair(usdtWbnbPair).token0();
        if (token0 == WBNB) {
            _wbnbReserve = uint256(reserve0);
            _usdtReserve = uint256(reserve1);
        } else {
            _wbnbReserve = uint256(reserve1);
            _usdtReserve = uint256(reserve0);
        }
    }

    function _getAmountInUsdt(uint256 tokenAmount) public view returns (uint256) {
        if (tokenAmount <= 0) return 0;
        (uint256 _pdcReserve, uint256 _wbnbReserve) = _getPdcWbnbReserves();
        if (_wbnbReserve <= 0) return 0;
        if (_pdcReserve <= 0) return 0;
        uint256 wbnbIn = uint256(getAmountIn(tokenAmount, _wbnbReserve, _pdcReserve));
        
        (uint256 _wbnbReserve1, uint256 _usdtReserve) = _getWbnbUsdtReserves();
        if (_wbnbReserve1 <= 0) return 0;
        if (_usdtReserve <= 0) return 0;
        return uint256(getAmountIn(wbnbIn, _usdtReserve, _wbnbReserve1));
    }

    function _getAmountOutUsdt(uint256 tokenAmount) public view returns (uint256) {
        if (tokenAmount <= 0) return 0;
        (uint256 _pdcReserve, uint256 _wbnbReserve) = _getPdcWbnbReserves();
        if (_wbnbReserve <= 0 || _pdcReserve <= 0) return 0;
        uint256 wbnbOut = uint256(getAmountOut(tokenAmount, _pdcReserve, _wbnbReserve));
        
        (uint256 _wbnbReserve1, uint256 _usdtReserve) = _getWbnbUsdtReserves();
        if (_wbnbReserve1 <= 0 || _usdtReserve <= 0) return 0;
        return uint256(getAmountOut(wbnbOut, _wbnbReserve1, _usdtReserve)); 
    }

    function _getAmountOutWbnb(uint256 tokenAmount) public view returns (uint256) {
        if (tokenAmount <= 0) return 0;
        (uint256 _pdcReserve, uint256 _wbnbReserve) = _getPdcWbnbReserves();
        if (_wbnbReserve <= 0 || _pdcReserve <= 0) return 0;
        return uint256(getAmountOut(tokenAmount, _pdcReserve, _wbnbReserve));
    }

    function _getAmountInPd(uint256 amountOut) private view returns(uint256){
        (uint256 _pdcReserve, uint256 _wbnbReserve) = _getPdcWbnbReserves();
        if (_wbnbReserve <= 0 || _pdcReserve <= 0) return 0;
        return uint256(getAmountIn(amountOut, _pdcReserve, _wbnbReserve));
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        if (amountOut <= 0) return 0;
        if (reserveIn <= 0) return 0;
        if (reserveOut <= 0) return 0;
        uint numerator = reserveIn.mul(amountOut).mul(10000);
        uint denominator = reserveOut.sub(amountOut).mul(9975);
        amountIn = (numerator / denominator).add(1);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        if (amountIn <= 0) return 0;
        if (reserveIn <= 0) return 0;
        if (reserveOut <= 0) return 0;
        uint amountInWithFee = amountIn.mul(9975);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(10000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
    
    
    function _swapDividend() internal {
        uint256 divBal = balanceOf(_divReceiver);
        uint256 divBalInUsdt = _getAmountOutUsdt(divBal);
        if (divBalInUsdt >= minimumAmountToSwap) {
            _approve(address(dividendTracker), address(uniswapV2Router), divBal + 10000);
            dividendTracker.swapAndDistributeDividends(address(this));
        }
    }


    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _total;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    
    function switchOwner (address _newOwner) public {
        require(_msgSender() == owner(), "permission denied.");
        require(_newOwner != address(0), "new owner is zero address.");
        _owner = _newOwner;
    }
    
    function setBasePriceTimeInterval(uint256 _basePriceTimeInterval) public {
        require(_msgSender() == owner(), "permission denied.");
        basePriceTimeInterval = _basePriceTimeInterval;
    }
    
    function setHighestSellTaxRate (uint256 _highestSellTaxRate) public {
        require(_msgSender() == owner(), "permission denied.");
        highestSellTaxRate = _highestSellTaxRate;
    }
    
    function setWBNB(address _wbnb) public {
        require(_msgSender() == owner(), "permission denied.");
        require(_wbnb != address(0), "new address is zero address.");
        WBNB = _wbnb;
    }
    
    function setMinimumAmountToSwap(uint256 _minimumAmountToSwap) public {
        require(_msgSender() == owner(), "permission denied.");
        minimumAmountToSwap = _minimumAmountToSwap;
    }
    
    function setMaxSell(uint256 __maxSell) public {
        require(_msgSender() == owner(), "permission denied.");
        _maxSell = __maxSell;
    }
    
    function setIsAutoDividend(bool _isAutoDividend) public {
        require(_msgSender() == owner(), "permission denied.");
        isAutoDividend = _isAutoDividend;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFee[account] != excluded, "Account is already the value of 'excluded'");
        _isExcludedFromFee[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(newValue >= 200000 && newValue <= 500000, "gasForProcessing must be between 200,000 and 500,000");
        require(newValue != gasForProcessing, "Cannot update gasForProcessing to same value");
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function setEnableFee(bool _enableFee) public {
        require(_msgSender() == owner(), "permission denied.");
        enableFee = _enableFee;
    }

    function getExcludeFromFee(address addr) public view returns(bool) {
        return _isExcludedFromFee[addr];
    }

    function updateFixSellSlippage(uint256 _fixSellSlippage) public onlyOwner{
        fixSellSlippage = _fixSellSlippage;
    }

    function dividendTokenBalanceOf(address account) public view returns (uint256) {
		return dividendTracker.balanceOf(account);
	}

    function getExcludedFromDividends(address account) public view returns (bool){
        return dividendTracker.getExcludedFromDividends(account);
    }

    function setDividendLimit(uint256 limit) public {
        require(_msgSender() == owner(), "permission denied.");
        dividendTracker.setDividendLimit(limit);
    }

    function setDividendToken(address newToken) public {
        require(_msgSender() == owner(), "permission denied.");
        dividendTracker.setDividendTokenAddress(newToken);
    }

    function updateClaimWait(uint256 claim) public {
        require(_msgSender() == owner(), "permission denied.");
        dividendTracker.updateClaimWait(claim);
    }

    function getWithdrawableDividendOf(address account) public view returns(uint256) {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function excludeFromDividends(address addr) public {
        require(_msgSender() == owner(), "permission denied.");
        dividendTracker.excludeFromDividends(addr);
    }

    function unexcludeFromDividends(address addr) public {
        require(_msgSender() == owner(), "permission denied.");
        dividendTracker.unexcludeFromDividends(addr);
    }

    function withdrawableDividendOf(address addr) public view returns(uint256) {
        return dividendTracker.withdrawableDividendOf(addr);
    }

    function withdrawnDividendOf(address addr) public view returns(uint256) {
        return dividendTracker.withdrawnDividendOf(addr);
    }

    function setSellRateUpper(uint256 newTax) public onlyOwner{
        sellRateUpper = newTax;
    }

    function setSellRateBelow(uint256 newTax) public onlyOwner{
        sellRateBelow = newTax;
    }


    


    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    
}