// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.17;

// libraries
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../../core/libraries/SmardexLibrary.sol";
import "../libraries/PoolAddress.sol";
import "../SmardexRouter.sol";
import "../libraries/Path.sol";

contract RouterForPairTest {
    using Path for bytes;
    using Path for address[];
    using SafeCast for uint256;
    using SafeCast for int256;

    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    address public immutable factory;
    address public immutable WETH;
    uint256 private constant DEFAULT_AMOUNT_IN_CACHED = type(uint256).max;
    uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    function mint(address _pair, address _to, uint256 _amount0, uint256 _amount1, address _payer) public payable {
        ISmardexPair(_pair).mint(_to, _amount0, _amount1, _payer);
    }

    function swap(address _pair, address _to, bool _zeroForOne, int256 _amountSpecified, bytes calldata _data) public {
        ISmardexPair(_pair).swap(_to, _zeroForOne, _amountSpecified, _data);
    }

    function pay(address _token, address _payer, address _to, uint256 _value) internal {
        if (_token == WETH && address(this).balance >= _value) {
            // pay with WETH
            IWETH(WETH).deposit{ value: _value }(); // wrap only what is needed to pay
            IWETH(WETH).transfer(_to, _value);
            //refund dust eth, if any ?
        } else if (_payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(_token, _to, _value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(_token, _payer, _to, _value);
        }
    }

    function smardexMintCallback(ISmardexMintCallback.MintCallbackData calldata _data) external {
        require(_data.amount0 > 0 || _data.amount1 > 0, "SmardexRouter: Callback Invalid amount");
        require(
            msg.sender == PoolAddress.pairForByStorage(factory, _data.token0, _data.token1),
            "SmarDexRouter: INVALID_PAIR"
        ); // ensure that msg.sender is a pair
        pay(_data.token0, _data.payer, msg.sender, _data.amount0);
        pay(_data.token1, _data.payer, msg.sender, _data.amount1);
    }

    function smardexSwapCallback(int256 _amount0Delta, int256 _amount1Delta, bytes calldata _data) external {
        require(_amount0Delta > 0 || _amount1Delta > 0, "SmardexRouter: Callback Invalid amount");
        SwapCallbackData memory _decodedData = abi.decode(_data, (SwapCallbackData));
        (address _tokenIn, address _tokenOut) = _decodedData.path.decodeFirstPool();
        require(
            msg.sender == PoolAddress.pairForByStorage(factory, _tokenIn, _tokenOut),
            "SmarDexRouter: INVALID_PAIR"
        ); // ensure that msg.sender is a pair
        (bool _isExactInput, uint256 _amountToPay) = _amount0Delta > 0
            ? (_tokenIn < _tokenOut, uint256(_amount0Delta))
            : (_tokenOut < _tokenIn, uint256(_amount1Delta));
        if (_isExactInput) {
            pay(_tokenIn, _decodedData.payer, msg.sender, _amountToPay);
        } else {
            _tokenIn = _tokenOut; // swap in/out because exact output swaps are reversed
            pay(_tokenIn, _decodedData.payer, msg.sender, _amountToPay);
        }
    }

    function swapETHForExactTokens(
        uint256 _amountOut,
        address[] calldata _path,
        address _to,
        uint256 _deadline
    ) external payable returns (uint256 amountIn_) {
        require(_path[0] == WETH, "SmarDexRouter: INVALID_PATH");
        amountIn_ = swapTokensForExactTokens(_amountOut, msg.value, _path, _to, _deadline);
    }

    function swapTokensForExactTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address[] calldata _path,
        address _to,
        uint256 // _deadline
    ) public returns (uint256 amountIn_) {
        // Path needs to be reversed as to get the amountIn that we will ask from next pair hop
        bytes memory _reversedPath = _path.encodeTightlyPackedReversed();
        amountIn_ = _swapExactOut(_amountOut, _to, SwapCallbackData({ path: _reversedPath, payer: msg.sender }));
        // amount In is only the right one for one Hop, otherwise we need cached amountIn from callback
        if (_path.length > 2) amountIn_ = amountInCached;
        require(amountIn_ <= _amountInMax, "SmarDexRouter: EXCESSIVE_INPUT_AMOUNT");
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;

        refundETH(_to);
    }

    function refundETH(address _to) private {
        if (address(this).balance > 0) {
            TransferHelper.safeTransferETH(_to, address(this).balance);
        }
    }

    function _swapExactOut(
        uint256 _amountOut,
        address _to,
        SwapCallbackData memory _data
    ) private returns (uint256 amountIn_) {
        // allow swapping to the router address with address 0
        if (_to == address(0)) {
            _to = address(this);
        }

        (address _tokenOut, address _tokenIn) = _data.path.decodeFirstPool();
        bool _zeroForOne = _tokenIn < _tokenOut;

        // do the swap
        (int256 _amount0, int256 _amount1) = ISmardexPair(PoolAddress.pairForByStorage(factory, _tokenIn, _tokenOut))
            .swap(_to, _zeroForOne, -_amountOut.toInt256(), abi.encode(_data));

        amountIn_ = _zeroForOne ? uint256(_amount0) : uint256(_amount1);
    }
}
