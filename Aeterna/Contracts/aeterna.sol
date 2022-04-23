/**
 *Submitted for verification at BscScan.com on 2022-04-22
*/

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.7.4;

library SafeMathInt {
    int256 private constant MIN_INT256 = int256(1) << 255;
    int256 private constant MAX_INT256 = ~(int256(1) << 255);

    function mul(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a * b;

        require(c != MIN_INT256 || (a & MIN_INT256) != (b & MIN_INT256));
        require((b == 0) || (c / b == a));
        return c;
    }

    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != -1 || a != MIN_INT256);

        return a / b;
    }

    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a));
        return c;
    }

    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));
        return c;
    }

    function abs(int256 a) internal pure returns (int256) {
        require(a != MIN_INT256);
        return a < 0 ? -a : a;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IPancakeSwapPair {
		event Approval(address indexed owner, address indexed spender, uint value);
		event Transfer(address indexed from, address indexed to, uint value);

		function name() external pure returns (string memory);
		function symbol() external pure returns (string memory);
		function decimals() external pure returns (uint8);
		function totalSupply() external view returns (uint);
		function balanceOf(address owner) external view returns (uint);
		function allowance(address owner, address spender) external view returns (uint);

		function approve(address spender, uint value) external returns (bool);
		function transfer(address to, uint value) external returns (bool);
		function transferFrom(address from, address to, uint value) external returns (bool);

		function DOMAIN_SEPARATOR() external view returns (bytes32);
		function PERMIT_TYPEHASH() external pure returns (bytes32);
		function nonces(address owner) external view returns (uint);

		function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

		event Mint(address indexed sender, uint amount0, uint amount1);
		event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
		event Swap(
				address indexed sender,
				uint amount0In,
				uint amount1In,
				uint amount0Out,
				uint amount1Out,
				address indexed to
		);
		event Sync(uint112 reserve0, uint112 reserve1);

		function MINIMUM_LIQUIDITY() external pure returns (uint);
		function factory() external view returns (address);
		function token0() external view returns (address);
		function token1() external view returns (address);
		function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
		function price0CumulativeLast() external view returns (uint);
		function price1CumulativeLast() external view returns (uint);
		function kLast() external view returns (uint);

		function mint(address to) external returns (uint liquidity);
		function burn(address to) external returns (uint amount0, uint amount1);
		function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
		function skim(address to) external;
		function sync() external;

		function initialize(address, address) external;
}

interface IPancakeSwapRouter{
		function factory() external pure returns (address);
		function WETH() external pure returns (address);

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
		function addLiquidityETH(
				address token,
				uint amountTokenDesired,
				uint amountTokenMin,
				uint amountETHMin,
				address to,
				uint deadline
		) external payable returns (uint amountToken, uint amountETH, uint liquidity);
		function removeLiquidity(
				address tokenA,
				address tokenB,
				uint liquidity,
				uint amountAMin,
				uint amountBMin,
				address to,
				uint deadline
		) external returns (uint amountA, uint amountB);
		function removeLiquidityETH(
				address token,
				uint liquidity,
				uint amountTokenMin,
				uint amountETHMin,
				address to,
				uint deadline
		) external returns (uint amountToken, uint amountETH);
		function removeLiquidityWithPermit(
				address tokenA,
				address tokenB,
				uint liquidity,
				uint amountAMin,
				uint amountBMin,
				address to,
				uint deadline,
				bool approveMax, uint8 v, bytes32 r, bytes32 s
		) external returns (uint amountA, uint amountB);
		function removeLiquidityETHWithPermit(
				address token,
				uint liquidity,
				uint amountTokenMin,
				uint amountETHMin,
				address to,
				uint deadline,
				bool approveMax, uint8 v, bytes32 r, bytes32 s
		) external returns (uint amountToken, uint amountETH);
		function swapExactTokensForTokens(
				uint amountIn,
				uint amountOutMin,
				address[] calldata path,
				address to,
				uint deadline
		) external returns (uint[] memory amounts);
		function swapTokensForExactTokens(
				uint amountOut,
				uint amountInMax,
				address[] calldata path,
				address to,
				uint deadline
		) external returns (uint[] memory amounts);
		function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
				external
				payable
				returns (uint[] memory amounts);
		function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
				external
				returns (uint[] memory amounts);
		function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
				external
				returns (uint[] memory amounts);
		function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
				external
				payable
				returns (uint[] memory amounts);

		function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
		function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
		function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
		function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
		function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
		function removeLiquidityETHSupportingFeeOnTransferTokens(
			address token,
			uint liquidity,
			uint amountTokenMin,
			uint amountETHMin,
			address to,
			uint deadline
		) external returns (uint amountETH);
		function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
			address token,
			uint liquidity,
			uint amountTokenMin,
			uint amountETHMin,
			address to,
			uint deadline,
			bool approveMax, uint8 v, bytes32 r, bytes32 s
		) external returns (uint amountETH);

		function swapExactTokensForTokensSupportingFeeOnTransferTokens(
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
		function swapExactTokensForETHSupportingFeeOnTransferTokens(
			uint amountIn,
			uint amountOutMin,
			address[] calldata path,
			address to,
			uint deadline
		) external;
}

interface IPancakeSwapFactory {
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

contract Ownable {
    address private _owner;

    event OwnershipRenounced(address indexed previousOwner);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    function waiveOwnership() public onlyOwner {
        emit OwnershipRenounced(_owner);
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

contract Aeterna is ERC20Detailed, Ownable {

    using SafeMath for uint256;
    using SafeMathInt for int256;

    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 444444 * 10**DECIMALS;
    uint256 private constant MAX_SUPPLY = 4444444444 * 10**DECIMALS;
    uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);
    uint256 private _gonsPerFragment;

    uint256 public constant DECIMALS = 5;
    uint256 public constant MAX_UINT256 = ~uint256(0);

    uint256 public _rewardYield = 2170;
    uint256 public _rewardYieldDenominator = 10 ** 7;

    address public pairAddress;
    IPancakeSwapPair public pairContract;
    IPancakeSwapRouter public router;

    uint256 public liquidityFee = 40;
    uint256 public aeternaTreasuryFee = 50;
    uint256 public aeternaDefenceFee = 50;
    uint256 public sellFee = 20;
    uint256 public totalFee = liquidityFee.add(aeternaTreasuryFee).add(aeternaDefenceFee);
    uint256 public feeDenominator = 1000;

    address public aeternaTreasuryAddress;
    address public aeternaDefenceAddress;

    bool public _autoRebase = false;
    bool public _rebasePairTokens = true;
    bool public _collectFeeOnTransfer = true;
    bool public _launched = false;

    bool public checkSellLimits = true;
    uint256 public sellThreshold = 1500 * 10**DECIMALS;

    uint256 public _rebaseFrequency = 15 minutes;
    uint256 public _rebaseStartedTime;
    uint256 public _lastRebasedTime;
    uint256 public _totalSupply;
    uint256 public _maxTxPercent = 5;

    uint256 public swapThreshold = 14 * 10**DECIMALS;
    bool public swapAndLiquifyEnabled = false;
    bool public swapAndLiquifyByLimitOnly = false;
    bool inSwap = false;

    mapping(address => bool) public _isFeeExempt;
    mapping (address => bool) public _isAuthorized;
    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;
    mapping(address => bool) public blacklist;
    mapping(address => uint256) public _sellHistory;

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);

    receive() external payable {}

    constructor() ERC20Detailed("Aeterna", "$Aeterna", uint8(DECIMALS)) Ownable() {

        router = IPancakeSwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pairAddress = IPancakeSwapFactory(router.factory()).createPair(router.WETH(), address(this));
        pairContract = IPancakeSwapPair(pairAddress);

        aeternaTreasuryAddress = 0xBABA1bF542EB6462deaB6D4FFb1610D3914a22C8;
        aeternaDefenceAddress = 0x5758371fBB53Ff2aE32fD732F6c77C4fDf4cAdD1;

        _allowedFragments[address(this)][address(router)] = uint256(-1);

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[owner()] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        _isAuthorized[owner()] = true;
        _isAuthorized[address(this)] = true;

        _isFeeExempt[owner()] = true;
        _isFeeExempt[aeternaTreasuryAddress] = true;
        _isFeeExempt[aeternaDefenceAddress] = true;
        _isFeeExempt[address(this)] = true;

        emit Transfer(address(0x0), owner(), _totalSupply);
    }

    function startLaunchSequence(uint256 _sellThreshold) external onlyOwner {
        _launched = true;
        _autoRebase = true;
        swapAndLiquifyEnabled = true;
        _rebaseStartedTime = block.timestamp;
        _lastRebasedTime = block.timestamp;
        sellThreshold = _sellThreshold;
    }

    function setRewardYield(uint256 rewardYield,
        uint256 rewardYieldDenominator,
        uint256 rebaseFrequency
    ) external onlyOwner {
        _rewardYield = rewardYield;
        _rewardYieldDenominator = rewardYieldDenominator;
        _rebaseFrequency = rebaseFrequency;
    }

    function setTaxes(uint256 _liquidityFee,
        uint256 _aeternaTreasuryFee,
        uint256 _aeternaDefenceFee,
        uint256 _sellFee
    ) external onlyOwner {
        liquidityFee = _liquidityFee;
        aeternaTreasuryFee = _aeternaTreasuryFee;
        aeternaDefenceFee = _aeternaDefenceFee;
        sellFee = _sellFee;
        totalFee = liquidityFee.add(aeternaTreasuryFee).add(aeternaDefenceFee);
    }

    function setFeeReceivers(address _aeternaTreasuryAddress, address _aeternaDefenceAddress) external onlyOwner {
        aeternaTreasuryAddress = _aeternaTreasuryAddress;
        aeternaDefenceAddress = _aeternaDefenceAddress;
    }

    function setAutoRebase(bool _flag) external onlyOwner {
        _autoRebase = _flag;
        if (_flag) {
            _lastRebasedTime = block.timestamp;
        }
    }

    function setRebasePairTokens(bool _flag) external onlyOwner {
        _rebasePairTokens = _flag;
    }

    function setTransferFeeStatus(bool _flag) external onlyOwner {
        _collectFeeOnTransfer = _flag;
    }

    function setSellLimits(bool _checkSellLimits,
        uint256 _sellThreshold
    ) external onlyOwner {
        checkSellLimits = _checkSellLimits;
        sellThreshold = _sellThreshold;
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
        _maxTxPercent = maxTxPercent;
    }

    function setSwapBackSettings(uint256 _swapThreshold,
        bool _swapAndLiquifyEnabled,
        bool _swapAndLiquifyByLimitOnly
    ) external onlyOwner {
        swapThreshold = _swapThreshold;
        swapAndLiquifyEnabled = _swapAndLiquifyEnabled;
        swapAndLiquifyByLimitOnly = _swapAndLiquifyByLimitOnly;
    }

    function setWhitelist(address _addr, bool _feeExempt) external onlyOwner {
        _isFeeExempt[_addr] = _feeExempt;
    }

    function setAuthorized(address _addr, bool status) external onlyOwner {
        _isAuthorized[_addr] = status;
    }

    function setBotBlacklist(address _botAddress, bool _flag) external onlyOwner {
        require(isContract(_botAddress), "only contract address, not allowed exteranlly owned account");
        blacklist[_botAddress] = _flag;
    }

    function setPairAddress(address _pairAddress) public onlyOwner {
        pairAddress = _pairAddress;
        pairContract = IPancakeSwapPair(_pairAddress);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address who) external view override returns (uint256) {
        return _gonBalances[who].div(_gonsPerFragment);
    }

    function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function allowance(address owner_, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue.sub(
                subtractedValue
            );
        }
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = _allowedFragments[msg.sender][
            spender
        ].add(addedValue);
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function approve(address spender, uint256 value)
        external
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return
            (TOTAL_GONS.sub(_gonBalances[DEAD]).sub(_gonBalances[ZERO])).div(
                _gonsPerFragment
            );
    }

    function isNotInSwap() external view returns (bool) {
        return !inSwap;
    }

    function manualSync() external onlyOwner {
        pairContract.sync();
    }

    function manualRebase() external onlyOwner {
        if (_launched && shouldRebase()) {
           rebase();
        }
    }

    function rebase() internal {
        if ( inSwap ) return;
        uint256 deltaTime = block.timestamp - _lastRebasedTime;
        uint256 times = deltaTime.div(_rebaseFrequency);
        uint256 epoch = times.mul(_rebaseFrequency.div(1 minutes));
        uint256 pairBalanceBefore = _gonBalances[pairAddress].div(_gonsPerFragment);

        for (uint256 i = 0; i < times; i++) {
            _totalSupply = _totalSupply
                .mul((_rewardYieldDenominator).add(_rewardYield))
                .div(_rewardYieldDenominator);
        }

        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        _lastRebasedTime = _lastRebasedTime.add(times.mul(_rebaseFrequency));

        uint256 pairBalanceAfter = _gonBalances[pairAddress].div(_gonsPerFragment);
        if(!_rebasePairTokens && pairBalanceAfter > pairBalanceBefore) {
            uint256 diffTokens = pairBalanceAfter - pairBalanceBefore;
            _basicTransfer(pairAddress, DEAD, diffTokens);
            emit Transfer(pairAddress, DEAD, diffTokens);
        }

        pairContract.sync();
        emit LogRebase(epoch, _totalSupply);
    }

    function transfer(address to, uint256 value)
        external
        override
        validRecipient(to)
        returns (bool)
    {
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override validRecipient(to) returns (bool) {

        if (_allowedFragments[from][msg.sender] != uint256(-1)) {
            _allowedFragments[from][msg.sender] = _allowedFragments[from][
                msg.sender
            ].sub(value, "Insufficient Allowance");
        }
        _transferFrom(from, to, value);
        return true;
    }

    function _basicTransfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 gonAmount = amount.mul(_gonsPerFragment);
        _gonBalances[from] = _gonBalances[from].sub(gonAmount);
        _gonBalances[to] = _gonBalances[to].add(gonAmount);
        return true;
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(!blacklist[sender] && !blacklist[recipient], "in_blacklist");
        if(!_isAuthorized[sender] && !_isAuthorized[recipient]) {
            require(_launched, "Not Launched.");
            if(sender == pairAddress || recipient == pairAddress) {
                require(amount <= _totalSupply.mul(_maxTxPercent).div(1000), "Transfer amount exceeds the maxTxAmount.");
            }
        }

        if(checkSellLimits && !_isAuthorized[sender] && recipient == pairAddress) {
            require(_sellHistory[sender].add(amount) <= sellThreshold, "Limit reached.");
            _sellHistory[sender] = _sellHistory[sender].add(amount);
        }

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        } else {
            bool hasFee = shouldTakeFee(sender, recipient);

            if (hasFee) {
                if (_autoRebase && shouldRebase()) {
                    rebase();
                }

                if (shouldSwapBack()) {
                    swapAndLiquify();
                }
            }

            uint256 gonAmount = amount.mul(_gonsPerFragment);
            _gonBalances[sender] = _gonBalances[sender].sub(gonAmount);

            uint256 gonAmountReceived = hasFee ? takeFee(sender, recipient, gonAmount) : gonAmount;
            _gonBalances[recipient] = _gonBalances[recipient].add(gonAmountReceived);

            emit Transfer(
                sender,
                recipient,
                gonAmountReceived.div(_gonsPerFragment)
            );

            return true;
        }
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 gonAmount
    ) internal  returns (uint256) {
        uint256 _totalFee = totalFee;

        if (recipient == pairAddress) {
            _totalFee = totalFee.add(sellFee);
        }

        uint256 feeAmount = gonAmount.div(feeDenominator).mul(_totalFee);

        if(feeAmount > 0) {
            _gonBalances[address(this)] = _gonBalances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));
        }

        return gonAmount.sub(feeAmount);
    }

    function swapAndLiquify() internal swapping {
        uint256 tAmount = _gonBalances[address(this)].div(_gonsPerFragment);
        if((tAmount < swapThreshold) || (totalFee == 0)) {
            return;
        }

        if(swapAndLiquifyByLimitOnly) {
            tAmount = swapThreshold;
        }

        uint256 tokensForLP = tAmount.mul(liquidityFee).div(totalFee).div(2);
        uint256 tokensForSwap = tAmount.sub(tokensForLP);

        swapTokensForBNB(tokensForSwap);

        bool success;
        uint256 bnbReceived = address(this).balance;
        uint256 totalShares = totalFee.sub(liquidityFee.div(2));

        uint256 bnbForLiquidity = bnbReceived.mul(liquidityFee).div(totalShares).div(2);
        uint256 bnbForTreasury = bnbReceived.mul(aeternaTreasuryFee).div(totalShares);
        uint256 bnbForDefence = bnbReceived.sub(bnbForTreasury).sub(bnbForLiquidity);

        if(bnbForLiquidity > 0 && tokensForLP > 0) {
            addLiquidity(tokensForLP, bnbForLiquidity);
        }

        if(bnbForTreasury > 0) {
            (success, ) = payable(aeternaTreasuryAddress).call{
                value: bnbForTreasury,
                gas: 30000
            }("");
        }

        if(bnbForDefence > 0) {
            (success, ) = payable(aeternaDefenceAddress).call{
                value: bnbForDefence,
                gas: 30000
            }("");
        }
    }

    function swapTokensForBNB(uint256 amountToSwap) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        router.addLiquidityETH{value: bnbAmount}(
                address(this),
                tokenAmount,
                0,
                0,
                owner(),
                block.timestamp
        );
    }

    function withdrawAllToTreasury() external swapping onlyOwner {
        uint256 amountToSwap = _gonBalances[address(this)].div(_gonsPerFragment);
        require( amountToSwap > 0,"There is no tokens deposited in token contract");
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        bool success;
        uint256 bnbReceived = address(this).balance;
        if(bnbReceived > 0) {
            (success, ) = payable(aeternaTreasuryAddress).call{
                value: bnbReceived,
                gas: 30000
            }("");
        }
    }

    function shouldTakeFee(address from, address to)
        internal
        view
        returns (bool)
    {
        if(_collectFeeOnTransfer) {
            return !_isFeeExempt[from] && !_isFeeExempt[to];
        } else {
            return !_isFeeExempt[from] && !_isFeeExempt[to] && (pairAddress == from || pairAddress == to);
        }
    }

    function shouldRebase() internal view returns (bool) {
        return (_totalSupply < MAX_SUPPLY) &&
            msg.sender != pairAddress  && !inSwap &&
            block.timestamp >= (_lastRebasedTime + _rebaseFrequency);
    }

    function shouldSwapBack() internal view returns (bool) {
        return !inSwap && swapAndLiquifyEnabled &&
            msg.sender != pairAddress;
    }

}