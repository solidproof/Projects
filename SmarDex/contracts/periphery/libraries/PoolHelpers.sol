// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.17;

// libraries
import "./PoolAddress.sol";
import "../../core/libraries/SmardexLibrary.sol";

// interfaces
import "../../core/interfaces/ISmardexPair.sol";

library PoolHelpers {
    /**
     * @notice sort token addresses, used to handle return values from pairs sorted in this order
     * @param _tokenA token to sort
     * @param _tokenB token to sort
     * @return token0_ token0 sorted
     * @return token1_ token1 sorted
     */
    function sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0_, address token1_) {
        require(_tokenA != _tokenB, "SmardexHelper: IDENTICAL_ADDRESSES");
        (token0_, token1_) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(token0_ != address(0), "SmardexHelper: ZERO_ADDRESS");
    }

    /**
     * @notice fetches the reserves for a pair
     * @param _factory the factory address
     * @param _tokenA token to fetch reserves
     * @param _tokenB token to fetch reserves
     * @return reserveA_ reserves of tokenA in the pair tokenA/TokenB
     * @return reserveB_ reserves of tokenB in the pair tokenA/TokenB
     */
    function getReserves(
        address _factory,
        address _tokenA,
        address _tokenB
    ) internal view returns (uint256 reserveA_, uint256 reserveB_) {
        (address _token0, ) = sortTokens(_tokenA, _tokenB);
        (uint256 _reserve0, uint256 _reserve1) = ISmardexPair(PoolAddress.pairFor(_factory, _tokenA, _tokenB))
            .getReserves();
        (reserveA_, reserveB_) = _tokenA == _token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
    }

    /**
     * @notice fetches the fictive reserves for a pair
     * @param _factory the factory address
     * @param _tokenA token to fetch fictive reserves
     * @param _tokenB token to fetch fictive reserves
     * @return fictiveReserveA_ fictive reserves of tokenA in the pair tokenA/TokenB
     * @return fictiveReserveB_ fictive reserves of tokenB in the pair tokenA/TokenB
     */
    function getFictiveReserves(
        address _factory,
        address _tokenA,
        address _tokenB
    ) internal view returns (uint256 fictiveReserveA_, uint256 fictiveReserveB_) {
        (address _token0, ) = sortTokens(_tokenA, _tokenB);
        (uint256 _fictiveReserve0, uint256 _fictiveReserve1) = ISmardexPair(
            PoolAddress.pairFor(_factory, _tokenA, _tokenB)
        ).getFictiveReserves();
        (fictiveReserveA_, fictiveReserveB_) = _tokenA == _token0
            ? (_fictiveReserve0, _fictiveReserve1)
            : (_fictiveReserve1, _fictiveReserve0);
    }

    /**
     * @notice fetches the priceAverage for a pair
     * @param _factory the factory address
     * @param _tokenA token to fetch priceAverage
     * @param _tokenB token to fetch priceAverage
     * @return priceAverageA_ priceAverage of tokenA in the pair tokenA/TokenB
     * @return priceAverageB_ priceAverage of tokenB in the pair tokenA/TokenB
     */
    function getPriceAverage(
        address _factory,
        address _tokenA,
        address _tokenB
    ) internal view returns (uint256 priceAverageA_, uint256 priceAverageB_) {
        (address _token0, ) = sortTokens(_tokenA, _tokenB);
        (uint256 _priceAverage0, uint256 _priceAverage1, ) = ISmardexPair(
            PoolAddress.pairFor(_factory, _tokenA, _tokenB)
        ).getPriceAverage();
        (priceAverageA_, priceAverageB_) = _tokenA == _token0
            ? (_priceAverage0, _priceAverage1)
            : (_priceAverage1, _priceAverage0);
    }

    /**
     * @notice given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
     * @param _amountA amount of asset A
     * @param _reserveA reserve of asset A
     * @param _reserveB reserve of asset B
     * @return amountB_ equivalent amount of asset B
     */
    function quote(uint256 _amountA, uint256 _reserveA, uint256 _reserveB) internal pure returns (uint256 amountB_) {
        require(_amountA > 0, "SmardexHelper: INSUFFICIENT_AMOUNT");
        require(_reserveA > 0 && _reserveB > 0, "SmardexHelper: INSUFFICIENT_LIQUIDITY");
        amountB_ = (_amountA * _reserveB) / _reserveA;
    }
}
