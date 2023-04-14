// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

library Liquidity {
    address public constant FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;
    uint public constant MIN_PERCENT = 100;
    uint public constant MAX_PRECENT = 10000;

    function swap(
        address _tokenIn,
        address _tokenOut,
        uint _amountIn,
        uint _slippage,
        address _to
    ) internal returns (uint) {
        approveIERC20(_tokenIn, ROUTER, _amountIn);

        address[] memory path;
        if (_tokenIn == WETH || _tokenOut == WETH) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = WETH;
            path[2] = _tokenOut;
        }

        uint _amountOutMin = (IUniswapV2Router02(ROUTER).getAmountsOut(
            _amountIn,
            path
        )[path.length - 1] * (MAX_PRECENT - _slippage)) / MAX_PRECENT;

        uint balanceBefore = balanceOfIERC20(_tokenOut, _to);
        IUniswapV2Router02(ROUTER)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                _amountIn,
                _amountOutMin,
                path,
                _to,
                block.timestamp
            );
        uint balanceAfter = balanceOfIERC20(_tokenOut, _to);
        return balanceAfter - balanceBefore;
    }

    function getPair(address _tokenA, address _tokenB)
        internal
        view
        returns (address)
    {
        return IUniswapV2Factory(FACTORY).getPair(_tokenA, _tokenB);
    }

    function approveIERC20(
        address _token,
        address _to,
        uint _amount
    ) internal returns (bool) {
        return IERC20(_token).approve(_to, _amount);
    }

    function balanceOfIERC20(address _token, address _user)
        internal
        view
        returns (uint)
    {
        return IERC20(_token).balanceOf(_user);
    }
}
