// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface IStableSwapRouter {

    /**
        Calculates Amount To Be Received From Stable Coin Swap
     */
    function expectedOut(address sender, uint256 amount) external view returns (uint256);

    /**
        Expected Fee To Be Taken From Swap Amount
     */
    function getFeeOut(uint256 amount) external view returns (uint256);

    /**
        Swap TokenIn For TokenOut, sends tokenOut to destination
     */
    function exchange(address tokenIn, address tokenOut, uint256 amountTokenIn, address destination) external;

    /**
        Swap `TokenIn` For `TokenOut` using `source` contract as means of exchange, sends `tokenOut` to `destination`
     */
    function exchange(address source, address tokenIn, address tokenOut, uint256 amountTokenIn, address destination) external;    
}