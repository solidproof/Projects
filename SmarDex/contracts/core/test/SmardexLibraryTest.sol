// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.17;

// libraries
import "../libraries/SmardexLibrary.sol";

contract SmardexLibraryTest {
    function approxEq(uint256 x, uint256 y) internal pure returns (bool) {
        return SmardexLibrary.approxEq(x, y);
    }

    function ratioApproxEq(uint256 _xNum, uint256 _xDen, uint256 _yNum, uint256 _yDen) external pure returns (bool) {
        return SmardexLibrary.ratioApproxEq(_xNum, _xDen, _yNum, _yDen);
    }

    function getUpdatedPriceAverage(
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageLastTimestamp,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut,
        uint256 _currentTimestamp
    ) external pure returns (uint256 newPriceAverageIn_, uint256 newPriceAverageOut_) {
        return
            SmardexLibrary.getUpdatedPriceAverage(
                _fictiveReserveIn,
                _fictiveReserveOut,
                _priceAverageLastTimestamp,
                _priceAverageIn,
                _priceAverageOut,
                _currentTimestamp
            );
    }

    function computeFirstTradeQtyIn(
        uint256 _amountIn,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut
    ) external pure returns (uint256 firstAmountIn_) {
        return
            SmardexLibrary.computeFirstTradeQtyIn(
                _amountIn,
                _fictiveReserveIn,
                _fictiveReserveOut,
                _priceAverageIn,
                _priceAverageOut
            );
    }

    function computeFirstTradeQtyOut(
        uint256 _amountOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut
    ) external pure returns (uint256 firstAmountOut_) {
        return
            SmardexLibrary.computeFirstTradeQtyOut(
                _amountOut,
                _fictiveReserveIn,
                _fictiveReserveOut,
                _priceAverageIn,
                _priceAverageOut
            );
    }

    function computeFictiveReserves(
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut
    ) external pure returns (uint256 newFictiveReserveIn_, uint256 newFictiveReserveOut_) {
        return SmardexLibrary.computeFictiveReserves(_reserveIn, _reserveOut, _fictiveReserveIn, _fictiveReserveOut);
    }

    function applyKConstRuleOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut
    )
        external
        pure
        returns (
            uint256 amountOut_,
            uint256 newReserveIn_,
            uint256 newReserveOut_,
            uint256 newFictiveReserveIn_,
            uint256 newFictiveReserveOut_
        )
    {
        return
            SmardexLibrary.applyKConstRuleOut(
                _amountIn,
                _reserveIn,
                _reserveOut,
                _fictiveReserveIn,
                _fictiveReserveOut
            );
    }

    function applyKConstRuleIn(
        uint256 _amountOut,
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut
    )
        external
        pure
        returns (
            uint256 amountIn_,
            uint256 newReserveIn_,
            uint256 newReserveOut_,
            uint256 newFictiveReserveIn_,
            uint256 newFictiveReserveOut_
        )
    {
        return
            SmardexLibrary.applyKConstRuleIn(
                _amountOut,
                _reserveIn,
                _reserveOut,
                _fictiveReserveIn,
                _fictiveReserveOut
            );
    }

    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut
    )
        external
        pure
        returns (
            uint256 amountOut_,
            uint256 newReserveIn_,
            uint256 newReserveOut_,
            uint256 newFictiveReserveIn_,
            uint256 newFictiveReserveOut_
        )
    {
        return
            SmardexLibrary.getAmountOut(
                _amountIn,
                _reserveIn,
                _reserveOut,
                _fictiveReserveIn,
                _fictiveReserveOut,
                _priceAverageIn,
                _priceAverageOut
            );
    }

    function getAmountIn(
        uint256 _amountOut,
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut
    )
        external
        pure
        returns (
            uint256 amountIn_,
            uint256 newReserveIn_,
            uint256 newReserveOut_,
            uint256 newFictiveReserveIn_,
            uint256 newFictiveReserveOut_
        )
    {
        return
            SmardexLibrary.getAmountIn(
                _amountOut,
                _reserveIn,
                _reserveOut,
                _fictiveReserveIn,
                _fictiveReserveOut,
                _priceAverageIn,
                _priceAverageOut
            );
    }
}
