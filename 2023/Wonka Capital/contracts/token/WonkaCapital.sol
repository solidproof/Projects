// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface WonkaNFT {
	function balanceOf(address account) external view returns(uint256);
}

interface IFactoryV2 {
    event PairCreated(address indexed token0, address indexed token1, address lpPair, uint);
    function getPair(address tokenA, address tokenB) external view returns (address lpPair);
    function createPair(address tokenA, address tokenB) external returns (address lpPair);
}

interface IV2Pair {
    function factory() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IRouter01 {
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
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IRouter02 is IRouter01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract WonkaCapital is Context, ERC20, Ownable {
	
	using SafeMath for uint256;
    using Address for address;

	IRouter02 public dexRouter;
	address public lpPair;
	WonkaNFT public wonkabronze;
    WonkaNFT public wonkasilver;
    WonkaNFT public wonkagold;
    address public wonkastake;
    bool public ntfAddressUpdated = false;
	
    uint256 private constant _totalTokens = 10**12 * 10**9;
	
    uint256 private constant _MAXFEE = 2000;
	
    string private _name = 'Wonka Capital';
    string private _symbol = 'WonkaCap';
	
    uint8 private constant _decimals = 9;
    uint256 private constant _VESTING_PERIOD = 1 days;
	
	uint168 private constant masterTaxDivisor = 10000;
	
	mapping(address => uint256) public startTime;
	
	struct TxLimits {
        uint256 everyone;
        uint256 bronzeHolder;
        uint256 silverHolder;
        uint256 goldHolder;
    }
	
	TxLimits public _txLimits = TxLimits({
        everyone: (_totalTokens* 25)/masterTaxDivisor,
        bronzeHolder: (_totalTokens* 30)/masterTaxDivisor,
        silverHolder: (_totalTokens* 35)/masterTaxDivisor,
        goldHolder: (_totalTokens* 40)/masterTaxDivisor
	});
	
	struct Fees {
        uint16 buyFee;
        uint16 sellFee;
        uint16 transferFee;
        uint16 vestingFee1;
        uint16 vestingFee2;
        uint16 vestingFee3;
        uint16 vestingFee4;
    }
	
	Fees public _taxRates = Fees({
        buyFee: 500,
        sellFee: 600,
        transferFee: 700,
        vestingFee1: 1200,
        vestingFee2: 1000,
        vestingFee3: 800,
        vestingFee4: 500
	});
	
	struct TaxWallets {
        address payable buytax;
        address payable selltax;
        address payable transfertax;
        address payable vestingtax;
    }

    TaxWallets public _taxWallets = TaxWallets({ 
        buytax: payable(0xa12F9b5957bbca3ed89d1Bd7480ef78a3815DaB0),
        selltax: payable(0xFd15C46eCD506c77453619662fc281c3948c3c64),
        transfertax: payable(0x73470bF87c6B30f8B33d3a4fb8241F1aD629dA11),
        vestingtax: payable(0xbb3B19A9537c954118995bd57c91C05cb7D3cbbf)
	});
	
	mapping(address => bool) public _isFreezed;
	
    mapping(address => bool) public _isExcludedFromTrxLimit;
    mapping(string => mapping(address => bool)) public _isExcludedFromFee;
	
    constructor (address _routerAddress) ERC20 (_name, _symbol) {
		
		dexRouter = IRouter02(_routerAddress);
		
		lpPair = IFactoryV2(dexRouter.factory()).createPair(address(this), dexRouter.WETH());
		_mint(_msgSender(), _totalTokens);
		approve(_routerAddress, _totalTokens);
		
		// Exclude from maxt Transaction Limit
        _isExcludedFromTrxLimit[owner()] = true;
        _isExcludedFromTrxLimit[address(this)] = true;
		_isExcludedFromTrxLimit[_taxWallets.buytax] = true;
		_isExcludedFromTrxLimit[_taxWallets.selltax] = true;
		_isExcludedFromTrxLimit[_taxWallets.transfertax] = true;
		_isExcludedFromTrxLimit[_taxWallets.vestingtax] = true;
		
		// exclude owner and this contract from fee
        _isExcludedFromFee['buy'][owner()] = true;
        _isExcludedFromFee['buy'][address(this)] = true;
		
		_isExcludedFromFee['sell'][owner()] = true;
        _isExcludedFromFee['sell'][address(this)] = true;
		
		_isExcludedFromFee['transfer'][owner()] = true;
        _isExcludedFromFee['transfer'][address(this)] = true;
		
		_isExcludedFromFee['vesting'][owner()] = true;
        _isExcludedFromFee['vesting'][address(this)] = true;
		
        _isExcludedFromFee['buy'][_taxWallets.buytax] = true;
        _isExcludedFromFee['buy'][_taxWallets.selltax] = true;
        _isExcludedFromFee['buy'][_taxWallets.transfertax] = true;
        _isExcludedFromFee['buy'][_taxWallets.vestingtax] = true;
		
		_isExcludedFromFee['sell'][_taxWallets.buytax] = true;
		_isExcludedFromFee['sell'][_taxWallets.selltax] = true;
		_isExcludedFromFee['sell'][_taxWallets.transfertax] = true;
		_isExcludedFromFee['sell'][_taxWallets.vestingtax] = true;
		
		_isExcludedFromFee['transfer'][_taxWallets.buytax] = true;
		_isExcludedFromFee['transfer'][_taxWallets.selltax] = true;
		_isExcludedFromFee['transfer'][_taxWallets.transfertax] = true;
		_isExcludedFromFee['transfer'][_taxWallets.vestingtax] = true;
		
		_isExcludedFromFee['vesting'][_taxWallets.buytax] = true;
		_isExcludedFromFee['vesting'][_taxWallets.selltax] = true;
		_isExcludedFromFee['vesting'][_taxWallets.transfertax] = true;
		_isExcludedFromFee['vesting'][_taxWallets.vestingtax] = true;
    }
	
	function name() public view override(ERC20) returns (string memory) {
        return _name;
    }

    function symbol() public view override(ERC20) returns (string memory) {
        return _symbol;
    }

	function decimals() public view virtual override(ERC20) returns (uint8) {
        return _decimals;
    }
	
	// /********************* Management **************************/
	function setName(string memory name_) external onlyOwner() {
        _name	=	name_;
    }
	
	function setSymbol(string memory symbol_) external onlyOwner() {
        _symbol	=	symbol_;
    }
	
	
    function setNftStakeAddress(address _wonkabronze, address _wonkasilver, address _wonkagold, address _stake, address _exchange) external onlyOwner() {
       
		wonkabronze 	= WonkaNFT(_wonkabronze);
		wonkasilver 	= WonkaNFT(_wonkasilver);
		wonkagold 		= WonkaNFT(_wonkagold);
		wonkastake 		= _stake;
		ntfAddressUpdated = true;
		
		_isExcludedFromFee['buy'][_wonkabronze] 	= true;
        _isExcludedFromFee['buy'][_wonkasilver] 	= true;
        _isExcludedFromFee['buy'][_wonkagold] 		= true;
        _isExcludedFromFee['buy'][_stake] 			= true;
        _isExcludedFromFee['buy'][_exchange] 			= true;
		
		_isExcludedFromFee['sell'][_wonkabronze] 	= true;
        _isExcludedFromFee['sell'][_wonkasilver] 	= true;
        _isExcludedFromFee['sell'][_wonkagold] 		= true;
        _isExcludedFromFee['sell'][_stake] 			= true;
        _isExcludedFromFee['sell'][_exchange] 			= true;
		
		_isExcludedFromFee['transfer'][_wonkabronze]= true;
        _isExcludedFromFee['transfer'][_wonkasilver]= true;
        _isExcludedFromFee['transfer'][_wonkagold]	= true;
        _isExcludedFromFee['transfer'][_stake]		= true;
        _isExcludedFromFee['transfer'][_exchange]		= true;
		
		_isExcludedFromFee['vesting'][_wonkabronze] = true;
        _isExcludedFromFee['vesting'][_wonkasilver] = true;
        _isExcludedFromFee['vesting'][_wonkagold] 	= true;
        _isExcludedFromFee['vesting'][_stake] 		= true;
        _isExcludedFromFee['vesting'][_exchange] 		= true;
		
		_isExcludedFromTrxLimit[_wonkabronze] 		= true;
        _isExcludedFromTrxLimit[_wonkasilver] 		= true;
        _isExcludedFromTrxLimit[_wonkagold] 		= true;
        _isExcludedFromTrxLimit[_stake] 			= true;	
        _isExcludedFromTrxLimit[_exchange] 			= true;	
		
		_isExcludedFromTrxLimit[_wonkabronze] 		= true;
        _isExcludedFromTrxLimit[_wonkasilver] 		= true;
        _isExcludedFromTrxLimit[_wonkagold] 		= true;
        _isExcludedFromTrxLimit[_stake] 			= true;	
        _isExcludedFromTrxLimit[_exchange] 			= true;	
    }
	
	
	function excludeIncludeBuyTax(address[] memory accounts, bool[] memory includeExcludes) external onlyOwner() {
        for (uint256 i = 0; i < accounts.length; i++) {
			_isExcludedFromFee['buy'][accounts[i]] = includeExcludes[i];
		}
    }
	
	function excludeIncludeSellTax(address[] memory accounts, bool[] memory includeExcludes) external onlyOwner() {
        for (uint256 i = 0; i < accounts.length; i++) {
			_isExcludedFromFee['sell'][accounts[i]] = includeExcludes[i];
		}
    }
	
	function excludeIncludeTransferTax(address[] memory accounts, bool[] memory includeExcludes) external onlyOwner() {
        for (uint256 i = 0; i < accounts.length; i++) {
			_isExcludedFromFee['transfer'][accounts[i]] = includeExcludes[i];
		}
    }
	
	function excludeIncludeVestingTax(address[] memory accounts, bool[] memory includeExcludes) external onlyOwner() {
        for (uint256 i = 0; i < accounts.length; i++) {
			_isExcludedFromFee['vesting'][accounts[i]] = includeExcludes[i];
		}
    }
	
	function excludeIncludeTrxLimit(address[] memory accounts, bool[] memory includeExcludes) external onlyOwner() {
        for (uint256 i = 0; i < accounts.length; i++) {
			_isExcludedFromTrxLimit[accounts[i]] = includeExcludes[i];
		}
    }
	
	function setIsFreezed(address[] memory accounts, bool[] memory isfeezed) external onlyOwner() {
        for (uint256 i = 0; i < accounts.length; i++) {
			_isFreezed[accounts[i]] = isfeezed[i];
		}
    }
	
    function setWallets(address payable _buytax, address payable _selltax, address payable _transfertax, address payable _vestingtax) external onlyOwner {
        
		
        _isExcludedFromFee['buy'][_taxWallets.buytax] = false;
        _isExcludedFromFee['buy'][_taxWallets.selltax] = false;
        _isExcludedFromFee['buy'][_taxWallets.transfertax] = false;
        _isExcludedFromFee['buy'][_taxWallets.vestingtax] = false;
		
		_isExcludedFromFee['sell'][_taxWallets.buytax] = false;
		_isExcludedFromFee['sell'][_taxWallets.selltax] = false;
		_isExcludedFromFee['sell'][_taxWallets.transfertax] = false;
		_isExcludedFromFee['sell'][_taxWallets.vestingtax] = false;
		
		_isExcludedFromFee['transfer'][_taxWallets.buytax] = false;
		_isExcludedFromFee['transfer'][_taxWallets.selltax] = false;
		_isExcludedFromFee['transfer'][_taxWallets.transfertax] = false;
		_isExcludedFromFee['transfer'][_taxWallets.vestingtax] = false;
		
		_isExcludedFromFee['vesting'][_taxWallets.buytax] = false;
		_isExcludedFromFee['vesting'][_taxWallets.selltax] = false;
		_isExcludedFromFee['vesting'][_taxWallets.transfertax] = false;
		_isExcludedFromFee['vesting'][_taxWallets.vestingtax] = false;
		
		_taxWallets.buytax = _buytax;
        _taxWallets.selltax = _selltax;
        _taxWallets.transfertax = _transfertax;
        _taxWallets.vestingtax = _vestingtax;
		
        
        _isExcludedFromFee['buy'][_taxWallets.buytax] = true;
        _isExcludedFromFee['buy'][_taxWallets.selltax] = true;
        _isExcludedFromFee['buy'][_taxWallets.transfertax] = true;
        _isExcludedFromFee['buy'][_taxWallets.vestingtax] = true;
		
		_isExcludedFromFee['sell'][_taxWallets.buytax] = true;
		_isExcludedFromFee['sell'][_taxWallets.selltax] = true;
		_isExcludedFromFee['sell'][_taxWallets.transfertax] = true;
		_isExcludedFromFee['sell'][_taxWallets.vestingtax] = true;
		
		_isExcludedFromFee['transfer'][_taxWallets.buytax] = true;
		_isExcludedFromFee['transfer'][_taxWallets.selltax] = true;
		_isExcludedFromFee['transfer'][_taxWallets.transfertax] = true;
		_isExcludedFromFee['transfer'][_taxWallets.vestingtax] = true;
		
		_isExcludedFromFee['vesting'][_taxWallets.buytax] = true;
		_isExcludedFromFee['vesting'][_taxWallets.selltax] = true;
		_isExcludedFromFee['vesting'][_taxWallets.transfertax] = true;
		_isExcludedFromFee['vesting'][_taxWallets.vestingtax] = true;

		_isExcludedFromTrxLimit[_taxWallets.buytax] = true;
		_isExcludedFromTrxLimit[_taxWallets.selltax] = true;
		_isExcludedFromTrxLimit[_taxWallets.transfertax] = true;
		_isExcludedFromTrxLimit[_taxWallets.vestingtax] = true;

    }

	
	function setTaxes(uint16 buyFee, uint16 sellFee, uint16 transferFee, uint16 vestingFee1, uint16 vestingFee2, uint16 vestingFee3, uint16 vestingFee4) external onlyOwner {
        
		require(buyFee <=_MAXFEE && sellFee <=_MAXFEE &&  transferFee <=_MAXFEE &&  vestingFee1 <=_MAXFEE &&  vestingFee2 <=_MAXFEE && vestingFee3 <=_MAXFEE && vestingFee4 <=_MAXFEE, "Invalid Fees");
        _taxRates.buyFee = buyFee;
        _taxRates.sellFee = sellFee;
        _taxRates.transferFee = transferFee;
        _taxRates.vestingFee1 = vestingFee1;
        _taxRates.vestingFee2 = vestingFee2;
        _taxRates.vestingFee3 = vestingFee3;
        _taxRates.vestingFee4 = vestingFee4;
    }
	
	function setMaxTransactionLimit(uint256 _everyone, uint256 _bronzeHolder, uint256 _silverHolder, uint256 _goldHolder) external onlyOwner {
        
        _txLimits.everyone 		= _everyone;
        _txLimits.bronzeHolder 	= _bronzeHolder;
        _txLimits.silverHolder 	= _silverHolder;
        _txLimits.goldHolder 	= _goldHolder;
    }
	
	
    function transfer(address recipient, uint256 amount) public override returns (bool) {
		
		_transfer(_msgSender(), recipient, amount);
        return true;
    }
	
	
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
	
	
	function getVestingFee(address addr) public view returns (uint256) {
		
		uint256 percent = 0;
		if(startTime[addr] > 0){
			uint256 time_since_start = ((block.timestamp - startTime[addr]) * 1e6 / _VESTING_PERIOD); // per day
			
			if (time_since_start <= 1 * 1e6) { //0-1
				percent = _taxRates.vestingFee1;
			}else if (time_since_start > 1 * 1e6 && time_since_start < 30 * 1e6) { //>1 to < 30
				percent = _taxRates.vestingFee2;
			}else if (time_since_start >= 30 * 1e6 && time_since_start < 60 * 1e6) { // >29 to < 60
				percent = _taxRates.vestingFee3;
			}else if (time_since_start >= 60 * 1e6 && time_since_start < 90 * 1e6) { // >60 to < 90
				percent = _taxRates.vestingFee4;
			}
		}
        return percent;
    }
	
	function checkMaxTransactionLimit(address sender, address recipient, uint256 amount) internal view {
        
		if (
            !_isExcludedFromTrxLimit[sender] &&
            !_isExcludedFromTrxLimit[recipient]
        ){
			uint256 checkLimit			=	_txLimits.everyone;
			if(ntfAddressUpdated){
				uint256 bronzebalance 	=	wonkabronze.balanceOf(recipient);
				uint256 silverbalance 	=	wonkasilver.balanceOf(recipient);
				uint256 goldbalance 	=	wonkagold.balanceOf(recipient);
				if(goldbalance>0){
					checkLimit		=	_txLimits.goldHolder;
				}else if(silverbalance>0){
					checkLimit		=	_txLimits.silverHolder;
				}else if(bronzebalance>0){
					checkLimit		=	_txLimits.bronzeHolder;
				}
			}
			require(
				amount <= checkLimit,
				"Transfer amount exceeds the maxTxAmount."
			);
		}
    }
	
	function calculateTaxes(address sender, address recipient, uint256 amount) internal view returns (uint256, uint256, uint256, uint256) {
        
		uint256	buyFee =0;
		uint256	sellFee =0;
		uint256	transferFee =0;
		uint256	vestingFee =0;
		uint256 bronzebalance 	=	0;
		uint256 silverbalance 	=	0;
		uint256 goldbalance 	=	0;
		
		
		if(sender==lpPair){// Buy
		
			if(ntfAddressUpdated){
				bronzebalance 	=	wonkabronze.balanceOf(recipient);
				silverbalance 	=	wonkasilver.balanceOf(recipient);
				goldbalance 	=	wonkagold.balanceOf(recipient);
			}
			if(!_isExcludedFromFee['buy'][recipient] && bronzebalance <1 && silverbalance < 1 && goldbalance <1){
				buyFee	=	amount * _taxRates.buyFee / masterTaxDivisor;
			}
		}else if(recipient==lpPair){// Sell
			
			if(ntfAddressUpdated){
				silverbalance 	=	wonkasilver.balanceOf(sender);
				goldbalance 	=	wonkagold.balanceOf(sender);
			}
			if(!_isExcludedFromFee['sell'][sender] && silverbalance < 1 && goldbalance <1){
				sellFee	=	amount * _taxRates.sellFee / masterTaxDivisor;
			}
		}else{
			
			if(!_isExcludedFromFee['transfer'][sender]){
				transferFee	=	amount * _taxRates.transferFee / masterTaxDivisor;
			}
		}
		if(!_isExcludedFromFee['vesting'][sender] && recipient==lpPair){ //transaction is for sale.
			if(ntfAddressUpdated){
				goldbalance 				=	wonkagold.balanceOf(sender);
			}
			if(goldbalance<1){
				uint256 vestinFeePercent	=	getVestingFee(sender);
				vestingFee					=	amount * vestinFeePercent / masterTaxDivisor;
			}
		}
		return (buyFee, sellFee, transferFee, vestingFee);
    }
	
	function _transferTaxes(address sender, address recipient, uint256 amount) private {
        super._transfer(sender, recipient, amount);
    }
	
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
		
        require(!_isFreezed[sender], "Sender Account Freeze");
        require(!_isFreezed[recipient], "Recipient Account Freeze");
		
		// Check Max Transaction Limit
		checkMaxTransactionLimit(sender, recipient, amount);
		
		(uint256 buyFee, uint256 sellFee, uint256 transferFee, uint256 vestingFee)	=	calculateTaxes(sender, recipient, amount);
		
		bool takeFee = true;
		if(buyFee>0){
			_transferTaxes(sender, _taxWallets.buytax, buyFee);
			takeFee = true;
		}
		
		if(sellFee>0){
			_transferTaxes(sender, _taxWallets.selltax, sellFee);
			takeFee = true;
		}
		
		if(transferFee>0){
			_transferTaxes(sender, _taxWallets.transfertax, transferFee);
			takeFee = true;
		}
		
		if(vestingFee>0){
			_transferTaxes(sender, _taxWallets.vestingtax, vestingFee);
			takeFee = true;
		}
		
		if(takeFee){
			
			uint256 feeTotal = buyFee
				.add(sellFee)
				.add(transferFee)
				.add(vestingFee);
			amount = amount.sub(feeTotal);
			startTime[recipient] = block.timestamp;
		}
		_transferStandard(sender, recipient, amount);
    }

    function _transferStandard(address sender, address recipient, uint256 amount) private {
        super._transfer(sender, recipient, amount);
    }
}