// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.17;

interface ISmardexMintCallback {
    /**
     * @notice callback data for mint
     * @param token0 address of the first token of the pair
     * @param token1 address of the second token of the pair
     * @param amount0 amount of token0 to provide
     * @param amount1 amount of token1 to provide
     * @param payer address of the payer to provide token for the mint
     */
    struct MintCallbackData {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        address payer;
    }

    /**
     * @notice callback to implement when calling SmardexPair.mint
     * @param _data callback data for mint
     */
    function smardexMintCallback(MintCallbackData calldata _data) external;
}
