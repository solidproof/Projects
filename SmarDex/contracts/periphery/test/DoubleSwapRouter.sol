// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.17;

// libraries
import "../../core/libraries/TransferHelper.sol";

//interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ISmardexRouter.sol";

contract DoubleSwapRouter {
    function doubleSwapExactInExactOut(
        ISmardexRouter router,
        uint256 amountIn,
        uint256 maxAmountIn,
        address[] calldata path
    ) external {
        address[] memory pathReversed = new address[](2);
        (pathReversed[0], pathReversed[1]) = (path[1], path[0]);
        TransferHelper.safeTransferFrom(path[0], msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(path[0], address(router), amountIn);
        router.swapExactTokensForTokens(amountIn, 1, path, msg.sender, block.timestamp);

        TransferHelper.safeTransferFrom(path[1], msg.sender, address(this), maxAmountIn);
        TransferHelper.safeApprove(path[1], address(router), maxAmountIn);
        router.swapTokensForExactTokens(amountIn, maxAmountIn, pathReversed, msg.sender, block.timestamp);

        TransferHelper.safeTransfer(path[0], msg.sender, IERC20(path[0]).balanceOf(address(this)));
        TransferHelper.safeTransfer(path[1], msg.sender, IERC20(path[1]).balanceOf(address(this)));
    }

    function doubleSwapExactOutExactIn(
        ISmardexRouter router,
        uint256 amountOut,
        uint256 maxAmountIn,
        address[] calldata path
    ) external {
        address[] memory pathReversed = new address[](2);
        (pathReversed[0], pathReversed[1]) = (path[1], path[0]);
        TransferHelper.safeTransferFrom(path[0], msg.sender, address(this), maxAmountIn);
        TransferHelper.safeApprove(path[0], address(router), maxAmountIn);
        router.swapTokensForExactTokens(amountOut, maxAmountIn, path, msg.sender, block.timestamp);

        TransferHelper.safeTransferFrom(path[1], msg.sender, address(this), amountOut);
        TransferHelper.safeApprove(path[1], address(router), maxAmountIn);
        router.swapExactTokensForTokens(amountOut, 1, pathReversed, msg.sender, block.timestamp);

        TransferHelper.safeTransfer(path[0], msg.sender, IERC20(path[0]).balanceOf(address(this)));
        TransferHelper.safeTransfer(path[1], msg.sender, IERC20(path[1]).balanceOf(address(this)));
    }
}
