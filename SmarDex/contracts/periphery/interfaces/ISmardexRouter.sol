// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.17;

// interfaces
import "../../core/interfaces/ISmardexSwapCallback.sol";
import "../../core/interfaces/ISmardexMintCallback.sol";

interface ISmardexRouter is ISmardexSwapCallback, ISmardexMintCallback {
    /**
     * @notice get the factory address
     * @return address of the factory
     */
    function factory() external view returns (address);

    /**
     * @notice get WETH address
     * @return address of the WETH token (Wrapped Ether)
     */
    function WETH() external view returns (address);

    /**
     * @notice Add liquidity to an ERC-20=ERC-20 pool. Receive liquidity token to materialize shares in the pool
     * @param _tokenA address of the first token in the pair
     * @param _tokenB address of the second token in the pair
     * @param _amountADesired The amount of tokenA to add as liquidity
     * if the B/A price is <= amountBDesired/amountADesired
     * @param _amountBDesired The amount of tokenB to add as liquidity
     * if the A/B price is <= amountADesired/amountBDesired
     * @param _amountAMin Bounds the extent to which the B/A price can go up before the transaction reverts.
     * Must be <= amountADesired.
     * @param _amountBMin Bounds the extent to which the A/B price can go up before the transaction reverts.
     * Must be <= amountBDesired.
     * @param _to Recipient of the liquidity tokens.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @return amountA_ The amount of tokenA sent to the pool.
     * @return amountB_ The amount of tokenB sent to the pool.
     * @return liquidity_ The amount of liquidity tokens minted.
     */
    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountA_, uint256 amountB_, uint256 liquidity_);

    /**
     * @notice Adds liquidity to an ERC-20=WETH pool with ETH. msg.value is the amount of ETH to add as liquidity.
     * if the token/WETH price is <= amountTokenDesired/msg.value (WETH depreciates).
     * @param _token A pool token.
     * @param _amountTokenDesired The amount of token to add as liquidity if the WETH/token price
     * is <= msg.value/amountTokenDesired (token depreciates).
     * @param _amountTokenMin Bounds the extent to which the WETH/token price can go up before the transaction reverts.
     * Must be <= amountTokenDesired.
     * @param _amountETHMin Bounds the extent to which the token/WETH price can go up before the transaction reverts.
     * Must be <= msg.value.
     * @param _to Recipient of the liquidity tokens.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @return amountToken_ The amount of token sent to the pool.
     * @return amountETH_ The amount of ETH converted to WETH and sent to the pool.
     * @return liquidity_ The amount of liquidity tokens minted.
     */
    function addLiquidityETH(
        address _token,
        uint256 _amountTokenDesired,
        uint256 _amountTokenMin,
        uint256 _amountETHMin,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256 amountToken_, uint256 amountETH_, uint256 liquidity_);

    /**
     * @notice Removes liquidity from an ERC-20=ERC-20 pool.
     * @param _tokenA A pool token.
     * @param _tokenB A pool token.
     * @param _liquidity The amount of liquidity tokens to remove.
     * @param _amountAMin The minimum amount of tokenA that must be received for the transaction not to revert.
     * @param _amountBMin The minimum amount of tokenB that must be received for the transaction not to revert.
     * @param _to Recipient of the liquidity tokens.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @return amountA_ The amount of tokenA received.
     * @return amountB_ The amount of tokenB received.
     */
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountA_, uint256 amountB_);

    /**
     * @notice Removes liquidity from an ERC-20=WETH pool and receive ETH.
     * @param _token A pool token.
     * @param _liquidity The amount of liquidity tokens to remove.
     * @param _amountTokenMin The minimum amount of token that must be received for the transaction not to revert.
     * @param _amountETHMin The minimum amount of ETH that must be received for the transaction not to revert.
     * @param _to Recipient of the liquidity tokens.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @return amountToken_ The amount of token received.
     * @return amountETH_ The amount of ETH received.
     */
    function removeLiquidityETH(
        address _token,
        uint256 _liquidity,
        uint256 _amountTokenMin,
        uint256 _amountETHMin,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountToken_, uint256 amountETH_);

    /**
     * @notice Removes liquidity from an ERC-20=WETH pool and receive ETH.
     * @param _tokenA A pool token.
     * @param _tokenB A pool token.
     * @param _liquidity The amount of liquidity tokens to remove.
     * @param _amountAMin The minimum amount of tokenA that must be received for the transaction not to revert.
     * @param _amountBMin The minimum amount of tokenB that must be received for the transaction not to revert.
     * @param _to Recipient of the liquidity tokens.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @param _approveMax Whether or not the approval amount in the signature is for liquidity or uint(-1).
     * @param _v The v component of the permit signature.
     * @param _r The r component of the permit signature.
     * @param _s The s component of the permit signature.
     * @return amountA_ The amount of tokenA received.
     * @return amountB_ The amount of tokenB received.
     */
    function removeLiquidityWithPermit(
        address _tokenA,
        address _tokenB,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline,
        bool _approveMax,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (uint256 amountA_, uint256 amountB_);

    /**
     * @notice Removes liquidity from an ERC-20=WETTH pool and receive ETH without pre-approval
     * @param _token A pool token.
     * @param _liquidity The amount of liquidity tokens to remove.
     * @param _amountTokenMin The minimum amount of token that must be received for the transaction not to revert.
     * @param _amountETHMin The minimum amount of ETH that must be received for the transaction not to revert.
     * @param _to Recipient of the liquidity tokens.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @param _approveMax Whether or not the approval amount in the signature is for liquidity or uint(-1).
     * @param _v The v component of the permit signature.
     * @param _r The r component of the permit signature.
     * @param _s The s component of the permit signature.
     * @return amountToken_ The amount of token received.
     * @return amountETH_ The amount of ETH received.
     */
    function removeLiquidityETHWithPermit(
        address _token,
        uint256 _liquidity,
        uint256 _amountTokenMin,
        uint256 _amountETHMin,
        address _to,
        uint256 _deadline,
        bool _approveMax,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (uint256 amountToken_, uint256 amountETH_);

    /**
     * @notice Swaps an exact amount of input tokens for as many output tokens as possible, along the route determined
     * by the path. The first element of path is the input token, the last is the output token, and any intermediate
     * elements represent intermediate pairs to trade through (if, for example, a direct pair does not exist).
     * @param _amountIn The amount of input tokens to send.
     * @param _amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param _path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses
     * must exist and have liquidity.
     * @param _to Recipient of the output tokens.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @return amountOut_ The output token amount.
     */
    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountOut_);

    /**
     * @notice Receive an exact amount of output tokens for as few input tokens as possible, along the route determined
     * by the path. The first element of path is the input token, the last is the output token, and any intermediate
     * elements represent intermediate tokens to trade through (if, for example, a direct pair does not exist).
     * @param _amountOut The amount of output tokens to receive.
     * @param _amountInMax The maximum amount of input tokens that can be required before the transaction reverts.
     * @param _path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses
     * must exist and have liquidity.
     * @param _to Recipient of the output tokens.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @return amountIn_ The input token amount.
     */
    function swapTokensForExactTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountIn_);

    /**
     * @notice Swaps an exact amount of ETH for as many output tokens as possible, along the route determined by the
     * path. The first element of path must be WETH, the last is the output token, and any intermediate elements
     * represent intermediate pairs to trade through (if, for example, a direct pair does not exist).
     * @param _amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param _path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses
     * must exist and have liquidity.
     * @param _to Recipient of the output tokens.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @return amountOut_ The input token amount.
     */
    function swapExactETHForTokens(
        uint256 _amountOutMin,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256 amountOut_);

    /**
     * @notice Receive an exact amount of ETH for as few input tokens as possible, along the route determined by the
     * path. The first element of path is the input token, the last must be WETH, and any intermediate elements
     * represent intermediate pairs to trade through (if, for example, a direct pair does not exist).
     * @param _amountOut The amount of ETH to receive.
     * @param _amountInMax The maximum amount of input tokens that can be required before the transaction reverts.
     * @param _path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses
     * must exist and have liquidity.
     * @param _to Recipient of ETH.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @return amountIn_ The input token amount.
     */
    function swapTokensForExactETH(
        uint256 _amountOut,
        uint256 _amountInMax,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountIn_);

    /**
     * @notice Swaps an exact amount of tokens for as much ETH as possible, along the route determined by the path.
     * The first element of path is the input token, the last must be WETH, and any intermediate elements represent
     * intermediate pairs to trade through (if, for example, a direct pair does not exist).
     * @param _amountIn The amount of input tokens to send.
     * @param _amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert.
     * @param _path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses
     * must exist and have liquidity.
     * @param _to Recipient of ETH.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @return amountOut_ The input token amount.
     */
    function swapExactTokensForETH(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountOut_);

    /**
     * @notice Receive an exact amount of tokens for as little ETH as possible, along the route determined by the path.
     * The first element of path must be WETH, the last is the output token and any intermediate elements represent
     * intermediate pairs to trade through (if, for example, a direct pair does not exist).
     * msg.value The maximum amount of ETH that can be required before the transaction reverts.
     * @param _amountOut The amount of tokens to receive.
     * @param _path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses
     * must exist and have liquidity.
     * @param _to Recipient of output tokens.
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @return amountIn_ The input token amount.
     */
    function swapETHForExactTokens(
        uint256 _amountOut,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256 amountIn_);

    /**
     * @notice Given some asset amount and reserves, returns an amount of the other asset representing equivalent value.
     */
    function quote(
        uint256 _amountA,
        uint256 _fictiveReserveA,
        uint256 _fictiveReserveB
    ) external pure returns (uint256 amountB_);

    /**
     * @notice return the amount of tokens the user would get by doing a swap
     * @param _amountIn quantity of token the user want to swap (to sell)
     * @param _reserveIn reserves of the selling token (getReserve())
     * @param _reserveOut reserves of the buying token (getReserve())
     * @param _fictiveReserveIn fictive reserve of the selling token (getFictiveReserves())
     * @param _fictiveReserveOut fictive reserve of the buying token (getFictiveReserves())
     * @param _priceAverageIn price average of the selling token
     * @param _priceAverageOut price average of the buying token
     * @return amountOut_ The amount of token the user would receive
     * @return newReserveIn_ reserves of the selling token after the swap
     * @return newReserveOut_ reserves of the buying token after the swap
     * @return newFictiveReserveIn_ fictive reserve of the selling token after the swap
     * @return newFictiveReserveOut_ fictive reserve of the buying token after the swap
     */
    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut
    )
        external
        pure
        returns (
            uint256 amountOut_,
            uint256 newReserveIn_,
            uint256 newReserveOut_,
            uint256 newFictiveReserveIn_,
            uint256 newFictiveReserveOut_
        );

    /**
     * @notice return the amount of tokens the user should spend by doing a swap
     * @param _amountOut quantity of token the user want to swap (to buy)
     * @param _reserveIn reserves of the selling token (getReserve())
     * @param _reserveOut reserves of the buying token (getReserve())
     * @param _fictiveReserveIn fictive reserve of the selling token (getFictiveReserves())
     * @param _fictiveReserveOut fictive reserve of the buying token (getFictiveReserves())
     * @param _priceAverageIn price average of the selling token
     * @param _priceAverageOut price average of the buying token
     * @return amountIn_ The amount of token the user would spend to receive _amountOut
     * @return newReserveIn_ reserves of the selling token after the swap
     * @return newReserveOut_ reserves of the buying token after the swap
     * @return newFictiveReserveIn_ fictive reserve of the selling token after the swap
     * @return newFictiveReserveOut_ fictive reserve of the buying token after the swap
     */
    function getAmountIn(
        uint256 _amountOut,
        uint256 _reserveIn,
        uint256 _reserveOut,
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut
    )
        external
        pure
        returns (
            uint256 amountIn_,
            uint256 newReserveIn_,
            uint256 newReserveOut_,
            uint256 newFictiveReserveIn_,
            uint256 newFictiveReserveOut_
        );
}
