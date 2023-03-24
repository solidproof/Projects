// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.17;

// libraries
import "./PoolHelpers.sol";

// interfaces
import "../../core/interfaces/ISmardexFactory.sol";

library PoolAddress {
    /**
     * @notice Deterministically computes the pool address given the factory and PoolKey
     * @param _factory The SmarDex factory contract address
     * @param _tokenA The first token of the pool
     * @param _tokenB The second token of the pool
     * @return pair_ The contract address of the SmardexPair
     */
    function pairFor(address _factory, address _tokenA, address _tokenB) internal pure returns (address pair_) {
        (address token0, address token1) = PoolHelpers.sortTokens(_tokenA, _tokenB);
        pair_ = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            _factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"b477a06204165d50e6d795c7c216306290eff5d6015f8b65bb46002a8775b548" // init code hash
                        )
                    )
                )
            )
        );
    }

    /**
     * @notice make a call to the factory to determine the pair address. usefull for coverage test
     * @param _factory The SmarDex factory contract address
     * @param _tokenA The first token of the pool
     * @param _tokenB The second token of the pool
     * @return pair_ The contract address of the SmardexPair
     */
    function pairForByStorage(
        address _factory,
        address _tokenA,
        address _tokenB
    ) internal view returns (address pair_) {
        return ISmardexFactory(_factory).getPair(_tokenA, _tokenB);
    }
}
