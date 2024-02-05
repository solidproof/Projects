// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

library LibUniswap {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event UniswapCall(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    function swap(
        ISwapRouter swapRouter,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal returns (uint256 amountOut, bool success) {
        // path of the token swap
        bytes memory path = encodePath(tokenIn, tokenOut, 500);
        // executes the swap on uniswap pool
        IERC20Upgradeable(tokenIn).safeTransfer(address(swapRouter), amountIn);
        // exact input swap to convert exact amount of tokens into usdc
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut
        });
        // since exact input swap tokens used = token amount passed
        try swapRouter.exactInput(params) returns (uint256 _amountOut) {
            amountOut = _amountOut;
            success = true;
        } catch {
            success = false;
        }
        emit UniswapCall(tokenIn, tokenOut, amountIn, amountOut);
    }

    function encodePath(
        address tokenIn,
        address tokenOut,
        uint24 slippage
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(tokenIn, slippage, tokenOut);
    }
}
