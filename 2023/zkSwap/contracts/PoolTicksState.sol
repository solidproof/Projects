// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {LiqDeltaMath} from './libraries/LiqDeltaMath.sol';
import {SafeCast} from './libraries/SafeCast.sol';
import {MathConstants} from './libraries/MathConstants.sol';
import {FullMath} from './libraries/FullMath.sol';
import {TickMath} from './libraries/TickMath.sol';
import {Linkedlist} from './libraries/Linkedlist.sol';

import {PoolStorage} from './PoolStorage.sol';

contract PoolTicksState is PoolStorage {
    using SafeCast for int128;
    using SafeCast for uint128;
    using Linkedlist for mapping(int24 => Linkedlist.Data);

    struct UpdatePositionData {
        // address of owner of the position
        address owner;
        // position's lower and upper ticks
        int24 tickLower;
        int24 tickUpper;
        // if minting, need to pass the previous initialized ticks for tickLower and tickUpper
        int24 tickLowerPrevious;
        int24 tickUpperPrevious;
        // any change in liquidity
        uint128 liquidityDelta;
        // true = adding liquidity, false = removing liquidity
        bool isAddLiquidity;
    }

    function _updatePosition(
        UpdatePositionData memory updateData,
        int24 currentTick,
        CumulativesData memory cumulatives
    ) internal returns (uint256 feesClaimable, uint256 feeGrowthInside) {
        // update ticks if necessary
        uint256 feeGrowthOutsideLowerTick = _updateTick(
            updateData.tickLower,
            currentTick,
            updateData.tickLowerPrevious,
            updateData.liquidityDelta,
            updateData.isAddLiquidity,
            cumulatives,
            true
        );

        uint256 feeGrowthOutsideUpperTick = _updateTick(
            updateData.tickUpper,
            currentTick,
            updateData.tickUpperPrevious,
            updateData.liquidityDelta,
            updateData.isAddLiquidity,
            cumulatives,
            false
        );

        // calculate feeGrowthInside
    unchecked {
        if (currentTick < updateData.tickLower) {
            feeGrowthInside = feeGrowthOutsideLowerTick - feeGrowthOutsideUpperTick;
        } else if (currentTick >= updateData.tickUpper) {
            feeGrowthInside = feeGrowthOutsideUpperTick - feeGrowthOutsideLowerTick;
        } else {
            feeGrowthInside =
            cumulatives.feeGrowth -
            feeGrowthOutsideLowerTick -
            feeGrowthOutsideUpperTick;
        }
    }

        // calc rTokens to be minted for the position's accumulated fees
        feesClaimable = _updatePositionData(updateData, feeGrowthInside);
    }

    /// @dev Update liquidity net data and do cross tick
    function _updateLiquidityAndCrossTick(
        int24 nextTick,
        uint128 currentLiquidity,
        uint256 feeGrowthGlobal,
        uint128 secondsPerLiquidityGlobal,
        bool willUpTick
    ) internal returns (uint128 newLiquidity, int24 newNextTick) {
    unchecked {
        ticks[nextTick].feeGrowthOutside = feeGrowthGlobal - ticks[nextTick].feeGrowthOutside;
        ticks[nextTick].secondsPerLiquidityOutside =
        secondsPerLiquidityGlobal -
        ticks[nextTick].secondsPerLiquidityOutside;
    }
        int128 liquidityNet = ticks[nextTick].liquidityNet;
        if (willUpTick) {
            newNextTick = initializedTicks[nextTick].next;
        } else {
            newNextTick = initializedTicks[nextTick].previous;
            liquidityNet = -liquidityNet;
        }
        newLiquidity = LiqDeltaMath.applyLiquidityDelta(
            currentLiquidity,
            liquidityNet >= 0 ? uint128(liquidityNet) : liquidityNet.revToUint128(),
            liquidityNet >= 0
        );
    }

    function _updatePoolData(
        uint128 baseL,
        uint128 reinvestL,
        uint160 sqrtP,
        int24 currentTick,
        int24 nextTick
    ) internal {
        poolData.baseL = baseL;
        poolData.reinvestL = reinvestL;
        poolData.sqrtP = sqrtP;
        poolData.currentTick = currentTick;
        poolData.nearestCurrentTick = nextTick > currentTick
        ? initializedTicks[nextTick].previous
        : nextTick;
    }

    /// @dev Return initial data before swapping
    /// @param willUpTick whether is up/down tick
    /// @return baseL current pool base liquidity without reinvestment liquidity
    /// @return reinvestL current pool reinvestment liquidity
    /// @return sqrtP current pool sqrt price
    /// @return currentTick current pool tick
    /// @return nextTick next tick to calculate data
    function _getInitialSwapData(bool willUpTick)
    internal
    view
    returns (
        uint128 baseL,
        uint128 reinvestL,
        uint160 sqrtP,
        int24 currentTick,
        int24 nextTick
    )
    {
        baseL = poolData.baseL;
        reinvestL = poolData.reinvestL;
        sqrtP = poolData.sqrtP;
        currentTick = poolData.currentTick;
        nextTick = poolData.nearestCurrentTick;
        if (willUpTick) {
            nextTick = initializedTicks[nextTick].next;
        }
    }

    function _updatePositionData(UpdatePositionData memory _data, uint256 feeGrowthInside)
    private
    returns (uint256 feesClaimable)
    {
        bytes32 key = _positionKey(_data.owner, _data.tickLower, _data.tickUpper);
        // calculate accumulated fees for current liquidity
        // feeGrowthInside is relative value, hence underflow is acceptable
        uint256 feeGrowth;
    unchecked {
        feeGrowth = feeGrowthInside - positions[key].feeGrowthInsideLast;
    }
        uint128 prevLiquidity = positions[key].liquidity;
        feesClaimable = FullMath.mulDivFloor(feeGrowth, prevLiquidity, MathConstants.TWO_POW_96);
        // update the position
        if (_data.liquidityDelta != 0) {
            positions[key].liquidity = LiqDeltaMath.applyLiquidityDelta(
                prevLiquidity,
                _data.liquidityDelta,
                _data.isAddLiquidity
            );
        }
        positions[key].feeGrowthInsideLast = feeGrowthInside;
    }

    /// @notice Updates a tick and returns the fee growth outside of that tick
    /// @param tick Tick to be updated
    /// @param tickCurrent Current tick
    /// @param tickPrevious the nearest initialized tick which is lower than or equal to `tick`
    /// @param liquidityDelta Liquidity quantity to be added | removed when tick is crossed up | down
    /// @param cumulatives All-time global fee growth and seconds, per unit of liquidity
    /// @param isLower true | false if updating a position's lower | upper tick
    /// @return feeGrowthOutside last value of feeGrowthOutside
    function _updateTick(
        int24 tick,
        int24 tickCurrent,
        int24 tickPrevious,
        uint128 liquidityDelta,
        bool isAdd,
        CumulativesData memory cumulatives,
        bool isLower
    ) private returns (uint256 feeGrowthOutside) {
        uint128 liquidityGrossBefore = ticks[tick].liquidityGross;
        require(liquidityGrossBefore != 0 || liquidityDelta != 0, 'invalid liq');

        if (liquidityDelta == 0) return ticks[tick].feeGrowthOutside;

        uint128 liquidityGrossAfter = LiqDeltaMath.applyLiquidityDelta(
            liquidityGrossBefore,
            liquidityDelta,
            isAdd
        );
        require(liquidityGrossAfter <= maxTickLiquidity, '> max liquidity');
        int128 signedLiquidityDelta = isAdd ? liquidityDelta.toInt128() : -(liquidityDelta.toInt128());
        // if lower tick, liquidityDelta should be added | removed when crossed up | down
        // else, for upper tick, liquidityDelta should be removed | added when crossed up | down
        int128 liquidityNetAfter = isLower
        ? ticks[tick].liquidityNet + signedLiquidityDelta
        : ticks[tick].liquidityNet - signedLiquidityDelta;

        if (liquidityGrossBefore == 0) {
            // by convention, all growth before a tick was initialized is assumed to happen below it
            if (tick <= tickCurrent) {
                ticks[tick].feeGrowthOutside = cumulatives.feeGrowth;
                ticks[tick].secondsPerLiquidityOutside = cumulatives.secondsPerLiquidity;
            }
        }

        ticks[tick].liquidityGross = liquidityGrossAfter;
        ticks[tick].liquidityNet = liquidityNetAfter;
        feeGrowthOutside = ticks[tick].feeGrowthOutside;

        if (liquidityGrossBefore > 0 && liquidityGrossAfter == 0) {
            delete ticks[tick];
        }

        if ((liquidityGrossBefore > 0) != (liquidityGrossAfter > 0)) {
            _updateTickList(tick, tickPrevious, tickCurrent, isAdd);
        }
    }

    /// @dev Update the tick linkedlist, assume that tick is not in the list
    /// @param tick tick index to update
    /// @param currentTick the pool currentt tick
    /// @param previousTick the nearest initialized tick that is lower than the tick, in case adding
    /// @param isAdd whether is add or remove the tick
    function _updateTickList(
        int24 tick,
        int24 previousTick,
        int24 currentTick,
        bool isAdd
    ) internal {
        if (isAdd) {
            if (tick == TickMath.MIN_TICK || tick == TickMath.MAX_TICK) return;
            // find the correct previousTick to the `tick`, avoid revert when new liquidity has been added between tick & previousTick
            int24 nextTick = initializedTicks[previousTick].next;
            require(
                nextTick != initializedTicks[previousTick].previous,
                'previous tick has been removed'
            );
            uint256 iteration = 0;
            while (nextTick <= tick && iteration < MathConstants.MAX_TICK_TRAVEL) {
                previousTick = nextTick;
                nextTick = initializedTicks[previousTick].next;
                iteration++;
            }
            initializedTicks.insert(tick, previousTick, nextTick);
            if (poolData.nearestCurrentTick < tick && tick <= currentTick) {
                poolData.nearestCurrentTick = tick;
            }
        } else {
            if (tick == poolData.nearestCurrentTick) {
                poolData.nearestCurrentTick = initializedTicks.remove(tick);
            } else {
                initializedTicks.remove(tick);
            }
        }
    }
}
