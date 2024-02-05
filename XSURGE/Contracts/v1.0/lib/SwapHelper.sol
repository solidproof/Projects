//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./IERC20.sol";
import "./IUniswapV2Router02.sol";

interface IXSurge {
    function sell(uint256 amount) external returns (address, uint256);
}

contract SwapHelper {

    address public immutable DEX;
    IUniswapV2Router02 immutable public router;

    constructor(address dex) {
        DEX = dex;
        router = IUniswapV2Router02(dex);
    }

    function _sellSurge(address surge) internal {
        IXSurge(surge).sell(IERC20(surge).balanceOf(address(this)));
    }

    function _tokenToToken(address tokenIn, address tokenOut, uint256 amountIn) internal {

        // approve router
        IERC20(tokenIn).approve(DEX, amountIn);

        address[] memory path = new address[](3);
        path[0] = tokenIn;
        path[1] = router.WETH();
        path[2] = tokenOut;

        // swap token for bnb
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, 0, path, address(this), block.timestamp + 300);

        delete path;
    }

    function _tokenToTokenDirect(address tokenIn, address tokenOut, uint256 amountIn) internal {
    
        // approve router
        IERC20(tokenIn).approve(DEX, amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // swap token for bnb
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, 0, path, address(this), block.timestamp + 300);

        delete path;
    }

    function _bnbToToken(address token, uint256 amount) internal {

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = token;

        // swap token for bnb
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(0, path, address(this), block.timestamp + 300);

        delete path;
    }

    function _tokenToBNB(address tokenIn, uint256 amountIn) internal {

        // approve router
        IERC20(tokenIn).approve(DEX, amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = router.WETH();

        // swap token for bnb
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(amountIn, 0, path, address(this), block.timestamp + 300);

        delete path;
    }

}