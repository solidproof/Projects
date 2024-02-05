// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface IStableSwapRouter {

    /**
        Calculates Amount To Be Received From Stable Coin Swap
     */
    function stableSwapOut(uint256 amount) external view returns (uint256);

    /**
        Swap TokenIn For TokenOut
     */
    function stableSwap(address tokenIn, address tokenOut, uint256 tokenInAmount) external;

    /**
        Swap TokenIn For TokenOut, Sending To Recipient
     */
    function stableSwap(address tokenIn, address tokenOut, uint256 tokenInAmount, address recipient) external;
}