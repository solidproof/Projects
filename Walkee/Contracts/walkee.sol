/**
 *Submitted for verification at BscScan.com on 2022-05-19
*/

// File: contracts\Library2.sol

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
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

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

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
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

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

abstract contract IERC20Metadata is IERC20 {
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

interface _WALKEE_CLAIM {
    function setWalkeeData(uint256 initBlock) external;

    function addFee(uint256 epoch) external payable;

    function setMin(
        uint256 epoch,
        address _address1,
        uint256 gon1,
        address _address2,
        uint256 gon2
    ) external;

    function getLastRewardEpoch() external view returns (uint256);

    event Reward(
        address indexed to,
        uint256 indexed epoch,
        uint256 indexed value
    );
}

interface _WALKEE {
    function getGonsPerFragment() external view returns (uint256);
}

contract WALKEE is IERC20Metadata, Ownable, _WALKEE {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    _WALKEE_CLAIM public claimContract;
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    IPancakeSwapPair public pairContract;
    mapping(address => bool) _isFeeExempt;
    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }
    modifier onlyClaimContract() {
        require(msg.sender == address(claimContract), "Only claim contract");
        _;
    }
    uint256 internal constant DECIMALS = 10;
    uint256 constant MAX_UINT256 = ~uint256(0);
    uint8 constant RATE_DECIMALS = 7;
    string _name = "WALKEE";
    string _symbol = "WALKEE";
    uint8 _decimals = uint8(DECIMALS);
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY =
        1.2 * 10**6 * 10**DECIMALS;
    uint256 public constant sellLiquidityFee = 75;
    uint256 public constant sellTreasuryFee = 450;
    uint256 public constant sellInsuranceFundFee = 450;
    uint256 public constant sellBurnFee = 75;
    uint256 public constant sellBNBFee = 450;

    uint256 public constant buyLiquidityFee = 50;
    uint256 public constant buyTreasuryFee = 300;
    uint256 public constant buyInsuranceFundFee = 300;
    uint256 public constant buyBurnFee = 50;
    uint256 public constant buyBNBFee = 300;

    uint256 public totalFeeSell =
        sellLiquidityFee
            .add(sellTreasuryFee)
            .add(sellInsuranceFundFee)
            .add(sellBurnFee)
            .add(sellBNBFee);
    uint256 public totalFeeBuy =
        buyLiquidityFee
            .add(buyTreasuryFee)
            .add(buyInsuranceFundFee)
            .add(buyBurnFee)
            .add(buyBNBFee);
    uint256 public constant feeDenominator = 10000;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = 0x0000000000000000000000000000000000000000;

    address public autoLiquidityReceiver =
        0x30503038323E467F0D3a9A8d8C643568418C4FED;
    address public treasuryReceiver =
        0xF8109A38058891A07Ce4b47814Cef475Cff95FED;
    address public insuranceFundReceiver =
        0x70096318102Ba1b41d3A3DE00D5f5AC48d343FED;
    address public walkeeRewardReceiver =
        0x000000000000000000000000000000000000baBe;
    address public burnAddress = DEAD;
    address public pairAddress;

    IPancakeSwapRouter public router;
    address public pair;
    bool inSwap = false;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    uint256 private constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    uint256 private constant MAX_SUPPLY = 2.4 * 10**10 * 10**DECIMALS;

    bool public _autoRebase = false;
    bool public _autoSwapBack = false;
    bool public _autoAddLiquidity = false;

    uint256 public _initRebaseStartTime;
    uint256 public _lastAddLiquidityTime;
    uint256 public _totalSupply = INITIAL_FRAGMENTS_SUPPLY;

    uint256 private _gonsPerFragment;
    uint256 public _rebaseEpoch = 0;

    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;
    mapping(address => bool) public blacklist;
    mapping(address => bool) public countHolders;

    uint256 _initBlock;
    uint256 public numberOfBlocksPerRewardsCycle = 28800; //1 day

    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    uint256 holders = 1;
    bool _startRebase = false;

    constructor()
        IERC20Metadata("WALKEE", "WALKEE", uint8(DECIMALS))
        Ownable()
    {
        router = IPancakeSwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IPancakeSwapFactory(router.factory()).createPair(
            router.WETH(),
            address(this)
        );
        _allowedFragments[address(this)][address(router)] = MAX_UINT256;
        pairAddress = pair;
        pairContract = IPancakeSwapPair(pair);
        _gonBalances[walkeeRewardReceiver] = TOTAL_GONS.div(6); //200k tokens
        _gonBalances[treasuryReceiver] = TOTAL_GONS.sub( //1tr tokens
            _gonBalances[walkeeRewardReceiver]
        );

        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        _initRebaseStartTime = block.timestamp;
        _lastAddLiquidityTime = block.timestamp;
        _isFeeExempt[treasuryReceiver] = true;
        _isFeeExempt[address(this)] = true;
        _initBlock = block.number;

        emit Transfer(
            address(0x0),
            treasuryReceiver,
            _gonBalances[treasuryReceiver].div(_gonsPerFragment)
        );
        emit Transfer(
            address(0x0),
            walkeeRewardReceiver,
            _gonBalances[walkeeRewardReceiver].div(_gonsPerFragment)
        );
    }

    function startRebase() external onlyOwner {
        require(!_startRebase);
        _startRebase = true;
        _initRebaseStartTime = block.timestamp;
        _autoRebase = true;
    }

    function getGonsPerFragment() external view override returns (uint256) {
        return _gonsPerFragment;
    }

    function getClaimContract() external view returns (address) {
        return address(claimContract);
    }

    function setClaimContract(address _contract) external onlyOwner {
        require(_contract != address(0x0) && isContract(_contract));
        if (_gonBalances[address(claimContract)] > 0) {
            //balance from old contract
            _gonBalances[_contract] = _gonBalances[_contract].add(
                _gonBalances[address(claimContract)]
            );
        }
        claimContract = _WALKEE_CLAIM(_contract);
        claimContract.setWalkeeData(_initBlock);
        _allowedFragments[_contract][address(router)] = MAX_UINT256;
        _isFeeExempt[address(claimContract)] = true;
        _gonBalances[address(claimContract)] = _gonBalances[
            address(claimContract)
        ].add(_gonBalances[walkeeRewardReceiver]);
        _gonBalances[walkeeRewardReceiver] = 0;
    }

    function _rebase() internal {
        if (!shouldRebase()) return;
        if (inSwap) return;
        uint256 rebaseRate;
        uint256 deltaTimeFromInit = block.timestamp - _initRebaseStartTime;
        uint256 epoch = currentRebaseEpoch();
        uint256 times = epoch - _rebaseEpoch;
        if (deltaTimeFromInit < (365 days)) {
            rebaseRate = 1800;
        } else if (deltaTimeFromInit >= (5 * 365 days)) {
            rebaseRate = 9;
        } else {
            rebaseRate = 10;
        }
        for (uint256 i = 0; i < times; i++) {
            _totalSupply = _totalSupply
                .mul((10**RATE_DECIMALS).add(rebaseRate))
                .div(10**RATE_DECIMALS);
        }
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        pairContract.sync();
        _rebaseEpoch = epoch;
        emit LogRebase(epoch, _totalSupply);
    }

    function currentRewardsEpoch() public view returns (uint256) {
        return
            1 +
            (block.number + 1 - _initBlock).div(numberOfBlocksPerRewardsCycle);
    }

    function currentRebaseEpoch() public view returns (uint256) {
        return (block.timestamp - _initRebaseStartTime).div(10 minutes);
    }

    function timeToNextEpoch() public view returns (uint256) {
        return
            _initRebaseStartTime +
            (currentRebaseEpoch() + 1).mul(10 minutes) -
            block.timestamp;
    }

    function shouldRebase() internal view returns (bool) {
        uint256 epoch = currentRebaseEpoch();
        return
            _startRebase &&
            _autoRebase &&
            (_totalSupply < MAX_SUPPLY) &&
            msg.sender != pair &&
            !inSwap &&
            epoch > _rebaseEpoch;
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

    function manualRebase() external returns (bool) {
        require(shouldRebase(), "Too early to rebase");
        _rebase();
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override validRecipient(to) returns (bool) {
        if (_allowedFragments[from][msg.sender] != MAX_UINT256) {
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
        if (!countHolders[sender]) {
            countHolders[sender] = true;
            holders = holders.add(1);
        }
        if (!countHolders[recipient]) {
            countHolders[recipient] = true;
            holders = holders.add(1);
        }
        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }
        _rebase();
        if (shouldAddLiquidity()) {
            _addLiquidity();
        }
        if (shouldSwapBack()) {
            _swapBack();
        }
        uint256 gonAmount = amount.mul(_gonsPerFragment);
        _gonBalances[sender] = _gonBalances[sender].sub(gonAmount);
        uint256 gonAmountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, gonAmount)
            : gonAmount;
        _gonBalances[recipient] = _gonBalances[recipient].add(
            gonAmountReceived
        );

        claimContract.setMin(
            currentRewardsEpoch(),
            sender,
            _gonBalances[sender],
            recipient,
            _gonBalances[recipient]
        );

        emit Transfer(
            sender,
            recipient,
            gonAmountReceived.div(_gonsPerFragment)
        );
        return true;
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 gonAmount
    ) internal returns (uint256) {
        uint256 _totalFee = 0;
        uint256 _treasuryFee = 0;
        uint256 _burnFee = 0;
        uint256 _insuranceFundFee = 0;
        uint256 _BNBFee = 0;
        uint256 _liquidityFee = 0;
        if (recipient == pair) {
            _totalFee = totalFeeSell;
            _treasuryFee = sellTreasuryFee;
            _insuranceFundFee = sellInsuranceFundFee;
            _BNBFee = sellBNBFee;
            _liquidityFee = sellLiquidityFee;
            _burnFee = sellBurnFee;
        } else {
            _totalFee = totalFeeBuy;
            _treasuryFee = buyTreasuryFee;
            _insuranceFundFee = buyInsuranceFundFee;
            _BNBFee = buyBNBFee;
            _liquidityFee = buyLiquidityFee;
            _burnFee = buyBurnFee;
        }

        uint256 feeAmount = gonAmount.div(feeDenominator).mul(_totalFee);

        _gonBalances[burnAddress] = _gonBalances[burnAddress].add(
            gonAmount.mul(_burnFee).div(feeDenominator)
        );
        _gonBalances[address(this)] = _gonBalances[address(this)].add(
            gonAmount.mul(_treasuryFee.add(_insuranceFundFee).add(_BNBFee)).div(
                feeDenominator
            )
        );
        _gonBalances[autoLiquidityReceiver] = _gonBalances[
            autoLiquidityReceiver
        ].add(gonAmount.mul(_liquidityFee).div(feeDenominator));

        emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));
        return gonAmount.sub(feeAmount);
    }

    function _sellToken(uint256 amountToSwap) internal returns (uint256) {
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
        return address(this).balance.sub(balanceBefore);
    }

    function _addLiquidity() internal swapping {
        uint256 autoLiquidityAmount = _gonBalances[autoLiquidityReceiver].div(
            _gonsPerFragment
        );
        _gonBalances[address(this)] = _gonBalances[address(this)].add(
            _gonBalances[autoLiquidityReceiver]
        );
        _gonBalances[autoLiquidityReceiver] = 0;
        uint256 amountToLiquify = autoLiquidityAmount.div(2);
        uint256 amountToSwap = autoLiquidityAmount.sub(amountToLiquify);

        if (amountToSwap == 0) {
            return;
        }

        uint256 amountETHLiquidity = _sellToken((amountToSwap));

        if (amountToLiquify > 0 && amountETHLiquidity > 0) {
            router.addLiquidityETH{value: amountETHLiquidity}(
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

    function _swapBack() internal swapping {
        uint256 amountToSwap = _gonBalances[address(this)].div(
            _gonsPerFragment
        );
        if (amountToSwap == 0) {
            return;
        }
        uint256 totalSwapBackFee = buyTreasuryFee.add(buyInsuranceFundFee).add(
            buyBNBFee
        );
        uint256 amountETH = _sellToken(amountToSwap);
        uint256 BNBReward = amountETH.mul(buyBNBFee).div(totalSwapBackFee);
        (bool success, ) = payable(treasuryReceiver).call{
            value: amountETH.mul(buyTreasuryFee).div(totalSwapBackFee),
            gas: 30000
        }("");
        (success, ) = payable(insuranceFundReceiver).call{
            value: amountETH.mul(buyInsuranceFundFee).div(totalSwapBackFee),
            gas: 30000
        }("");
        claimContract.addFee{value: BNBReward}(currentRewardsEpoch());
    }

    function shouldTakeFee(address from, address to)
        internal
        view
        returns (bool)
    {
        return (pair == from || pair == to) && !_isFeeExempt[from];
    }

    function shouldAddLiquidity() internal view returns (bool) {
        return
            _autoAddLiquidity &&
            !inSwap &&
            msg.sender != pair &&
            block.timestamp >= (_lastAddLiquidityTime + 2 days);
    }

    function shouldSwapBack() internal view returns (bool) {
        return _autoSwapBack && !inSwap && msg.sender != pair;
    }

    function setAutoRebase(bool _flag) external onlyOwner {
        _autoRebase = _flag;
    }

    function setAutoSwapBack(bool _flag) external onlyOwner {
        _autoSwapBack = _flag;
    }

    function setAutoAddLiquidity(bool _flag) external onlyOwner {
        if (_flag) {
            _autoAddLiquidity = _flag;
            _lastAddLiquidityTime = block.timestamp;
        } else {
            _autoAddLiquidity = _flag;
        }
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

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
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

    function setFeeReceivers(
        address _autoLiquidityReceiver,
        address _treasuryReceiver,
        address _insuranceFundReceiver,
        address _burnAddress
    ) external onlyOwner {
        autoLiquidityReceiver = _autoLiquidityReceiver;
        treasuryReceiver = _treasuryReceiver;
        insuranceFundReceiver = _insuranceFundReceiver;
        burnAddress = _burnAddress;
    }

    function getLiquidityBacking(uint256 accuracy)
        public
        view
        returns (uint256)
    {
        uint256 liquidityBalance = _gonBalances[pair].div(_gonsPerFragment);
        return
            accuracy.mul(liquidityBalance.mul(2)).div(getCirculatingSupply());
    }

    function setWhitelist(address _addr) external onlyOwner {
        _isFeeExempt[_addr] = true;
    }

    function setBotBlacklist(address _botAddress, bool _flag)
        external
        onlyOwner
    {
        require(isContract(_botAddress), "only contract address");
        blacklist[_botAddress] = _flag;
    }

    function setPairAddress(address _pairAddress) public onlyOwner {
        pairAddress = _pairAddress;
    }

    function setLP(address _address) external onlyOwner {
        pairContract = IPancakeSwapPair(_address);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address who) external view override returns (uint256) {
        return _gonBalances[who].div(_gonsPerFragment);
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    receive() external payable {}
}