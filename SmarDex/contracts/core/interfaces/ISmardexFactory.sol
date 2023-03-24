// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.17;

interface ISmardexFactory {
    /**
     * @notice emitted at each SmardexPair created
     * @param token0 address of the token0
     * @param token1 address of the token1
     * @param pair address of the SmardexPair created
     * @param totalPair number of SmardexPair created so far
     */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 totalPair);

    /**
     * @notice return which address fees will be transferred
     */
    function feeTo() external view returns (address);

    /**
     * @notice return which address can update feeTo
     */
    function feeToSetter() external view returns (address);

    /**
     * @notice return the address of the pair of 2 tokens
     */
    function getPair(address _tokenA, address _tokenB) external view returns (address pair_);

    /**
     * @notice return the address of the pair at index
     * @param _index index of the pair
     * @return pair_ address of the pair
     */
    function allPairs(uint256 _index) external view returns (address pair_);

    /**
     * @notice return the quantity of pairs
     * @return quantity in uint256
     */
    function allPairsLength() external view returns (uint256);

    /**
     * @notice create pair with 2 address
     * @param _tokenA address of tokenA
     * @param _tokenB address of tokenB
     * @return pair_ address of the pair created
     */
    function createPair(address _tokenA, address _tokenB) external returns (address pair_);

    /**
     * @notice set the address who will receive fees, can only be call by feeToSetter
     * @param _feeTo address to replace
     */
    function setFeeTo(address _feeTo) external;

    /**
     * @notice set the address who can update feeTo, can only be call by feeToSetter
     * @param _feeToSetter address to replace
     */
    function setFeeToSetter(address _feeToSetter) external;
}
