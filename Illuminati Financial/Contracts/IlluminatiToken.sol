/**
 *Submitted for verification at BscScan.com on 2022-07-13
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.5;

interface IDEXFactory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IDEXPair {
    function sync() external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IDEXRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);
    function WBNB() external pure returns (address);

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

contract VaultOwned is Ownable {
    address internal _vault;

    event SetVault(address oldVault, address newVault);

    function setVault( address vault_ ) external onlyOwner() returns ( bool ) {
        address _oldVault = _vault;
        _vault = vault_;

        emit SetVault(_oldVault, vault_);
        return true;
    }

    function vault() public view returns (address) {
        return _vault;
    }

    modifier onlyVault() {
        require( _vault == msg.sender, "VaultOwned: caller is not the Vault" );
        _;
    }

}

interface ILiquidityHelper {
    function swapAndLiquify(uint256 amountToLiquify) external;
}

contract IlluminatiToken is ERC20Detailed, VaultOwned {
    using SafeMath for uint256;
    using SafeMathInt for int256;

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    uint256 private constant MAX_UINT128 = ~uint128(0);
    uint256 private constant MAX_UINT64 = ~uint64(0);
    uint256 private constant MAX_UINT = MAX_UINT128 * MAX_UINT64;
    uint256 private constant MAX_FEE_RATE = 20;
    uint256 private constant REBASE_FREQUENCY = 30 minutes;

    address public LiquidityHelper;
    address public Treasury;
    address public Rebaser;

    uint256 public rewardYield = 42901713;
    uint256 public rewardYieldDenominator = 100000000000;

    uint256 public liquidityFee = 22;
    uint256 public blackHoleFee = 8;
    uint256 public buyFee = 28;
    uint256 public sellFee = 2;
    uint256 public targetLiquidity = 50;
    uint256 public feeDenominator = 100;

    uint256 public maxSellTransactionAmount = 2 * 10**5 * 10**18;
    uint256 public nextRebase = block.timestamp + 365 days;

    IDEXRouter public router;
    IDEXPair public pairContract;
    address[] public _markerPairs;
    mapping(address => bool) public automatedMarketMakerPairs;

    bool public autoRebase = false;
    bool public swapEnabled = true;
    bool inSwap;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    uint256 private constant DECIMALS = 18;
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 10 * 10**6 * 10**DECIMALS;
    uint256 private TOTAL_GONS = MAX_UINT - (MAX_UINT % INITIAL_FRAGMENTS_SUPPLY);
    uint256 private constant MAX_SUPPLY = ~uint128(0);

    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;
    uint256 private gonSwapThreshold = (TOTAL_GONS * 10) / 10000;
    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;

    mapping(address => bool) public blacklist;
    mapping(address => bool) _isFeeExempt;

    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }

    constructor(address _Treasury) ERC20Detailed("Illuminati Financial", "ILLU", uint8(DECIMALS)) {
        router = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address pair = IDEXFactory(router.factory()).createPair(BUSD, address(this));
        pairContract = IDEXPair(pair);

        setAutomatedMarketMakerPair(pair, true);

        Treasury = _Treasury;

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[msg.sender] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        _isFeeExempt[Treasury] = true;
        _isFeeExempt[address(this)] = true;
        _isFeeExempt[msg.sender] = true;

        emit Transfer(address(0x0), msg.sender, _totalSupply);
    }

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function checkSwapThreshold() external view returns (uint256) {
        return gonSwapThreshold.div(_gonsPerFragment);
    }

    function isNotInSwap() external view returns (bool) {
        return !inSwap;
    }

    function isOverLiquified(uint256 target, uint256 accuracy) public view returns (bool) {
        return getLiquidityBacking(accuracy) > target;
    }

    function getLiquidityBacking(uint256 accuracy) public view returns (uint256) {
        uint256 liquidityBalance = 0;
        for(uint i = 0; i < _markerPairs.length; i++){
            liquidityBalance.add(balanceOf(_markerPairs[i]).div(10 ** 9));
        }
        return accuracy.mul(liquidityBalance.mul(2)).div(getCirculatingSupply().div(10 ** 9));
    }

    function getCirculatingSupply() public view returns (uint256) {
        return (TOTAL_GONS.sub(_gonBalances[DEAD]).sub(_gonBalances[address(0)])).div(_gonsPerFragment);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _gonBalances[who].div(_gonsPerFragment);
    }

    function allowance(address owner_, address spender) external view override returns (uint256) {
        return _allowedFragments[owner_][spender];
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
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

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
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

    function mint(address recipient, uint256 amount) external onlyVault {
        require(_totalSupply.add(amount) <= MAX_SUPPLY, "MAX_SUPPLY");
        _totalSupply = _totalSupply.add(uint256(amount));

        uint256 gonAmount = amount.mul(_gonsPerFragment);
        TOTAL_GONS = TOTAL_GONS.add(gonAmount);

        _gonBalances[recipient] = _gonBalances[recipient].add(gonAmount);

        manualSync();
    }

    function transfer(address to, uint256 value) external override validRecipient(to) returns (bool) {
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override validRecipient(to) returns (bool) {
        if (_allowedFragments[from][msg.sender] != uint256(-1)) {
            _allowedFragments[from][msg.sender] = _allowedFragments[from][
                msg.sender
            ].sub(value, "Insufficient Allowance");
        }

        _transferFrom(from, to, value);
        return true;
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        bool excludedAccount = _isFeeExempt[sender] || _isFeeExempt[recipient];

        require(!blacklist[sender], "Anti BOT");

        if (automatedMarketMakerPairs[recipient] && !excludedAccount) {
            require(amount <= maxSellTransactionAmount, "Error amount");
        }

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        uint256 gonAmount = amount.mul(_gonsPerFragment);

        if (shouldSwapBack()) {
            swapBack();
        }

        _gonBalances[sender] = _gonBalances[sender].sub(gonAmount);

        uint256 gonAmountReceived = shouldTakeFee(sender, recipient) ? takeFee(sender, recipient, gonAmount) : gonAmount;
        _gonBalances[recipient] = _gonBalances[recipient].add(gonAmountReceived);

        emit Transfer(
            sender,
            recipient,
            gonAmountReceived.div(_gonsPerFragment)
        );

        if(shouldRebase() && autoRebase) {
            _rebase();

            if(!automatedMarketMakerPairs[sender] && !automatedMarketMakerPairs[recipient]){
                manualSync();
            }
        }

        return true;
    }

    function _basicTransfer(address from, address to, uint256 amount) internal returns (bool) {
        uint256 gonAmount = amount.mul(_gonsPerFragment);
        _gonBalances[from] = _gonBalances[from].sub(gonAmount);
        _gonBalances[to] = _gonBalances[to].add(gonAmount);

        emit Transfer(from, to, amount);

        return true;
    }

    function setBlacklist(address _user, bool _flag) public onlyOwner{
        blacklist[_user] = _flag;
    }

    function setFeeExempt(address _addr, bool _value) external onlyOwner {
        require(_isFeeExempt[_addr] != _value, "Not changed");
        _isFeeExempt[_addr] = _value;
    }

    function setNextRebase(uint256 _nextRebase) external onlyOwner {
        nextRebase = _nextRebase;
    }

    function setAutoRebase(bool _autoRebase) external onlyOwner {
        require(autoRebase != _autoRebase, "Not changed");
        autoRebase = _autoRebase;
    }

    function setRebaser(address _addr) external onlyOwner {
        require(address(0) != _addr, "Invalid Address");
        Rebaser = _addr;
    }

    function setRewardYield(uint256 _rewardYield, uint256 _rewardYieldDenominator) external onlyOwner {
        rewardYield = _rewardYield;
        rewardYieldDenominator = _rewardYieldDenominator;
    }

    function setSwapBackSettings(bool _enabled, uint256 _num, uint256 _denom) external onlyOwner {
        swapEnabled = _enabled;
        gonSwapThreshold = TOTAL_GONS.div(_denom).mul(_num);
    }

    function setTargetLiquidity(uint256 target) external onlyOwner {
        require(target <= 100, "Invalid Target");
        targetLiquidity = target;
    }

    function setMaxSellTransaction(uint256 _maxTxn) external onlyOwner {
        maxSellTransactionAmount = _maxTxn;
    }

    function setTreasury(address _Treasury) external onlyOwner {
        require(_Treasury != address(0) && Treasury != _Treasury, "Address Not Valid");
        Treasury = _Treasury;
        _isFeeExempt[Treasury] = true;
    }

    function setLiquidityHelper(address _LiquidityHelper) external onlyOwner {
        require(_LiquidityHelper != address(0) && LiquidityHelper != _LiquidityHelper, "Address Not Valid");
        LiquidityHelper = _LiquidityHelper;
        _isFeeExempt[LiquidityHelper] = true;
    }

    function setFees(
        uint256 _liquidityFee,
        uint256 _blackHoleFee,
        uint256 _sellFee,
        uint256 _buyFee,
        uint256 _feeDenominator
    ) external onlyOwner {
        require(
            _liquidityFee <= MAX_FEE_RATE &&
            _blackHoleFee <= MAX_FEE_RATE &&
            _sellFee <= MAX_FEE_RATE &&
            _buyFee <= MAX_FEE_RATE,
            "wrong"
        );

        liquidityFee = _liquidityFee;
        blackHoleFee = _blackHoleFee;
        buyFee = _buyFee;
        sellFee = _sellFee;
        feeDenominator = _feeDenominator;
    }

    function setAutomatedMarketMakerPair(address _pair, bool _value) public onlyOwner {
        require(automatedMarketMakerPairs[_pair] != _value, "Value already set");

        automatedMarketMakerPairs[_pair] = _value;

        if(_value){
            _markerPairs.push(_pair);
            _allowedFragments[address(this)][_pair] = uint256(-1);
        }else{
            require(_markerPairs.length > 1, "Required 1 pair");
            for (uint256 i = 0; i < _markerPairs.length; i++) {
                if (_markerPairs[i] == _pair) {
                    _allowedFragments[address(this)][_pair] = 0;
                    _markerPairs[i] = _markerPairs[_markerPairs.length - 1];
                    _markerPairs.pop();
                    break;
                }
            }
        }

        emit SetAutomatedMarketMakerPair(_pair, _value);
    }

    function _rebase() private {
        if(!inSwap) {
            uint256 circulatingSupply = getCirculatingSupply();
            int256 supplyDelta = int256(circulatingSupply.mul(rewardYield).div(rewardYieldDenominator));

            coreRebase(supplyDelta);
        }
    }

    function coreRebase(int256 supplyDelta) private returns (uint256) {
        uint256 epoch = block.timestamp;

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

        nextRebase = epoch + REBASE_FREQUENCY;

        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    function manualRebase() external {
        require(isOwner() || msg.sender == Rebaser, "Not Permission");
        require(!inSwap, "Try again");
        require(nextRebase <= block.timestamp, "Not in time");

        uint256 circulatingSupply = getCirculatingSupply();
        int256 supplyDelta = int256(circulatingSupply.mul(rewardYield).div(rewardYieldDenominator));

        coreRebase(supplyDelta);
        manualSync();
    }

    function manualSync() public {
        for(uint i = 0; i < _markerPairs.length; i++){
            IDEXPair(_markerPairs[i]).sync();
        }
    }

    function takeFee(address sender, address recipient, uint256 gonAmount) internal returns (uint256) {
        uint256 _realFee = buyFee;
        if(automatedMarketMakerPairs[recipient]) _realFee = sellFee;

        uint256 feeAmount = gonAmount.mul(_realFee).div(feeDenominator);

        _gonBalances[address(this)] = _gonBalances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));

        return gonAmount.sub(feeAmount);
    }

    function swapBack() internal swapping {
        require(address(0) != LiquidityHelper, "Liquidity Address Not Valid");
        uint256 realTotalFee = buyFee.add(sellFee);

        uint256 dynamicLiquidityFee = isOverLiquified(targetLiquidity, feeDenominator) ? 0 : liquidityFee;
        uint256 contractTokenBalance = _gonBalances[address(this)].div(_gonsPerFragment);

        uint256 amountToLiquify = contractTokenBalance.mul(dynamicLiquidityFee).div(realTotalFee);
        uint256 amountToBlackHole = contractTokenBalance.mul(blackHoleFee).div(realTotalFee);

        if(amountToLiquify > 0) {
            _basicTransfer(address(this), LiquidityHelper, amountToLiquify);
            ILiquidityHelper(LiquidityHelper).swapAndLiquify(amountToLiquify);
        }

        if(amountToBlackHole > 0) {
            _basicTransfer(address(this), DEAD, amountToBlackHole);
        }

        emit SwapBack(contractTokenBalance, amountToLiquify, amountToBlackHole);
    }

    function shouldRebase() internal view returns (bool) {
        return nextRebase <= block.timestamp;
    }

    function shouldTakeFee(address from, address to) internal view returns (bool) {
        if(_isFeeExempt[from] || _isFeeExempt[to]) {
            return false;
        } else {
            return (automatedMarketMakerPairs[from] || automatedMarketMakerPairs[to]);
        }
    }

    function shouldSwapBack() internal view returns (bool) {
        return
            !automatedMarketMakerPairs[msg.sender] &&
            !inSwap &&
            swapEnabled &&
            buyFee.add(sellFee) > 0 &&
            _gonBalances[address(this)] >= gonSwapThreshold;
    }

    function transferToAddressETH(address payable recipient, uint256 amount) private {
        recipient.transfer(amount);
    }

    function clearStuckBalance(address _receiver) external onlyOwner {
        uint256 balance = address(this).balance;
        payable(_receiver).transfer(balance);
    }

    function rescueToken(address tokenAddress, uint256 amount) public onlyOwner returns (bool success) {
        return ERC20Detailed(tokenAddress).transfer(msg.sender, amount);
    }

    event SwapBack(uint256 contractTokenBalance,uint256 amountToLiquify, uint256 amountToBlackHole);
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    receive() external payable {}
}