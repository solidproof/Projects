pragma solidity 0.8.2;

// SPDX-License-Identifier: Unlicensed

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IUniswapV2Factory {
   function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router {
   function factory() external pure returns (address);
   function WETH() external pure returns (address);
   function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity);
   function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
   function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
}

interface IStaking {
   function updatePool(uint256 amount) external;
}

interface ILiquidityProvider {
   function provideLiquidity(uint256 USDCAmount, uint256 TGCAmount) external;
   function transferUSDT(address marketing, uint256 amount) external;
}

contract LiquidityProvider is ILiquidityProvider {
	using SafeMath for uint256;
	
	address public immutable TGCToken;
	address public constant USDC = address(0x07865c6E87B9F70255377e024ace6630C1Eaa37F);
	IUniswapV2Router public uniswapV2Router;
	
    modifier onlyToken() {
       require(msg.sender == TGCToken, "!TGCToken"); _;
    }
	
    constructor () {
       TGCToken = msg.sender;
	   uniswapV2Router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    }
	
	function provideLiquidity(uint256 USDCAmount, uint256 TGCAmount) external override onlyToken {
		IERC20(USDC).approve(address(uniswapV2Router), USDCAmount);
		IERC20(TGCToken).approve(address(uniswapV2Router), TGCAmount);
		
		uniswapV2Router.addLiquidity(
			address(USDC),
			address(TGCToken),
			USDCAmount,
			TGCAmount,
			0,
			0,
			address(this),
			block.timestamp
	   );	
	}
	
	function transferUSDT(address marketing, uint256 amount) external override onlyToken {
	   IERC20(USDC).transfer(address(marketing), amount);
	}
}

