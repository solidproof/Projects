// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Linkedlist} from './libraries/Linkedlist.sol';
import {TickMath} from './libraries/TickMath.sol';
import {MathConstants as C} from './libraries/MathConstants.sol';
import {IPoolOracle} from './interfaces/oracle/IPoolOracle.sol';

import {IFactory} from './interfaces/IFactory.sol';
import {IPoolStorage} from './interfaces/pool/IPoolStorage.sol';

abstract contract PoolStorage is IPoolStorage {
    using Clones for address;
    using Linkedlist for mapping(int24 => Linkedlist.Data);

    address internal constant LIQUIDITY_LOCKUP_ADDRESS = 0xD444422222222222222222222222222222222222;

    struct PoolData {
        uint160 sqrtP;
        int24 nearestCurrentTick;
        int24 currentTick;
        bool locked;
        uint128 baseL;
        uint128 reinvestL;
        uint128 reinvestLLast;
        uint256 feeGrowthGlobal;
        uint128 secondsPerLiquidityGlobal;
        uint32 secondsPerLiquidityUpdateTime;
    }

    // data stored for each initialized individual tick
    struct TickData {
        // gross liquidity of all positions in tick
        uint128 liquidityGross;
        // liquidity quantity to be added | removed when tick is crossed up | down
        int128 liquidityNet;
        // fee growth per unit of liquidity on the other side of this tick (relative to current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint256 feeGrowthOutside;
        // the seconds per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint128 secondsPerLiquidityOutside;
    }

    // data stored for each user's position
    struct Position {
        // the amount of liquidity owned by this position
        uint128 liquidity;
        // fee growth per unit of liquidity as of the last update to liquidity
        uint256 feeGrowthInsideLast;
    }

    struct CumulativesData {
        uint256 feeGrowth;
        uint128 secondsPerLiquidity;
    }

    /// see IPoolStorage for explanations of the immutables below
    IFactory public immutable override factory;
    IERC20 public immutable override token0;
    IERC20 public immutable override token1;
    IPoolOracle public immutable override poolOracle;
    uint128 public immutable override maxTickLiquidity;
    uint24 public immutable override swapFeeUnits;
    int24 public immutable override tickDistance;

    mapping(int24 => TickData) public override ticks;
    mapping(int24 => Linkedlist.Data) public override initializedTicks;

    mapping(bytes32 => Position) internal positions;

    PoolData internal poolData;

    /// @dev Mutually exclusive reentrancy protection into the pool from/to a method.
    /// Also prevents entrance to pool actions prior to initalization
    modifier lock() {
        require(poolData.locked == false, 'locked');
        poolData.locked = true;
        _;
        poolData.locked = false;
    }

    constructor() {
        // fetch data from factory constructor
        (
        address _factory,
        address _poolOracle,
        address _token0,
        address _token1,
        uint24 _swapFeeUnits,
        int24 _tickDistance
        ) = IFactory(msg.sender).parameters();
        factory = IFactory(_factory);
        poolOracle = IPoolOracle(_poolOracle);
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        swapFeeUnits = _swapFeeUnits;
        tickDistance = _tickDistance;

        maxTickLiquidity = type(uint128).max / TickMath.getMaxNumberTicks(_tickDistance);
        poolData.locked = true; // set pool to locked state
    }

    function _initPoolStorage(uint160 initialSqrtP, int24 initialTick) internal {
        poolData.baseL = 0;
        poolData.reinvestL = C.MIN_LIQUIDITY;
        poolData.reinvestLLast = C.MIN_LIQUIDITY;

        poolData.sqrtP = initialSqrtP;
        poolData.currentTick = initialTick;
        poolData.nearestCurrentTick = TickMath.MIN_TICK;

        initializedTicks.init(TickMath.MIN_TICK, TickMath.MAX_TICK);

        poolOracle.initializeOracle(_blockTimestamp());

        poolData.locked = false; // unlock the pool
    }

    function getPositions(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) external view override returns (uint128 liquidity, uint256 feeGrowthInsideLast) {
        bytes32 key = _positionKey(owner, tickLower, tickUpper);
        return (positions[key].liquidity, positions[key].feeGrowthInsideLast);
    }

    /// @inheritdoc IPoolStorage
    function getPoolState()
    external
    view
    override
    returns (
        uint160 sqrtP,
        int24 currentTick,
        int24 nearestCurrentTick,
        bool locked
    )
    {
        sqrtP = poolData.sqrtP;
        currentTick = poolData.currentTick;
        nearestCurrentTick = poolData.nearestCurrentTick;
        locked = poolData.locked;
    }

    /// @inheritdoc IPoolStorage
    function getLiquidityState()
    external
    view
    override
    returns (
        uint128 baseL,
        uint128 reinvestL,
        uint128 reinvestLLast
    )
    {
        baseL = poolData.baseL;
        reinvestL = poolData.reinvestL;
        reinvestLLast = poolData.reinvestLLast;
    }

    function getFeeGrowthGlobal() external view override returns (uint256) {
        return poolData.feeGrowthGlobal;
    }

    function getSecondsPerLiquidityData()
    external
    view
    override
    returns (uint128 secondsPerLiquidityGlobal, uint32 lastUpdateTime)
    {
        secondsPerLiquidityGlobal = poolData.secondsPerLiquidityGlobal;
        lastUpdateTime = poolData.secondsPerLiquidityUpdateTime;
    }

    function getSecondsPerLiquidityInside(int24 tickLower, int24 tickUpper)
    external
    view
    override
    returns (uint128 secondsPerLiquidityInside)
    {
        require(tickLower <= tickUpper, 'bad tick range');
        int24 currentTick = poolData.currentTick;
        uint128 secondsPerLiquidityGlobal = poolData.secondsPerLiquidityGlobal;
        uint32 lastUpdateTime = poolData.secondsPerLiquidityUpdateTime;

        uint128 lowerValue = ticks[tickLower].secondsPerLiquidityOutside;
        uint128 upperValue = ticks[tickUpper].secondsPerLiquidityOutside;

    unchecked {
        if (currentTick < tickLower) {
            secondsPerLiquidityInside = lowerValue - upperValue;
        } else if (currentTick >= tickUpper) {
            secondsPerLiquidityInside = upperValue - lowerValue;
        } else {
            secondsPerLiquidityInside = secondsPerLiquidityGlobal - (lowerValue + upperValue);
        }
    }

        // in the case where position is in range (tickLower <= _poolTick < tickUpper),
        // need to add timeElapsed per liquidity
        if (tickLower <= currentTick && currentTick < tickUpper) {
            uint256 secondsElapsed = _blockTimestamp() - lastUpdateTime;
            uint128 baseL = poolData.baseL;
            if (secondsElapsed > 0 && baseL > 0) {
            unchecked {
                secondsPerLiquidityInside += uint128((secondsElapsed << 96) / baseL);
            }
            }
        }
    }

    function _positionKey(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, tickLower, tickUpper));
    }

    /// @dev For overriding in tests
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp);
    }
}
