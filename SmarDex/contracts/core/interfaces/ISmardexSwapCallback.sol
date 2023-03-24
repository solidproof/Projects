// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.17;

interface ISmardexSwapCallback {
    /**
     * @notice callback data for swap
     * @param _amount0Delta amount of token0 for the swap (negative is incoming, positive is required to pay to pair)
     * @param _amount1Delta amount of token1 for the swap (negative is incoming, positive is required to pay to pair)
     * @param _data for Router path and payer for the swap (see router for details)
     */
    function smardexSwapCallback(int256 _amount0Delta, int256 _amount1Delta, bytes calldata _data) external;
}
