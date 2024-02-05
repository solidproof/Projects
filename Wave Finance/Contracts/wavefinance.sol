//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

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

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}


library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
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

    function renounceOwnership() public onlyOwner {
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

contract Wave is ERC20Detailed, Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event NewNextRebase(uint256 nextRebase);
    event NewRewardYield(uint256 _rewardYield,uint256 _rewardYieldDenominator);
    event NewAutoRebase(bool _autoRebase);
    event NewRebaseFrequency(uint256 _rebaseFrequency);
    event DustSwiped(address _receiver,uint256 balance);
    event ManualRebase();
    event NewLPSet(address _address);
    event InitialDistributionFinished();
    event AddressExemptedFromTransferLock(address _addr);
    event AddressExemptedFromFee(address _addr);
    event NewSwapBackSet(bool _enabled,uint256 _num,uint256 _denom);
    event NewTargetLiquiditySet(uint256 target,uint256 accuracy);
    event NewFeeReceiversSet(address _autoLiquidityReceiver,address _treasuryReceiver);
    event NewFeesSet(uint256 _liquidityFee,uint256 _treasuryFee, uint256 _Firepit ,uint256 _feeDenominator);
    event SetTaxBracketFeeMultiplierEvent(uint256 indexed state, uint256 indexed time);
    event SetTaxBracketEvent(bool indexed value,uint256 indexed time
    );
    event set_Wrapped(address _addr, bool indexed value);

    IPancakeSwapPair public pairContract;

    bool public initialDistributionFinished;

    mapping(address => bool) allowTransfer;
    mapping(address => bool) _isFeeExempt;

    modifier initialDistributionLock() {
        require(initialDistributionFinished || isOwner() || allowTransfer[msg.sender]);
        _;
    }

    modifier validRecipient(address to) {
        require(to != address(0x0), "Address cannot be zero address.");
        _;
    }

    uint256 private constant DECIMALS = 18;
    uint256 private constant MAX_UINT256 = type(uint256).max / 100;
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 1000 * 10**6 * 10**DECIMALS;

    uint256 private constant maxBracketTax = 10; // max bracket is holding 10%

    uint256 public constant MAX_TAX_BRACKET_FEE_RATE = 5;
    uint256 public taxBracketMultiplier = 5;
    bool public isTaxBracketEnabled = false;


    // Buy Fees
    uint256 public liquidityFee = 5;
    uint256 private constant MaxliquidityFee = 5;
    uint256 public treasuryFee = 5;
    uint256 private constant MaxtreasuryFee = 5;
    uint256 public firePitFee = 3;
    uint256 private constant MaxFirePitfee = 3;
    uint256 public totalFeeBuy = liquidityFee.add(treasuryFee).add(firePitFee);

    // Sell Fees
    uint256 public liquidityFeeSell = 5;
    uint256 private constant MaxliquidityFeeSell = 5;
    uint256 public treasuryFeeSell = 15;
    uint256 private constant MaxtreasuryFeeSell = 15;
    uint256 public firePitFeeSell = 3;
    uint256 public totalFeeSell = liquidityFeeSell.add(treasuryFeeSell).add(firePitFeeSell);

    uint256 public feeDenominator = 100;
    uint256 public rewardYield = 3943560072416;
    uint256 public rewardYieldDenominator = 10000000000000000;
    uint256 public rebaseFrequency = 1800;
    uint256 public nextRebase = block.timestamp + rebaseFrequency;
    bool public autoRebase = true;

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = 0x0000000000000000000000000000000000000000;

    address public autoLiquidityReceiver;
    address public treasuryReceiver;
    address public firePit;


    uint256 targetLiquidity = 50;
    uint256 targetLiquidityDenominator = 100;

    IPancakeSwapRouter public router;
    address public immutable pair;

    address public wrapped;
    bool public swapEnabled = true;
    uint256 public INDEX;
    bool public wrapped_set = false;
    uint256 private gonSwapThreshold = (TOTAL_GONS * 10) / 10000;
    bool inSwap;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    uint256 private constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    uint256 private constant MAX_SUPPLY = ~uint128(0);

    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;
    mapping(address => uint256) private _gonBalances;

    mapping(address => mapping(address => uint256)) private _allowedFragments;


    constructor(
        address _router,
        address _autoLiquidityReceiver,
        address _treasuryReceiver,
        address _firePit
    ) ERC20Detailed("Wave", "$WAVE", uint8(DECIMALS)) {

        require(
            (_router != address(0x0)) &&
            (_autoLiquidityReceiver != address(0x0)) &&
            (_treasuryReceiver != address(0x0)) &&
            (_firePit != address(0x0))
            , "Address cannot be zero address.");

        router = IPancakeSwapRouter(_router);

        address _pair = IPancakeSwapFactory(IPancakeSwapRouter(_router).factory()).createPair(
            IPancakeSwapRouter(_router).WETH(),
            address(this)
        );

        pair = _pair;

        autoLiquidityReceiver = _autoLiquidityReceiver;
        treasuryReceiver = _treasuryReceiver;
        firePit = _firePit;

        _allowedFragments[address(this)][address(_router)] = ~uint256(0);
        pairContract = IPancakeSwapPair(_pair);

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[treasuryReceiver] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        initialDistributionFinished = false;
        _isFeeExempt[treasuryReceiver] = true;
        _isFeeExempt[firePit] = true;
        _isFeeExempt[address(this)] = true;

        _transferOwnership(treasuryReceiver);
        emit Transfer(address(0x0), treasuryReceiver, _totalSupply);

        setIndex(uint256(1).mul(10**DECIMALS));
    }

    modifier onlyWrapped() {
        require(msg.sender == wrapped, "Sender must be the wrapped contract.");
        _;
    }

    function setWrapped(address addr) external onlyOwner {
        require(wrapped_set == false, "Wrapped contract address can only be defined once.");
        require(isContract(addr), "Address must be of Contract");
        require(addr != address(0x0), "Address cannot be zero address.");

        wrapped = addr;
        wrapped_set = true; // prevents modifying the wrapped address after it was modified once

        emit set_Wrapped(addr, true);
    }

    function setNextRebase(uint256 _nextRebase) external onlyOwner {
        nextRebase = _nextRebase;

        emit NewNextRebase(_nextRebase);
    }

    function setRewardYield(uint256 _rewardYield, uint256 _rewardYieldDenominator) external onlyOwner {
        require(_rewardYieldDenominator > 0 , "You can't set to 0");
        rewardYield = _rewardYield;
        rewardYieldDenominator = _rewardYieldDenominator;

        emit NewRewardYield(_rewardYield,_rewardYieldDenominator);
    }

    function setAutoRebase(bool _autoRebase) external onlyOwner {
        autoRebase = _autoRebase;

        emit NewAutoRebase(_autoRebase);
    }

    //enable burn fee if necessary
    function setTaxBracket(bool _isTaxBracketEnabled) external onlyOwner {
        require(
            isTaxBracketEnabled != _isTaxBracketEnabled,
            "Tax Bracket function hasn't changed"
        );
        isTaxBracketEnabled = _isTaxBracketEnabled;
        emit SetTaxBracketEvent(_isTaxBracketEnabled, block.timestamp);
    }

    function setRebaseFrequency(uint256 _rebaseFrequency) external onlyOwner {
        rebaseFrequency = _rebaseFrequency;

        emit NewRebaseFrequency(_rebaseFrequency);
    }

    function shouldRebase() public view returns (bool) {
        return nextRebase <= block.timestamp;
    }

    function swipe(address _receiver) external onlyOwner {

        require(_receiver != address(0x0), "Address cannot be zero address.");
        uint256 balance = address(this).balance;
        payable(_receiver).transfer(balance);

        emit DustSwiped(_receiver,balance);
    }

    function coreRebase(uint256 epoch, int256 supplyDelta) private returns (uint256) {
        if (supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }

        if (supplyDelta < 0) {
            _totalSupply = _totalSupply.sub(uint256(-supplyDelta));
        } else {
            _totalSupply = _totalSupply.add(uint256(supplyDelta));
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        pairContract.sync();

        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    function _rebase() private {
        if(!inSwap) {
            uint256 epoch = block.timestamp;
            uint256 circulatingSupply = getCirculatingSupply();
            int256 supplyDelta = int256(circulatingSupply.mul(rewardYield).div(rewardYieldDenominator));

            coreRebase(epoch, supplyDelta);
            nextRebase = epoch + rebaseFrequency;
        }
    }

    function rebase() external onlyOwner {
        require(!inSwap, "Try again");
         _rebase();

         emit ManualRebase();
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function transfer(address to, uint256 value)
        external
        override
        validRecipient(to)
        initialDistributionLock
        returns (bool)
    {
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function setLP(address _address) external onlyOwner {
        pairContract = IPancakeSwapPair(_address);
        _isFeeExempt[_address] = true;

        emit NewLPSet(_address);
    }

    function allowance(address owner_, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _gonBalances[who].div(_gonsPerFragment);
    }

    function getCurrentTaxBracket(address _address)
    public
    view
    returns (uint256)
    {
        uint112 reserve0;
        uint112 reserve1;
        uint32 blockTimestampLast;
        address token0;
        address token1;
        IPancakeSwapPair iDexFeeCalculator;
        uint256 LPTotal;

        iDexFeeCalculator = IPancakeSwapPair(pair);
            (reserve0, reserve1, blockTimestampLast) = iDexFeeCalculator
            .getReserves();
            token0 = iDexFeeCalculator.token0();
            token1 = iDexFeeCalculator.token1();
            if (token0 == address(this)) {
                LPTotal += reserve0;
            } else if (token1 == address(this)) {
                LPTotal += reserve1;
            }
        //gets the total balance of the user
        uint256 userTotal = balanceOf(_address);
        //calculate the percentage
        uint256 totalCap = userTotal.mul(100).div(LPTotal);
        //calculate what is smaller, and use that
        uint256 _bracket = SafeMath.min(totalCap, maxBracketTax);
        //multiply the bracket with the multiplier
        _bracket *= taxBracketMultiplier;
        return _bracket;
    }

    function scaledBalanceOf(address who) external view returns (uint256) {
        return _gonBalances[who];
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
        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        uint256 gonAmount = amount.mul(_gonsPerFragment);

        if (shouldSwapBack()) {
            swapBack();
        }

        _gonBalances[sender] = _gonBalances[sender].sub(gonAmount);

        uint256 gonAmountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, gonAmount)
            : gonAmount;
        _gonBalances[recipient] = _gonBalances[recipient].add(
            gonAmountReceived
        );

        emit Transfer(
            sender,
            recipient,
            gonAmountReceived.div(_gonsPerFragment)
        );

        if(shouldRebase() && autoRebase) {
            _rebase();
        }

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override validRecipient(to) returns (bool) {
        if (_allowedFragments[from][msg.sender] != ~uint256(0)) {
            _allowedFragments[from][msg.sender] = _allowedFragments[from][
                msg.sender
            ].sub(value, "Insufficient Allowance");
        }

        _transferFrom(from, to, value);
        return true;
    }

    function swapBack() internal swapping {
        uint256 dynamicLiquidityFee = isOverLiquified(
            targetLiquidity,
            targetLiquidityDenominator
        )
            ? 0
            : liquidityFee;
        uint256 contractTokenBalance = _gonBalances[address(this)].div(
            _gonsPerFragment
        );
        uint256 amountToLiquify = contractTokenBalance
            .mul(dynamicLiquidityFee)
            .div(totalFeeBuy)
            .div(2);
        uint256 amountToSwap = contractTokenBalance.sub(amountToLiquify);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        uint256 balanceBefore = address(this).balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountBNB = address(this).balance.sub(balanceBefore);

        uint256 totalBNBFee = totalFeeBuy.sub(dynamicLiquidityFee.div(2));

        uint256 amountBNBLiquidity = amountBNB
            .mul(dynamicLiquidityFee)
            .div(totalBNBFee)
            .div(2);
        uint256 amountBNBTreasury = amountBNB.mul(treasuryFee).div(
            totalBNBFee
        );

        (bool success, ) = payable(treasuryReceiver).call{
            value: amountBNBTreasury,
            gas: 30000
        }("");

        success = false;

        if (amountToLiquify > 0) {
            router.addLiquidityETH{value: amountBNBLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );
        }
    }

    function takeFee(address sender, address recipient, uint256 gonAmount) internal returns (uint256) {
        uint256 _totalFee = totalFeeBuy;
        if(recipient == pair) {
            _totalFee = totalFeeSell;
            firePitFee = firePitFeeSell;
        }

        //calculate Tax
        if (isTaxBracketEnabled) {
            _totalFee += getCurrentTaxBracket(sender);
        }

        uint256 feeForFirePit = gonAmount.mul(firePitFee).div(feeDenominator);
        uint256 feeAmount = gonAmount.mul(_totalFee).div(feeDenominator).sub(feeForFirePit);

        _gonBalances[firePit] = _gonBalances[firePit].add(
            feeForFirePit
        );
        _gonBalances[address(this)] = _gonBalances[address(this)].add(
            feeAmount
        );
        emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));

        return gonAmount.sub(feeAmount);
    }

    function isTaxBracket() internal view returns (bool) {
        return isTaxBracketEnabled;
    }


    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        initialDistributionLock
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
        initialDistributionLock
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

    function mint(address recipient, uint256 amount) external onlyWrapped {
        // Only wrapped token can mint tokens to provide additional rewards.
        _totalSupply = _totalSupply.add(uint256(amount));

        uint256 gonsAmount = amount.mul(_gonsPerFragment);

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        pairContract.sync();


        _gonBalances[recipient] = _gonBalances[recipient].add(gonsAmount);
    }

    function gonsForBalance(uint256 amount) public view returns (uint256) {
        return amount.mul(_gonsPerFragment);
    }

    function balanceForGons(uint256 gons) public view returns (uint256) {
        return gons.div(_gonsPerFragment);
    }

    function index() external view returns (uint256) {
        return balanceForGons(INDEX);
    }
    function _index() internal view returns (uint256) {
        return balanceForGons(INDEX);
    }

    function getDecimals() external pure returns (uint256) {
        return 10**DECIMALS;
    }

    function setIndex(uint256 _INDEX) internal {
        // defines the first number to index on - executed only once
        INDEX = gonsForBalance(_INDEX);
    }

    function approve(address spender, uint256 value)
        external
        override
        validRecipient(spender)
        initialDistributionLock
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function setInitialDistributionFinished() external onlyOwner {
        initialDistributionFinished = true;

        emit InitialDistributionFinished();
    }

    function enableTransfer(address _addr) external onlyOwner {
        allowTransfer[_addr] = true;

        emit AddressExemptedFromTransferLock(_addr);
    }

    function setFeeExempt(address _addr) external onlyOwner {
        _isFeeExempt[_addr] = true;

        emit AddressExemptedFromFee(_addr);
    }

    function shouldTakeFee(address from, address to) internal view returns (bool) {
        return (pair == from || pair == to) && (!_isFeeExempt[from]);
    }

    function setSwapBackSettings(
        bool _enabled,
        uint256 _num,
        uint256 _denom
    ) external onlyOwner {
        swapEnabled = _enabled;
        gonSwapThreshold = TOTAL_GONS.div(_denom).mul(_num);

        emit NewSwapBackSet(_enabled,_num,_denom);
    }

    function shouldSwapBack() internal view returns (bool) {
        return
            msg.sender != pair &&
            !inSwap &&
            swapEnabled &&
            _gonBalances[address(this)] >= gonSwapThreshold;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return
            (TOTAL_GONS.sub(_gonBalances[DEAD]).sub(_gonBalances[ZERO])).div(
                _gonsPerFragment
            );
    }

    function setTaxBracketFeeMultiplier(uint256 _taxBracketFeeMultiplier)
    external
    onlyOwner
    {
        require(
            _taxBracketFeeMultiplier <= MAX_TAX_BRACKET_FEE_RATE,
            'max bracket fee exceeded'
        );
        taxBracketMultiplier = _taxBracketFeeMultiplier;
        emit SetTaxBracketFeeMultiplierEvent(_taxBracketFeeMultiplier, block.timestamp);
    }

    function setTargetLiquidity(uint256 target, uint256 accuracy) external onlyOwner {
        targetLiquidity = target;
        targetLiquidityDenominator = accuracy;

        emit NewTargetLiquiditySet(target,accuracy);
    }

    function isNotInSwap() external view returns (bool) {
        return !inSwap;
    }

    function checkSwapThreshold() external view returns (uint256) {
        return gonSwapThreshold.div(_gonsPerFragment);
    }

    function manualSync() external {
        IPancakeSwapPair(pair).sync();
    }

    function setFeeReceivers(
        address _autoLiquidityReceiver,
        address _treasuryReceiver
    ) external onlyOwner {

        require(
            (_autoLiquidityReceiver != address(0x0)) &&
            (_treasuryReceiver != address(0x0)),
            "Address cannot be zero address."
        );

        autoLiquidityReceiver = _autoLiquidityReceiver;
        treasuryReceiver = _treasuryReceiver;

        emit NewFeeReceiversSet(_autoLiquidityReceiver,_treasuryReceiver);
    }

    function setFeesBuy( uint256 _liquidityFee, uint256 _treasuryFee, uint256 _feeDenominator, uint256 _firePitFee) external onlyOwner {
        require(_liquidityFee <= MaxliquidityFee , "You can't set higher than MAX");
        require(_treasuryFee <= MaxtreasuryFee , "You can't set higher than MAX");
        require(_firePitFee <= MaxFirePitfee , "You can't set higher than MAX");
        require(_feeDenominator > 0 , "You can't set to 0");
        liquidityFee = _liquidityFee;
        treasuryFee = _treasuryFee;
        firePitFee = _firePitFee;
        totalFeeBuy = liquidityFee.add(treasuryFee);
        feeDenominator = _feeDenominator;
        emit NewFeesSet(_liquidityFee,_treasuryFee, _firePitFee,_feeDenominator);
    }

    function setFeesSell( uint256 _liquidityFeeSell, uint256 _treasuryFeeSell, uint256 _feeDenominator, uint256 _firePitFeeSell) external onlyOwner {
        require(_liquidityFeeSell <= MaxliquidityFeeSell , "You can't set higher than MAX");
        require(_treasuryFeeSell <= MaxtreasuryFeeSell , "You can't set higher than MAX");
        require(_firePitFeeSell <= MaxFirePitfee , "You can't set higher than MAX");
        liquidityFeeSell = _liquidityFeeSell;
        treasuryFeeSell = _treasuryFeeSell;
        firePitFeeSell = _firePitFeeSell;
        totalFeeSell = liquidityFeeSell.add(treasuryFeeSell);
        feeDenominator = _feeDenominator;

        emit NewFeesSet(_liquidityFeeSell,_treasuryFeeSell, _firePitFeeSell,_feeDenominator);
    }

    function getLiquidityBacking(uint256 accuracy)
        public
        view
        returns (uint256)
    {
        uint256 liquidityBalance = _gonBalances[pair].div(_gonsPerFragment);
        return accuracy.mul(liquidityBalance.mul(2)).div(getCirculatingSupply());
    }

    function isOverLiquified(uint256 target, uint256 accuracy) public view returns (bool) {
        return getLiquidityBacking(accuracy) > target;
    }

    function isContract(address _adr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(_adr) }
        return size > 0;
    }

    receive() external payable {}
}