// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.17;

// interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

interface ISmardexPair is IERC20, IERC20Permit {
    /**
     * @notice emitted at each mint
     * @param sender address calling the mint function (usualy the Router contract)
     * @param to address that receives the LP-tokens
     * @param amount0 amount of token0 to be added in liquidity
     * @param amount1 amount of token1 to be added in liquidity
     * @dev the amount of LP-token sent can be caught using the transfer event of the pair
     */
    event Mint(address indexed sender, address indexed to, uint256 amount0, uint256 amount1);

    /**
     * @notice emitted at each burn
     * @param sender address calling the burn function (usualy the Router contract)
     * @param to address that receives the tokens
     * @param amount0 amount of token0 to be withdrawn
     * @param amount1 amount of token1 to be withdrawn
     * @dev the amount of LP-token sent can be caught using the transfer event of the pair
     */
    event Burn(address indexed sender, address indexed to, uint256 amount0, uint256 amount1);

    /**
     * @notice emitted at each swap
     * @param sender address calling the swap function (usualy the Router contract)
     * @param to address that receives the out-tokens
     * @param amount0 amount of token0 to be swapped
     * @param amount1 amount of token1 to be swapped
     * @dev one of the 2 amount is always negative, the other one is always positive. The positive one is the one that
     * the user send to the contract, the negative one is the one that the contract send to the user.
     */
    event Swap(address indexed sender, address indexed to, int256 amount0, int256 amount1);

    /**
     * @notice emitted each time the fictive reserves are changed (mint, burn, swap)
     * @param reserve0 the new reserve of token0
     * @param reserve1 the new reserve of token1
     * @param fictiveReserve0 the new fictive reserve of token0
     * @param fictiveReserve1 the new fictive reserve of token1
     * @param priceAverage0 the new priceAverage of token0
     * @param priceAverage1 the new priceAverage of token1
     */
    event Sync(
        uint256 reserve0,
        uint256 reserve1,
        uint256 fictiveReserve0,
        uint256 fictiveReserve1,
        uint256 priceAverage0,
        uint256 priceAverage1
    );

    /**
     * @notice get the factory address
     * @return address of the factory
     */
    function factory() external view returns (address);

    /**
     * @notice get the token0 address
     * @return address of the token0
     */
    function token0() external view returns (address);

    /**
     * @notice get the token1 address
     * @return address of the token1
     */
    function token1() external view returns (address);

    /**
     * @notice called once by the factory at time of deployment
     * @param _token0 address of token0
     * @param _token1 address of token1
     */
    function initialize(address _token0, address _token1) external;

    /**
     * @notice return current Reserves of both token in the pair,
     *  corresponding to token balance - pending fees
     * @return reserve0_ current reserve of token0 - pending fee0
     * @return reserve1_ current reserve of token1 - pending fee1
     */
    function getReserves() external view returns (uint256 reserve0_, uint256 reserve1_);

    /**
     * @notice return current Fictives Reserves of both token in the pair
     * @return fictiveReserve0_ current fictive reserve of token0
     * @return fictiveReserve1_ current fictive reserve of token1
     */
    function getFictiveReserves() external view returns (uint256 fictiveReserve0_, uint256 fictiveReserve1_);

    /**
     * @notice return current pending fees of both token in the pair
     * @return fees0_ current pending fees of token0
     * @return fees1_ current pending fees of token1
     */
    function getFees() external view returns (uint256 fees0_, uint256 fees1_);

    /**
     * @notice return last updated price average at timestamp of both token in the pair,
     *  read price0Average/price1Average for current price of token0/token1
     * @return priceAverage0_ current price for token0
     * @return priceAverage1_ current price for token1
     * @return blockTimestampLast_ last block timestamp when price was updated
     */
    function getPriceAverage()
        external
        view
        returns (uint256 priceAverage0_, uint256 priceAverage1_, uint256 blockTimestampLast_);

    /**
     * @notice return current price average of both token in the pair for provided currentTimeStamp
     *  read price0Average/price1Average for current price of token0/token1
     * @param _fictiveReserveIn,
     * @param _fictiveReserveOut,
     * @param _priceAverageLastTimestamp,
     * @param _priceAverageIn current price for token0
     * @param _priceAverageOut current price for token1
     * @param _currentTimestamp block timestamp to get price
     * @return priceAverageIn_ current price for token0
     * @return priceAverageOut_ current price for token1
     */
    function getUpdatedPriceAverage(
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageLastTimestamp,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut,
        uint256 _currentTimestamp
    ) external pure returns (uint256 priceAverageIn_, uint256 priceAverageOut_);

    /**
     * @notice Mint lp tokens proportionally of added tokens in balance. Should be called from a contract
     * that makes safety checks like the SmardexRouter
     * @param _to address who will receive minted tokens
     * @param _amount0 amount of token0 to provide
     * @param _amount1 amount of token1 to provide
     * @return liquidity_ amount of lp tokens minted and sent to the address defined in parameter
     */
    function mint(
        address _to,
        uint256 _amount0,
        uint256 _amount1,
        address _payer
    ) external returns (uint256 liquidity_);

    /**
     * @notice Burn lp tokens in the balance of the contract. Sends to the defined address the amount of token0 and
     * token1 proportionally of the amount burned. Should be called from a contract that makes safety checks like the
     * SmardexRouter
     * @param _to address who will receive tokens
     * @return amount0_ amount of token0 sent to the address defined in parameter
     * @return amount1_ amount of token0 sent to the address defined in parameter
     */
    function burn(address _to) external returns (uint256 amount0_, uint256 amount1_);

    /**
     * @notice Swaps tokens. Sends to the defined address the amount of token0 and token1 defined in parameters.
     * Tokens to trade should be already sent in the contract.
     * Swap function will check if the resulted balance is correct with current reserves and reserves fictive.
     * Should be called from a contract that makes safety checks like the SmardexRouter
     * @param _to address who will receive tokens
     * @param _zeroForOne token0 to token1
     * @param _amountSpecified amount of token wanted
     * @param _data used for flash swap, data.length must be 0 for regular swap
     */
    function swap(
        address _to,
        bool _zeroForOne,
        int256 _amountSpecified,
        bytes calldata _data
    ) external returns (int256 amount0_, int256 amount1_);
}
