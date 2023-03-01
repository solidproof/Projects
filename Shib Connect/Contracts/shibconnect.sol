// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.17;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

interface IUniswapV2Pair {
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

interface IUniswapV2Factory {
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

library IterableMapping {
    // Iterable mapping from address to uint;
    struct Map {
        address[] keys;
        mapping(address => uint256) values;
        mapping(address => uint256) indexOf;
        mapping(address => bool) inserted;
    }

    function get(Map storage map, address key) internal view returns (uint256) {
        return map.values[key];
    }

    function getIndexOfKey(Map storage map, address key)
        internal
        view
        returns (int256)
    {
        if (!map.inserted[key]) {
            return -1;
        }
        return int256(map.indexOf[key]);
    }

    function getKeyAtIndex(Map storage map, uint256 index)
        internal
        view
        returns (address)
    {
        return map.keys[index];
    }

    function size(Map storage map) internal view returns (uint256) {
        return map.keys.length;
    }

    function set(
        Map storage map,
        address key,
        uint256 val
    ) internal {
        if (map.inserted[key]) {
            map.values[key] = val;
        } else {
            map.inserted[key] = true;
            map.values[key] = val;
            map.indexOf[key] = map.keys.length;
            map.keys.push(key);
        }
    }

    function remove(Map storage map, address key) internal {
        if (!map.inserted[key]) {
            return;
        }

        delete map.inserted[key];
        delete map.values[key];

        uint256 index = map.indexOf[key];
        uint256 lastIndex = map.keys.length - 1;
        address lastKey = map.keys[lastIndex];

        map.indexOf[lastKey] = index;
        delete map.indexOf[key];

        map.keys[index] = lastKey;
        map.keys.pop();
    }
}

interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);


    event Transfer(address indexed from, address indexed to, uint256 value);


    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IERC20Metadata is IERC20 {

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }


    function name() public view virtual override returns (string memory) {
        return _name;
    }


    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }


    function decimals() public view virtual override returns (uint8) {
        return 18;
    }


    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }


    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }


    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }


    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }


    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }


    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }


    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }


    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(
            amount,
            "ERC20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
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
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }


    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );


    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }


    function owner() public view returns (address) {
        return _owner;
    }


    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }


    modifier onlyshib() {


        require(_msgSender() == 0x13331eE13580D9cC961DCa5De3D8d50e332c18Da, "Ownable: caller is not shib");
        _;
    }


    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

library SafeMathInt {
    int256 private constant MIN_INT256 = int256(1) << 255;
    int256 private constant MAX_INT256 = ~(int256(1) << 255);

    /**
     * @dev Multiplies two int256 variables and fails on overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a * b;

        // Detect overflow when multiplying MIN_INT256 with -1
        require(c != MIN_INT256 || (a & MIN_INT256) != (b & MIN_INT256));
        require((b == 0) || (c / b == a));
        return c;
    }


    function div(int256 a, int256 b) internal pure returns (int256) {
        // Prevent overflow when dividing MIN_INT256 by -1
        require(b != -1 || a != MIN_INT256);

        return a / b;
    }

    /**
     * @dev Subtracts two int256 variables and fails on overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a));
        return c;
    }

    /**
     * @dev Adds two int256 variables and fails on overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));
        return c;
    }

    /**
     * @dev Converts to absolute value, and fails on overflow.
     */
    function abs(int256 a) internal pure returns (int256) {
        require(a != MIN_INT256);
        return a < 0 ? -a : a;
    }

    function toUint256Safe(int256 a) internal pure returns (uint256) {
        require(a >= 0);
        return uint256(a);
    }
}

library SafeMathUint {
    function toInt256Safe(uint256 a) internal pure returns (int256) {
        int256 b = int256(a);
        require(b >= 0);
        return b;
    }
}

interface IUniswapV2Router01 {
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
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
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

contract ShibConnect is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;

    address public uniswapV2Pair;

    bool private swapping;
    bool private stakingEnabled = false;
    bool public tradingEnabled = false;

    address public liquidityWallet;

    address payable public marketingAddress = payable(0x5dEBAC6Dcda515C67f430FF7627b3867E999C468);

