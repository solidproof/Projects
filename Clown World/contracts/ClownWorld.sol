/**

    Website: ClownWorldMeme.com
    Twitter: https://twitter.com/clownworldmeme?s=21&amp;t=hrx2uHtzdW-ylt0Px2z0KQ
    Telegram: https://t.me/ClownWorldMeme 
    TikTok: https://www.tiktok.com/@clownworldmeme?_t=8anlQHaFduk&_r=1
     
**/

pragma solidity 0.8.2;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IUniswapV2Factory {
   function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router {
   function factory() external pure returns (address);
   function WETH() external pure returns (address);
   function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external payable returns (uint amountToken, uint amountETH, uint liquidity);
   function swapExactTokensForETHSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
}

contract ClownWorld is Ownable, ERC20 {
	using SafeMath for uint256;
	
    mapping (address => uint256) public _rOwned;
    mapping (address => uint256) public _tOwned;
    mapping (address => bool) public _isExcludedFromFee;
	mapping (address => bool) public _isExcludedFromMaxTokenPerWallet;
    mapping (address => bool) public _isExcludedFromReward;
	mapping (address => bool) public _automatedMarketMakerPairs;
	
    address[] private _excluded;
	
	address public constant burnWallet = address(0x000000000000000000000000000000000000dEaD);
	address public marketingWallet = payable(0x5B384bc26bC46A9D5bFC4dCFF8FC8CEf37d57E82);
	
    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 555555555555 * (10**18);
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
	
	uint256 public liquidityFeeTotal;
    uint256 public marketingFeeTotal;
	
	uint256[] public liquidityFee;
	uint256[] public marketingFee;
	uint256[] public reflectionFee;
	uint256[] public burnFee;
	
	uint256 private _liquidityFee;
	uint256 private _marketingFee;
	uint256 private _reflectionFee;
	uint256 private _burnFee;
	
    IUniswapV2Router public uniswapV2Router;
    address public uniswapV2Pair;
	
	bool private swapping;
	bool public swapAndLiquifyEnabled;
	
    uint256 public swapTokensAtAmount = 555555 * (10**18);
	uint256 public maxTokenPerWallet = 5555555555 * (10**18);
	
	event SwapTokensAmountUpdated(uint256 amount);
	event MarketingWalletUpdated(address newWallet);
	event SwapAndLiquifyStatusUpdated(bool status);
	event AutomatedMarketMakerPairUpdated(address pair, bool status);
	event MigrateTokens(address token, address receiver, uint256 amount);
	event TransferETH(address recipient, uint256 amount);
	event LiquidityFeeUpdated(uint256 buy, uint256 sell, uint256 p2p);
	event MarketingFeeUpdated(uint256 buy, uint256 sell, uint256 p2p);
	event ReflectionFeeUpdated(uint256 buy, uint256 sell, uint256 p2p);
	event BurnFeeUpdated(uint256 buy, uint256 sell, uint256 p2p);
	
    constructor (address owner) ERC20("Clown World", "$CLNWLD") {
        _rOwned[owner] = _rTotal;
        
        uniswapV2Router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

		_setAutomatedMarketMakerPair(uniswapV2Pair, true);
		
        _isExcludedFromFee[owner] = true;
        _isExcludedFromFee[address(this)] = true;
		
		_isExcludedFromMaxTokenPerWallet[address(uniswapV2Pair)] = true;
		_isExcludedFromMaxTokenPerWallet[address(this)] = true;
		_isExcludedFromMaxTokenPerWallet[owner] = true;
		
		liquidityFee.push(200);
		liquidityFee.push(200);
		liquidityFee.push(0);
		
		marketingFee.push(200);
		marketingFee.push(200);
		marketingFee.push(0);

		reflectionFee.push(200);
		reflectionFee.push(200);
		reflectionFee.push(0);
		
		burnFee.push(200);
		burnFee.push(200);
		burnFee.push(0);
		
		_excludeFromReward(address(burnWallet));
		_excludeFromReward(address(uniswapV2Pair));
		_excludeFromReward(address(this));
		
        emit Transfer(address(0), owner, _tTotal);
    }
	
	receive() external payable {}

    function totalSupply() public override pure returns (uint256) {
        return _tTotal;
    }
	
	function excludeFromFee(address account, bool status) external onlyOwner {
	    require(_isExcludedFromFee[account] != status, "Account is already the value of 'status'");
	    _isExcludedFromFee[account] = status;
	}
	
	function excludeFromMaxTokenPerWallet(address account, bool status) external onlyOwner {
	    require(_isExcludedFromMaxTokenPerWallet[account] != status, "Account is already the value of 'status'");
	    _isExcludedFromMaxTokenPerWallet[account] = status;
	}
	
	function excludeFromReward(address account) public onlyOwner() {
        require(!_isExcludedFromReward[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcludedFromReward[account] = true;
        _excluded.push(account);
    }
	
    function includeInReward(address account) external onlyOwner() {
        require(_isExcludedFromReward[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcludedFromReward[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
	
	function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
  	    require(amount <= totalSupply(), "Amount cannot be over the total supply.");
		
		swapTokensAtAmount = amount;
		emit SwapTokensAmountUpdated(amount);
  	}
	
	function setMarketingWallet(address payable _marketingWallet) external onlyOwner{
	   require(_marketingWallet != address(0), "Zero address");
	   
	   marketingWallet = _marketingWallet;
	   emit MarketingWalletUpdated(_marketingWallet);
    }
	
	function setSwapAndLiquifyEnabled(bool status) external onlyOwner {
        require(swapAndLiquifyEnabled != status, "Account is already the value of 'status'");
		
		swapAndLiquifyEnabled = status;
		emit SwapAndLiquifyStatusUpdated(status);
    }
	
	function setAutomatedMarketMakerPair(address pair, bool status) external onlyOwner {
        require(_automatedMarketMakerPairs[pair] != status, "Automated market maker pair is already set to that value");
        require(pair != address(uniswapV2Pair), "The pair cannot be removed from automatedMarketMakerPairs");
		
		_automatedMarketMakerPairs[address(pair)] = status;
		emit AutomatedMarketMakerPairUpdated(pair, status);
    }
	
	function setLiquidityFee(uint256 buy, uint256 sell, uint256 p2p) external onlyOwner {
	    require(marketingFee[0] + reflectionFee[0] + burnFee[0] + buy  <= 2500 , "Max fee limit reached for 'BUY'");
		require(marketingFee[1] + reflectionFee[1] + burnFee[1] + sell <= 2500 , "Max fee limit reached for 'SELL'");
		require(marketingFee[2] + reflectionFee[2] + burnFee[2] + p2p  <= 2500 , "Max fee limit reached for 'P2P'");
		
		liquidityFee[0] = buy;
		liquidityFee[1] = sell;
		liquidityFee[2] = p2p;
		
		emit LiquidityFeeUpdated(buy, sell, p2p);
	}
	
	function setMarketingFee(uint256 buy, uint256 sell, uint256 p2p) external onlyOwner {
	    require(liquidityFee[0] + reflectionFee[0] + burnFee[0] + buy  <= 2500 , "Max fee limit reached for 'BUY'");
		require(liquidityFee[1] + reflectionFee[1] + burnFee[1] + sell <= 2500 , "Max fee limit reached for 'SELL'");
		require(liquidityFee[2] + reflectionFee[2] + burnFee[2] + p2p  <= 2500 , "Max fee limit reached for 'P2P'");
		
		marketingFee[0] = buy;
		marketingFee[1] = sell;
		marketingFee[2] = p2p;
		
		emit MarketingFeeUpdated(buy, sell, p2p);
	}
	
	function setReflectionFee(uint256 buy, uint256 sell, uint256 p2p) external onlyOwner {
	    require(liquidityFee[0] + marketingFee[0] + burnFee[0] + buy  <= 2500 , "Max fee limit reached for 'BUY'");
		require(liquidityFee[1] + marketingFee[1] + burnFee[1] + sell <= 2500 , "Max fee limit reached for 'SELL'");
		require(liquidityFee[2] + marketingFee[2] + burnFee[2] + p2p  <= 2500 , "Max fee limit reached for 'P2P'");
		
		reflectionFee[0] = buy;
		reflectionFee[1] = sell;
		reflectionFee[2] = p2p;
		
		emit ReflectionFeeUpdated(buy, sell, p2p);
	}
	
	function setBurnFee(uint256 buy, uint256 sell, uint256 p2p) external onlyOwner {
	    require(liquidityFee[0] + marketingFee[0] + reflectionFee[0] + buy  <= 2500 , "Max fee limit reached for 'BUY'");
		require(liquidityFee[1] + marketingFee[1] + reflectionFee[1] + sell <= 2500 , "Max fee limit reached for 'SELL'");
		require(liquidityFee[2] + marketingFee[2] + reflectionFee[2] + p2p  <= 2500 , "Max fee limit reached for 'P2P'");
		
		burnFee[0] = buy;
		burnFee[1] = sell;
		burnFee[2] = p2p;
		
		emit BurnFeeUpdated(buy, sell, p2p);
	}
	
    function balanceOf(address account) public override view returns (uint256) {
        if (_isExcludedFromReward[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }
	
    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }
	
	function _excludeFromReward(address account) internal {
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcludedFromReward[account] = true;
        _excluded.push(account);
    }
	
    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(_automatedMarketMakerPairs[pair] != value, "Automated market maker pair is already set to that value");
        _automatedMarketMakerPairs[pair] = value;
    }
	
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }
	
    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, tMarketing, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity, tMarketing);
    }
	
    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256) {
		uint256 tFee = calculateReflectionFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tMarketing = calculateMarketingFee(tAmount);
		
		uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity).sub(tMarketing);
        return (tTransferAmount, tFee, tLiquidity, tMarketing);
    }
	
    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rMarketing = tMarketing.mul(currentRate);
		
		uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity).sub(rMarketing);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }
	
    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
	
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcludedFromReward[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }
	
    function _takeMarketing(uint256 tMarketing) private {
        uint256 currentRate =  _getRate();
        uint256 rMarketing = tMarketing.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rMarketing);
        if(_isExcludedFromReward[address(this)])
           _tOwned[address(this)] = _tOwned[address(this)].add(tMarketing);
    }
	
	function _takeBurn(uint256 tBurn) private {
        uint256 currentRate =  _getRate();
        uint256 rBurn = tBurn.mul(currentRate);
        _rOwned[burnWallet] = _rOwned[burnWallet].add(rBurn);
        if(_isExcludedFromReward[burnWallet])
            _tOwned[burnWallet] = _tOwned[burnWallet].add(tBurn);
    }
	
    function calculateReflectionFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_reflectionFee).div(10000);
    }
	
    function calculateMarketingFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_marketingFee).div(10000);
    }
	
    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(10000);
    }
	
	function calculateBurnFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_burnFee).div(10000);
    }
	
    function removeAllFee() private {
       _reflectionFee = 0;
       _marketingFee = 0;
       _liquidityFee = 0;
	   _burnFee = 0;
    }
	
    function applyBuyFee() private {
	   _reflectionFee = reflectionFee[0];
       _marketingFee = marketingFee[0];
       _liquidityFee = liquidityFee[0];
	   _burnFee = burnFee[0];
    }
	
	function applySellFee() private {
	   _reflectionFee = reflectionFee[1];
       _marketingFee = marketingFee[1];
       _liquidityFee = liquidityFee[1];
	   _burnFee = burnFee[1];
    }
	
	function applyP2PFee() private {
	   _reflectionFee = reflectionFee[2];
       _marketingFee = marketingFee[2];
       _liquidityFee = liquidityFee[2];
	   _burnFee = burnFee[2];
    }
	
    function _transfer(address from, address to, uint256 amount) internal override{
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
		
		if(!_isExcludedFromMaxTokenPerWallet[to])
		{
            uint256 balanceRecepient = balanceOf(to);
            require(balanceRecepient + amount <= maxTokenPerWallet, "Exceeds maximum token per wallet limit");
        }
		
        uint256 contractTokenBalance = balanceOf(address(this));
		bool canSwap = contractTokenBalance >= swapTokensAtAmount;
		
        if (canSwap && !swapping && _automatedMarketMakerPairs[to] && swapAndLiquifyEnabled) 
		{
		    uint256 tokenToLiqudity = liquidityFeeTotal.div(2);
			uint256 tokenToMarketing = marketingFeeTotal;
			uint256 tokenToSwap = tokenToLiqudity.add(tokenToMarketing);
			
			if(tokenToSwap >= swapTokensAtAmount) 
			{
			    swapping = true;
				
				uint256 initialBalance = address(this).balance;
				swapTokensForETH(swapTokensAtAmount);
				uint256 newBalance = address(this).balance.sub(initialBalance);
				
				uint256 liqudityPart = newBalance.mul(tokenToLiqudity).div(tokenToSwap);
				uint256 marketingPart = newBalance - liqudityPart;
				
				if(liqudityPart > 0)
				{
				    uint256 liqudityToken = swapTokensAtAmount.mul(tokenToLiqudity).div(tokenToSwap);
					addLiquidity(liqudityToken, liqudityPart);
					liquidityFeeTotal = liquidityFeeTotal.sub(liqudityToken).sub(liqudityToken);
				}
				if(marketingPart > 0) 
				{
				    payable(marketingWallet).transfer(marketingPart);
					marketingFeeTotal = marketingFeeTotal.sub(swapTokensAtAmount.mul(tokenToMarketing).div(tokenToSwap));
				}
				swapping = false;
			}
        }
		
        bool takeFee = true;
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to])
		{
            takeFee = false;
        }
        _tokenTransfer(from, to, amount, takeFee);
    }
	
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
		
		if(!takeFee) 
		{
		    removeAllFee();
		}
		else if(!_automatedMarketMakerPairs[sender] && !_automatedMarketMakerPairs[recipient])
		{
		    applyP2PFee();
		}
		else if(_automatedMarketMakerPairs[recipient])
		{
		    applySellFee();
		}
		else
		{
		    applyBuyFee();
		}
		
		uint256 tBurn = calculateBurnFee(amount);
		if(tBurn > 0)
		{
		   _takeBurn(tBurn);
		   emit Transfer(sender, address(burnWallet), tBurn);
		}
		
        if (_isExcludedFromReward[sender] && !_isExcludedFromReward[recipient]) 
		{
            _transferFromExcluded(sender, recipient, amount, tBurn);
        } 
		else if (!_isExcludedFromReward[sender] && _isExcludedFromReward[recipient]) 
		{
            _transferToExcluded(sender, recipient, amount, tBurn);
        } 
		else if (!_isExcludedFromReward[sender] && !_isExcludedFromReward[recipient]) 
		{
            _transferStandard(sender, recipient, amount, tBurn);
        } 
		else if (_isExcludedFromReward[sender] && _isExcludedFromReward[recipient]) 
		{
            _transferBothExcluded(sender, recipient, amount, tBurn);
        } 
		else 
		{
            _transferStandard(sender, recipient, amount, tBurn);
        }
    }
	
    function _transferStandard(address sender, address recipient, uint256 tAmount, uint256 tBurn) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        
		tTransferAmount = tTransferAmount.sub(tBurn);
		rTransferAmount = rTransferAmount.sub(tBurn.mul(_getRate()));
		
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeMarketing(tMarketing);
        _reflectFee(rFee, tFee);
		
		liquidityFeeTotal += tLiquidity;
        marketingFeeTotal += tMarketing;
		
		if(tMarketing.add(tLiquidity) > 0)
		{
		    emit Transfer(sender, address(this), tMarketing.add(tLiquidity));
		}
        emit Transfer(sender, recipient, tTransferAmount);
    }
	
    function _transferToExcluded(address sender, address recipient, uint256 tAmount, uint256 tBurn) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        
		tTransferAmount = tTransferAmount.sub(tBurn);
		rTransferAmount = rTransferAmount.sub(tBurn.mul(_getRate()));
		
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);           
        _takeLiquidity(tLiquidity);
        _takeMarketing(tMarketing);
        _reflectFee(rFee, tFee);
		
		liquidityFeeTotal += tLiquidity;
        marketingFeeTotal += tMarketing;
		
		if(tMarketing.add(tLiquidity) > 0)
		{
		    emit Transfer(sender, address(this), tMarketing.add(tLiquidity));
		}
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount, uint256 tBurn) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        
		tTransferAmount = tTransferAmount.sub(tBurn);
		rTransferAmount = rTransferAmount.sub(tBurn.mul(_getRate()));
		
		_tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
        _takeLiquidity(tLiquidity);
        _takeMarketing(tMarketing);
        _reflectFee(rFee, tFee);
		
		liquidityFeeTotal += tLiquidity;
        marketingFeeTotal += tMarketing;
		
		if(tMarketing.add(tLiquidity) > 0)
		{
		    emit Transfer(sender, address(this), tMarketing.add(tLiquidity));
		}
        emit Transfer(sender, recipient, tTransferAmount);
    }
	
	function _transferBothExcluded(address sender, address recipient, uint256 tAmount, uint256 tBurn) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        
		tTransferAmount = tTransferAmount.sub(tBurn);
		rTransferAmount = rTransferAmount.sub(tBurn.mul(_getRate()));
		
		_tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);        
        _takeLiquidity(tLiquidity);
        _takeMarketing(tMarketing);
        _reflectFee(rFee, tFee);
		
		liquidityFeeTotal += tLiquidity;
        marketingFeeTotal += tMarketing;
		
		if(tMarketing.add(tLiquidity) > 0)
		{
		    emit Transfer(sender, address(this), tMarketing.add(tLiquidity));
		}
        emit Transfer(sender, recipient, tTransferAmount);
    }
	
	function swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
		
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
	
	function addLiquidity(uint256 tokenAmount, uint256 ETHAmount) private{
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: ETHAmount}(
            address(this),
            tokenAmount,
            0, 
            0,
            address(this),
            block.timestamp
        );
    }
	
	function migrateTokens(address token, address receiver, uint256 amount) external onlyOwner{
       require(token != address(0), "Zero address");
	   require(receiver != address(0), "Zero address");
	   if(address(token) == address(this))
	   {
	       require(IERC20(address(this)).balanceOf(address(this)).sub(liquidityFeeTotal).sub(marketingFeeTotal) >= amount, "Insufficient balance on contract");
	   }
	   else
	   {
	       require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient balance on contract");
	   }
	   IERC20(token).transfer(address(receiver), amount);
       emit MigrateTokens(token, receiver, amount);
    }
	
	function migrateETH(address payable recipient) external onlyOwner{
	   require(recipient != address(0), "Zero address");
	   
	   emit TransferETH(recipient, address(this).balance);
       recipient.transfer(address(this).balance);
    }
}