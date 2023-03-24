// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.17;

// libraries
import "../libraries/PoolAddress.sol";
import "../SmardexRouter.sol";

contract SmardexRouterTest is SmardexRouter {
    constructor(address _factory, address _WETH) SmardexRouter(_factory, _WETH) {}

    function pairFor_pure(address factory, address tokenA, address tokenB) public pure returns (address pair) {
        pair = PoolAddress.pairFor(factory, tokenA, tokenB);
    }

    function mint(address _pair, address _to, uint256 _amount0, uint256 _amount1, address _payer) public {
        ISmardexPair(_pair).mint(_to, _amount0, _amount1, _payer);
    }

    function swap(address _pair, address _to, bool _zeroForOne, int256 _amountSpecified, bytes calldata _path) public {
        ISmardexPair(_pair).swap(_to, _zeroForOne, _amountSpecified, _path);
    }

    function unwrapWETHTest(uint256 _amountMinimum, address _to) external {
        _unwrapWETH(_amountMinimum, _to);
    }
}
