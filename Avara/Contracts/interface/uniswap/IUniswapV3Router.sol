/**
    ***********************************************************
    * Copyright (c) Avara Dev. 2022. (Telegram: @avara_cc)  *
    ***********************************************************

     ▄▄▄·  ▌ ▐· ▄▄▄· ▄▄▄   ▄▄▄·
    ▐█ ▀█ ▪█·█▌▐█ ▀█ ▀▄ █·▐█ ▀█
    ▄█▀▀█ ▐█▐█•▄█▀▀█ ▐▀▀▄ ▄█▀▀█
    ▐█ ▪▐▌ ███ ▐█ ▪▐▌▐█•█▌▐█ ▪▐▌
     ▀  ▀ . ▀   ▀  ▀ .▀  ▀ ▀  ▀  - Ethereum Network

    Avara - Always Vivid, Always Rising Above
    https://avara.cc/
    https://github.com/avara-cc
    https://github.com/avara-cc/AvaraETH/wiki
*/

// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.4;

interface IUniswapV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    function exactInputSingle(
        IUniswapV3Router.ExactInputSingleParams memory params
    ) external returns (uint256 amountOut);

    function exactInput(
        IUniswapV3Router.ExactInputParams memory params
    ) external returns (uint256 amountOut);

    function exactOutputSingle(
        IUniswapV3Router.ExactOutputSingleParams memory params
    ) external returns (uint256 amountIn);

    function exactOutput(
        IUniswapV3Router.ExactOutputParams memory params
    ) external returns (uint256 amountIn);
}
