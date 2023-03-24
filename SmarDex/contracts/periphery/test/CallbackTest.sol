// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.17;

//libraries
import "../../core/libraries/TransferHelper.sol";
import "../libraries/PoolAddress.sol";
//interfaces
import "../interfaces/ISmardexRouter.sol";
import "../libraries/Path.sol";

contract CallbackTest {
    using Path for bytes;

    address public immutable factory;
    address public immutable WETH;
    bool public isToken0ToLower;

    constructor(address _factory, address _weth) {
        factory = _factory;
        WETH = _weth;
    }

    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    function setIsToken0ToLower(bool _isToken0ToLower) external {
        isToken0ToLower = _isToken0ToLower;
    }

    // From UniV3 PeripheryPayments.sol
    // https://github.com/Uniswap/v3-periphery/blob/v1.3.0/contracts/base/PeripheryPayments.sol
    /// @param _token The token to pay
    /// @param _payer The entity that must pay
    /// @param _to The entity that will receive payment
    /// @param _value The amount to pay
    function pay(address _token, address _payer, address _to, uint256 _value) internal {
        // pull payment
        TransferHelper.safeTransferFrom(_token, _payer, _to, _value);
    }

    function smardexMintCallback(ISmardexMintCallback.MintCallbackData calldata _data) external {
        require(_data.amount0 > 0 || _data.amount1 > 0, "SmardexRouter: Callback Invalid amount");
        require(msg.sender == PoolAddress.pairFor(factory, _data.token0, _data.token1), "SmarDexRouter: INVALID_PAIR"); // ensure that msg.sender is a pair
        pay(_data.token0, _data.payer, msg.sender, isToken0ToLower ? _data.amount0 - 1 : _data.amount0);
        // we send less token 1 than expected
        pay(_data.token1, _data.payer, msg.sender, isToken0ToLower ? _data.amount1 : _data.amount1 - 1);
    }

    function smardexSwapCallback(int256 _amount0Delta, int256 _amount1Delta, bytes calldata _data) external {
        require(_amount0Delta > 0 || _amount1Delta > 0, "SmardexRouter: Callback Invalid amount");
        SwapCallbackData memory _decodedData = abi.decode(_data, (SwapCallbackData));
        (address _tokenIn, address _tokenOut) = _decodedData.path.decodeFirstPool();
        require(msg.sender == PoolAddress.pairFor(factory, _tokenIn, _tokenOut), "SmarDexRouter: INVALID_PAIR"); // ensure that msg.sender is a pair
        (bool _isExactInput, uint256 _amountToPay) = _amount0Delta > 0
            ? (_tokenIn < _tokenOut, uint256(_amount0Delta))
            : (_tokenOut < _tokenIn, uint256(_amount1Delta));
        _amountToPay -= 1;
        if (_isExactInput) {
            pay(_tokenIn, _decodedData.payer, msg.sender, _amountToPay);
        } else {
            _tokenIn = _tokenOut; // swap in/out because exact output swaps are reversed
            pay(_tokenIn, _decodedData.payer, msg.sender, _amountToPay);
        }
    }

    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        address _to,
        uint256 _deadline
    ) external returns (uint256 liquidity_) {
        require(_deadline >= block.timestamp, "SmardexRouter: EXPIRED");
        address _pair = PoolAddress.pairFor(factory, _tokenA, _tokenB);
        bool _orderedPair = _tokenA < _tokenB;
        liquidity_ = ISmardexPair(_pair).mint(
            _to,
            _orderedPair ? _amountADesired : _amountBDesired,
            _orderedPair ? _amountBDesired : _amountADesired,
            msg.sender
        );
    }

    function swap(address _pair, address _to, bool _zeroForOne, int256 _amountSpecified, bytes calldata _path) public {
        ISmardexPair(_pair).swap(_to, _zeroForOne, _amountSpecified, _path);
    }
}