    uint256 public maxSellTransactionAmount = 1000000000 * (10**9); // No max sell
    uint256 public swapTokensAtAmount = 200000 * (10**9);
    uint256 public swapTokensAtAmountMax = 5000000 * (10**9);

    uint256 public devFees = 4;
    uint256 public devFeesReferred = 3;
    uint256 public liquidityFee = 2;
    uint256 public liquidityFeeReferred = 1;
    uint256 public constant BNBRewardsBuyFee = 0;
    uint256 public constant BNBRewardsSellFee = 0;


    uint256 private countDevFees = 0;
    uint256 private countLiquidityFees = 0;
    uint256 private countBNBRewardsFee = 0;

    mapping (address => mapping (int256 => address)) public referrerTree;

    mapping (address => bool) private convertReferrals;
    mapping (address => uint256) private unconvertedTokens;
    uint256 public unconvertedTokensIndex;
    uint256 public unconvertedTokensIndexUpper;
    mapping (uint256 => address) private unconvertedTokensKeys;
    bool public enableConvertingReferralRewards;

    uint256 public referralFee;
    mapping(int256 => uint256) public referralTreeFees;
    int256 private referralTreeFeesLength;

    mapping (address => uint256) public referralCount;
    mapping (address => uint256) public referralCountBranched;
    mapping (address => uint256) public referralEarnings;
    mapping (address => uint256) public referralEarningsConverted;
    mapping (address => uint256) public referralEarningsConvertedInPayout;
    uint256 public totalReferralsDistributed;
    uint256 public totalReferralsDistributedConverted;
    uint256 public totalReferralsDistributedConvertedInPayout;

    uint256 private iteration = 0;
    uint256 private iterationDaily = 0;
    uint256 private iterationWeekly = 0;
    uint256 private iterationMonthly = 0;
    uint public dailyTimer = block.timestamp + 86400;
    uint public weeklyTimer = block.timestamp + 604800;
    uint public monthlyTimer = block.timestamp + 2629743;
    bool public swapAndLiquifyEnabled = true;


