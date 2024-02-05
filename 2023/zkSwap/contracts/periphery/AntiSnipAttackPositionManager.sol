// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.16;
pragma abicoder v2;

import {AntiSnipAttack} from '../periphery/libraries/AntiSnipAttack.sol';
import {SafeCast} from '../libraries/SafeCast.sol';

import './BasePositionManager.sol';

contract AntiSnipAttackPositionManager is BasePositionManager {
    using SafeCast for uint256;
    mapping(uint256 => AntiSnipAttack.Data) public antiSnipAttackData;

    constructor(
        address _factory,
        address _WETH,
        address _descriptor
    ) BasePositionManager(_factory, _WETH, _descriptor) {}

    function mint(MintParams calldata params)
    public
    payable
    override
    returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    )
    {
        (tokenId, liquidity, amount0, amount1) = super.mint(params);
        antiSnipAttackData[tokenId] = AntiSnipAttack.initialize(block.timestamp.toUint32());
    }

    function addLiquidity(IncreaseLiquidityParams calldata params)
    external
    payable
    override
    onlyNotExpired(params.deadline)
    returns (
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 additionalRTokenOwed
    )
    {
        Position storage pos = _positions[params.tokenId];
        PoolInfo memory poolInfo = _poolInfoById[pos.poolId];
        IPool pool;
        uint256 feeGrowthInsideLast;

        (liquidity, amount0, amount1, feeGrowthInsideLast, pool) = _addLiquidity(
            AddLiquidityParams({
        token0: poolInfo.token0,
        token1: poolInfo.token1,
        fee: poolInfo.fee,
        recipient: address(this),
        tickLower: pos.tickLower,
        tickUpper: pos.tickUpper,
        ticksPrevious: params.ticksPrevious,
        amount0Desired: params.amount0Desired,
        amount1Desired: params.amount1Desired,
        amount0Min: params.amount0Min,
        amount1Min: params.amount1Min
        })
        );

        uint128 tmpLiquidity = pos.liquidity;

        if (feeGrowthInsideLast != pos.feeGrowthInsideLast) {
            uint256 feeGrowthInsideDiff;
        unchecked {
            feeGrowthInsideDiff = feeGrowthInsideLast - pos.feeGrowthInsideLast;
        }
            // zero fees burnable when adding liquidity
            (additionalRTokenOwed, ) = AntiSnipAttack.update(
                antiSnipAttackData[params.tokenId],
                tmpLiquidity,
                liquidity,
                block.timestamp.toUint32(),
                true,
                FullMath.mulDivFloor(tmpLiquidity, feeGrowthInsideDiff, C.TWO_POW_96),
                IFactory(factory).vestingPeriod()
            );
            pos.rTokenOwed += additionalRTokenOwed;
            pos.feeGrowthInsideLast = feeGrowthInsideLast;
        }

        pos.liquidity += liquidity;

        emit AddLiquidity(params.tokenId, liquidity, amount0, amount1, additionalRTokenOwed);
    }

    function removeLiquidity(RemoveLiquidityParams calldata params)
    external
    override
    isAuthorizedForToken(params.tokenId)
    onlyNotExpired(params.deadline)
    returns (
        uint256 amount0,
        uint256 amount1,
        uint256 additionalRTokenOwed
    )
    {
        Position storage pos = _positions[params.tokenId];
        uint128 tmpLiquidity = pos.liquidity;
        require(tmpLiquidity >= params.liquidity, 'Insufficient liquidity');

        PoolInfo memory poolInfo = _poolInfoById[pos.poolId];
        IPool pool = _getPool(poolInfo.token0, poolInfo.token1, poolInfo.fee);

        uint256 feeGrowthInsideLast;
        (amount0, amount1, feeGrowthInsideLast) = pool.burn(
            pos.tickLower,
            pos.tickUpper,
            params.liquidity
        );
        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, 'Low return amounts');

        // call update() function regardless of fee growth difference
        // to calculate burnable fees
        uint256 feesBurnable;
        uint256 feeGrowthInsideDiff;
    unchecked {
        feeGrowthInsideDiff = feeGrowthInsideLast - pos.feeGrowthInsideLast;
    }
        (additionalRTokenOwed, feesBurnable) = AntiSnipAttack.update(
            antiSnipAttackData[params.tokenId],
            tmpLiquidity,
            params.liquidity,
            block.timestamp.toUint32(),
            false,
            FullMath.mulDivFloor(tmpLiquidity, feeGrowthInsideDiff, C.TWO_POW_96),
            IFactory(factory).vestingPeriod()
        );
        pos.rTokenOwed += additionalRTokenOwed;
        pos.feeGrowthInsideLast = feeGrowthInsideLast;
        if (feesBurnable > 0) pool.burnRTokens(feesBurnable, true);

        pos.liquidity = tmpLiquidity - params.liquidity;

        emit RemoveLiquidity(params.tokenId, params.liquidity, amount0, amount1, additionalRTokenOwed);
    }

    function syncFeeGrowth(uint256 tokenId)
    external
    override
    isAuthorizedForToken(tokenId)
    returns(uint256 additionalRTokenOwed)
    {
        Position storage pos = _positions[tokenId];

        PoolInfo memory poolInfo = _poolInfoById[pos.poolId];
        IPool pool = _getPool(poolInfo.token0, poolInfo.token1, poolInfo.fee);

        uint256 feeGrowthInsideLast = pool.tweakPosZeroLiq(
            pos.tickLower,
            pos.tickUpper
        );

        uint256 feeGrowthInsideDiff;

        unchecked {
            feeGrowthInsideDiff = feeGrowthInsideLast - pos.feeGrowthInsideLast;
        }

        uint128 tmpLiquidity = pos.liquidity;
        (additionalRTokenOwed, ) = AntiSnipAttack.update(
            antiSnipAttackData[tokenId],
            tmpLiquidity,
            0,
            block.timestamp.toUint32(),
            false,
            FullMath.mulDivFloor(tmpLiquidity, feeGrowthInsideDiff, C.TWO_POW_96),
            IFactory(factory).vestingPeriod()
        );
        pos.rTokenOwed += additionalRTokenOwed;
        pos.feeGrowthInsideLast = feeGrowthInsideLast;

        emit SyncFeeGrowth(tokenId, additionalRTokenOwed);
    }
}
