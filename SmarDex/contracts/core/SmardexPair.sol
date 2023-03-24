// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.17;

// contracts
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

// libraries
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./libraries/SmardexLibrary.sol";
import "./libraries/TransferHelper.sol";

// interfaces
import "./interfaces/ISmardexPair.sol";
import "./interfaces/ISmardexFactory.sol";
import "./interfaces/ISmardexSwapCallback.sol";
import "./interfaces/ISmardexMintCallback.sol";

/**
 * @title SmardexPair
 * @notice Pair contract that allows user to swap 2 ERC20-strict tokens in a decentralised and automated way
 */
contract SmardexPair is ISmardexPair, ERC20Permit {
    using SafeCast for uint256;
    using SafeCast for int256;

    /**
     * @notice swap parameters used by function swap
     * @param amountCalculated return amount from getAmountIn/Out is always positive but to avoid too much cast, is int
     * @param fictiveReserveIn fictive reserve of the in-token of the pair
     * @param fictiveReserveOut fictive reserve of the out-token of the pair
     * @param priceAverageIn in-token ratio component of the price average
     * @param priceAverageOut out-token ratio component of the price average
     * @param token0 address of the token0
     * @param token1 address of the token1
     * @param balanceIn contract balance of the in-token
     * @param balanceOut contract balance of the out-token
     */
    struct SwapParams {
        int256 amountCalculated;
        uint256 fictiveReserveIn;
        uint256 fictiveReserveOut;
        uint256 priceAverageIn;
        uint256 priceAverageOut;
        address token0;
        address token1;
        uint256 balanceIn;
        uint256 balanceOut;
    }

    uint8 private constant CONTRACT_UNLOCKED = 1;
    uint8 private constant CONTRACT_LOCKED = 2;
    uint256 private constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant AUTOSWAP_SELECTOR = bytes4(keccak256(bytes("executeWork(address,address)")));

    address public factory;
    address public token0;
    address public token1;

    // smardex new fictive reserves
    uint128 internal fictiveReserve0;
    uint128 internal fictiveReserve1; // accessible via getFictiveReserves()

    // moving average on the price
    uint128 internal priceAverage0;
    uint128 internal priceAverage1;
    uint40 internal priceAverageLastTimestamp; // accessible via getPriceAverage()

    // fee for FEE_POOL
    uint104 internal feeToAmount0;
    uint104 internal feeToAmount1; // accessible via getFees()

    // reentrancy
    uint8 private lockStatus = CONTRACT_UNLOCKED;

    modifier lock() {
        require(lockStatus == CONTRACT_UNLOCKED, "SmarDex: LOCKED");
        lockStatus = CONTRACT_LOCKED;
        _;
        lockStatus = CONTRACT_UNLOCKED;
    }

    constructor() ERC20("SmarDex LP-Token", "SDEX-LP") ERC20Permit("SmarDex LP-Token") {
        factory = msg.sender;
    }

    ///@inheritdoc ISmardexPair
    function initialize(address _token0, address _token1) external override {
        require(msg.sender == factory, "SmarDex: FORBIDDEN"); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    ///@inheritdoc ISmardexPair
    function getReserves() external view override returns (uint256 reserve0_, uint256 reserve1_) {
        reserve0_ = IERC20(token0).balanceOf(address(this)) - feeToAmount0;
        reserve1_ = IERC20(token1).balanceOf(address(this)) - feeToAmount1;
    }

    ///@inheritdoc ISmardexPair
    function getFictiveReserves() external view override returns (uint256 fictiveReserve0_, uint256 fictiveReserve1_) {
        fictiveReserve0_ = fictiveReserve0;
        fictiveReserve1_ = fictiveReserve1;
    }

    ///@inheritdoc ISmardexPair
    function getFees() external view override returns (uint256 fees0_, uint256 fees1_) {
        fees0_ = feeToAmount0;
        fees1_ = feeToAmount1;
    }

    ///@inheritdoc ISmardexPair
    function getPriceAverage()
        external
        view
        returns (uint256 priceAverage0_, uint256 priceAverage1_, uint256 priceAverageLastTimestamp_)
    {
        priceAverage0_ = priceAverage0;
        priceAverage1_ = priceAverage1;
        priceAverageLastTimestamp_ = priceAverageLastTimestamp;
    }

    ///@inheritdoc ISmardexPair
    function getUpdatedPriceAverage(
        uint256 _fictiveReserveIn,
        uint256 _fictiveReserveOut,
        uint256 _priceAverageLastTimestamp,
        uint256 _priceAverageIn,
        uint256 _priceAverageOut,
        uint256 _currentTimestamp
    ) public pure returns (uint256 priceAverageIn_, uint256 priceAverageOut_) {
        (priceAverageIn_, priceAverageOut_) = SmardexLibrary.getUpdatedPriceAverage(
            _fictiveReserveIn,
            _fictiveReserveOut,
            _priceAverageLastTimestamp,
            _priceAverageIn,
            _priceAverageOut,
            _currentTimestamp
        );
    }

    ///@inheritdoc ISmardexPair
    function mint(
        address _to,
        uint256 _amount0,
        uint256 _amount1,
        address _payer
    ) external override returns (uint256 liquidity_) {
        liquidity_ = _mintBeforeFee(_to, _amount0, _amount1, _payer);

        // we call feeTo out of the internal locked mint (_mintExt) function to be able to swap fees in here
        _feeToSwap();
    }

    ///@inheritdoc ISmardexPair
    function burn(address _to) external override returns (uint256 amount0_, uint256 amount1_) {
        (amount0_, amount1_) = _burnBeforeFee(_to);

        // we call feeTo out of the internal locked burn (_burnExt) function to be able to swap fees in here
        _feeToSwap();
    }

    ///@inheritdoc ISmardexPair
    function swap(
        address _to,
        bool _zeroForOne,
        int256 _amountSpecified,
        bytes calldata _data
    ) external override lock returns (int256 amount0_, int256 amount1_) {
        require(_amountSpecified != 0, "SmarDex: ZERO_AMOUNT");

        SwapParams memory _params = SwapParams({
            amountCalculated: 0,
            fictiveReserveIn: 0,
            fictiveReserveOut: 0,
            priceAverageIn: 0,
            priceAverageOut: 0,
            token0: token0,
            token1: token1,
            balanceIn: 0,
            balanceOut: 0
        });

        (
            _params.balanceIn,
            _params.balanceOut,
            _params.fictiveReserveIn,
            _params.fictiveReserveOut,
            _params.priceAverageIn,
            _params.priceAverageOut
        ) = _zeroForOne
            ? (
                IERC20(_params.token0).balanceOf(address(this)) - feeToAmount0,
                IERC20(_params.token1).balanceOf(address(this)) - feeToAmount1,
                fictiveReserve0,
                fictiveReserve1,
                priceAverage0,
                priceAverage1
            )
            : (
                IERC20(_params.token1).balanceOf(address(this)) - feeToAmount1,
                IERC20(_params.token0).balanceOf(address(this)) - feeToAmount0,
                fictiveReserve1,
                fictiveReserve0,
                priceAverage1,
                priceAverage0
            );

        // compute new price average
        (_params.priceAverageIn, _params.priceAverageOut) = SmardexLibrary.getUpdatedPriceAverage(
            _params.fictiveReserveIn,
            _params.fictiveReserveOut,
            priceAverageLastTimestamp,
            _params.priceAverageIn,
            _params.priceAverageOut,
            block.timestamp
        );

        // SSTORE new price average
        (priceAverage0, priceAverage1, priceAverageLastTimestamp) = _zeroForOne
            ? (_params.priceAverageIn.toUint128(), _params.priceAverageOut.toUint128(), uint40(block.timestamp))
            : (_params.priceAverageOut.toUint128(), _params.priceAverageIn.toUint128(), uint40(block.timestamp));

        if (_amountSpecified > 0) {
            uint256 _temp;
            (_temp, , , _params.fictiveReserveIn, _params.fictiveReserveOut) = SmardexLibrary.getAmountOut(
                _amountSpecified.toUint256(),
                _params.balanceIn,
                _params.balanceOut,
                _params.fictiveReserveIn,
                _params.fictiveReserveOut,
                _params.priceAverageIn,
                _params.priceAverageOut
            );
            _params.amountCalculated = _temp.toInt256();
        } else {
            uint256 _temp;
            (_temp, , , _params.fictiveReserveIn, _params.fictiveReserveOut) = SmardexLibrary.getAmountIn(
                (-_amountSpecified).toUint256(),
                _params.balanceIn,
                _params.balanceOut,
                _params.fictiveReserveIn,
                _params.fictiveReserveOut,
                _params.priceAverageIn,
                _params.priceAverageOut
            );
            _params.amountCalculated = _temp.toInt256();
        }

        (amount0_, amount1_) = _zeroForOne
            ? (
                _amountSpecified > 0
                    ? (_amountSpecified, -_params.amountCalculated)
                    : (_params.amountCalculated, _amountSpecified)
            )
            : (
                _amountSpecified > 0
                    ? (-_params.amountCalculated, _amountSpecified)
                    : (_amountSpecified, _params.amountCalculated)
            );

        require(_to != _params.token0 && _to != _params.token1, "SmarDex: INVALID_TO");
        if (_zeroForOne) {
            if (amount1_ < 0) {
                TransferHelper.safeTransfer(_params.token1, _to, uint256(-amount1_));
            }
            ISmardexSwapCallback(msg.sender).smardexSwapCallback(amount0_, amount1_, _data);
            uint256 _balanceInBefore = _params.balanceIn;
            _params.balanceIn = IERC20(token0).balanceOf(address(this));
            require(
                _balanceInBefore + feeToAmount0 + (amount0_).toUint256() <= _params.balanceIn,
                "SmarDex: INSUFFICIENT_TOKEN0_INPUT_AMOUNT"
            );
            _params.balanceOut = IERC20(token1).balanceOf(address(this));
        } else {
            if (amount0_ < 0) {
                TransferHelper.safeTransfer(_params.token0, _to, uint256(-amount0_));
            }
            ISmardexSwapCallback(msg.sender).smardexSwapCallback(amount0_, amount1_, _data);
            uint256 _balanceInBefore = _params.balanceIn;
            _params.balanceIn = IERC20(token1).balanceOf(address(this));
            require(
                _balanceInBefore + feeToAmount1 + (amount1_).toUint256() <= _params.balanceIn,
                "SmarDex: INSUFFICIENT_TOKEN1_INPUT_AMOUNT"
            );
            _params.balanceOut = IERC20(token0).balanceOf(address(this));
        }

        // update feeTopart
        bool _feeOn = ISmardexFactory(factory).feeTo() != address(0);
        if (_zeroForOne) {
            if (_feeOn) {
                feeToAmount0 += ((uint256(amount0_) * SmardexLibrary.FEES_POOL) / SmardexLibrary.FEES_BASE).toUint104();
            }
            _update(
                _params.balanceIn,
                _params.balanceOut,
                _params.fictiveReserveIn,
                _params.fictiveReserveOut,
                _params.priceAverageIn,
                _params.priceAverageOut
            );
        } else {
            if (_feeOn) {
                feeToAmount1 += ((uint256(amount1_) * SmardexLibrary.FEES_POOL) / SmardexLibrary.FEES_BASE).toUint104();
            }
            _update(
                _params.balanceOut,
                _params.balanceIn,
                _params.fictiveReserveOut,
                _params.fictiveReserveIn,
                _params.priceAverageOut,
                _params.priceAverageIn
            );
        }

        emit Swap(msg.sender, _to, amount0_, amount1_);
    }

    /**
     * @notice update fictive reserves and emit the Sync event
     * @param _balance0 the new balance of token0
     * @param _balance1 the new balance of token1
     * @param _fictiveReserve0 the new fictive reserves of token0
     * @param _fictiveReserve1 the new fictive reserves of token1
     * @param _priceAverage0 the new priceAverage of token0
     * @param _priceAverage1 the new priceAverage of token1
     */
    function _update(
        uint256 _balance0,
        uint256 _balance1,
        uint256 _fictiveReserve0,
        uint256 _fictiveReserve1,
        uint256 _priceAverage0,
        uint256 _priceAverage1
    ) private {
        require(_fictiveReserve0 > 0 && _fictiveReserve1 > 0, "SmarDex: FICTIVE_RESERVES_TOO_LOW");
        require(_fictiveReserve0 <= type(uint128).max && _fictiveReserve1 <= type(uint128).max, "SmarDex: OVERFLOW");
        fictiveReserve0 = uint128(_fictiveReserve0);
        fictiveReserve1 = uint128(_fictiveReserve1);

        emit Sync(
            _balance0 - feeToAmount0,
            _balance1 - feeToAmount1,
            _fictiveReserve0,
            _fictiveReserve1,
            _priceAverage0,
            _priceAverage1
        );
    }

    /**
     * @notice transfers feeToAmount of tokens 0 and 1 to feeTo, and reset feeToAmounts
     * @return feeOn_ if part of the fees goes to feeTo
     */
    function _mintFee() private returns (bool feeOn_) {
        address _feeTo = ISmardexFactory(factory).feeTo();
        feeOn_ = _feeTo != address(0);
        if (feeOn_) {
            // gas saving
            uint256 _feeToAmount0 = feeToAmount0;
            uint256 _feeToAmount1 = feeToAmount1;

            if (_feeToAmount0 > 0) {
                TransferHelper.safeTransfer(token0, _feeTo, _feeToAmount0);
                feeToAmount0 = 0;
            }
            if (_feeToAmount1 > 0) {
                TransferHelper.safeTransfer(token1, _feeTo, _feeToAmount1);
                feeToAmount1 = 0;
            }
        } else {
            feeToAmount0 = 0;
            feeToAmount1 = 0;
        }
    }

    /**
     * @notice Mint lp tokens proportionally of added tokens in balance.
     * @param _to address who will receive minted tokens
     * @param _amount0 amount of token0 to provide
     * @param _amount1 amount of token1 to provide
     * @param _payer address of the payer to provide token for the mint
     * @return liquidity_ amount of lp tokens minted and sent to the address defined in parameter
     */
    function _mintBeforeFee(
        address _to,
        uint256 _amount0,
        uint256 _amount1,
        address _payer
    ) internal lock returns (uint256 liquidity_) {
        _mintFee();

        uint256 _fictiveReserve0;
        uint256 _fictiveReserve1;

        // gas saving
        uint256 _balance0 = IERC20(token0).balanceOf(address(this));
        uint256 _balance1 = IERC20(token1).balanceOf(address(this));
        uint256 _totalSupply = totalSupply();

        ISmardexMintCallback(msg.sender).smardexMintCallback(
            ISmardexMintCallback.MintCallbackData({
                token0: token0,
                token1: token1,
                amount0: _amount0,
                amount1: _amount1,
                payer: _payer
            })
        );

        // gas savings
        uint256 _balance0after = IERC20(token0).balanceOf(address(this));
        uint256 _balance1after = IERC20(token1).balanceOf(address(this));

        require(_balance0after >= _balance0 + _amount0, "SmarDex: INSUFFICIENT_AMOUNT_0");
        require(_balance1after >= _balance1 + _amount1, "SmarDex: INSUFFICIENT_AMOUNT_1");

        if (_totalSupply == 0) {
            liquidity_ = Math.sqrt(_amount0 * _amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0xdead), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
            _fictiveReserve0 = _balance0after / 2;
            _fictiveReserve1 = _balance1after / 2;
        } else {
            liquidity_ = Math.min((_amount0 * _totalSupply) / _balance0, (_amount1 * _totalSupply) / _balance1);

            // update proportionally the fictiveReserves
            _fictiveReserve0 = (fictiveReserve0 * (_totalSupply + liquidity_)) / _totalSupply;
            _fictiveReserve1 = (fictiveReserve1 * (_totalSupply + liquidity_)) / _totalSupply;
        }

        require(liquidity_ > 0, "SmarDex: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(_to, liquidity_);

        _update(_balance0after, _balance1after, _fictiveReserve0, _fictiveReserve1, priceAverage0, priceAverage1);

        emit Mint(msg.sender, _to, _amount0, _amount1);
    }

    /**
     * @notice Burn lp tokens in the balance of the contract. Sends to the defined address the amount of token0 and
     * token1 proportionally of the amount burned.
     * @param _to address who will receive tokens
     * @return amount0_ amount of token0 sent to the address defined in parameter
     * @return amount1_ amount of token0 sent to the address defined in parameter
     */
    function _burnBeforeFee(address _to) internal lock returns (uint256 amount0_, uint256 amount1_) {
        _mintFee();

        // gas savings
        address _token0 = token0;
        address _token1 = token1;
        uint256 _balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 _balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 _liquidity = balanceOf(address(this));
        uint256 _totalSupply = totalSupply();

        // pro-rata distribution
        amount0_ = (_liquidity * _balance0) / _totalSupply;
        amount1_ = (_liquidity * _balance1) / _totalSupply;
        require(amount0_ > 0 && amount1_ > 0, "SmarDex: INSUFFICIENT_LIQUIDITY_BURNED");

        // update proportionally the fictiveReserves
        uint256 _fictiveReserve0 = fictiveReserve0;
        uint256 _fictiveReserve1 = fictiveReserve1;
        _fictiveReserve0 -= (_fictiveReserve0 * _liquidity) / _totalSupply;
        _fictiveReserve1 -= (_fictiveReserve1 * _liquidity) / _totalSupply;

        _burn(address(this), _liquidity);
        TransferHelper.safeTransfer(_token0, _to, amount0_);
        TransferHelper.safeTransfer(_token1, _to, amount1_);

        _balance0 = IERC20(_token0).balanceOf(address(this));
        _balance1 = IERC20(_token1).balanceOf(address(this));

        _update(_balance0, _balance1, _fictiveReserve0, _fictiveReserve1, priceAverage0, priceAverage1);

        emit Burn(msg.sender, _to, amount0_, amount1_);
    }

    /**
     * @notice execute function "executeWork(address,address)" of the feeTo contract. Doesn't revert tx if it reverts
     */
    function _feeToSwap() internal {
        address _feeTo = ISmardexFactory(factory).feeTo();

        // call contract destination for handling fees
        // We don't handle return values so it does not revert for LP if something went wrong in feeTo
        _feeTo.call(abi.encodeWithSelector(AUTOSWAP_SELECTOR, token0, token1));
    }
}
