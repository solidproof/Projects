// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../interface/IERC20.sol";
import "../interface/IERC721Metadata.sol";
import "../interface/IPair.sol";
import "../interface/IFactory.sol";
import "../interface/ICallee.sol";
import "../interface/IUnderlying.sol";
import "./PairFees.sol";
import "../lib/Math.sol";
import "../lib/SafeERC20.sol";
import "../Reentrancy.sol";

// The base pair of pools, either stable or volatile
contract DraculaPair is IERC20, IPair, Reentrancy {
    using SafeERC20 for IERC20;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    /// @dev Used to denote stable or volatile pair
    bool public immutable stable;

    uint256 public override totalSupply = 0;

    mapping(address => mapping(address => uint256)) public override allowance;
    mapping(address => uint256) public override balanceOf;

    bytes32 public immutable DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    uint256 internal constant _FEE_PRECISION = 1e32;
    mapping(address => uint256) public nonces;
    uint256 public immutable chainId;

    uint256 internal constant MINIMUM_LIQUIDITY = 10 ** 3;
    /// @dev 0.02% swap fee
    uint256 internal constant SWAP_FEE_STABLE = 5_000;
    /// @dev 0.4% swap fee
    uint256 internal constant SWAP_FEE_VOLATILE = 250;
    /// @dev 1% max allowed swap fee
    uint256 internal constant SWAP_FEE_MAX = 100;
    /// @dev 50% of swap fee
    uint256 internal constant TREASURY_FEE = 2;
    /// @dev Capture oracle reading every 30 minutes
    uint256 internal constant PERIOD_SIZE = 1800;

    address public immutable override token0;
    address public immutable override token1;
    address public immutable fees;
    address public immutable factory;
    address public immutable treasury;

    Observation[] public observations;

    uint256 public swapFee;
    uint256 internal immutable decimals0;
    uint256 internal immutable decimals1;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public blockTimestampLast;

    uint256 public reserve0CumulativeLast;
    uint256 public reserve1CumulativeLast;

    // index0 and index1 are used to accumulate fees,
    // this is split out from normal trades to keep the swap "clean"
    // this further allows LP holders to easily claim fees for tokens they have/staked
    uint256 public index0 = 0;
    uint256 public index1 = 0;

    // position assigned to each LP to track their current index0 & index1 vs the global position
    mapping(address => uint256) public supplyIndex0;
    mapping(address => uint256) public supplyIndex1;

    // tracks the amount of unclaimed, but claimable tokens off of fees for token0 and token1
    mapping(address => uint256) public claimable0;
    mapping(address => uint256) public claimable1;

    event Treasury(address indexed sender, uint256 amount0, uint256 amount1);
    event Fees(address indexed sender, uint256 amount0, uint256 amount1);
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
    event Sync(uint256 reserve0, uint256 reserve1);
    event Claim(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1
    );
    event FeesChanged(uint256 newValue);

    constructor() {
        factory = msg.sender;
        treasury = IFactory(msg.sender).treasury();
        (address _token0, address _token1, bool _stable) = IFactory(msg.sender)
            .getInitializable();
        (token0, token1, stable) = (_token0, _token1, _stable);
        fees = address(new PairFees(_token0, _token1));

        swapFee = _stable ? SWAP_FEE_STABLE : SWAP_FEE_VOLATILE;

        if (_stable) {
            name = string(
                abi.encodePacked(
                    "Stable AMM - ",
                    IERC721Metadata(_token0).symbol(),
                    "/",
                    IERC721Metadata(_token1).symbol()
                )
            );
            symbol = string(
                abi.encodePacked(
                    "sAMM-",
                    IERC721Metadata(_token0).symbol(),
                    "/",
                    IERC721Metadata(_token1).symbol()
                )
            );
        } else {
            name = string(
                abi.encodePacked(
                    "Volatile AMM - ",
                    IERC721Metadata(_token0).symbol(),
                    "/",
                    IERC721Metadata(_token1).symbol()
                )
            );
            symbol = string(
                abi.encodePacked(
                    "vAMM-",
                    IERC721Metadata(_token0).symbol(),
                    "/",
                    IERC721Metadata(_token1).symbol()
                )
            );
        }

        decimals0 = 10 ** IUnderlying(_token0).decimals();
        decimals1 = 10 ** IUnderlying(_token1).decimals();

        observations.push(Observation(block.timestamp, 0, 0));

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        chainId = block.chainid;
    }

    function setSwapFee(uint256 value) external {
        require(msg.sender == factory, "!factory");
        require(value >= SWAP_FEE_MAX, "max");
        swapFee = value;
        emit FeesChanged(value);
    }

    function observationLength() external view returns (uint256) {
        return observations.length;
    }

    function lastObservation() public view returns (Observation memory) {
        return observations[observations.length - 1];
    }

    function metadata()
        external
        view
        returns (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            bool st,
            address t0,
            address t1
        )
    {
        return (
            decimals0,
            decimals1,
            reserve0,
            reserve1,
            stable,
            token0,
            token1
        );
    }

    function tokens() external view override returns (address, address) {
        return (token0, token1);
    }

    /// @dev Claim accumulated but unclaimed fees (viewable via claimable0 and claimable1)
    function claimFees()
        external
        override
        returns (uint256 claimed0, uint256 claimed1)
    {
        _updateFor(msg.sender);

        claimed0 = claimable0[msg.sender];
        claimed1 = claimable1[msg.sender];

        if (claimed0 > 0 || claimed1 > 0) {
            claimable0[msg.sender] = 0;
            claimable1[msg.sender] = 0;

            PairFees(fees).claimFeesFor(msg.sender, claimed0, claimed1);

            emit Claim(msg.sender, msg.sender, claimed0, claimed1);
        }
    }

    /// @dev Accrue fees on token0
    function _update0(uint256 amount) internal {
        uint256 toTreasury = amount / TREASURY_FEE;
        uint256 toFees = amount - toTreasury;

        // transfer the fees out to PairFees and Treasury
        IERC20(token0).safeTransfer(treasury, toTreasury);
        IERC20(token0).safeTransfer(fees, toFees);
        // 1e32 adjustment is removed during claim
        uint256 _ratio = (toFees * _FEE_PRECISION) / totalSupply;
        if (_ratio > 0) {
            index0 += _ratio;
        }
        // keep the same structure of events for compatibility
        emit Treasury(msg.sender, toTreasury, 0);
        emit Fees(msg.sender, toFees, 0);
    }

    /// @dev Accrue fees on token1
    function _update1(uint256 amount) internal {
        uint256 toTreasury = amount / TREASURY_FEE;
        uint256 toFees = amount - toTreasury;

        IERC20(token1).safeTransfer(treasury, toTreasury);
        IERC20(token1).safeTransfer(fees, toFees);
        uint256 _ratio = (toFees * _FEE_PRECISION) / totalSupply;
        if (_ratio > 0) {
            index1 += _ratio;
        }
        // keep the same structure of events for compatibility
        emit Treasury(msg.sender, 0, toTreasury);
        emit Fees(msg.sender, 0, toFees);
    }

    /// @dev This function MUST be called on any balance changes,
    ///      otherwise can be used to infinitely claim fees
    //       Fees are segregated from core funds, so fees can never put liquidity at risk
    function _updateFor(address recipient) internal {
        uint256 _supplied = balanceOf[recipient];
        // get LP balance of `recipient`
        if (_supplied > 0) {
            uint256 _supplyIndex0 = supplyIndex0[recipient];
            // get last adjusted index0 for recipient
            uint256 _supplyIndex1 = supplyIndex1[recipient];
            uint256 _index0 = index0;
            // get global index0 for accumulated fees
            uint256 _index1 = index1;
            supplyIndex0[recipient] = _index0;
            // update user current position to global position
            supplyIndex1[recipient] = _index1;
            uint256 _delta0 = _index0 - _supplyIndex0;
            // see if there is any difference that need to be accrued
            uint256 _delta1 = _index1 - _supplyIndex1;
            if (_delta0 > 0) {
                uint256 _share = (_supplied * _delta0) / _FEE_PRECISION;
                // add accrued difference for each supplied token
                claimable0[recipient] += _share;
            }
            if (_delta1 > 0) {
                uint256 _share = (_supplied * _delta1) / _FEE_PRECISION;
                claimable1[recipient] += _share;
            }
        } else {
            supplyIndex0[recipient] = index0;
            // new users are set to the default global state
            supplyIndex1[recipient] = index1;
        }
    }

    function getReserves()
        public
        view
        override
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        )
    {
        _reserve0 = uint112(reserve0);
        _reserve1 = uint112(reserve1);
        _blockTimestampLast = uint32(blockTimestampLast);
    }

    /// @dev Update reserves and, on the first call per block, price accumulators
    function _update(
        uint256 balance0,
        uint256 balance1,
        uint256 _reserve0,
        uint256 _reserve1
    ) internal {
        uint256 blockTimestamp = block.timestamp;
        uint256 timeElapsed = blockTimestamp - blockTimestampLast;
        // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            unchecked {
                reserve0CumulativeLast += _reserve0 * timeElapsed;
                reserve1CumulativeLast += _reserve1 * timeElapsed;
            }
        }

        Observation memory _point = lastObservation();
        timeElapsed = blockTimestamp - _point.timestamp;
        // compare the last observation with current timestamp,
        // if greater than 30 minutes, record a new event
        if (timeElapsed > PERIOD_SIZE) {
            observations.push(
                Observation(
                    blockTimestamp,
                    reserve0CumulativeLast,
                    reserve1CumulativeLast
                )
            );
        }
        reserve0 = balance0;
        reserve1 = balance1;
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    /// @dev Produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices()
        public
        view
        returns (
            uint256 reserve0Cumulative,
            uint256 reserve1Cumulative,
            uint256 blockTimestamp
        )
    {
        blockTimestamp = block.timestamp;
        reserve0Cumulative = reserve0CumulativeLast;
        reserve1Cumulative = reserve1CumulativeLast;

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (
            uint256 _reserve0,
            uint256 _reserve1,
            uint256 _blockTimestampLast
        ) = getReserves();
        if (_blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint256 timeElapsed = blockTimestamp - _blockTimestampLast;
            unchecked {
                reserve0Cumulative += _reserve0 * timeElapsed;
                reserve1Cumulative += _reserve1 * timeElapsed;
            }
        }
    }

    /// @dev Gives the current twap price measured from amountIn * tokenIn gives amountOut
    function current(
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        Observation memory _observation = lastObservation();
        (
            uint256 reserve0Cumulative,
            uint256 reserve1Cumulative,

        ) = currentCumulativePrices();
        if (block.timestamp == _observation.timestamp) {
            _observation = observations[observations.length - 2];
        }

        uint256 timeElapsed = block.timestamp - _observation.timestamp;
        uint256 _reserve0 = (reserve0Cumulative -
            _observation.reserve0Cumulative) / timeElapsed;
        uint256 _reserve1 = (reserve1Cumulative -
            _observation.reserve1Cumulative) / timeElapsed;
        amountOut = _getAmountOut(amountIn, tokenIn, _reserve0, _reserve1);
    }

    /// @dev As per `current`, however allows user configured granularity, up to the full window size
    function quote(
        address tokenIn,
        uint256 amountIn,
        uint256 granularity
    ) external view returns (uint256 amountOut) {
        uint256[] memory _prices = sample(tokenIn, amountIn, granularity, 1);
        uint256 priceAverageCumulative;
        for (uint256 i = 0; i < _prices.length; i++) {
            priceAverageCumulative += _prices[i];
        }
        return priceAverageCumulative / granularity;
    }

    /// @dev Returns a memory set of twap prices
    function prices(
        address tokenIn,
        uint256 amountIn,
        uint256 points
    ) external view returns (uint256[] memory) {
        return sample(tokenIn, amountIn, points, 1);
    }

    function sample(
        address tokenIn,
        uint256 amountIn,
        uint256 points,
        uint256 window
    ) public view returns (uint256[] memory) {
        uint256[] memory _prices = new uint256[](points);

        uint256 length = observations.length - 1;
        uint256 i = length - (points * window);
        uint256 nextIndex = 0;
        uint256 index = 0;

        for (; i < length; i += window) {
            nextIndex = i + window;
            uint256 timeElapsed = observations[nextIndex].timestamp -
                observations[i].timestamp;
            uint256 _reserve0 = (observations[nextIndex].reserve0Cumulative -
                observations[i].reserve0Cumulative) / timeElapsed;
            uint256 _reserve1 = (observations[nextIndex].reserve1Cumulative -
                observations[i].reserve1Cumulative) / timeElapsed;
            _prices[index] = _getAmountOut(
                amountIn,
                tokenIn,
                _reserve0,
                _reserve1
            );
            index = index + 1;
        }
        return _prices;
    }

    /// @dev This low-level function should be called from a contract which performs important safety checks
    ///      standard uniswap v2 implementation
    function mint(
        address to
    ) external override lock returns (uint256 liquidity) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        uint256 _balance0 = IERC20(token0).balanceOf(address(this));
        uint256 _balance1 = IERC20(token1).balanceOf(address(this));
        uint256 _amount0 = _balance0 - _reserve0;
        uint256 _amount1 = _balance1 - _reserve1;

        uint256 _totalSupply = totalSupply;
        // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(_amount0 * _amount1) - MINIMUM_LIQUIDITY;
            // permanently lock the first MINIMUM_LIQUIDITY tokens
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(
                (_amount0 * _totalSupply) / _reserve0,
                (_amount1 * _totalSupply) / _reserve1
            );
        }
        require(liquidity > 0, "DraculaPair: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(_balance0, _balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, _amount0, _amount1);
    }

    /// @dev This low-level function should be called from a contract which performs important safety checks
    ///      standard uniswap v2 implementation
    function burn(
        address to
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        (address _token0, address _token1) = (token0, token1);
        uint256 _balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 _balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 _liquidity = balanceOf[address(this)];

        // gas savings, must be defined here since totalSupply can update in _mintFee
        uint256 _totalSupply = totalSupply;
        // using balances ensures pro-rata distribution
        amount0 = (_liquidity * _balance0) / _totalSupply;
        // using balances ensures pro-rata distribution
        amount1 = (_liquidity * _balance1) / _totalSupply;
        require(
            amount0 > 0 && amount1 > 0,
            "DraculaPair: INSUFFICIENT_LIQUIDITY_BURNED"
        );
        _burn(address(this), _liquidity);
        IERC20(_token0).safeTransfer(to, amount0);
        IERC20(_token1).safeTransfer(to, amount1);
        _balance0 = IERC20(_token0).balanceOf(address(this));
        _balance1 = IERC20(_token1).balanceOf(address(this));

        _update(_balance0, _balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /// @dev This low-level function should be called from a contract which performs important safety checks
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external override lock {
        require(!IFactory(factory).isPaused(), "DraculaPair: PAUSE");
        require(
            amount0Out > 0 || amount1Out > 0,
            "DraculaPair: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        require(
            amount0Out < _reserve0 && amount1Out < _reserve1,
            "DraculaPair: INSUFFICIENT_LIQUIDITY"
        );
        uint256 _balance0;
        uint256 _balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            (address _token0, address _token1) = (token0, token1);
            require(to != _token0 && to != _token1, "DraculaPair: INVALID_TO");
            // optimistically transfer tokens
            if (amount0Out > 0) IERC20(_token0).safeTransfer(to, amount0Out);
            // optimistically transfer tokens
            if (amount1Out > 0) IERC20(_token1).safeTransfer(to, amount1Out);
            // callback, used for flash loans
            if (data.length > 0)
                ICallee(to).hook(msg.sender, amount0Out, amount1Out, data);
            _balance0 = IERC20(_token0).balanceOf(address(this));
            _balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint256 amount0In = _balance0 > _reserve0 - amount0Out
            ? _balance0 - (_reserve0 - amount0Out)
            : 0;
        uint256 amount1In = _balance1 > _reserve1 - amount1Out
            ? _balance1 - (_reserve1 - amount1Out)
            : 0;
        require(
            amount0In > 0 || amount1In > 0,
            "DraculaPair: INSUFFICIENT_INPUT_AMOUNT"
        );
        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            (address _token0, address _token1) = (token0, token1);
            // accrue fees for token0 and move them out of pool
            if (amount0In > 0) _update0(amount0In / swapFee);
            // accrue fees for token1 and move them out of pool
            if (amount1In > 0) _update1(amount1In / swapFee);
            // since we removed tokens, we need to reconfirm balances,
            // can also simply use previous balance - amountIn/ SWAP_FEE,
            // but doing balanceOf again as safety check
            _balance0 = IERC20(_token0).balanceOf(address(this));
            _balance1 = IERC20(_token1).balanceOf(address(this));
            // The curve, either x3y+y3x for stable pools, or x*y for volatile pools
            require(
                _k(_balance0, _balance1) >= _k(_reserve0, _reserve1),
                "DraculaPair: K"
            );
        }

        _update(_balance0, _balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /// @dev Force balances to match reserves
    function skim(address to) external lock {
        (address _token0, address _token1) = (token0, token1);
        IERC20(_token0).safeTransfer(
            to,
            IERC20(_token0).balanceOf(address(this)) - (reserve0)
        );
        IERC20(_token1).safeTransfer(
            to,
            IERC20(_token1).balanceOf(address(this)) - (reserve1)
        );
    }

    // force reserves to match balances
    function sync() external lock {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }

    function _f(uint256 x0, uint256 y) internal pure returns (uint256) {
        return
            (x0 * ((((y * y) / 1e18) * y) / 1e18)) /
            1e18 +
            (((((x0 * x0) / 1e18) * x0) / 1e18) * y) /
            1e18;
    }

    function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return
            (3 * x0 * ((y * y) / 1e18)) /
            1e18 +
            ((((x0 * x0) / 1e18) * x0) / 1e18);
    }

    function _getY(
        uint256 x0,
        uint256 xy,
        uint256 y
    ) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 yPrev = y;
            uint256 k = _f(x0, y);
            if (k < xy) {
                uint256 dy = ((xy - k) * 1e18) / _d(x0, y);
                y = y + dy;
            } else {
                uint256 dy = ((k - xy) * 1e18) / _d(x0, y);
                y = y - dy;
            }
            if (Math.closeTo(y, yPrev, 1)) {
                break;
            }
        }
        return y;
    }

    function getAmountOut(
        uint256 amountIn,
        address tokenIn
    ) external view override returns (uint256) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        // remove fee from amount received
        amountIn -= amountIn / swapFee;
        return _getAmountOut(amountIn, tokenIn, _reserve0, _reserve1);
    }

    function _getAmountOut(
        uint256 amountIn,
        address tokenIn,
        uint256 _reserve0,
        uint256 _reserve1
    ) internal view returns (uint256) {
        if (stable) {
            uint256 xy = _k(_reserve0, _reserve1);
            _reserve0 = (_reserve0 * 1e18) / decimals0;
            _reserve1 = (_reserve1 * 1e18) / decimals1;
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0
                ? (_reserve0, _reserve1)
                : (_reserve1, _reserve0);
            amountIn = tokenIn == token0
                ? (amountIn * 1e18) / decimals0
                : (amountIn * 1e18) / decimals1;
            uint256 y = reserveB - _getY(amountIn + reserveA, xy, reserveB);
            return (y * (tokenIn == token0 ? decimals1 : decimals0)) / 1e18;
        } else {
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0
                ? (_reserve0, _reserve1)
                : (_reserve1, _reserve0);
            return (amountIn * reserveB) / (reserveA + amountIn);
        }
    }

    function _k(uint256 x, uint256 y) internal view returns (uint256) {
        if (stable) {
            uint256 _x = (x * 1e18) / decimals0;
            uint256 _y = (y * 1e18) / decimals1;
            uint256 _a = (_x * _y) / 1e18;
            uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
            // x3y+y3x >= k
            return (_a * _b) / 1e18;
        } else {
            // xy >= k
            return x * y;
        }
    }

    //****************************************************************************
    //**************************** ERC20 *****************************************
    //****************************************************************************

    function _mint(address dst, uint256 amount) internal {
        // balances must be updated on mint/burn/transfer
        _updateFor(dst);
        totalSupply += amount;
        balanceOf[dst] += amount;
        emit Transfer(address(0), dst, amount);
    }

    function _burn(address dst, uint256 amount) internal {
        _updateFor(dst);
        totalSupply -= amount;
        balanceOf[dst] -= amount;
        emit Transfer(dst, address(0), amount);
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        require(
            spender != address(0),
            "DraculaPair: Approve to the zero address"
        );
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(deadline >= block.timestamp, "DraculaPair: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "DraculaPair: INVALID_SIGNATURE"
        );
        allowance[owner][spender] = value;

        emit Approval(owner, spender, value);
    }

    function transfer(
        address dst,
        uint256 amount
    ) external override returns (bool) {
        _transferTokens(msg.sender, dst, amount);
        return true;
    }

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external override returns (bool) {
        address spender = msg.sender;
        uint256 spenderAllowance = allowance[src][spender];

        if (spender != src && spenderAllowance != type(uint256).max) {
            require(
                spenderAllowance >= amount,
                "DraculaPair: Insufficient allowance"
            );
            unchecked {
                uint256 newAllowance = spenderAllowance - amount;
                allowance[src][spender] = newAllowance;
                emit Approval(src, spender, newAllowance);
            }
        }

        _transferTokens(src, dst, amount);
        return true;
    }

    function _transferTokens(
        address src,
        address dst,
        uint256 amount
    ) internal {
        require(dst != address(0), "DraculaPair: Transfer to the zero address");

        // update fee position for src
        _updateFor(src);
        // update fee position for dst
        _updateFor(dst);

        uint256 srcBalance = balanceOf[src];
        require(
            srcBalance >= amount,
            "DraculaPair: Transfer amount exceeds balance"
        );
        unchecked {
            balanceOf[src] = srcBalance - amount;
        }

        balanceOf[dst] += amount;

        emit Transfer(src, dst, amount);
    }
}