contract TGC is Ownable, ERC20 {
	using SafeMath for uint256;
	
    mapping (address => uint256) public _rOwned;
    mapping (address => uint256) public _tOwned;
	mapping (address => uint256) public totalSend;
    mapping (address => uint256) public totalReceived;
	mapping (address => uint256) public lockedAmount;
    mapping (address => bool) public _isExcludedFromFee;
	mapping (address => bool) public _isExcludedFromMaxBuyPerWallet;
    mapping (address => bool) public _isExcludedFromReward;
	mapping (address => bool) public _automatedMarketMakerPairs;
	mapping (address => bool) public _isHolder;
	
    address[] private _excluded;
	
	address public constant burnWallet = address(0x000000000000000000000000000000000000dEaD);
	address public constant USDC = address(0x07865c6E87B9F70255377e024ace6630C1Eaa37F);
	address public constant marketingWallet = address(0x38de9e7f51A14DACc46F1E68C620C6f00E4966F4);
	
	IStaking public stakingContract;
	address public LPProviderAddress;
	
    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 1000000000 * (10**18);
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
	
	uint256 public liquidityFeeTotal;
    uint256 public marketingFeeTotal;
	uint256 public holders;
	
	uint256[] public liquidityFee;
	uint256[] public marketingFee;
	uint256[] public reflectionFee;
	uint256[] public stakingFee;
	uint256[] public burnFee;
	
	uint256 private _liquidityFee;
	uint256 private _marketingFee;
	uint256 private _reflectionFee;
	uint256 private _stakingFee;
	uint256 private _burnFee;
	
    IUniswapV2Router public uniswapV2Router;
    address public uniswapV2Pair;
	LiquidityProvider public LPProvider;
	
	bool private swapping;
	
    uint256 public swapTokensAtAmount = 1250000  * (10**18);
	uint256 public maxBuyPerWallet = 20000000 * (10**18);
	
	event LockToken(uint256 amount, address user);
	event UnLockToken(uint256 amount, address user);
	event SwapTokensAmountUpdated(uint256 amount);
	
    constructor (address owner) ERC20("The Grays Currency", "TGC") {
        _rOwned[owner] = _rTotal;
        
        uniswapV2Router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), address(USDC));
		
		LPProvider = new LiquidityProvider();
		LPProviderAddress = address(LPProvider);
		
		_setAutomatedMarketMakerPair(uniswapV2Pair, true);
		
        _isExcludedFromFee[owner] = true;
        _isExcludedFromFee[address(this)] = true;
		_isExcludedFromFee[address(LPProviderAddress)] = true;
		
		_isExcludedFromMaxBuyPerWallet[address(uniswapV2Pair)] = true;
		_isExcludedFromMaxBuyPerWallet[address(this)] = true;
		_isExcludedFromMaxBuyPerWallet[owner] = true;
		_isExcludedFromMaxBuyPerWallet[address(LPProviderAddress)] = true;
		
		liquidityFee.push(50);
		liquidityFee.push(0);
		liquidityFee.push(0);
		liquidityFee.push(50);
		liquidityFee.push(0);
		
		marketingFee.push(250);
		marketingFee.push(150);
		marketingFee.push(100);
		marketingFee.push(200);
		marketingFee.push(0);
		
		reflectionFee.push(200);
		reflectionFee.push(100);
		reflectionFee.push(100);
		reflectionFee.push(500);
		reflectionFee.push(0);
		
		stakingFee.push(200);
		stakingFee.push(200);
		stakingFee.push(200);
		stakingFee.push(300);
		stakingFee.push(0);
		
		burnFee.push(300);
		burnFee.push(200);
		burnFee.push(100);
		burnFee.push(250);
		burnFee.push(0);
		
		_excludeFromReward(address(burnWallet));
		_excludeFromReward(address(uniswapV2Pair));
		_excludeFromReward(address(this));
		_excludeFromReward(address(LPProviderAddress));
		
		_isHolder[owner] = true;
		holders += 1;
		
		totalReceived[owner] +=_tTotal;
        emit Transfer(address(0), owner, _tTotal);
    }
	
	receive() external payable {}

    function totalSupply() public override pure returns (uint256) {
        return _tTotal;
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
	
	function setStakingContract(IStaking contractAddress) external onlyOwner{
	   require(address(contractAddress) != address(0), "Zero address");
	   require(address(stakingContract) == address(0), "Staking contract already set");
	   
	   stakingContract = IStaking(contractAddress);
	   
	   _excludeFromReward(address(stakingContract));
	   _isExcludedFromFee[address(stakingContract)] = true;
    }
	
	function lockToken(uint256 amount, address user) external {
	   require(msg.sender == address(stakingContract), "sender not allowed");
	   
	   uint256 unlockBalance = balanceOf(user) - lockedAmount[user];
	   require(unlockBalance >= amount, "locking amount exceeds balance");
	   lockedAmount[user] += amount;
	   emit LockToken(amount, user);
    }
	
	function unlockToken(uint256 amount, address user) external {
	   require(msg.sender == address(stakingContract), "sender not allowed");
	   require(lockedAmount[user] >= amount, "amount is not correct");
	   
	   lockedAmount[user] -= amount;
	   emit UnLockToken(amount, user);
    }
	
	function unlockSend(uint256 amount, address user) external {
	   require(msg.sender == address(stakingContract), "sender not allowed");
	   require(lockedAmount[user] >= amount, "amount is not correct");
	   
	   lockedAmount[user] -= amount;
	   IERC20(address(this)).transferFrom(address(user), address(stakingContract), amount);
	   emit UnLockToken(amount, user);
    }
	
	function airdropToken(uint256 amount) external {
       require(amount > 0, "Transfer amount must be greater than zero");
	   require(balanceOf(msg.sender) - lockedAmount[msg.sender] >= amount, "transfer amount exceeds balance");
	   
	   _tokenTransfer(msg.sender, address(this), amount, true, true);
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
	
	function _takeStaking(uint256 tStaking) private {
        uint256 currentRate =  _getRate();
        uint256 rStaking = tStaking.mul(currentRate);
        _rOwned[address(stakingContract)] = _rOwned[address(stakingContract)].add(rStaking);
        if(_isExcludedFromReward[address(stakingContract)])
            _tOwned[address(stakingContract)] = _tOwned[address(stakingContract)].add(tStaking);
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
	
	function calculateStakingFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_stakingFee).div(10000);
    }
	
    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(10000);
    }
	
	function calculateBurnFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_burnFee).div(10000);
    }
	
    function removeAllFee() private {
       _reflectionFee = 0;
	   _stakingFee = 0;
       _marketingFee = 0;
       _liquidityFee = 0;
	   _burnFee = 0;
    }
	
    function applyBuyFeeTierOne() private {
	   _reflectionFee = reflectionFee[0];
	   _stakingFee = stakingFee[0];
       _marketingFee = marketingFee[0];
       _liquidityFee = liquidityFee[0];
	   _burnFee = burnFee[0];
    }
	
	function applyBuyFeeTierTwo() private {
	   _reflectionFee = reflectionFee[1];
	   _stakingFee = stakingFee[1];
       _marketingFee = marketingFee[1];
       _liquidityFee = liquidityFee[1];
	   _burnFee = burnFee[1];
    }
	
	function applyBuyFeeTierThree() private {
	   _reflectionFee = reflectionFee[2];
	   _stakingFee = stakingFee[2];
       _marketingFee = marketingFee[2];
       _liquidityFee = liquidityFee[2];
	   _burnFee = burnFee[2];
    }
	
	function applySellFee() private {
	   _reflectionFee = reflectionFee[3];
	   _stakingFee = stakingFee[3];
       _marketingFee = marketingFee[3];
       _liquidityFee = liquidityFee[3];
	   _burnFee = burnFee[3];
    }
	
	function applyP2PFee() private {
	   _reflectionFee = reflectionFee[4];
	   _stakingFee = stakingFee[4];
       _marketingFee = marketingFee[4];
       _liquidityFee = liquidityFee[4];
	   _burnFee = burnFee[4];
    }
	
	function applyAirdropFee() private {
	   _reflectionFee = 10000;
	   _stakingFee = 0;
       _marketingFee = 0;
       _liquidityFee = 0;
	   _burnFee = 0;
    }
	
    function _transfer(address from, address to, uint256 amount) internal override{
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
		require(balanceOf(from) - lockedAmount[from] >= amount, "transfer amount exceeds balance");
		
		if(!_isHolder[address(to)]) {
		   _isHolder[to] = true;
		   holders += 1;
		}
		
		if((balanceOf(from) - amount) == 0) {
		   _isHolder[from] = false;
		   holders -= 1;
		}
		
		if(!_isExcludedFromMaxBuyPerWallet[to] && _automatedMarketMakerPairs[from])
		{
            uint256 balanceRecepient = balanceOf(to);
            require(balanceRecepient + amount <= maxBuyPerWallet, "Exceeds maximum buy per wallet limit");
        }
		
        uint256 contractTokenBalance = balanceOf(address(this));
		bool canSwap = contractTokenBalance >= swapTokensAtAmount;
		
        if (canSwap && !swapping && _automatedMarketMakerPairs[to]) 
		{
		    uint256 tokenToLiqudity = liquidityFeeTotal.div(2);
			uint256 tokenToMarketing = marketingFeeTotal;
			uint256 tokenToSwap = tokenToLiqudity.add(tokenToMarketing);
			
			if(tokenToSwap >= swapTokensAtAmount) 
			{
			    swapping = true;
				
				address[] memory path = new address[](2);
				path[0] = address(this);
				path[1] = address(USDC);
				
				uint256 USDCInitial = IERC20(USDC).balanceOf(address(LPProviderAddress));
				_approve(address(this), address(uniswapV2Router), swapTokensAtAmount);
				uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
					swapTokensAtAmount,
					0,
					path,
					address(LPProviderAddress),
					block.timestamp.add(300)
				);
				
				uint256 USDCFinal = IERC20(USDC).balanceOf(address(LPProviderAddress)) - USDCInitial;
				uint256 liqudityPart = USDCFinal.mul(tokenToLiqudity).div(tokenToSwap);
				uint256 marketingPart = USDCFinal - liqudityPart;
				
				if(liqudityPart > 0)
				{
				    uint256 liqudityToken = swapTokensAtAmount.mul(tokenToLiqudity).div(tokenToSwap);
				    IERC20(address(this)).transfer(address(LPProviderAddress), liqudityToken);
					LPProvider.provideLiquidity(liqudityPart, liqudityToken);
					liquidityFeeTotal = liquidityFeeTotal.sub(liqudityToken).sub(liqudityToken);
				}
				if(marketingPart > 0) 
				{
				    LPProvider.transferUSDT(address(marketingWallet), marketingPart);
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
		else
		{
		    if(!_isHolder[address(this)]) {
			   _isHolder[address(this)] = true;
			   holders += 1;
			}
			
			if(!_isHolder[address(stakingContract)]) {
			   _isHolder[address(stakingContract)] = true;
			   holders += 1;
			}
			
			if(!_isHolder[address(burnWallet)]) {
			   _isHolder[address(burnWallet)] = true;
			   holders += 1;
			}
		}
		
        _tokenTransfer(from,to,amount,takeFee,false);
    }
	
    function getQuotes(uint256 amountIn) public view returns (uint256){
	   address[] memory path = new address[](2);
       path[0] = address(this);
	   path[1] = address(USDC);
	   
	   uint256[] memory USDCRequired = uniswapV2Router.getAmountsOut(amountIn, path);
	   return USDCRequired[1];
    }
	
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee, bool airdrop) private {
		totalSend[sender] += amount;
		
		if(!takeFee) 
		{
		    removeAllFee();
		}
		else if(airdrop)
		{
		    applyAirdropFee();
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
		    uint256 USDCRequired = getQuotes(amount);
			if(USDCRequired >= 20000 * 10**6)
			{
			    applyBuyFeeTierThree();
			}
			else if(USDCRequired >= 10000 * 10**6)
			{
			    applyBuyFeeTierTwo();
			}
			else
			{
			    applyBuyFeeTierOne();
			}
		}
		
		uint256 _totalFee = _reflectionFee + _stakingFee + _marketingFee + _liquidityFee + _burnFee;
		if(_totalFee > 0)
		{
		    uint256 _feeAmount = amount.mul(_totalFee).div(10000);
		    totalReceived[recipient] += amount.sub(_feeAmount);
		}
		else
		{
		    totalReceived[recipient] += amount;
		}
		
		uint256 tBurn = calculateBurnFee(amount);
		if(tBurn > 0)
		{
		   _takeBurn(tBurn);
		   emit Transfer(sender, address(burnWallet), tBurn);
		}
		
		uint256 tStaking = calculateStakingFee(amount);
		if(tStaking > 0) 
		{
		    _takeStaking(tStaking);
		    stakingContract.updatePool(tStaking);
		    emit Transfer(sender, address(stakingContract), tStaking);
		}
		
        if (_isExcludedFromReward[sender] && !_isExcludedFromReward[recipient]) 
		{
            _transferFromExcluded(sender, recipient, amount, tStaking, tBurn);
        } 
		else if (!_isExcludedFromReward[sender] && _isExcludedFromReward[recipient]) 
		{
            _transferToExcluded(sender, recipient, amount, tStaking, tBurn);
        } 
		else if (!_isExcludedFromReward[sender] && !_isExcludedFromReward[recipient]) 
		{
            _transferStandard(sender, recipient, amount, tStaking, tBurn);
        } 
		else if (_isExcludedFromReward[sender] && _isExcludedFromReward[recipient]) 
		{
            _transferBothExcluded(sender, recipient, amount, tStaking, tBurn);
        } 
		else 
		{
            _transferStandard(sender, recipient, amount, tStaking, tBurn);
        }
    }
	
    function _transferStandard(address sender, address recipient, uint256 tAmount, uint256 tStaking, uint256 tBurn) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        
		tTransferAmount = tTransferAmount.sub(tStaking).sub(tBurn);
		rTransferAmount = rTransferAmount.sub(tStaking.mul(_getRate())).sub(tBurn.mul(_getRate()));
		
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
	
    function _transferToExcluded(address sender, address recipient, uint256 tAmount, uint256 tStaking, uint256 tBurn) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        
		tTransferAmount = tTransferAmount.sub(tStaking).sub(tBurn);
		rTransferAmount = rTransferAmount.sub(tStaking.mul(_getRate())).sub(tBurn.mul(_getRate()));
		
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

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount, uint256 tStaking, uint256 tBurn) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        
		tTransferAmount = tTransferAmount.sub(tStaking).sub(tBurn);
		rTransferAmount = rTransferAmount.sub(tStaking.mul(_getRate())).sub(tBurn.mul(_getRate()));
		
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
	
	function _transferBothExcluded(address sender, address recipient, uint256 tAmount, uint256 tStaking, uint256 tBurn) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        
		tTransferAmount = tTransferAmount.sub(tStaking).sub(tBurn);
		rTransferAmount = rTransferAmount.sub(tStaking.mul(_getRate())).sub(tBurn.mul(_getRate()));
		
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
	
	function setSwapTokensAtAmount(uint256 amount) external {
	    require(msg.sender == address(marketingWallet), "Incorrect request");
  	    require(amount <= totalSupply(), "Amount cannot be over the total supply.");
		swapTokensAtAmount = amount;
		
		emit SwapTokensAmountUpdated(amount);
  	}
}
