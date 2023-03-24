// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.17;

//contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//libraries
import "../libraries/PoolAddress.sol";

//interfaces
import "../interfaces/ISmardexRouter.sol";
import "../../core/interfaces/ISmardexFactory.sol";

contract FakeERC20reentrancy is ERC20 {
    address public immutable factory;
    address public immutable WETH;

    bool private active = false;

    error PairNotFound(address token0, address token1);

    constructor(address _factory, address _weth) ERC20("FakeERC20reentrancy", "FRE") {
        factory = _factory;
        WETH = _weth;
        _mint(msg.sender, 100_000_000 ether);
    }

    function activate() external {
        active = !active;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        if (active && recipient == PoolAddress.pairFor(factory, address(this), WETH)) {
            active = false;
            //try to reentrancy add liquidity
            ISmardexPair(recipient).mint(address(this), 100, 100, address(this));
        }
        return super.transferFrom(sender, recipient, amount);
    }

    struct SwapCallbackData {
        address payer;
        bytes path;
    }

    // From UniV3 PeripheryPayments.sol
    // https://github.com/Uniswap/v3-periphery/blob/v1.3.0/contracts/base/PeripheryPayments.sol
    /// @param _token The token to pay
    /// @param _payer The entity that must pay
    /// @param _to The entity that will receive payment
    /// @param _value The amount to pay
    function pay(address _token, address _payer, address _to, uint256 _value) internal {
        // pull payment
        if (_token == address(this)) transferFrom(_payer, _to, _value);
        else IERC20(_token).transferFrom(_payer, _to, _value);
    }

    function smardexMintCallback(ISmardexMintCallback.MintCallbackData calldata _data) external {
        require(_data.amount0 > 0 || _data.amount1 > 0, "SmardexRouter: Callback Invalid amount");
        require(msg.sender == PoolAddress.pairFor(factory, _data.token0, _data.token1), "SmarDexRouter: INVALID_PAIR"); // ensure that msg.sender is a pair
        // ISmardexPair(msg.sender).mint(address(this), 1, 1, _data.payer);
        pay(_data.token0, _data.payer, msg.sender, _data.amount0);
        pay(_data.token1, _data.payer, msg.sender, _data.amount1);
    }

    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        address _to,
        uint256 _deadline
    ) public returns (uint256 liquidity_) {
        require(_deadline >= block.timestamp, "SmardexRouter: EXPIRED");
        address _pair = ISmardexFactory(factory).getPair(_tokenA, _tokenB);
        if (_pair == address(0)) {
            revert PairNotFound(_tokenA, _tokenB);
        }
        bool _orderedPair = _tokenA < _tokenB;
        liquidity_ = ISmardexPair(_pair).mint(
            _to,
            _orderedPair ? _amountADesired : _amountBDesired,
            _orderedPair ? _amountBDesired : _amountADesired,
            msg.sender
        );
    }
}
