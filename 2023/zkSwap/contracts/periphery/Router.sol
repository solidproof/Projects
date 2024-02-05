// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.16;
pragma abicoder v2;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {TickMath} from '../libraries/TickMath.sol';
import {SafeCast} from '../libraries/SafeCast.sol';
import {PathHelper} from './libraries/PathHelper.sol';
import {PoolAddress} from './libraries/PoolAddress.sol';

import {IPool} from '../interfaces/IPool.sol';
import {IFactory} from '../interfaces/IFactory.sol';
import {IRouter} from '../interfaces/periphery/IRouter.sol';
import {IWETH} from '../interfaces/IWETH.sol';

import {DeadlineValidation} from './base/DeadlineValidation.sol';
import {Multicall} from './base/Multicall.sol';
import {RouterTokenHelperWithFee} from './base/RouterTokenHelperWithFee.sol';

/// @title KyberSwap V2 Swap Router
contract Router is IRouter, RouterTokenHelperWithFee, Multicall, DeadlineValidation {
    using PathHelper for bytes;
    using SafeCast for uint256;

    /// @dev Use as the placeholder value for amountInCached
    uint256 private constant DEFAULT_AMOUNT_IN_CACHED = type(uint256).max;

    /// @dev Use to cache the computed amount in for an exact output swap.
    uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;

    constructor(address _factory, address _WETH) RouterTokenHelperWithFee(_factory, _WETH) {}

    struct SwapCallbackData {
        bytes path;
        address source;
    }

    function swapCallback(
        int256 deltaQty0,
        int256 deltaQty1,
        bytes calldata data
    ) external override {
        require(deltaQty0 > 0 || deltaQty1 > 0, 'Router: invalid delta qties');
        SwapCallbackData memory swapData = abi.decode(data, (SwapCallbackData));
        (address tokenIn, address tokenOut, uint24 fee) = swapData.path.decodeFirstPool();
        require(
            msg.sender == address(_getPool(tokenIn, tokenOut, fee)),
            'Router: invalid callback sender'
        );

        (bool isExactInput, uint256 amountToTransfer) = deltaQty0 > 0
        ? (tokenIn < tokenOut, uint256(deltaQty0))
        : (tokenOut < tokenIn, uint256(deltaQty1));
        if (isExactInput) {
            // transfer token from source to the pool which is the msg.sender
            // wrap eth -> weth and transfer if needed
            _transferTokens(tokenIn, swapData.source, msg.sender, amountToTransfer);
        } else {
            if (swapData.path.hasMultiplePools()) {
                swapData.path = swapData.path.skipToken();
                _swapExactOutputInternal(amountToTransfer, msg.sender, 0, swapData);
            } else {
                amountInCached = amountToTransfer;
                // transfer tokenOut to the pool (it's the original tokenIn)
                // wrap eth -> weth and transfer if user uses passes eth with the swap
                _transferTokens(tokenOut, swapData.source, msg.sender, amountToTransfer);
            }
        }
    }

    function swapExactInputSingle(ExactInputSingleParams calldata params)
    external
    payable
    override
    onlyNotExpired(params.deadline)
    returns (uint256 amountOut)
    {
        amountOut = _swapExactInputInternal(
            params.amountIn,
            params.recipient,
            params.limitSqrtP,
            SwapCallbackData({
        path: abi.encodePacked(params.tokenIn, params.fee, params.tokenOut),
        source: msg.sender
        })
        );
        require(amountOut >= params.minAmountOut, 'Router: insufficient amountOut');
    }

    function swapExactInput(ExactInputParams memory params)
    external
    payable
    override
    onlyNotExpired(params.deadline)
    returns (uint256 amountOut)
    {
        address source = msg.sender; // msg.sender is the source of tokenIn for the first swap

        while (true) {
            bool hasMultiplePools = params.path.hasMultiplePools();

            params.amountIn = _swapExactInputInternal(
                params.amountIn,
                hasMultiplePools ? address(this) : params.recipient, // for intermediate swaps, this contract custodies
                0,
                SwapCallbackData({path: params.path.getFirstPool(), source: source})
            );

            if (hasMultiplePools) {
                source = address(this);
                params.path = params.path.skipToken();
            } else {
                amountOut = params.amountIn;
                break;
            }
        }

        require(amountOut >= params.minAmountOut, 'Router: insufficient amountOut');
    }

    function swapExactOutputSingle(ExactOutputSingleParams calldata params)
    external
    payable
    override
    onlyNotExpired(params.deadline)
    returns (uint256 amountIn)
    {
        amountIn = _swapExactOutputInternal(
            params.amountOut,
            params.recipient,
            params.limitSqrtP,
            SwapCallbackData({
        path: abi.encodePacked(params.tokenOut, params.fee, params.tokenIn),
        source: msg.sender
        })
        );
        require(amountIn <= params.maxAmountIn, 'Router: amountIn is too high');
        // has to be reset even though we don't use it in the single hop case
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    }

    function swapExactOutput(ExactOutputParams calldata params)
    external
    payable
    override
    onlyNotExpired(params.deadline)
    returns (uint256 amountIn)
    {
        _swapExactOutputInternal(
            params.amountOut,
            params.recipient,
            0,
            SwapCallbackData({path: params.path, source: msg.sender})
        );

        amountIn = amountInCached;
        require(amountIn <= params.maxAmountIn, 'Router: amountIn is too high');
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    }

    /// @dev Performs a single exact input swap
    function _swapExactInputInternal(
        uint256 amountIn,
        address recipient,
        uint160 limitSqrtP,
        SwapCallbackData memory data
    ) private returns (uint256 amountOut) {
        // allow swapping to the router address with address 0
        if (recipient == address(0)) recipient = address(this);

        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();

        bool isFromToken0 = tokenIn < tokenOut;

        (int256 amount0, int256 amount1) = _getPool(tokenIn, tokenOut, fee).swap(
            recipient,
            amountIn.toInt256(),
            isFromToken0,
            limitSqrtP == 0
            ? (isFromToken0 ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
            : limitSqrtP,
            abi.encode(data)
        );
        return uint256(-(isFromToken0 ? amount1 : amount0));
    }

    /// @dev Perform a swap exact amount out using callback
    function _swapExactOutputInternal(
        uint256 amountOut,
        address recipient,
        uint160 limitSqrtP,
        SwapCallbackData memory data
    ) private returns (uint256 amountIn) {
        // consider address 0 as the router address
        if (recipient == address(0)) recipient = address(this);

        (address tokenOut, address tokenIn, uint24 fee) = data.path.decodeFirstPool();

        bool isFromToken0 = tokenOut < tokenIn;

        (int256 amount0Delta, int256 amount1Delta) = _getPool(tokenIn, tokenOut, fee).swap(
            recipient,
            -amountOut.toInt256(),
            isFromToken0,
            limitSqrtP == 0
            ? (isFromToken0 ? TickMath.MAX_SQRT_RATIO - 1 : TickMath.MIN_SQRT_RATIO + 1)
            : limitSqrtP,
            abi.encode(data)
        );

        uint256 receivedAmountOut;
        (amountIn, receivedAmountOut) = isFromToken0
        ? (uint256(amount1Delta), uint256(-amount0Delta))
        : (uint256(amount0Delta), uint256(-amount1Delta));

        // if no price limit has been specified, receivedAmountOut should be equals to amountOut
        assert(limitSqrtP != 0 || receivedAmountOut == amountOut);
    }

    /// @dev Returns the pool address for the requested token pair swap fee
    ///   Because the function calculates it instead of fetching the address from the factory,
    ///   the returned pool address may not be in existence yet
    function _getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) private view returns (IPool) {
        return IPool(PoolAddress.computeAddress(factory, tokenA, tokenB, fee, poolInitHash));
    }
}