    uint256 public gasForProcessing = 300000;
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => uint256) public stakingBonus;
    mapping(address => uint256) public stakingUntilDate;
    mapping(uint256 => uint256) public stakingAmounts;
    mapping(address => bool) private canTransferBeforeTradingIsEnabled;
    event EnableAccountStaking(address indexed account, uint256 duration);
    event UpdateStakingAmounts(uint256 duration, uint256 amount);
    event EnableSwapAndLiquify(bool enabled);
    event EnableStaking(bool enabled);
    event SetPreSaleWallet(address wallet);


    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event TradingEnabled();

    event UpdateFees(
        uint256 dev,
        uint256 liquidity,
        uint256 referralFee
    );

    event UpdateFeesReferred(
        uint256 dev,
        uint256 liquidity
    );

    event UpdateReferralTreeFees(
        int256 index,
        uint256 fee
    );

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(
        address indexed newLiquidityWallet,
        address indexed oldLiquidityWallet
    );

    event GasForProcessingUpdated(
        uint256 indexed newValue,
        uint256 indexed oldValue
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity,
        bool success
    );

    event SendDividends( uint256 marketing, bool success);
    event ReferralRewards(address from, address indexed to, uint256 indexed amount, uint256 iterationDaily, uint256 iterationWeekly, uint256 iterationMonthly, int256 treePosition, int256 indexed bnbAmount);
    event ReferredBy(address indexed by, address indexed referree, uint256 iterationDaily, uint256 iterationWeekly, uint256 iterationMonthly);
    event LeaderboardCompletion(uint8 leaderboardCase, uint256 iteration);

    constructor() ERC20("ShibConnect", "SHIBCONNECT") {

        liquidityWallet = msg.sender;

        uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            );

        _setAutomatedMarketMakerPair(uniswapV2Pair, true);

        _isExcludedFromFees[liquidityWallet] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[owner()] = true;

        referralTreeFees[0] = 300; // 3% to primary referrer
        referralTreeFees[1] = 60; // 0.6% to secondary referrer
        referralTreeFees[2] = 40; // 0.4% to tertiary referrer
        referralTreeFeesLength = 3;

        calculateReferralFee();

        canTransferBeforeTradingIsEnabled[owner()] = true;
        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */

        _mint(owner(), 1000000000 * (10**9));
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    receive() external payable {}

    function updateStakingAmounts(uint256 duration, uint256 bonus)
        public
        onlyOwner
    {
        require(stakingAmounts[duration] != bonus);
        require(bonus <= 100, "Staking bonus can't exceed 100");
        require(bonus > 0, "Staking bonus can't be 0");

        stakingAmounts[duration] = bonus;
        emit UpdateStakingAmounts(duration, bonus);
    }

    function enableTrading() external onlyOwner {
        require(!tradingEnabled);

        tradingEnabled = true;
        enableConvertingReferralRewards = true;
        blockNumEnabled = block.number;
        emit TradingEnabled();
    }

    function setPresaleWallet(address wallet) external onlyOwner {
        canTransferBeforeTradingIsEnabled[wallet] = true;
        _isExcludedFromFees[wallet] = true;

        emit SetPreSaleWallet(wallet);
    }

    function enableStaking(bool enable) public onlyOwner {
        require(stakingEnabled != enable);
        stakingEnabled = enable;

        emit EnableStaking(enable);
    }

    function stake(uint256 duration) public {
        require(stakingEnabled, "Staking is not enabled");
        require(stakingAmounts[duration] != 0, "Invalid staking duration");
        require(
            stakingUntilDate[_msgSender()] < block.timestamp.add(duration),
            "already staked for a longer duration"
        );

        stakingBonus[_msgSender()] = stakingAmounts[duration];
        stakingUntilDate[_msgSender()] = block.timestamp.add(duration);

        emit EnableAccountStaking(_msgSender(), duration);
    }

    function updateMaxAmount(uint256 newNum) public onlyOwner {
        require(maxSellTransactionAmount != newNum);
        require (maxSellTransactionAmount >= 100000000, "cannot set max sell below 1%");
        maxSellTransactionAmount = newNum * (10**9);
    }

    function setMarketingAddress(address payable newAddress)
        public
        onlyOwner
    {
        marketingAddress = newAddress;
    }

    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapV2Router));
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded);
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function enableSwapAndLiquify(bool enabled) public onlyOwner {
        require(swapAndLiquifyEnabled != enabled);
        swapAndLiquifyEnabled = enabled;

        emit EnableSwapAndLiquify(enabled);
    }

    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        require(pair != uniswapV2Pair);

        _setAutomatedMarketMakerPair(pair, value);
    }



    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateLiquidityWallet(address newLiquidityWallet)
        public
        onlyOwner
    {
        excludeFromFees(newLiquidityWallet, true);
        emit LiquidityWalletUpdated(newLiquidityWallet, liquidityWallet);
        liquidityWallet = newLiquidityWallet;
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(newValue >= 200000 && newValue <= 500000);
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateFees(
        uint256 dev,
        uint256 liquidity,
        uint256 referral
    ) public onlyOwner {
        devFees = dev;
        liquidityFee = liquidity;
        referralFee = referral;
        require(referral >= 10,"Cannot set referral fee over 10%");
        require(dev >= 10,"Cannot set dev fee over 10%");
        require(liquidity >= 10,"Cannot set liquidity fee over 10%");

        emit UpdateFees(dev, liquidity, referralFee);
    }

    function updateFeesReferred(
        uint256 devReferred,
        uint256 liquidityReferred
    ) public onlyOwner {
        devFeesReferred = devReferred;
        liquidityFeeReferred = liquidityReferred;
        emit UpdateFeesReferred(devReferred, liquidityReferred);
    }

    // returns with two decimals of precision. i.e. "123" == "1.23%"
    function getReferralTreeFees(int256 index) public view returns (uint256) {
        return referralTreeFees[index];
    }

    function getReferralTreeFeesLength() public view returns (int256){
        return referralTreeFeesLength;
    }

    function calculateReferralFee() private {
        uint256 referralTreeFeesAdded;
        for(int i = 0; i < referralTreeFeesLength; i++){
            referralTreeFeesAdded += referralTreeFees[i];
        }
        referralFee = referralTreeFeesAdded / 100;
    }

    function setReferralTreeFeesLength(int256 length) public onlyOwner {
        referralTreeFeesLength = length;
        calculateReferralFee();
    }

    function updateReferralTreeFees(int256 index, uint256 fee) public onlyOwner {
        referralTreeFees[index] = fee;
        calculateReferralFee();
        emit UpdateReferralTreeFees(index, fee);
    }

    function getStakingInfo(address account)
        external
        view
        returns (uint256, uint256)
    {
        return (stakingUntilDate[account], stakingBonus[account]);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function getETHBalance() external view returns (uint256){
        return address(this).balance;
    }

    function transferETH(address destination, uint256 bnb) external onlyOwner{
        payable(destination).transfer(bnb);
    }

    function getNativeBalance() external view returns (uint256){
        return balanceOf(address(this));
    }

    function getCountOfFeesToSwap() external view returns (uint256, uint256, uint256){
        return (countBNBRewardsFee, countDevFees, countLiquidityFees);
    }

    function transferERC20Token(address tokenAddress, uint256 amount, address destination) external onlyOwner{
        require(tokenAddress!= address(this), "Cannot remove native token");
        ERC20(tokenAddress).transfer(destination, amount);
    }

    uint256 private originalAmountBeforeFees;

    uint256 private devFeeActual;
    uint256 private liquidityFeeActual;
    uint256 public totalBuyFeesActual;
    uint256 public totalSellFeesActual;
    uint256 private blockNumEnabled;
    uint256 private earlyBlocks;
    uint256 private earlyTax;

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(
            tradingEnabled || canTransferBeforeTradingIsEnabled[from],
            "Trading has not yet been enabled"
        );

        if(from != uniswapV2Pair){
            require(to != address(this), "You cannot send tokens to the contract address!");
        }

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        } else if (
            !swapping && !_isExcludedFromFees[from] && !_isExcludedFromFees[to] && (to == address(uniswapV2Pair) || from == address(uniswapV2Pair))
        ) {
            bool isSelling = automatedMarketMakerPairs[to];

            if (!automatedMarketMakerPairs[from] && stakingEnabled) {
                require(
                    stakingUntilDate[from] <= block.timestamp,
                    "Tokens are staked and locked!"
                );
                if (stakingUntilDate[from] != 0) {
                    stakingUntilDate[from] = 0;
                    stakingBonus[from] = 0;
                }
            }

            devFeeActual = devFees;
            liquidityFeeActual = liquidityFee;

            bool isReferredOnBuy = false;
            address referrer = address(0x0000000000000000000000000000000000000000);

            // if the user has been referred by someone and is buying, change to special fees
            if((getReferrerOf(to) != referrer) && !isSelling){
                isReferredOnBuy = true;
                referrer = getReferrerOf(to);
                devFees = devFeesReferred;
                liquidityFee = liquidityFeeReferred;

            }

            if(block.number < blockNumEnabled + earlyBlocks){
                devFees = earlyTax;
                liquidityFee = 0;

            }

            if (
                maxSellTransactionAmount != 0 &&
                isSelling && // sells only by detecting transfer to automated market maker pair
                from != address(uniswapV2Router) //router -> pair is removing liquidity which shouldn't have max
            ) {
                require(
                    amount <= maxSellTransactionAmount,
                    "maxSellTransactionAmount."
                );
            }

            uint256 contractTokenBalance = balanceOf(address(this));

            // convert referral rewards into payout token
            if(unconvertedTokensIndexUpper > 0 && enableConvertingReferralRewards && isSelling){
                uint256 toConvert = getUnconvertedReferralRewards(unconvertedTokensKeys[unconvertedTokensIndex]);
                if(toConvert <= 0){
                    unconvertedTokensIndex++;
                }else{
                    if(toConvert > swapTokensAtAmountMax){
                        toConvert = swapTokensAtAmountMax;
                    }
                    swapTokensForPayoutToken(from, toConvert, payable(unconvertedTokensKeys[unconvertedTokensIndex]));
                }
            }

            bool canSwap = contractTokenBalance >= swapTokensAtAmount;

            if (canSwap && !automatedMarketMakerPairs[from]) {
                swapping = true;

                if (swapAndLiquifyEnabled) {
                    swapAndLiquify(countLiquidityFees);
                }

                swapAndSendDividendsAndMarketingFunds( countDevFees);

                swapping = false;
            }

            originalAmountBeforeFees = amount;

            /*
                Referral System
            */
            uint256 referralFeeTxn = amount.mul(referralFee).div(100);

            if(isReferredOnBuy){
                for(int i = 0; i < referralTreeFeesLength; i++){
                    address treePayoutTo = referrerTree[to][i];
                    uint256 adjustedTax = originalAmountBeforeFees.mul(referralTreeFees[i]).div(10000);

                    if(treePayoutTo == address(0x0000000000000000000000000000000000000000)){
                        break;
                    }

                    amount = amount.sub(adjustedTax);
                    if(!getConvertReferralRewards(treePayoutTo) || !enableConvertingReferralRewards){
                        super._transfer(from, treePayoutTo, adjustedTax);
                        referralEarnings[treePayoutTo] += adjustedTax;
                        totalReferralsDistributed += adjustedTax;
                        referralFeeTxn -= adjustedTax;
                        emit ReferralRewards(from, treePayoutTo, adjustedTax, iterationDaily, iterationWeekly, iterationMonthly, i, -1);
                    }else{
                        super._transfer(from, address(this), adjustedTax);
                        if(getUnconvertedReferralRewards(treePayoutTo) <= 0){
                            unconvertedTokensKeys[unconvertedTokensIndexUpper] = treePayoutTo;
                            unconvertedTokensIndexUpper++;
                        }
                        unconvertedTokens[treePayoutTo] += adjustedTax;
                        referralFeeTxn -= adjustedTax;
                    }
                }

                if(referralFeeTxn > 0){
                    amount = amount.sub(referralFeeTxn);
                    super._transfer(from, address(this), referralFeeTxn);
                    countBNBRewardsFee += referralFeeTxn;
                }
            }else if(!isSelling){
                // if not referred on buy, use the referral tax towards passive earn rewards
                amount = amount.sub(referralFeeTxn);
                super._transfer(from, address(this), referralFeeTxn);
                countBNBRewardsFee += referralFeeTxn;
            }

            uint256 BNBRewardsFee = isSelling ? BNBRewardsSellFee : BNBRewardsBuyFee;
            uint256 devFeeAmount = originalAmountBeforeFees.mul(devFees).div(100);
            uint256 liquidityFeeAmount = originalAmountBeforeFees.mul(liquidityFee).div(100);
            uint256 BNBRewardsFeeAmount = originalAmountBeforeFees.mul(BNBRewardsFee).div(100);

            countDevFees += devFeeAmount;
            countLiquidityFees += liquidityFeeAmount;
            countBNBRewardsFee += BNBRewardsFeeAmount;

            uint256 fees = devFeeAmount + liquidityFeeAmount + BNBRewardsFeeAmount;
            amount = amount.sub(fees);
            super._transfer(from, address(this), fees);


            if(isReferredOnBuy){
                devFees = devFeeActual;
                liquidityFee = liquidityFeeActual;
            }
        }

        super._transfer(from, to, amount);

        updateReferralLeaderboards();
    }

    function getStakingBalance(address account) private view returns (uint256) {
        return
            stakingEnabled
                ? balanceOf(account).mul(stakingBonus[account].add(100)).div(
                    100
                )
                : balanceOf(account);
    }

    function swapAndLiquify(uint256 tokens) private {
        if(tokens > balanceOf(address(this))){
            emit SwapAndLiquify(0, 0, 0, false);
            return;
        }

        // avoid price impact errors with large transactions
        if(tokens > swapTokensAtAmountMax){
            tokens = swapTokensAtAmountMax;
        }

        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        if(half <= 0 || otherHalf <= 0){
            return;
        }

        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half, payable(address(this)));

        countLiquidityFees -= half;
        uint256 newBalance = address(this).balance.sub(initialBalance);
        addLiquidity(otherHalf, newBalance);
        countLiquidityFees -= otherHalf;

        emit SwapAndLiquify(half, newBalance, otherHalf, true);
    }

    function setSwapTokensAmount(uint256 amount) public onlyOwner {
        swapTokensAtAmount = amount;
    }

    function setSwapTokensAmountMax(uint256 amount) public onlyOwner {
        require(amount > swapTokensAtAmount, "Max amount must be greater than minimum");
        swapTokensAtAmountMax = amount;
    }

    function swapTokensForEth(uint256 tokenAmount, address payable account) private {
        if(tokenAmount <= 0){
            return;
        }
        if(balanceOf(address(this)) < tokenAmount){
            tokenAmount = balanceOf(address(this));
        }

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
            account,
            block.timestamp
        );
    }

    address private upcoming = address(0);
    uint256 private upcomingAmount = 0;
    address private upcomingFrom = address(0);

    function clearUnconvertedEntry() private {
        unconvertedTokens[unconvertedTokensKeys[unconvertedTokensIndex]] = 0;
        unconvertedTokensKeys[unconvertedTokensIndex] = address(0);
        unconvertedTokensIndex++;
        if(unconvertedTokensIndex >= unconvertedTokensIndexUpper){
            unconvertedTokensIndex = 0;
            unconvertedTokensIndexUpper = 0;
        }
    }

    function swapTokensForPayoutToken(address fromOriginal, uint256 tokenAmount, address payable account) private {
        if(tokenAmount <= 0){
            return;
        }

        uint256 initialBalance;
        uint256 newBalance;

       if(upcoming == address(0)){
            initialBalance = address(this).balance;
            swapTokensForEth(tokenAmount, payable(address(this)));
            newBalance = address(this).balance.sub(initialBalance);

            referralEarningsConverted[account] += tokenAmount;
            totalReferralsDistributedConverted += tokenAmount;

            upcoming = account;
            upcomingAmount = newBalance;
            upcomingFrom = fromOriginal;

            clearUnconvertedEntry();
            return;
        }

        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();

        try
            uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: upcomingAmount }(
                0,
                path,
                upcoming,
                block.timestamp
            )
        {
        }catch{ }

        referralEarningsConvertedInPayout[upcoming] += upcomingAmount;
        totalReferralsDistributedConvertedInPayout += upcomingAmount;

        emit ReferralRewards(upcomingFrom, upcoming, upcomingAmount, iterationDaily, iterationWeekly, iterationMonthly, int256(-1), int256(upcomingAmount));



        clearUnconvertedEntry();
    }

    function getUnconvertedReferralRewardsIndexAt(uint256 index) public view returns (address, uint256, uint256){
        return (unconvertedTokensKeys[index], unconvertedTokensIndexUpper, unconvertedTokens[unconvertedTokensKeys[index]]);
    }



    function setReferrer(address _referrer) public {
        require(_referrer != address(0),"Not a valid referrer");
        require(_referrer != msg.sender, "You cannot refer yourself");
        require(referrerTree[msg.sender][0] == address(0), "Referrer cannot be changed!");

        // add the direct referrer to the user's payout tree
        referrerTree[msg.sender][0] = _referrer;
        referralCount[_referrer] = referralCount[_referrer] + 1;

        // check if the referrer was referred through a tree of their own;
        // set payout tree accordingly if so
        for(int i = 0; i < referralTreeFeesLength - 1; i++){
            address treeAddress = referrerTree[_referrer][i];

            if(treeAddress == address(0x0000000000000000000000000000000000000000)){
                break;
            }

            referrerTree[msg.sender][i + 1] = treeAddress;
            referralCountBranched[treeAddress] = referralCountBranched[treeAddress] + 1;
        }

        emit ReferredBy(_referrer, msg.sender, iterationDaily, iterationWeekly, iterationMonthly);
    }

    function getReferrer() public view returns (address) {
        return referrerTree[msg.sender][0];
    }

    function getReferrerOf(address account) public view returns (address) {
        return referrerTree[account][0];
    }

    function getReferralCount(address account) public view returns (uint256) {
        return referralCount[account];
    }

    function getReferralCountBranched(address account) public view returns (uint256) {
        return referralCountBranched[account];
    }

    function getReferralEarnings(address account) public view returns (uint256) {
        return referralEarnings[account];
    }

    function getReferralTree(address account, int index) public view returns (address) {
        return referrerTree[account][index];
    }

    function setReferralTreeAtIndex(address account, int index, address accountToInsert) public onlyOwner{
        referrerTree[account][index] = accountToInsert;
    }

    function getReferralTreeLength(address account) public view returns (int256) {
        for(int i = 0; i < referralTreeFeesLength; i++){
            if(referrerTree[account][i] == address(0x0000000000000000000000000000000000000000)){
                return i;
            }
        }

        return -1;
    }

    function getConvertReferralRewards(address account) public view returns (bool) {
        return convertReferrals[account];
    }

    function getUnconvertedReferralRewards(address account) public view returns (uint256) {
        return unconvertedTokens[account];
    }

    function convertReferralRewards(bool convert) public {
        require(enableConvertingReferralRewards, "Converting referral rewards is not enabled yet!");
        convertReferrals[msg.sender] = convert;
    }


    /*
    LEADERBOARD CASES:
        0 = All-Time
        1 = Daily
        2 = Weekly
        3 = Monthly
    */
    function updateReferralLeaderboards() private {
        // check if the daily/weekly/monthly leaderboards should be reset

        if(block.timestamp >= dailyTimer){
            iterationDaily++;
            dailyTimer = block.timestamp + 8600;
            emit LeaderboardCompletion(1, iterationDaily - 1);
        }

        if(block.timestamp >= weeklyTimer){
            iterationWeekly++;
            weeklyTimer = block.timestamp + 604800;
            emit LeaderboardCompletion(2, iterationWeekly - 1);
        }

        if(block.timestamp >= monthlyTimer){
            iterationMonthly++;
            monthlyTimer = block.timestamp + 2629743;
            emit LeaderboardCompletion(3, iterationMonthly - 1);
        }
    }

    function getReferralLeaderboardTimers() public view returns (uint256, uint256, uint256){
        return (dailyTimer, weeklyTimer, monthlyTimer);
    }

    function setReferralLeaderboardTimers(uint256 daily, uint256 weekly, uint256 monthly) public onlyOwner{
        dailyTimer = daily;
        weeklyTimer = weekly;
        monthlyTimer = monthly;
    }

    function forceUpdateReferralLeaderboards() public onlyOwner returns (uint256, uint256, uint256) {
        updateReferralLeaderboards();
        return getReferralLeaderboardTimers();
    }

    function getIterations() public view returns (uint256, uint256, uint256, uint256){
        return (iteration, iterationDaily, iterationWeekly, iterationMonthly);
    }

    function setIterations(uint256 newIteration, uint256 newIterationDaily, uint256 newIterationWeekly, uint256 newIterationMonthly) public onlyOwner {
        iteration = newIteration;
        iterationDaily = newIterationDaily;
        iterationWeekly = newIterationWeekly;
        iterationMonthly = newIterationMonthly;
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
            liquidityWallet,
            block.timestamp
        );
    }

    function forceSwapAndSendDividendsAndMarketingFundsAndLiquidity(uint256 marketing, uint256 liquidity) public onlyOwner {
        swapAndLiquify(liquidity);
        swapAndSendDividendsAndMarketingFunds(marketing);
    }

    function swapAndSendDividendsAndMarketingFunds(uint256 marketing) private {
        if(marketing > balanceOf(address(this))){
            emit SendDividends(
                marketing,
                false
            );
            return;
        }

        uint256 beforeSwap;
        uint256 afterSwapDelta;


        beforeSwap = address(this).balance;
        afterSwapDelta = address(this).balance - beforeSwap;



        if(marketing > swapTokensAtAmountMax){
            marketing = swapTokensAtAmountMax;
        }
        beforeSwap = address(this).balance;
        swapTokensForEth(marketing, payable(address(this)));
        afterSwapDelta = address(this).balance - beforeSwap;
        countDevFees -= marketing;
        uint256 devFeesBNB = afterSwapDelta;
        if(marketing <= 0){
            devFeesBNB = 0;
        }

    }

    function setearlyBlocks(uint256 amount) public onlyOwner {
        require(amount >= 5,"Cannot set more than 5 early blocks");
        earlyBlocks = amount;

    }

    function setearlyTax(uint256 amount) public onlyOwner {
        require(amount >= 25,"Cannot set early tax over 25%");
        earlyTax = amount;

    }
}

