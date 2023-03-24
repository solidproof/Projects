// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

// libraries
import "@openzeppelin/contracts/utils/math/Math.sol";

// interfaces
import "../interfaces/ISmardexPair.sol";

library SmardexLibrary {
    /// @notice amount of fees sent to LP, not in percent but in FEES_BASE
    uint256 public constant FEES_LP = 5;

    /// @notice amount of fees sent to the pool, not in percent but in FEES_BASE. if feeTo is null, sent to the LP
    uint256 public constant FEES_POOL = 2;

    /// @notice total amount of fees, not in percent but in FEES_BASE
    uint256 public constant FEES_TOTAL = FEES_LP + FEES_POOL;

    /// @notice base of the FEES
    uint256 public constant FEES_BASE = 10000;

    /// @notice ratio of quantity that is send to the user, after removing the fees, not in percent but in FEES_BASE
    uint256 public constant REVERSE_FEES_TOTAL = FEES_BASE - FEES_TOTAL;

    /// @notice precision for approxEq, not in percent but in APPROX_PRECISION_BASE
    uint256 public constant APPROX_PRECISION = 1;

    /// @notice base of the APPROX_PRECISION
    uint256 public constant APPROX_PRECISION_BASE = 1_000_000;

    /// @notice number of seconds to reset priceAverage
    uint256 private constant MAX_BLOCK_DIFF_SECONDS = 300;

    /**
     * @notice check if 2 numbers are approximatively equal, using APPROX_PRECISION
     * @param _x number to compare
     * @param _y number to compare
     * @return true if numbers are approximatively equal, false otherwise
     */
    function approxEq(uint256 _x, uint256 _y) internal pure returns (bool) {
        if (_x > _y) {
            return _x < (_y + (_y * APPROX_PRECISION) / APPROX_PRECISION_BASE);
        } else {
            return _y < (_x + (_x * APPROX_PRECISION) / APPROX_PRECISION_BASE);
        }
    }

    /**
     * @notice check if 2 ratio are approximatively equal: _xNum _/ xDen ~= _yNum / _yDen
     * @param _xNum numerator of the first ratio to compare
     * @param _xDen denominator of the first ratio to compare
     * @param _yNum numerator of the second ratio to compare
     * @param _yDen denominator of the second ratio to compare
     * @return true if ratio are approximatively equal, false otherwise
     */
    function ratioApproxEq(uint256 _xNum, uint256 _xDen, uint256 _yNum, uint256 _yDen) internal pure returns (bool) {
        return approxEq(_xNum * _yDen, _xDen * _yNum);
    }

    /**
     * @notice update priceAverage given old timestamp, new timestamp and prices
     * @param _fictiveReserveIn ratio component of the new price of the in-token
     * @param _fictiveReserveOut ratio component of the new price of the out-token
     * @param _priceAverageLastTimestamp timestamp of the last priceAvregae update (0, if never updated)
     * @param _priceAverageIn ratio component of the last priceAverage of the in-token
     * @param _priceAverageOut ratio component of the last priceAverage of the out-token
     * @param _currentTimestamp timestamp of the priceAverage to update
     * @return newPriceAverageIn_ ratio component of the updated priceAverage of the in-token
     * @return newPriceAverageOut_ ratio component of the updated priceAverage of the out-token
     */
    function getUpdatedPriceAverage(
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageLastTimestamp,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut,
        uint256 _currentTimestamp
    ) internal pure returns (uint256 newPriceAverageIn_, uint256 newPriceAverageOut_) {
        require(_currentTimestamp >= _priceAverageLastTimestamp, "SmardexPair: INVALID_TIMESTAMP");

        // very first time
        if (_priceAverageLastTimestamp == 0) {
            newPriceAverageIn_ = _fictiveReserveIn;
            newPriceAverageOut_ = _fictiveReserveOut;
        }
        // another tx has been done in the same block
        else if (_priceAverageLastTimestamp == _currentTimestamp) {
            newPriceAverageIn_ = _priceAverageIn;
            newPriceAverageOut_ = _priceAverageOut;
        }
        // need to compute new linear-average price
        else {
            // compute new price:
            uint256 _timeDiff = Math.min(_currentTimestamp - _priceAverageLastTimestamp, MAX_BLOCK_DIFF_SECONDS);

            newPriceAverageIn_ = _fictiveReserveIn;
            newPriceAverageOut_ =
                (((MAX_BLOCK_DIFF_SECONDS - _timeDiff) * _priceAverageOut * newPriceAverageIn_) /
                    _priceAverageIn +
                    _timeDiff *
                    _fictiveReserveOut) /
                MAX_BLOCK_DIFF_SECONDS;
        }
    }

    /**
     * @notice compute the firstTradeAmountIn so that the price reach the price Average
     * @param _amountIn the amountIn requested, it's the maximum possible value for firstAmountIn_
     * @param _fictiveReserveIn fictive reserve of the in-token
     * @param _fictiveReserveOut fictive reserve of the out-token
     * @param _priceAverageIn ratio component of the priceAverage of the in-token
     * @param _priceAverageOut ratio component of the priceAverage of the out-token
     * @return firstAmountIn_ the first amount of in-token
     *
     * @dev if the trade is going in the direction that the price will never reach the priceAverage, or if _amountIn
     * is not big enough to reach the priceAverage or if the price is already equal to the priceAverage, then
     * firstAmountIn_ will be set to _amountIn
     */
    function computeFirstTradeQtyIn(
        uint256 _amountIn,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut
    ) internal pure returns (uint256 firstAmountIn_) {
        // default value
        firstAmountIn_ = _amountIn;

        // if trade is in the good direction
        if (_fictiveReserveOut * _priceAverageIn > _fictiveReserveIn * _priceAverageOut) {
            // pre-compute all operands
            uint256 _toSub = _fictiveReserveIn * (FEES_BASE + REVERSE_FEES_TOTAL - FEES_POOL);
            uint256 _toDiv = (REVERSE_FEES_TOTAL + FEES_LP) << 1;
            uint256 _inSqrt = (((_fictiveReserveIn * _fictiveReserveOut) << 2) / _priceAverageOut) *
                _priceAverageIn *
                (REVERSE_FEES_TOTAL * (FEES_BASE - FEES_POOL)) +
                (_fictiveReserveIn * _fictiveReserveIn * (FEES_LP * FEES_LP));

            // reverse sqrt check to only compute sqrt if really needed
            if (_inSqrt < (_toSub + _amountIn * _toDiv) ** 2) {
                firstAmountIn_ = (Math.sqrt(_inSqrt) - _toSub) / _toDiv;
            }
        }
    }

    /**
     * @notice compute the firstTradeAmountOut so that the price reach the price Average
     * @param _amountOut the amountOut requested, it's the maximum possible value for firstAmountOut_
     * @param _fictiveReserveIn fictive reserve of the in-token
     * @param _fictiveReserveOut fictive reserve of the out-token
     * @param _priceAverageIn ratio component of the priceAverage of the in-token
     * @param _priceAverageOut ratio component of the priceAverage of the out-token
     * @return firstAmountOut_ the first amount of out-token
     *
     * @dev if the trade is going in the direction that the price will never reach the priceAverage, or if _amountOut
     * is not big enough to reach the priceAverage or if the price is already equal to the priceAverage, then
     * firstAmountOut_ will be set to _amountOut
     */
    function computeFirstTradeQtyOut(
        uint256 _amountOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut
    ) internal pure returns (uint256 firstAmountOut_) {
        // default value
        firstAmountOut_ = _amountOut;

        // if trade is in the good direction
        if (_fictiveReserveOut * _priceAverageIn > _fictiveReserveIn * _priceAverageOut) {
            // pre-compute all operands
            uint256 _fictiveReserveOutPredFees = (_fictiveReserveIn * FEES_LP * _priceAverageOut) / _priceAverageIn;
            uint256 _toAdd = ((_fictiveReserveOut * REVERSE_FEES_TOTAL) << 1) + _fictiveReserveOutPredFees;
            uint256 _toDiv = REVERSE_FEES_TOTAL << 1;
            uint256 _inSqrt = (((_fictiveReserveOut * _fictiveReserveOutPredFees) << 2) *
                (REVERSE_FEES_TOTAL * (FEES_BASE - FEES_POOL))) /
                FEES_LP +
                _fictiveReserveOutPredFees *
                _fictiveReserveOutPredFees;

            // reverse sqrt check to only compute sqrt if really needed
            if (_inSqrt > (_toAdd - _amountOut * _toDiv) ** 2) {
                firstAmountOut_ = (_toAdd - Math.sqrt(_inSqrt)) / _toDiv;
            }
        }
    }

    /**
     * @notice compute fictive reserves
     * @param _reserveIn reserve of the in-token
     * @param _reserveOut reserve of the out-token
     * @param _fictiveReserveIn fictive reserve of the in-token
     * @param _fictiveReserveOut fictive reserve of the out-token
     * @return newFictiveReserveIn_ new fictive reserve of the in-token
     * @return newFictiveReserveOut_ new fictive reserve of the out-token
     */
    function computeFictiveReserves(
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut
    ) internal pure returns (uint256 newFictiveReserveIn_, uint256 newFictiveReserveOut_) {
        if (_reserveOut * _fictiveReserveIn < _reserveIn * _fictiveReserveOut) {
            uint256 _temp = (((_reserveOut * _reserveOut) / _fictiveReserveOut) * _fictiveReserveIn) / _reserveIn;
            newFictiveReserveIn_ =
                (_temp * _fictiveReserveIn) /
                _fictiveReserveOut +
                (_reserveOut * _fictiveReserveIn) /
                _fictiveReserveOut;
            newFictiveReserveOut_ = _reserveOut + _temp;
        } else {
            newFictiveReserveIn_ = (_fictiveReserveIn * _reserveOut) / _fictiveReserveOut + _reserveIn;
            newFictiveReserveOut_ = (_reserveIn * _fictiveReserveOut) / _fictiveReserveIn + _reserveOut;
        }

        // div all values by 4
        newFictiveReserveIn_ >>= 2;
        newFictiveReserveOut_ >>= 2;
    }

    /**
     * @notice apply k const rule using fictive reserve, when the amountIn is specified
     * @param _amountIn qty of token that arrives in the contract
     * @param _reserveIn reserve of the in-token
     * @param _reserveOut reserve of the out-token
     * @param _fictiveReserveIn fictive reserve of the in-token
     * @param _fictiveReserveOut fictive reserve of the out-token
     * @return amountOut_ qty of token that leaves in the contract
     * @return newReserveIn_ new reserve of the in-token after the transaction
     * @return newReserveOut_ new reserve of the out-token after the transaction
     * @return newFictiveReserveIn_ new fictive reserve of the in-token after the transaction
     * @return newFictiveReserveOut_ new fictive reserve of the out-token after the transaction
     */
    function applyKConstRuleOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut
    )
        internal
        pure
        returns (
            uint256 amountOut_,
            uint256 newReserveIn_,
            uint256 newReserveOut_,
            uint256 newFictiveReserveIn_,
            uint256 newFictiveReserveOut_
        )
    {
        // k const rule
        uint256 _amountInWithFee = _amountIn * REVERSE_FEES_TOTAL;
        uint256 _numerator = _amountInWithFee * _fictiveReserveOut;
        uint256 _denominator = _fictiveReserveIn * FEES_BASE + _amountInWithFee;
        amountOut_ = _numerator / _denominator;

        // update new reserves and add lp-fees to pools
        uint256 _amountInWithFeeLp = (_amountInWithFee + (_amountIn * FEES_LP)) / FEES_BASE;
        newReserveIn_ = _reserveIn + _amountInWithFeeLp;
        newFictiveReserveIn_ = _fictiveReserveIn + _amountInWithFeeLp;
        newReserveOut_ = _reserveOut - amountOut_;
        newFictiveReserveOut_ = _fictiveReserveOut - amountOut_;
    }

    /**
     * @notice apply k const rule using fictive reserve, when the amountOut is specified
     * @param _amountOut qty of token that leaves in the contract
     * @param _reserveIn reserve of the in-token
     * @param _reserveOut reserve of the out-token
     * @param _fictiveReserveIn fictive reserve of the in-token
     * @param _fictiveReserveOut fictive reserve of the out-token
     * @return amountIn_ qty of token that arrives in the contract
     * @return newReserveIn_ new reserve of the in-token after the transaction
     * @return newReserveOut_ new reserve of the out-token after the transaction
     * @return newFictiveReserveIn_ new fictive reserve of the in-token after the transaction
     * @return newFictiveReserveOut_ new fictive reserve of the out-token after the transaction
     */
    function applyKConstRuleIn(
        uint256 _amountOut,
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut
    )
        internal
        pure
        returns (
            uint256 amountIn_,
            uint256 newReserveIn_,
            uint256 newReserveOut_,
            uint256 newFictiveReserveIn_,
            uint256 newFictiveReserveOut_
        )
    {
        // k const rule
        uint256 _numerator = _fictiveReserveIn * _amountOut * FEES_BASE;
        uint256 _denominator = (_fictiveReserveOut - _amountOut) * REVERSE_FEES_TOTAL;
        amountIn_ = _numerator / _denominator + 1;

        // update new reserves
        uint256 _amountInWithFeeLp = (amountIn_ * (REVERSE_FEES_TOTAL + FEES_LP)) / FEES_BASE;
        newReserveIn_ = _reserveIn + _amountInWithFeeLp;
        newFictiveReserveIn_ = _fictiveReserveIn + _amountInWithFeeLp;
        newReserveOut_ = _reserveOut - _amountOut;
        newFictiveReserveOut_ = _fictiveReserveOut - _amountOut;
    }

    /**
     * @notice return the amount of tokens the user would get by doing a swap
     * @param _amountIn quantity of token the user want to swap (to sell)
     * @param _reserveIn reserves of the selling token (getReserve())
     * @param _reserveOut reserves of the buying token (getReserve())
     * @param _fictiveReserveIn fictive reserve of the selling token (getFictiveReserves())
     * @param _fictiveReserveOut fictive reserve of the buying token (getFictiveReserves())
     * @param _priceAverageIn price average of the selling token
     * @param _priceAverageOut price average of the buying token
     * @return amountOut_ The amount of token the user would receive
     * @return newReserveIn_ reserves of the selling token after the swap
     * @return newReserveOut_ reserves of the buying token after the swap
     * @return newFictiveReserveIn_ fictive reserve of the selling token after the swap
     * @return newFictiveReserveOut_ fictive reserve of the buying token after the swap
     */
    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut
    )
        internal
        pure
        returns (
            uint256 amountOut_,
            uint256 newReserveIn_,
            uint256 newReserveOut_,
            uint256 newFictiveReserveIn_,
            uint256 newFictiveReserveOut_
        )
    {
        require(_amountIn > 0, "SmarDexLibrary: INSUFFICIENT_INPUT_AMOUNT");
        require(
            _reserveIn > 0 && _reserveOut > 0 && _fictiveReserveIn > 0 && _fictiveReserveOut > 0,
            "SmarDexLibrary: INSUFFICIENT_LIQUIDITY"
        );

        uint256 _amountInWithFees = (_amountIn * REVERSE_FEES_TOTAL) / FEES_BASE;
        uint256 _firstAmountIn = computeFirstTradeQtyIn(
            _amountInWithFees,
            _fictiveReserveIn,
            _fictiveReserveOut,
            _priceAverageIn,
            _priceAverageOut
        );

        // if there is 2 trade: 1st trade mustn't re-compute fictive reserves, 2nd should
        if (
            _firstAmountIn == _amountInWithFees &&
            ratioApproxEq(_fictiveReserveIn, _fictiveReserveOut, _priceAverageIn, _priceAverageOut)
        ) {
            (_fictiveReserveIn, _fictiveReserveOut) = computeFictiveReserves(
                _reserveIn,
                _reserveOut,
                _fictiveReserveIn,
                _fictiveReserveOut
            );
        }

        // avoid stack too deep
        {
            uint256 _firstAmountInNoFees = (_firstAmountIn * FEES_BASE) / REVERSE_FEES_TOTAL;
            (
                amountOut_,
                newReserveIn_,
                newReserveOut_,
                newFictiveReserveIn_,
                newFictiveReserveOut_
            ) = applyKConstRuleOut(
                _firstAmountInNoFees,
                _reserveIn,
                _reserveOut,
                _fictiveReserveIn,
                _fictiveReserveOut
            );

            // update amountIn in case there is a second trade
            _amountIn -= _firstAmountInNoFees;
        }

        // if we need a second trade
        if (_firstAmountIn < _amountInWithFees) {
            // in the second trade ALWAYS recompute fictive reserves
            (newFictiveReserveIn_, newFictiveReserveOut_) = computeFictiveReserves(
                newReserveIn_,
                newReserveOut_,
                newFictiveReserveIn_,
                newFictiveReserveOut_
            );

            uint256 _secondAmountOutNoFees;
            (
                _secondAmountOutNoFees,
                newReserveIn_,
                newReserveOut_,
                newFictiveReserveIn_,
                newFictiveReserveOut_
            ) = applyKConstRuleOut(
                _amountIn,
                newReserveIn_,
                newReserveOut_,
                newFictiveReserveIn_,
                newFictiveReserveOut_
            );
            amountOut_ += _secondAmountOutNoFees;
        }
    }

    /**
     * @notice return the amount of tokens the user should spend by doing a swap
     * @param _amountOut quantity of token the user want to swap (to buy)
     * @param _reserveIn reserves of the selling token (getReserve())
     * @param _reserveOut reserves of the buying token (getReserve())
     * @param _fictiveReserveIn fictive reserve of the selling token (getFictiveReserves())
     * @param _fictiveReserveOut fictive reserve of the buying token (getFictiveReserves())
     * @param _priceAverageIn price average of the selling token
     * @param _priceAverageOut price average of the buying token
     * @return amountIn_ The amount of token the user would spend to receive _amountOut
     * @return newReserveIn_ reserves of the selling token after the swap
     * @return newReserveOut_ reserves of the buying token after the swap
     * @return newFictiveReserveIn_ fictive reserve of the selling token after the swap
     * @return newFictiveReserveOut_ fictive reserve of the buying token after the swap
     */
    function getAmountIn(
        uint256 _amountOut,
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut
    )
        internal
        pure
        returns (
            uint256 amountIn_,
            uint256 newReserveIn_,
            uint256 newReserveOut_,
            uint256 newFictiveReserveIn_,
            uint256 newFictiveReserveOut_
        )
    {
        require(_amountOut > 0, "SmarDexLibrary: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            _amountOut < _fictiveReserveOut &&
                _reserveIn > 0 &&
                _reserveOut > 0 &&
                _fictiveReserveIn > 0 &&
                _fictiveReserveOut > 0,
            "SmarDexLibrary: INSUFFICIENT_LIQUIDITY"
        );

        uint256 _firstAmountOut = computeFirstTradeQtyOut(
            _amountOut,
            _fictiveReserveIn,
            _fictiveReserveOut,
            _priceAverageIn,
            _priceAverageOut
        );

        // if there is 2 trade: 1st trade mustn't re-compute fictive reserves, 2nd should
        if (
            _firstAmountOut == _amountOut &&
            ratioApproxEq(_fictiveReserveIn, _fictiveReserveOut, _priceAverageIn, _priceAverageOut)
        ) {
            (_fictiveReserveIn, _fictiveReserveOut) = computeFictiveReserves(
                _reserveIn,
                _reserveOut,
                _fictiveReserveIn,
                _fictiveReserveOut
            );
        }

        (amountIn_, newReserveIn_, newReserveOut_, newFictiveReserveIn_, newFictiveReserveOut_) = applyKConstRuleIn(
            _firstAmountOut,
            _reserveIn,
            _reserveOut,
            _fictiveReserveIn,
            _fictiveReserveOut
        );

        // if we need a second trade
        if (_firstAmountOut < _amountOut) {
            // in the second trade ALWAYS recompute fictive reserves
            (newFictiveReserveIn_, newFictiveReserveOut_) = computeFictiveReserves(
                newReserveIn_,
                newReserveOut_,
                newFictiveReserveIn_,
                newFictiveReserveOut_
            );

            uint256 _secondAmountIn;
            (
                _secondAmountIn,
                newReserveIn_,
                newReserveOut_,
                newFictiveReserveIn_,
                newFictiveReserveOut_
            ) = applyKConstRuleIn(
                _amountOut - _firstAmountOut,
                newReserveIn_,
                newReserveOut_,
                newFictiveReserveIn_,
                newFictiveReserveOut_
            );
            amountIn_ += _secondAmountIn;
        }
    }
}
