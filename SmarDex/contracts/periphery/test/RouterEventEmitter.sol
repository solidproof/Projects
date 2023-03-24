// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.17;

// interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ISmardexRouter.sol";

contract RouterEventEmitter {
    event Amount(uint256 amount);

    receive() external payable {}

    function swapExactTokensForTokens(
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IERC20(path[0]).approve(router, amountIn);
        uint256 amount = ISmardexRouter(router).swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
        emit Amount(amount);
    }

    function swapTokensForExactTokens(
        address router,
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountInMax);
        IERC20(path[0]).approve(router, amountInMax);
        uint256 amount = ISmardexRouter(router).swapTokensForExactTokens(amountOut, amountInMax, path, to, deadline);
        emit Amount(amount);
    }

    function swapETHForExactTokens(
        address _router,
        uint256 _amountOut,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external payable {
        uint256 amount = ISmardexRouter(_router).swapETHForExactTokens{ value: msg.value }(
            _amountOut,
            _path,
            _to,
            _deadline
        );
        emit Amount(amount);
    }

    function swapExactETHForTokens(
        address _router,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external payable {
        uint256 amount = ISmardexRouter(_router).swapExactETHForTokens{ value: msg.value }(
            _amountOutMin,
            _path,
            _to,
            _deadline
        );
        emit Amount(amount);
    }
}
