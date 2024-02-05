// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMuteSwitchPairDynamic {
    function fees() external view returns (address);
}

interface IMuteSwitchFactoryDynamic {
    function getPair(address tokenA, address tokenB, bool stable) external view returns (address pair);
    function createPair(address tokenA, address tokenB, uint feeType, bool stable) external returns (address pair);
}

interface IMuteSwitchRouterDynamic {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint feeType,
        bool stable
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool stable
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata stable
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata stable
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata stable
    ) external;
}
