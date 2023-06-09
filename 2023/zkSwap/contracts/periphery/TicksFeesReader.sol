// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.16;
pragma abicoder v2;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IPoolStorage} from '../interfaces/pool/IPoolStorage.sol';
import {IBasePositionManager} from '../interfaces/periphery/IBasePositionManager.sol';
import {MathConstants as C} from '../libraries/MathConstants.sol';
import {QtyDeltaMath} from '../libraries/QtyDeltaMath.sol';
import {FullMath} from '../libraries/FullMath.sol';
import {ReinvestmentMath} from '../libraries/ReinvestmentMath.sol';
import {SafeCast} from '../libraries/SafeCast.sol';
import {TickMath as T} from '../libraries/TickMath.sol';

contract TicksFeesReader {
    using SafeCast for uint256;

    /// @dev Simplest method that attempts to fetch all initialized ticks
    /// Has the highest probability of running out of gas
    function getAllTicks(IPoolStorage pool) external view returns (int24[] memory allTicks) {
        // + 3 because of MIN_TICK, 0 and MAX_TICK
        // count (1, MAX_TICK - 1) * 2
        uint32 maxNumTicks = uint32((uint256(int256((T.MAX_TICK - 1) / pool.tickDistance()))) * 2 + 3);
        allTicks = new int24[](maxNumTicks);
        int24 currentTick = T.MIN_TICK;
        allTicks[0] = currentTick;
        uint32 i = 1;
        while (currentTick < T.MAX_TICK) {
            (, currentTick) = pool.initializedTicks(currentTick);
            allTicks[i] = currentTick;
            i++;
        }
    }

    /// @dev Fetches all initialized ticks with a specified startTick (searches uptick)
    /// @dev 0 length = Use maximum length
    function getTicksInRange(
        IPoolStorage pool,
        int24 startTick,
        uint32 length
    ) external view returns (int24[] memory allTicks) {
        (int24 previous, int24 next) = pool.initializedTicks(startTick);
        // startTick is uninitialized, return
        if (previous == 0 && next == 0) return allTicks;
        // calculate num ticks from starting tick
        uint32 maxNumTicks;
        if (length == 0) {
            int24 tickDistance = pool.tickDistance(); // tickDistance should always be positive
            if (startTick == T.MIN_TICK) {
                maxNumTicks = uint32((uint256(int256((T.MAX_TICK - 1) / tickDistance))) * 2 + 3);
            } else if (startTick == T.MAX_TICK) {
                maxNumTicks = 1;
            } else {
                // startTick % tickDistance == 0
                maxNumTicks = uint32(uint256(int256((T.MAX_TICK - 1 - startTick) / tickDistance))) + 2;
            }
        } else {
            maxNumTicks = length;
        }

        allTicks = new int24[](maxNumTicks);
        for (uint32 i = 0; i < maxNumTicks; i++) {
            allTicks[i] = startTick;
            if (startTick == T.MAX_TICK) break;
            (, startTick) = pool.initializedTicks(startTick);
        }
    }

    function getNearestInitializedTicks(IPoolStorage pool, int24 tick)
    external
    view
    returns (int24 previous, int24 next)
    {
        require(T.MIN_TICK <= tick && tick <= T.MAX_TICK, 'tick not in range');
        // if queried tick already initialized, fetch and return values
        (previous, next) = pool.initializedTicks(tick);
        if (previous != 0 || next != 0) return (previous, next);

        // search downtick from MAX_TICK
        if (tick > 0) {
            previous = T.MAX_TICK;
            while (previous > tick) {
                (previous, ) = pool.initializedTicks(previous);
            }
            (, next) = pool.initializedTicks(previous);
        } else {
            // search uptick from MIN_TICK
            next = T.MIN_TICK;
            while (next < tick) {
                (, next) = pool.initializedTicks(next);
            }
            (previous, ) = pool.initializedTicks(next);
        }
    }

    function getTotalRTokensOwedToPosition(
        IBasePositionManager posManager,
        IPoolStorage pool,
        uint256 tokenId
    ) public view returns (uint256 rTokenOwed) {
        (IBasePositionManager.Position memory pos, ) = posManager.positions(tokenId);
        require(
            posManager.addressToPoolId(address(pool)) == pos.poolId,
            'tokenId and pool dont match'
        );

        // sync pool fee growth
        (uint256 feeGrowthGlobal, ) = _syncFeeGrowthGlobal(pool);
        // calc feeGrowthInside
        uint256 feeGrowthInside = _calcFeeGrowthInside(pool, pos, feeGrowthGlobal);
        // take difference in feeGrowthInside against position feeGrowthInside
        if (feeGrowthInside != pos.feeGrowthInsideLast) {
            uint256 feeGrowthInsideDiff;
        unchecked {
            feeGrowthInsideDiff = feeGrowthInside - pos.feeGrowthInsideLast;
        }
            pos.rTokenOwed += FullMath.mulDivFloor(pos.liquidity, feeGrowthInsideDiff, C.TWO_POW_96);
        }
        rTokenOwed = pos.rTokenOwed;
    }

    function getTotalFeesOwedToPosition(
        IBasePositionManager posManager,
        IPoolStorage pool,
        uint256 tokenId
    ) external view returns (uint256 token0Owed, uint256 token1Owed) {
        (IBasePositionManager.Position memory pos, ) = posManager.positions(tokenId);
        require(
            posManager.addressToPoolId(address(pool)) == pos.poolId,
            'tokenId and pool dont match'
        );
        // sync pool fee growth and rTotalSupply
        (uint256 feeGrowthGlobal, uint256 rTotalSupply) = _syncFeeGrowthGlobal(pool);
        // calc feeGrowthInside
        uint256 feeGrowthInside = _calcFeeGrowthInside(pool, pos, feeGrowthGlobal);
        // take difference in feeGrowthInside against position feeGrowthInside
        if (feeGrowthInside != pos.feeGrowthInsideLast) {
            uint256 feeGrowthInsideDiff;
        unchecked {
            feeGrowthInsideDiff = feeGrowthInside - pos.feeGrowthInsideLast;
        }
            pos.rTokenOwed += FullMath.mulDivFloor(pos.liquidity, feeGrowthInsideDiff, C.TWO_POW_96);
        }

        (, uint128 reinvestL, ) = pool.getLiquidityState();
        uint256 deltaL = FullMath.mulDivFloor(pos.rTokenOwed, reinvestL, rTotalSupply);
        (uint160 sqrtP, , , ) = pool.getPoolState();
        // finally, calculate token amounts owed
        token0Owed = QtyDeltaMath.getQty0FromBurnRTokens(sqrtP, deltaL);
        token1Owed = QtyDeltaMath.getQty1FromBurnRTokens(sqrtP, deltaL);
    }

    function _syncFeeGrowthGlobal(IPoolStorage pool)
    internal
    view
    returns (uint256 feeGrowthGlobal, uint256 rTotalSupply)
    {
        (uint128 baseL, uint128 reinvestL, uint128 reinvestLLast) = pool.getLiquidityState();
        feeGrowthGlobal = pool.getFeeGrowthGlobal();
        rTotalSupply = IERC20(address(pool)).totalSupply();
        // logic ported from Pool._syncFeeGrowth()
        uint256 rMintQty = ReinvestmentMath.calcrMintQty(
            uint256(reinvestL),
            uint256(reinvestLLast),
            baseL,
            rTotalSupply
        );

        if (rMintQty != 0) {
            // add rMintQty to rTotalSupply before deductGovermentFee
            rTotalSupply += rMintQty;

            rMintQty = _deductGovermentFee(pool, rMintQty);
        unchecked {
            feeGrowthGlobal += FullMath.mulDivFloor(rMintQty, C.TWO_POW_96, baseL);
        }
        }
    }

    /// @return the lp fee without governance fee
    function _deductGovermentFee(IPoolStorage pool, uint256 rMintQty)
    internal
    view
    returns (uint256)
    {
        // fetch governmentFeeUnits
        (, uint24 governmentFeeUnits) = pool.factory().feeConfiguration();
        if (governmentFeeUnits == 0) {
            return rMintQty;
        }

        unchecked {
            uint256 rGovtQty = (rMintQty * governmentFeeUnits) / C.FEE_UNITS;
            return rMintQty - rGovtQty;
        }
    }

    function _calcFeeGrowthInside(
        IPoolStorage pool,
        IBasePositionManager.Position memory pos,
        uint256 feeGrowthGlobal
    ) internal view returns (uint256 feeGrowthInside) {
        (, , uint256 feeGrowthOutsideLowerTick, ) = pool.ticks(pos.tickLower);
        (, , uint256 feeGrowthOutsideUpperTick, ) = pool.ticks(pos.tickUpper);
        (, int24 currentTick, , ) = pool.getPoolState();

        unchecked {
            if (currentTick < pos.tickLower) {
                feeGrowthInside = feeGrowthOutsideLowerTick - feeGrowthOutsideUpperTick;
            } else if (currentTick >= pos.tickUpper) {
                feeGrowthInside = feeGrowthOutsideUpperTick - feeGrowthOutsideLowerTick;
            } else {
                feeGrowthInside = feeGrowthGlobal - feeGrowthOutsideLowerTick - feeGrowthOutsideUpperTick;
            }
        }
    }
}
