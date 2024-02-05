// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../interface/IRouter.sol";
import "../interface/IFactory.sol";
import "../interface/IPair.sol";
import "../lib/Math.sol";

contract SwapLibrary {
    address public immutable factory;
    IRouter public immutable router;
    bytes32 immutable pairCodeHash;

    constructor(address _router) {
        router = IRouter(_router);
        factory = IRouter(_router).factory();
        pairCodeHash = IFactory(IRouter(_router).factory()).pairCodeHash();
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

    function _get_y(
        uint256 x0,
        uint256 xy,
        uint256 y
    ) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 y_prev = y;
            uint256 k = _f(x0, y);
            if (k < xy) {
                uint256 dy = ((xy - k) * 1e18) / _d(x0, y);
                y = y + dy;
            } else {
                uint256 dy = ((k - xy) * 1e18) / _d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }

    function getTradeDiff(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        bool stable
    ) external view returns (uint256 a, uint256 b) {
        (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            bool st,
            address t0,

        ) = IPair(router.pairFor(tokenIn, tokenOut, stable)).metadata();
        uint256 sample = tokenIn == t0 ? (r0 * dec1) / r1 : (r1 * dec0) / r0;
        a =
            (_getAmountOut(sample, tokenIn, r0, r1, t0, dec0, dec1, st) *
                1e18) /
            sample;
        b =
            (_getAmountOut(amountIn, tokenIn, r0, r1, t0, dec0, dec1, st) *
                1e18) /
            amountIn;
    }

    function getTradeDiffSimple(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        bool stable,
        uint256 sample
    ) external view returns (uint256 a, uint256 b) {
        (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            bool st,
            address t0,

        ) = IPair(router.pairFor(tokenIn, tokenOut, stable)).metadata();
        if (sample == 0) {
            sample = _calcSample(tokenIn, t0, dec0, dec1);
        }
        a =
            (_getAmountOut(sample, tokenIn, r0, r1, t0, dec0, dec1, st) *
                1e18) /
            sample;
        b =
            (_getAmountOut(amountIn, tokenIn, r0, r1, t0, dec0, dec1, st) *
                1e18) /
            amountIn;
    }

    function getTradeDiff2(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        bool stable
    ) external view returns (uint256 a, uint256 b) {
        (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            bool st,
            address t0,

        ) = IPair(router.pairFor(tokenIn, tokenOut, stable)).metadata();
        uint256 sample;
        if (!stable) {
            sample = tokenIn == t0 ? (r0 * dec1) / r1 : (r1 * dec0) / r0;
        } else {
            sample = _calcSample(tokenIn, t0, dec0, dec1);
        }
        a =
            (_getAmountOut(sample, tokenIn, r0, r1, t0, dec0, dec1, st) *
                1e18) /
            sample;
        b =
            (_getAmountOut(amountIn, tokenIn, r0, r1, t0, dec0, dec1, st) *
                1e18) /
            amountIn;
    }

    function getTradeDiff3(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        bool stable
    ) external view returns (uint256 a, uint256 b) {
        (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            bool st,
            address t0,

        ) = IPair(router.pairFor(tokenIn, tokenOut, stable)).metadata();
        uint256 sample;
        if (!stable) {
            a =
                (amountIn * 1e18) /
                (tokenIn == t0 ? (r0 * 1e18) / r1 : (r1 * 1e18) / r0);
        } else {
            sample = _calcSample(tokenIn, t0, dec0, dec1);
            a =
                (_getAmountOut(sample, tokenIn, r0, r1, t0, dec0, dec1, st) *
                    amountIn) /
                sample;
        }
        b = _getAmountOut(amountIn, tokenIn, r0, r1, t0, dec0, dec1, st);
    }

    function _calcSample(
        address tokenIn,
        address t0,
        uint256 dec0,
        uint256 dec1
    ) internal pure returns (uint256) {
        uint256 tokenInDecimals = tokenIn == t0 ? dec0 : dec1;
        uint256 tokenOutDecimals = tokenIn == t0 ? dec1 : dec0;
        return
            10 **
                Math.max(
                    (
                        tokenInDecimals > tokenOutDecimals
                            ? tokenInDecimals - tokenOutDecimals
                            : tokenOutDecimals - tokenInDecimals
                    ),
                    1
                ) *
            10_000;
    }

    function getTradeDiff(
        uint256 amountIn,
        address tokenIn,
        address pair
    ) external view returns (uint256 a, uint256 b) {
        (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            bool st,
            address t0,

        ) = IPair(pair).metadata();
        uint256 sample = tokenIn == t0 ? (r0 * dec1) / r1 : (r1 * dec0) / r0;
        a =
            (_getAmountOut(sample, tokenIn, r0, r1, t0, dec0, dec1, st) *
                1e18) /
            sample;
        b =
            (_getAmountOut(amountIn, tokenIn, r0, r1, t0, dec0, dec1, st) *
                1e18) /
            amountIn;
    }

    function getSample(
        address tokenIn,
        address tokenOut,
        bool stable
    ) external view returns (uint256) {
        (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            bool st,
            address t0,

        ) = IPair(router.pairFor(tokenIn, tokenOut, stable)).metadata();
        uint256 sample = tokenIn == t0 ? (r0 * dec1) / r1 : (r1 * dec0) / r0;
        return
            (_getAmountOut(sample, tokenIn, r0, r1, t0, dec0, dec1, st) *
                1e18) / sample;
    }

    function getMinimumValue(
        address tokenIn,
        address tokenOut,
        bool stable
    ) external view returns (uint256, uint256, uint256) {
        (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            ,
            address t0,

        ) = IPair(router.pairFor(tokenIn, tokenOut, stable)).metadata();
        uint256 sample = tokenIn == t0 ? (r0 * dec1) / r1 : (r1 * dec0) / r0;
        return (sample, r0, r1);
    }

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        bool stable
    ) external view returns (uint256) {
        (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            bool st,
            address t0,

        ) = IPair(router.pairFor(tokenIn, tokenOut, stable)).metadata();
        return
            (_getAmountOut(amountIn, tokenIn, r0, r1, t0, dec0, dec1, st) *
                1e18) / amountIn;
    }

    function _getAmountOut(
        uint256 amountIn,
        address tokenIn,
        uint256 _reserve0,
        uint256 _reserve1,
        address token0,
        uint256 decimals0,
        uint256 decimals1,
        bool stable
    ) internal pure returns (uint256) {
        if (stable) {
            uint256 xy = _k(_reserve0, _reserve1, stable, decimals0, decimals1);
            _reserve0 = (_reserve0 * 1e18) / decimals0;
            _reserve1 = (_reserve1 * 1e18) / decimals1;
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0
                ? (_reserve0, _reserve1)
                : (_reserve1, _reserve0);
            amountIn = tokenIn == token0
                ? (amountIn * 1e18) / decimals0
                : (amountIn * 1e18) / decimals1;
            uint256 y = reserveB - _get_y(amountIn + reserveA, xy, reserveB);
            return (y * (tokenIn == token0 ? decimals1 : decimals0)) / 1e18;
        } else {
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0
                ? (_reserve0, _reserve1)
                : (_reserve1, _reserve0);
            return (amountIn * reserveB) / (reserveA + amountIn);
        }
    }

    function _k(
        uint256 x,
        uint256 y,
        bool stable,
        uint256 decimals0,
        uint256 decimals1
    ) internal pure returns (uint256) {
        if (stable) {
            uint256 _x = (x * 1e18) / decimals0;
            uint256 _y = (y * 1e18) / decimals1;
            uint256 _a = (_x * _y) / 1e18;
            uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
            return (_a * _b) / 1e18;
            // x3y+y3x >= k
        } else {
            return x * y;
            // xy >= k
        }
    }

    function getNormalizedReserves(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (uint256 reserveA, uint256 reserveB) {
        address pair = pairFor(tokenA, tokenB, stable);
        if (pair == address(0)) {
            return (0, 0);
        }
        (
            uint256 decimals0,
            uint256 decimals1,
            uint256 reserve0,
            uint256 reserve1,
            ,
            address t0,
            address t1
        ) = IPair(pair).metadata();

        reserveA = tokenA == t0 ? reserve0 : reserve1;
        reserveB = tokenA == t1 ? reserve0 : reserve1;
        uint256 decimalsA = tokenA == t0 ? decimals0 : decimals1;
        uint256 decimalsB = tokenA == t1 ? decimals0 : decimals1;
        reserveA = (reserveA * 1e18) / decimalsA;
        reserveB = (reserveB * 1e18) / decimalsB;
    }

    /// @dev Calculates the CREATE2 address for a pair without making any external calls.
    function pairFor(
        address tokenA,
        address tokenB,
        bool stable
    ) public view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1, stable)),
                            pairCodeHash // init code hash
                        )
                    )
                )
            )
        );
    }

    function sortTokens(
        address tokenA,
        address tokenB
    ) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "ZERO_ADDRESS");
    }
}
