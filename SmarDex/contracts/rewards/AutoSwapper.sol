// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

// libraries
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../core/libraries/SmardexLibrary.sol";
import "../periphery/libraries/Path.sol";

// interfaces
import "../core/interfaces/ISmardexPair.sol";
import "./interfaces/IAutoSwapper.sol";

/**
 * @title AutoSwapper
 * @notice AutoSwapper makes it automatic and/or public to get fees from Smardex and convert it to tokens for staking
 */
contract AutoSwapper is IAutoSwapper {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Path for bytes;

    /**
     * @notice callback data for swap from SmardexRouter
     * @param path path of the swap, array of token addresses tightly packed
     * @param payer address of the payer for the swap
     */
    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    /**
     * @notice swap parameters used by function _swapAndSend
     * @param zeroForOne true if we swap the token0 with token1, false otherwise
     * @param balanceIn balance of in-token to be swapped
     * @param pair pair address
     * @param fictiveReserve0 fictive reserve of token0 of the pair
     * @param fictiveReserve1 fictive reserve of token1 of the pair
     * @param oldPriceAv0 priceAverage of token0 of the pair before the swap
     * @param oldPriceAv1 priceAverage of token1 of the pair before the swap
     * @param oldPriceAvTimestamp priceAverageLastTimestamp of the pair before the swap
     * @param newPriceAvIn priceAverage of token0 of the pair after the swap
     * @param newPriceAvOut priceAverage of token1 of the pair after the swap
     */
    struct SwapCallParams {
        bool zeroForOne;
        uint256 balanceIn;
        ISmardexPair pair;
        uint256 fictiveReserve0;
        uint256 fictiveReserve1;
        uint256 oldPriceAv0;
        uint256 oldPriceAv1;
        uint256 oldPriceAvTimestamp;
        uint256 newPriceAvIn;
        uint256 newPriceAvOut;
    }

    bytes4 private constant SWAP_SELECTOR = bytes4(keccak256(bytes("swap(address,bool,int256,bytes)")));
    uint256 private constant AUTOSWAP_SLIPPAGE = 2; // 2%
    uint256 private constant AUTOSWAP_SLIPPAGE_BASE = 100;

    ISmardexFactory public immutable factory;
    address public immutable stakingAddress;
    IERC20 public immutable smardexToken;

    ISmardexPair private constant DEFAULT_CACHED_PAIR = ISmardexPair(address(0));
    ISmardexPair private cachedPair = DEFAULT_CACHED_PAIR;

    constructor(ISmardexFactory _factory, IERC20 _smardexToken, address _stakingAddress) {
        factory = _factory;
        smardexToken = _smardexToken;
        stakingAddress = _stakingAddress;
    }

    /// @inheritdoc IAutoSwapper
    function executeWork(IERC20 _token0, IERC20 _token1) external {
        _swapAndSend(_token0);
        _swapAndSend(_token1);
        transferTokens();
    }

    /// @inheritdoc IAutoSwapper
    function transferTokens() public {
        uint256 _balance = smardexToken.balanceOf(address(this));
        if (_balance == 0) return;
        smardexToken.safeTransfer(stakingAddress, _balance);
    }

    /**
     * @notice private function to swap token in SDEX and send it to the staking address
     * @param _token address of the token to swap into sdex
     */
    function _swapAndSend(IERC20 _token) private {
        if (_token == smardexToken) return;
        SwapCallParams memory _params = SwapCallParams({
            zeroForOne: _token < smardexToken,
            balanceIn: _token.balanceOf(address(this)),
            pair: ISmardexPair(factory.getPair(address(_token), address(smardexToken))),
            fictiveReserve0: 0,
            fictiveReserve1: 0,
            oldPriceAv0: 0,
            oldPriceAv1: 0,
            oldPriceAvTimestamp: 0,
            newPriceAvIn: 0,
            newPriceAvOut: 0
        });

        // basic check on input data
        if (_params.balanceIn == 0 || address(_params.pair) == address(0)) return;

        // get reserves and pricesAv
        (_params.fictiveReserve0, _params.fictiveReserve1) = _params.pair.getFictiveReserves();
        (_params.oldPriceAv0, _params.oldPriceAv1, _params.oldPriceAvTimestamp) = _params.pair.getPriceAverage();

        if (_params.oldPriceAv0 == 0 || _params.oldPriceAv1 == 0) {
            (_params.oldPriceAv0, _params.oldPriceAv1) = (_params.fictiveReserve0, _params.fictiveReserve1);
        }

        if (_params.zeroForOne) {
            (_params.newPriceAvIn, _params.newPriceAvOut) = SmardexLibrary.getUpdatedPriceAverage(
                _params.fictiveReserve0,
                _params.fictiveReserve1,
                _params.oldPriceAvTimestamp,
                _params.oldPriceAv0,
                _params.oldPriceAv1,
                block.timestamp
            );
        } else {
            (_params.newPriceAvIn, _params.newPriceAvOut) = SmardexLibrary.getUpdatedPriceAverage(
                _params.fictiveReserve1,
                _params.fictiveReserve0,
                _params.oldPriceAvTimestamp,
                _params.oldPriceAv1,
                _params.oldPriceAv0,
                block.timestamp
            );
        }

        // we allow for 2% slippage from previous swaps in block
        uint256 _amountOutWithSlippage = (_params.balanceIn *
            _params.newPriceAvOut *
            (AUTOSWAP_SLIPPAGE_BASE - AUTOSWAP_SLIPPAGE)) / (_params.newPriceAvIn * AUTOSWAP_SLIPPAGE_BASE);
        require(_amountOutWithSlippage > 0, "AutoSwapper: slippage calculation failed");

        cachedPair = _params.pair;

        // we dont check for success as we dont want to revert the whole tx if the swap fails
        address(_params.pair).call(
            abi.encodeWithSelector(
                SWAP_SELECTOR,
                stakingAddress,
                _token < smardexToken,
                _params.balanceIn.toInt256(),
                abi.encode(
                    SwapCallbackData({ path: abi.encodePacked(_token, smardexToken), payer: address(this) }),
                    _amountOutWithSlippage
                )
            )
        );

        cachedPair = DEFAULT_CACHED_PAIR;
    }

    /// @inheritdoc ISmardexSwapCallback
    function smardexSwapCallback(int256 _amount0Delta, int256 _amount1Delta, bytes calldata _dataFromPair) external {
        require(_amount0Delta > 0 || _amount1Delta > 0, "SmardexRouter: Callback Invalid amount");
        (SwapCallbackData memory _data, uint256 _amountOutWithSlippage) = abi.decode(
            _dataFromPair,
            (SwapCallbackData, uint256)
        );
        (address _tokenIn, ) = _data.path.decodeFirstPool();
        require(msg.sender == address(cachedPair), "SmarDexRouter: INVALID_PAIR"); // ensure that msg.sender is a pair
        // ensure that the trade gives at least the minimum amount of output token (negative delta)
        require(
            (_amount0Delta < 0 ? uint256(-_amount0Delta) : (-_amount1Delta).toUint256()) >= _amountOutWithSlippage,
            "SmardexAutoSwapper: Invalid price"
        );
        // send positive delta to pair
        IERC20(_tokenIn).safeTransfer(
            msg.sender,
            _amount0Delta > 0 ? uint256(_amount0Delta) : _amount1Delta.toUint256()
        );
    }
}
