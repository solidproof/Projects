/**
 *Submitted for verification at BscScan.com on 2022-05-11
*/

// SPDX-License-Identifier: MIT
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

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IPancakeSwapPair {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface IPancakeSwapRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IPancakeSwapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

contract Ownable {
    address private _owner;

    event OwnershipRenounced(address indexed previousOwner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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

contract ApeyieldToken is ERC20Detailed, Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 bnbReceived, uint256 tokensIntoLiqudity);

    string public constant _name = "Apeyield";
    string public constant _symbol = "APD";
    uint256 public constant DECIMALS = 18;

    // IPancakeSwapPair public pairContract;
    mapping(address => bool) _isFeeExempt;

    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }

    uint256 public constant MAX_UINT256 = ~uint256(0);
    uint8 public constant RATE_DECIMALS = 7;

    uint256 public constant INITIAL_FRAGMENTS_SUPPLY = 325 * 10**3 * 10**DECIMALS; //325,000

    uint256 public buyLiquidityFee = 40;
    uint256 public buyTreasuryFee = 50;
    uint256 public buyInsuranceFee = 20;
    uint256 public buyBurnFee = 20;
    uint256 public sellLiquidityFee = 40;
    uint256 public sellTreasuryFee = 70;
    uint256 public sellInsuranceFee = 20;
    uint256 public sellBurnFee = 20;
    uint256 public totalBuyFee =
        buyLiquidityFee.add(buyTreasuryFee).add(buyInsuranceFee).add(buyBurnFee);
    uint256 public totalSellFee =
        sellLiquidityFee.add(sellTreasuryFee).add(sellInsuranceFee).add(sellBurnFee);
    uint256 public constant feeDenominator = 1000;
    uint256 public tradingActiveBlock = 0;

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = 0x0000000000000000000000000000000000000000;

    address public autoLiquidityReceiver;
    address public treasuryReceiver;
    address public insuranceReceiver;
    uint256 public dynamicRebaseMultiplier = 5;
    uint256 public buyTotal;
    uint256 public sellTotal;

    bool public tradingActive = false;

    IPancakeSwapRouter public router;
    address[] public _markerPairs;
    uint256 public _markerPairCount;
    mapping(address => bool) public automatedMarketMakerPairs;
    bool inSwap = false;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    uint256 private constant MAX_SUPPLY = 3 * 10**9 * 10**DECIMALS; //3 Billion

    bool public _autoRebase;
    bool public _autoAddLiquidity;
    uint256 public _initRebaseStartTime;
    uint256 public _lastRebasedTime;
    uint256 public _lastAddLiquidityTime;
    uint256 public _totalSupply;
    uint256 private _gonsPerFragment;

    bool public isTaxBracketEnabled = true;
    uint256 private constant maxBracketTax = 10; // max bracket is holding 10%
    uint256 public taxBracketMultiplier = 50;

    mapping(address => uint256) public _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;

    constructor() ERC20Detailed("Apeyield", "APD", uint8(DECIMALS)) Ownable() {
        router = IPancakeSwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address _pair = IPancakeSwapFactory(router.factory()).createPair(
            router.WETH(),
            address(this)
        );
        address _owner = 0xfFbCF23e03D949659451D45080d6790CF95c64E0;
        treasuryReceiver = 0xfFbCF23e03D949659451D45080d6790CF95c64E0;
        insuranceReceiver = 0xfFbCF23e03D949659451D45080d6790CF95c64E0;
        autoLiquidityReceiver = DEAD;

        _allowedFragments[address(this)][address(router)] = uint256(-1);
        setAutomatedMarketMakerPair(_pair, true);

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[_owner] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        _isFeeExempt[_owner] = true;
        _isFeeExempt[treasuryReceiver] = true;
        _isFeeExempt[insuranceReceiver] = true;
        _isFeeExempt[address(this)] = true;

        _transferOwnership(_owner);
        emit Transfer(address(0x0), treasuryReceiver, _totalSupply);
    }

    function rebase() internal {
        if (inSwap) return;
        uint256 rebaseRate;
        uint256 deltaTimeFromInit = block.timestamp - _initRebaseStartTime;
        uint256 deltaTime = block.timestamp - _lastRebasedTime;
        uint256 times = deltaTime.div(5 minutes);
        uint256 epoch = times.mul(10);

        if (deltaTimeFromInit < (365 days)) {
            rebaseRate = 510; //  (1+510/10^7)^105120 =  212.93422093 = 21293.422093 %
        } else if (deltaTimeFromInit >= (7 * 365 days)) {
            rebaseRate = 2;
        } else if (deltaTimeFromInit >= ((15 * 365 days) / 10)) {
            rebaseRate = 14;
        } else if (deltaTimeFromInit >= (365 days)) {
            rebaseRate = 115;
        }

        uint256 _dynamicRebase = getDynamicRebaseRate();
        buyTotal = 0;
        sellTotal = 0;
        uint256 _yearsPassed = (deltaTimeFromInit.div(365 days)).add(1);

        rebaseRate += _dynamicRebase.div(_yearsPassed);

        for (uint256 i = 0; i < times; i++) {
            _totalSupply = _totalSupply.mul((10**RATE_DECIMALS).add(rebaseRate)).div(
                10**RATE_DECIMALS
            );
        }

        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        _lastRebasedTime = _lastRebasedTime.add(times.mul(5 minutes));

        manualSync();

        emit LogRebase(epoch, _totalSupply);
    }

    function getDynamicRebaseRate() public view returns (uint256) {
        uint256 _rebaseRate = buyTotal
            .add((sellTotal.mul(2)))
            .mul(100)
            .mul(dynamicRebaseMultiplier)
            .div(getTokensInLPCirculation());

        if (_rebaseRate > 280) return 280; // Max 790   || (1+(790÷10^7))^105120 = 4040.614204898 | 404061.4204898 %
        return _rebaseRate;
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
            _allowedFragments[from][msg.sender] = _allowedFragments[from][msg.sender].sub(
                value,
                "Insufficient Allowance"
            );
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
        if (!tradingActive) {
            require(_isFeeExempt[sender] || _isFeeExempt[recipient], "Trading is not active.");
        }

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }
        if (shouldRebase()) {
            rebase();
        }

        if (shouldAddLiquidity()) {
            addLiquidity();
        }

        if (shouldSwapBack()) {
            swapBack();
        }

        if (_autoRebase) {
            if (automatedMarketMakerPairs[recipient]) sellTotal = sellTotal.add(amount);
            else buyTotal = buyTotal.add(amount);
        }

        uint256 gonAmount = amount.mul(_gonsPerFragment);
        _gonBalances[sender] = _gonBalances[sender].sub(gonAmount);
        uint256 gonAmountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, gonAmount)
            : gonAmount;
        _gonBalances[recipient] = _gonBalances[recipient].add(gonAmountReceived);

        emit Transfer(sender, recipient, gonAmountReceived.div(_gonsPerFragment));
        return true;
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 gonAmount
    ) internal returns (uint256) {
        if (automatedMarketMakerPairs[recipient] && isTaxBracketEnabled) {
            //sell Fee
            uint256 _dynamicFee;
            uint256 _totalFee = totalSellFee;
            _dynamicFee = getCurrentTaxBracket(sender);
            _totalFee = _totalFee.add(_dynamicFee);
            uint256 feeAmount = gonAmount.mul(_totalFee).div(feeDenominator);

            _gonBalances[DEAD] = _gonBalances[DEAD].add(
                gonAmount.mul(sellBurnFee).div(feeDenominator)
            );
            _gonBalances[address(this)] = _gonBalances[address(this)].add(
                gonAmount.mul(sellTreasuryFee.add(sellInsuranceFee)).div(feeDenominator)
            );
            _gonBalances[autoLiquidityReceiver] = _gonBalances[autoLiquidityReceiver].add(
                gonAmount.mul(sellLiquidityFee).div(feeDenominator)
            );

            emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));
            return gonAmount.sub(feeAmount);
        }
        if (automatedMarketMakerPairs[sender] && isTaxBracketEnabled) {
            //buy tax
            uint256 _dynamicFee;
            uint256 _totalFee = totalBuyFee;
            _dynamicFee = getCurrentTaxBracket(recipient);
            _totalFee = _totalFee.add(_dynamicFee);
            uint256 feeAmount = gonAmount.mul(_totalFee).div(feeDenominator);

            _gonBalances[DEAD] = _gonBalances[DEAD].add(
                gonAmount.mul(buyBurnFee).div(feeDenominator)
            );
            _gonBalances[address(this)] = _gonBalances[address(this)].add(
                gonAmount.mul(buyTreasuryFee.add(buyInsuranceFee)).div(feeDenominator)
            );
            _gonBalances[autoLiquidityReceiver] = _gonBalances[autoLiquidityReceiver].add(
                gonAmount.mul(buyLiquidityFee).div(feeDenominator)
            );

            emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));
            return gonAmount.sub(feeAmount);
        }
    }

    function getCurrentTaxBracket(address _address) public view returns (uint256) {
        //gets the total balance of the user
        uint256 userTotal = balanceOf(_address);

        //calculate the percentage
        uint256 totalCap = userTotal.mul(100).div(getTokensInLPCirculation());

        //calculate what is smaller, and use that
        uint256 _bracket = SafeMath.min(totalCap, maxBracketTax);

        //multiply the bracket with the multiplier
        _bracket *= taxBracketMultiplier;

        return _bracket;
    }

    function getTokensInLPCirculation() public view returns (uint256) {
        uint112 reserve0;
        uint112 reserve1;
        uint32 blockTimestampLast;
        address token0;
        address token1;
        IPancakeSwapPair iDexFeeCalculator;
        uint256 LPTotal;

        for (uint256 i = 0; i < _markerPairs.length; i++) {
            iDexFeeCalculator = IPancakeSwapPair(_markerPairs[i]);
            (reserve0, reserve1, blockTimestampLast) = iDexFeeCalculator.getReserves();

            token0 = iDexFeeCalculator.token0();
            token1 = iDexFeeCalculator.token1();

            if (token0 == address(this)) {
                LPTotal += reserve0;
                //first one
            } else if (token1 == address(this)) {
                LPTotal += reserve1;
            }
        }

        return LPTotal;
    }

    function setTaxBracket(bool _isTaxBracketEnabled) external onlyOwner {
        require(isTaxBracketEnabled != _isTaxBracketEnabled, "Tax Bracket function hasn't changed");
        isTaxBracketEnabled = _isTaxBracketEnabled;
    }

    function setTaxMultiplier(uint256 _taxBracketMultiplier) external onlyOwner {
        require(_taxBracketMultiplier <= 50, "");
        taxBracketMultiplier = _taxBracketMultiplier;
    }

    function addLiquidity() internal swapping {
        uint256 autoLiquidityAmount = _gonBalances[autoLiquidityReceiver].div(_gonsPerFragment);
        _gonBalances[address(this)] = _gonBalances[address(this)].add(
            _gonBalances[autoLiquidityReceiver]
        );
        _gonBalances[autoLiquidityReceiver] = 0;
        uint256 amountToLiquify = autoLiquidityAmount.div(2);
        uint256 amountToSwap = autoLiquidityAmount.sub(amountToLiquify);

        if (amountToSwap == 0) {
            return;
        }
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

        uint256 amountETHLiquidity = address(this).balance.sub(balanceBefore);

        if (amountToLiquify > 0 && amountETHLiquidity > 0) {
            router.addLiquidityETH{ value: amountETHLiquidity }(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );
        }
        _lastAddLiquidityTime = block.timestamp;
    }

    function swapBack() internal swapping {
        uint256 amountToSwap = _gonBalances[address(this)].div(_gonsPerFragment);

        if (amountToSwap == 0) {
            return;
        }

        uint256 balanceBefore = address(this).balance;
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

        uint256 amountBNBtoTransfer = address(this).balance.sub(balanceBefore);

        (bool success, ) = payable(insuranceReceiver).call{
            value: amountBNBtoTransfer.mul(sellInsuranceFee).div(
                sellInsuranceFee.add(sellTreasuryFee)
            ),
            gas: 30000
        }("");
        (success, ) = payable(treasuryReceiver).call{
            value: amountBNBtoTransfer.mul(sellTreasuryFee).div(
                sellInsuranceFee.add(sellTreasuryFee)
            ),
            gas: 30000
        }("");
    }

    function shouldTakeFee(address from, address to) internal view returns (bool) {
        return
            (automatedMarketMakerPairs[from] || automatedMarketMakerPairs[to]) &&
            !_isFeeExempt[from];
    }

    function shouldRebase() internal view returns (bool) {
        return
            _autoRebase &&
            (_totalSupply < MAX_SUPPLY) &&
            !automatedMarketMakerPairs[msg.sender] &&
            !inSwap &&
            block.timestamp >= (_lastRebasedTime + 5 minutes);
    }

    function shouldAddLiquidity() internal view returns (bool) {
        return
            _autoAddLiquidity &&
            !inSwap &&
            !automatedMarketMakerPairs[msg.sender] &&
            block.timestamp >= (_lastAddLiquidityTime + 2 days);
    }

    function shouldSwapBack() internal view returns (bool) {
        return !inSwap && !automatedMarketMakerPairs[msg.sender];
    }

    function setAutoRebase(bool _flag) external onlyOwner {
        if (_flag) {
            _autoRebase = _flag;
            _lastRebasedTime = block.timestamp;
        } else {
            _autoRebase = _flag;
        }
    }

    function setAutoAddLiquidity(bool _flag) external onlyOwner {
        if (_flag) {
            _autoAddLiquidity = _flag;
            _lastAddLiquidityTime = block.timestamp;
        } else {
            _autoAddLiquidity = _flag;
        }
    }

    function allowance(address owner_, address spender) external view override returns (uint256) {
        return _allowedFragments[owner_][spender];
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue.sub(subtractedValue);
        }
        emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _allowedFragments[msg.sender][spender] = _allowedFragments[msg.sender][spender].add(
            addedValue
        );
        emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
        return true;
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function getCirculatingSupply() public view returns (uint256) {
        return (TOTAL_GONS.sub(_gonBalances[DEAD]).sub(_gonBalances[ZERO])).div(_gonsPerFragment);
    }

    function isNotInSwap() external view returns (bool) {
        return !inSwap;
    }

    function manualSync() public {
        for (uint256 i = 0; i < _markerPairs.length; i++) {
            IPancakeSwapPair(_markerPairs[i]).sync();
        }
    }

    function setAutomatedMarketMakerPair(address _pair, bool _value) public onlyOwner {
        require(automatedMarketMakerPairs[_pair] != _value, "Value already set");

        automatedMarketMakerPairs[_pair] = _value;

        if (_value) {
            _markerPairs.push(_pair);
            _markerPairCount++;
        } else {
            require(_markerPairs.length > 1, "Required 1 pair");
            for (uint256 i = 0; i < _markerPairs.length; i++) {
                if (_markerPairs[i] == _pair) {
                    _markerPairs[i] = _markerPairs[_markerPairs.length - 1];
                    _markerPairs.pop();
                    break;
                }
            }
        }

        emit SetAutomatedMarketMakerPair(_pair, _value);
    }

    function setDynamicRebaseMultiplier(uint256 _dynamicRebaseMultiplier) public {
        dynamicRebaseMultiplier = _dynamicRebaseMultiplier;
    }

    function setFeeReceivers(address _treasuryReceiver, address _insuranceReceiver)
        external
        onlyOwner
    {
        treasuryReceiver = _treasuryReceiver;
        insuranceReceiver = _insuranceReceiver;
    }

    function setTaxes(
        uint256 _buyLiquidityFee,
        uint256 _buyTreasuryFee,
        uint256 _buyInsuranceFee,
        uint256 _buyBurnFee,
        uint256 _sellLiquidityFee,
        uint256 _sellTreasuryFee,
        uint256 _sellInsuranceFee,
        uint256 _sellBurnFee
    ) external onlyOwner {
        buyLiquidityFee = _buyLiquidityFee;
        buyTreasuryFee = _buyTreasuryFee;
        buyInsuranceFee = _buyInsuranceFee;
        buyBurnFee = _buyBurnFee;
        sellLiquidityFee = _sellLiquidityFee;
        sellTreasuryFee = _sellTreasuryFee;
        sellInsuranceFee = _sellInsuranceFee;
        sellBurnFee = _sellBurnFee;
    }

    function getLiquidityBacking(uint256 accuracy) public view returns (uint256) {
        uint256 liquidityBalance = 0;
        for (uint256 i = 0; i < _markerPairs.length; i++) {
            liquidityBalance.add(balanceOf(_markerPairs[i]));
        }

        return accuracy.mul(liquidityBalance.mul(2)).div(getCirculatingSupply());
    }

    function setWhitelist(address _addr) external onlyOwner {
        _isFeeExempt[_addr] = true;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _gonBalances[who].div(_gonsPerFragment);
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function enableTrading() external onlyOwner {
        require(tradingActive == false, "Trading is already enabled");
        _initRebaseStartTime = block.timestamp;
        _lastRebasedTime = block.timestamp;
        _autoRebase = true;
        _autoAddLiquidity = true;
        tradingActive = true;
        tradingActiveBlock = block.number.add(2);
    }
    receive() external payable {}
}