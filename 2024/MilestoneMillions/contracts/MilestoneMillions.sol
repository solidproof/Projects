// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

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
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address UNISWAP_V2_PAIR);
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

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

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
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(
        address to
    ) external returns (uint256 amount0, uint256 amount1);

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

contract MilestoneMillions is IERC20, Ownable {
    using SafeMath for uint256;
    /* -------------------------------------------------------------------------- */
    /*                                   events                                   */
    /* -------------------------------------------------------------------------- */
    event Reflect(uint256 amountReflected, uint256 newTotalProportion);

    /* -------------------------------------------------------------------------- */
    /*                                  constants                                 */
    /* -------------------------------------------------------------------------- */
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = 0x0000000000000000000000000000000000000000;

    /* -------------------------------------------------------------------------- */
    /*                                   states                                   */
    /* -------------------------------------------------------------------------- */
    IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
        IUniswapV2Router02(0xeeabd314e2eE640B1aca3B27808972B05c7f6A3b);
    address public immutable UNISWAP_V2_PAIR;

    struct Fee {
        uint8 reflection;
        uint8 operation;
        uint8 lp;
        uint8 buyback;
        uint8 burn;
        uint128 total;
    }

    string _name = "MilestoneMillions";
    string _symbol = "MSMIL";

    uint256 _totalSupply = 500000000 ether;
    uint256 public _maxTxAmount = (_totalSupply * 1) / 100;
    uint256 public _maxWalletAmount = (_totalSupply * 1) / 100;

    /* rOwned = ratio of tokens owned relative to circulating supply (NOT total supply, since circulating <= total) */
    mapping(address => uint256) public _rOwned;
    uint256 public _totalProportion = _totalSupply;

    mapping(address => mapping(address => uint256)) _allowances;

    bool public tradingEnabled = false;
    bool public limitsEnabled = true;
    mapping(address => bool) isFeeExempt;
    mapping(address => bool) isTxLimitExempt;

    Fee public buyFee =
        Fee({
            reflection: 2,
            operation: 2,
            lp: 1,
            buyback: 0,
            burn: 0,
            total: 5
        });
    Fee public sellFee =
        Fee({
            reflection: 4,
            operation: 5,
            lp: 1,
            buyback: 0,
            burn: 0,
            total: 10
        });

    address private operationTaxReceiver;
    address private autoLPReceiver;
    address private buybackFeeReceiver;

    bool public claimingFees = true;
    uint256 public swapThreshold = (_totalSupply * 1) / 1000;
    bool inSwap;
    /* -------------------------------------------------------------------------- */
    /*                                  modifiers                                 */
    /* -------------------------------------------------------------------------- */
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 constructor                                */
    /* -------------------------------------------------------------------------- */
    constructor() {
        // create uniswap pair
        address _uniswapPair = IUniswapV2Factory(UNISWAP_V2_ROUTER.factory())
            .createPair(address(this), UNISWAP_V2_ROUTER.WETH());
        UNISWAP_V2_PAIR = _uniswapPair;

        _allowances[address(this)][address(UNISWAP_V2_ROUTER)] = type(uint256)
            .max;
        _allowances[address(this)][tx.origin] = type(uint256).max;

        isTxLimitExempt[address(this)] = true;
        isTxLimitExempt[address(UNISWAP_V2_ROUTER)] = true;
        isTxLimitExempt[_uniswapPair] = true;
        isTxLimitExempt[tx.origin] = true;
        isFeeExempt[tx.origin] = true;

        operationTaxReceiver = msg.sender;
        autoLPReceiver = msg.sender;
        buybackFeeReceiver = msg.sender;

        _rOwned[tx.origin] = _totalSupply;
        emit Transfer(address(0), tx.origin, _totalSupply);
    }

    receive() external payable {}

    /* -------------------------------------------------------------------------- */
    /*                                    ERC20                                   */
    /* -------------------------------------------------------------------------- */
    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            require(
                _allowances[sender][msg.sender] >= amount,
                "ERC20: insufficient allowance"
            );
            _allowances[sender][msg.sender] =
                _allowances[sender][msg.sender] -
                amount;
        }

        return _transferFrom(sender, recipient, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    views                                   */
    /* -------------------------------------------------------------------------- */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function allowance(
        address holder,
        address spender
    ) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function tokensToProportion(uint256 tokens) public view returns (uint256) {
        return (tokens * _totalProportion) / _totalSupply;
    }

    function tokenFromReflection(
        uint256 proportion
    ) public view returns (uint256) {
        return (proportion * _totalSupply) / _totalProportion;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply - balanceOf(DEAD) - balanceOf(ZERO);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   owners                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev removes limits on tx and wallet amounts
    function removeLimits() external onlyOwner {
        _maxTxAmount = _totalSupply;
        _maxWalletAmount = _totalSupply;
        limitsEnabled = false;
    }

    function openTrading() external onlyOwner {
        tradingEnabled = true;
    }

    /// @dev set the fee receivers
    function setFeeReceivers(
        address _operationTaxReceiver,
        address _autoLPReceiver,
        address _buybackFeeReceiver
    ) external onlyOwner {
        operationTaxReceiver = _operationTaxReceiver;
        autoLPReceiver = _autoLPReceiver;
        buybackFeeReceiver = _buybackFeeReceiver;
    }

    /// @dev set the max tx amount
    function setMaxTxAmount(uint256 amount) external onlyOwner {
        require(amount >= 10, "_maxTxAmount cannot be less than 1%");
        _maxTxAmount = (amount * _totalSupply) / 1000;
    }

    /// @dev set the max wallet amount
    function setMaxWalletAmount(uint256 amount) external onlyOwner {
        require(amount >= 10, "_maxWalletAmount cannot be less than 1%");
        _maxWalletAmount = (amount * _totalSupply) / 1000;
    }

    /// @dev set the buy tax
    function setBuyTaxes(
        uint8 reflection,
        uint8 operation,
        uint8 lp,
        uint8 buyback,
        uint8 burn
    ) external onlyOwner {
        buyFee = Fee({
            reflection: reflection,
            operation: operation,
            lp: lp,
            buyback: buyback,
            burn: burn,
            total: reflection + operation + lp + buyback + burn
        });
        require(buyFee.total <= 10, "Buy fee too high");
    }

    /// @dev set the sell tax
    function setSellTaxes(
        uint8 reflection,
        uint8 operation,
        uint8 lp,
        uint8 buyback,
        uint8 burn
    ) external onlyOwner {
        sellFee = Fee({
            reflection: reflection,
            operation: operation,
            lp: lp,
            buyback: buyback,
            burn: burn,
            total: reflection + operation + lp + buyback + burn
        });
        require(sellFee.total <= 10, "Sell fee too high");
    }

    /// @dev set an address as exempt from fees
    function setFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }

    /// @dev set an address as exempt from tx limits
    function setTxLimitExempt(address holder, bool exempt) external onlyOwner {
        isTxLimitExempt[holder] = exempt;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   private                                  */
    /* -------------------------------------------------------------------------- */
    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        if (
            limitsEnabled &&
            !isTxLimitExempt[sender] &&
            !isTxLimitExempt[recipient]
        ) {
            if (!tradingEnabled) {
                require(
                    isFeeExempt[sender] || isFeeExempt[recipient],
                    "Trading is not active."
                );
            }
            require(
                amount <= _maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
        }

        if (_shouldSwapBack()) {
            _swapBack();
        }

        uint256 proportionAmount = tokensToProportion(amount);
        require(_rOwned[sender] >= proportionAmount, "Insufficient Balance");
        _rOwned[sender] = _rOwned[sender] - proportionAmount;

        uint256 proportionReceived = _shouldTakeFee(sender, recipient)
            ? _takeFeeInProportions(
                sender == UNISWAP_V2_PAIR ? true : false,
                sender,
                proportionAmount
            )
            : proportionAmount;
        _rOwned[recipient] = _rOwned[recipient] + proportionReceived;
        if (
            limitsEnabled &&
            !isTxLimitExempt[recipient] &&
            recipient != UNISWAP_V2_PAIR
        ) {
            require(
                _rOwned[recipient] <= tokensToProportion(_maxWalletAmount),
                "Wallet amount exceeds the maxWalletAmount."
            );
        }

        emit Transfer(
            sender,
            recipient,
            tokenFromReflection(proportionReceived)
        );
        return true;
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        uint256 proportionAmount = tokensToProportion(amount);
        require(_rOwned[sender] >= proportionAmount, "Insufficient Balance");
        _rOwned[sender] = _rOwned[sender] - proportionAmount;
        _rOwned[recipient] = _rOwned[recipient] + proportionAmount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _takeFeeInProportions(
        bool buying,
        address sender,
        uint256 proportionAmount
    ) internal returns (uint256) {
        Fee memory __buyFee = buyFee;
        Fee memory __sellFee = sellFee;

        uint256 proportionFeeAmount = buying == true
            ? (proportionAmount * __buyFee.total) / 100
            : (proportionAmount * __sellFee.total) / 100;

        // reflect
        uint256 proportionReflected = buying == true
            ? (proportionFeeAmount * __buyFee.reflection) / __buyFee.total
            : (proportionFeeAmount * __sellFee.reflection) / __sellFee.total;

        _totalProportion = _totalProportion - proportionReflected;

        // take fees
        uint256 _proportionToContract = proportionFeeAmount -
            proportionReflected;
        if (_proportionToContract > 0) {
            _rOwned[address(this)] =
                _rOwned[address(this)] +
                _proportionToContract;

            emit Transfer(
                sender,
                address(this),
                tokenFromReflection(_proportionToContract)
            );
        }
        emit Reflect(proportionReflected, _totalProportion);
        return proportionAmount - proportionFeeAmount;
    }

    function _shouldSwapBack() internal view returns (bool) {
        return
            msg.sender != UNISWAP_V2_PAIR &&
            !inSwap &&
            claimingFees &&
            balanceOf(address(this)) >= swapThreshold;
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        approve(address(UNISWAP_V2_ROUTER), tokenAmount);

        // add the liquidity
        UNISWAP_V2_ROUTER.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            autoLPReceiver,
            block.timestamp
        );
    }

    function _swapBack() internal swapping {
        Fee memory __sellFee = sellFee;

        uint256 __swapThreshold = swapThreshold;
        uint256 amountToBurn = (__swapThreshold * __sellFee.burn) /
            __sellFee.total;
        uint256 tokensForLiqudity = (__swapThreshold * __sellFee.lp) /
            (__sellFee.total * 2);
        uint256 amountToSwap = __swapThreshold -
            amountToBurn -
            tokensForLiqudity;
        approve(address(UNISWAP_V2_ROUTER), amountToSwap);

        // burn
        _transferFrom(address(this), DEAD, amountToBurn);

        // swap
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = UNISWAP_V2_ROUTER.WETH();

        UNISWAP_V2_ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountETH = address(this).balance;

        uint256 totalSwapFee = __sellFee.total -
            __sellFee.reflection -
            __sellFee.burn;

        uint256 amountETHLP = (amountETH * __sellFee.lp) / (totalSwapFee * 2);
        uint256 amountETHBuyback = (amountETH * __sellFee.buyback) /
            totalSwapFee;

        // send
        if (tokensForLiqudity > 0 && amountETHLP > 0) {
            addLiquidity(tokensForLiqudity, amountETHLP);
        }
        (bool tmpSuccess,  ) = payable(buybackFeeReceiver).call{
            value: amountETHBuyback
        }("");
        (tmpSuccess, ) = payable(operationTaxReceiver).call{
            value: address(this).balance
        }("");
    }

    function _shouldTakeFee(
        address sender,
        address recipient
    ) internal view returns (bool) {
        bool isBuyOrSell = sender == UNISWAP_V2_PAIR ||
            recipient == UNISWAP_V2_PAIR;
        bool isExemptFromFee = isFeeExempt[sender] || isFeeExempt[recipient];
        return !isExemptFromFee && isBuyOrSell;
    }
}
