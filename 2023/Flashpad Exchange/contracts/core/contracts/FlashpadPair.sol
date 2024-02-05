pragma solidity =0.5.16;

import "./interfaces/IFlashpadPair.sol";
import "./UniswapV2ERC20.sol";
import "./libraries/Math.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IFlashpadFactory.sol";
import "./interfaces/IUniswapV2Callee.sol";

contract FlashpadPair is IFlashpadPair, UniswapV2ERC20 {
  using SafeMath  for uint;

  uint public constant MINIMUM_LIQUIDITY = 10 ** 3;
  uint public constant MAXIMUM_TIMELOCK = 90 days;
  bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

  address public factory;
  address public token0;
  address public token1;

  bool public initialized;

  uint public constant FEE_DENOMINATOR = 100000;
  uint public constant MAX_FEE_PERCENT = 2000; // = 2%

  uint112 private reserve0;           // uses single storage slot, accessible via getReserves
  uint112 private reserve1;           // uses single storage slot, accessible via getReserves
  uint16 public token0FeePercent = 300; // default = 0.3%  // uses single storage slot, accessible via getReserves
  uint16 public token1FeePercent = 300; // default = 0.3%  // uses single storage slot, accessible via getReserves

  uint public precisionMultiplier0;
  uint public precisionMultiplier1;

  uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

  bool public stableSwap; // if set to true, defines pair type as stable
  bool public pairTypeImmutable; // if set to true, stableSwap states cannot be updated anymore

  uint256 public timeLock;
  uint256 public initTime;
  uint256 public startTime;
  uint private unlocked = 1;
  modifier lock() {
    require(unlocked == 1, "FlashpadPair: LOCKED");
    unlocked = 0;
    _;
    unlocked = 1;
  }

  function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint16 _token0FeePercent, uint16 _token1FeePercent) {
    _reserve0 = reserve0;
    _reserve1 = reserve1;
    _token0FeePercent = token0FeePercent;
    _token1FeePercent = token1FeePercent;
  }

  function _safeTransfer(address token, address to, uint value) private {
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), "FlashpadPair: TRANSFER_FAILED");
  }

  event DrainWrongToken(address indexed token, address to);
  event FeePercentUpdated(uint16 token0FeePercent, uint16 token1FeePercent);
  event SetStableSwap(bool prevStableSwap, bool stableSwap);
  event SetPairTypeImmutable();
  event SetPairTimeLock(uint256 oldValue, uint256 newValue);
  event SetPairStartTime(uint256 oldValue, uint256 newValue);
  event Mint(address indexed sender, uint amount0, uint amount1);
  event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
  event Swap(
    address indexed sender,
    uint amount0In,
    uint amount1In,
    uint amount0Out,
    uint amount1Out,
    address indexed to
  );
  event Sync(uint112 reserve0, uint112 reserve1);
  event Skim();

  constructor() public {
    factory = msg.sender;
  }

  // called once by the factory at time of deployment
  function initialize(address _token0, address _token1, uint256 _timeLock, uint256 _startTime) external {
    require(msg.sender == factory && !initialized, "FlashpadPair: FORBIDDEN");
    require(timeLock <= MAXIMUM_TIMELOCK, "FlashpadPair: timeLock mustn't exceed the maximum");
    // sufficient check
    token0 = _token0;
    token1 = _token1;

    precisionMultiplier0 = 10 ** uint(IERC20(_token0).decimals());
    precisionMultiplier1 = 10 ** uint(IERC20(_token1).decimals());

    initTime = block.timestamp;
    timeLock = _timeLock;
    startTime = _startTime;

    initialized = true;
  }

  /**
  * @dev Updates the swap fees percent
  *
  * Can only be called by the factory's feeAmountOwner
  */
  function setFeePercent(uint16 newToken0FeePercent, uint16 newToken1FeePercent) external lock {
    require(msg.sender == IFlashpadFactory(factory).feePercentOwner(), "FlashpadPair: only factory's feeAmountOwner");
    require(newToken0FeePercent <= MAX_FEE_PERCENT && newToken1FeePercent <= MAX_FEE_PERCENT, "FlashpadPair: feePercent mustn't exceed the maximum");
    require(newToken0FeePercent > 0 && newToken1FeePercent > 0, "FlashpadPair: feePercent mustn't exceed the minimum");
    token0FeePercent = newToken0FeePercent;
    token1FeePercent = newToken1FeePercent;
    emit FeePercentUpdated(newToken0FeePercent, newToken1FeePercent);
  }

  /**
  * @dev Set pair is stable
  *
  * Can only be called by the factory's setStableOwner
  */
  function setStableSwap(bool stable, uint112 expectedReserve0, uint112 expectedReserve1) external lock {
    require(msg.sender == IFlashpadFactory(factory).setStableOwner(), "FlashpadPair: only factory's setStableOwner");
    require(!pairTypeImmutable, "FlashpadPair: immutable");

    require(stable != stableSwap, "FlashpadPair: no update");
    require(expectedReserve0 == reserve0 && expectedReserve1 == reserve1, "FlashpadPair: failed");

    bool feeOn = _mintFee(reserve0, reserve1);

    emit SetStableSwap(stableSwap, stable);
    stableSwap = stable;
    kLast = (stable && feeOn) ? _k(uint(reserve0), uint(reserve1)) : 0;
  }

  /**
  * @dev Set pair is mmutable
  *
  * Can only be called by the factory's owner
  */
  function setPairTypeImmutable() external lock {
    require(msg.sender == IFlashpadFactory(factory).owner(), "FlashpadPair: only factory's owner");
    require(!pairTypeImmutable, "FlashpadPair: already immutable");

    pairTypeImmutable = true;
    emit SetPairTypeImmutable();
  }

  /**
  * @dev Set time lock to remove liquidity
  *
  * Can only be called by the factory's owner
  */
  function setPairTimeLock(uint256 _timeLock) external lock {
    require(msg.sender == IFlashpadFactory(factory).owner(), "FlashpadPair: only factory's owner");
    require(!pairTypeImmutable, "FlashpadPair: immutable");
    require(timeLock <= MAXIMUM_TIMELOCK, "FlashpadPair: timeLock mustn't exceed the maximum");

    uint256 oldValue = timeLock;
    timeLock = _timeLock;

    emit SetPairTimeLock(oldValue, timeLock);
  }

  /**
  * @dev Set time start to user can swap
  *
  * Can only be called by the factory's owner
  */
  function setPairStartTime(uint256 _startTime) external lock {
    require(msg.sender == IFlashpadFactory(factory).owner(), "FlashpadPair: only factory's owner");
    require(!pairTypeImmutable, "FlashpadPair: immutable");

    uint256 oldValue = startTime;
    startTime = _startTime;

    emit SetPairStartTime(oldValue, startTime);
  }

  // update reserves
  function _update(uint balance0, uint balance1) private {
    require(balance0 <= uint112(- 1) && balance1 <= uint112(- 1), "FlashpadPair: OVERFLOW");

    reserve0 = uint112(balance0);
    reserve1 = uint112(balance1);
    emit Sync(uint112(balance0), uint112(balance1));
  }

  // if fee is on, mint liquidity equivalent to "factory.ownerFeeShare()" of the growth in sqrt(k)
  // only for uni configuration
  function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
    if(stableSwap) return false;

    (uint ownerFeeShare, address feeTo) = IFlashpadFactory(factory).feeInfo();
    feeOn = feeTo != address(0);
    uint _kLast = kLast;
    // gas savings
    if (feeOn) {
      if (_kLast != 0) {
        uint rootK = Math.sqrt(_k(uint(_reserve0), uint(_reserve1)));
        uint rootKLast = Math.sqrt(_kLast);
        if (rootK > rootKLast) {
          uint d = (FEE_DENOMINATOR.mul(100) / ownerFeeShare).sub(100);
          uint numerator = totalSupply.mul(rootK.sub(rootKLast)).mul(100);
          uint denominator = rootK.mul(d).add(rootKLast.mul(100));
          uint liquidity = numerator / denominator;
          if (liquidity > 0) _mint(feeTo, liquidity);
        }
      }
    } else if (_kLast != 0) {
      kLast = 0;
    }
  }

  // this low-level function should be called from a contract which performs important safety checks
  function mint(address to) external lock returns (uint liquidity) {
    (uint112 _reserve0, uint112 _reserve1,,) = getReserves();
    // gas savings
    uint balance0 = IERC20(token0).balanceOf(address(this));
    uint balance1 = IERC20(token1).balanceOf(address(this));
    uint amount0 = balance0.sub(_reserve0);
    uint amount1 = balance1.sub(_reserve1);

    bool feeOn = _mintFee(_reserve0, _reserve1);
    uint _totalSupply = totalSupply;
    // gas savings, must be defined here since totalSupply can update in _mintFee
    if (_totalSupply == 0) {
      liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
      _mint(address(0), MINIMUM_LIQUIDITY);
      // permanently lock the first MINIMUM_LIQUIDITY tokens
    } else {
      liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
    }
    require(liquidity > 0, "FlashpadPair: INSUFFICIENT_LIQUIDITY_MINTED");
    _mint(to, liquidity);

    _update(balance0, balance1);
    if (feeOn) kLast = _k(uint(reserve0), uint(reserve1));
    // reserve0 and reserve1 are up-to-date
    emit Mint(msg.sender, amount0, amount1);
  }

  // this low-level function should be called from a contract which performs important safety checks
  function burn(address to) external lock returns (uint amount0, uint amount1) {
    require(block.timestamp >= getTimeCanRemoveLiquidity(), "FlashpadPair: INVALID_TIME_LOCK");
    (uint112 _reserve0, uint112 _reserve1,,) = getReserves(); // gas savings
    address _token0 = token0; // gas savings
    address _token1 = token1; // gas savings
    uint balance0 = IERC20(_token0).balanceOf(address(this));
    uint balance1 = IERC20(_token1).balanceOf(address(this));
    uint liquidity = balanceOf[address(this)];

    bool feeOn = _mintFee(_reserve0, _reserve1);
    uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
    amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
    amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
    require(amount0 > 0 && amount1 > 0, "FlashpadPair: INSUFFICIENT_LIQUIDITY_BURNED");
    _burn(address(this), liquidity);
    _safeTransfer(_token0, to, amount0);
    _safeTransfer(_token1, to, amount1);
    balance0 = IERC20(_token0).balanceOf(address(this));
    balance1 = IERC20(_token1).balanceOf(address(this));

    _update(balance0, balance1);
    if (feeOn) kLast = _k(uint(reserve0), uint(reserve1)); // reserve0 and reserve1 are up-to-date
    emit Burn(msg.sender, amount0, amount1, to);
  }

  struct TokensData {
    address token0;
    address token1;
    uint amount0Out;
    uint amount1Out;
    uint balance0;
    uint balance1;
    uint remainingFee0;
    uint remainingFee1;
  }

  // this low-level function should be called from a contract which performs important safety checks
  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {
    TokensData memory tokensData = TokensData({
      token0: token0,
      token1: token1,
      amount0Out: amount0Out,
      amount1Out: amount1Out,
      balance0: 0,
      balance1: 0,
      remainingFee0: 0,
      remainingFee1: 0
    });
    _swap(tokensData, to, data, address(0));
  }

  // this low-level function should be called from a contract which performs important safety checks
  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data, address referrer) external {
    TokensData memory tokensData = TokensData({
      token0: token0,
      token1: token1,
      amount0Out: amount0Out,
      amount1Out: amount1Out,
      balance0: 0,
      balance1: 0,
      remainingFee0: 0,
      remainingFee1: 0
    });
    _swap(tokensData, to, data, referrer);
  }


  function _swap(TokensData memory tokensData, address to, bytes memory data, address referrer) internal lock {
    require(block.timestamp >= startTime, "FlashpadPair: INVALID_TIME");
    require(tokensData.amount0Out > 0 || tokensData.amount1Out > 0, "FlashpadPair: INSUFFICIENT_OUTPUT_AMOUNT");

    (uint112 _reserve0, uint112 _reserve1, uint16 _token0FeePercent, uint16 _token1FeePercent) = getReserves();
    require(tokensData.amount0Out < _reserve0 && tokensData.amount1Out < _reserve1, "FlashpadPair: INSUFFICIENT_LIQUIDITY");


    {
      require(to != tokensData.token0 && to != tokensData.token1, "FlashpadPair: INVALID_TO");
      // optimistically transfer tokens
      if (tokensData.amount0Out > 0) _safeTransfer(tokensData.token0, to, tokensData.amount0Out);
      // optimistically transfer tokens
      if (tokensData.amount1Out > 0) _safeTransfer(tokensData.token1, to, tokensData.amount1Out);
      if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, tokensData.amount0Out, tokensData.amount1Out, data);
      tokensData.balance0 = IERC20(tokensData.token0).balanceOf(address(this));
      tokensData.balance1 = IERC20(tokensData.token1).balanceOf(address(this));
    }

    uint amount0In = tokensData.balance0 > _reserve0 - tokensData.amount0Out ? tokensData.balance0 - (_reserve0 - tokensData.amount0Out) : 0;
    uint amount1In = tokensData.balance1 > _reserve1 - tokensData.amount1Out ? tokensData.balance1 - (_reserve1 - tokensData.amount1Out) : 0;
    require(amount0In > 0 || amount1In > 0, "FlashpadPair: INSUFFICIENT_INPUT_AMOUNT");

    tokensData.remainingFee0 = amount0In.mul(_token0FeePercent) / FEE_DENOMINATOR;
    tokensData.remainingFee1 = amount1In.mul(_token1FeePercent) / FEE_DENOMINATOR;

    {// scope for referer/stable fees management
      uint fee = 0;

      uint referrerInputFeeShare = referrer != address(0) ? IFlashpadFactory(factory).referrersFeeShare(referrer) : 0;
      if (referrerInputFeeShare > 0) {
        if (amount0In > 0) {
          fee = amount0In.mul(referrerInputFeeShare).mul(_token0FeePercent) / (FEE_DENOMINATOR ** 2);
          tokensData.remainingFee0 = tokensData.remainingFee0.sub(fee);
          _safeTransfer(tokensData.token0, referrer, fee);
        }
        if (amount1In > 0) {
          fee = amount1In.mul(referrerInputFeeShare).mul(_token1FeePercent) / (FEE_DENOMINATOR ** 2);
          tokensData.remainingFee1 = tokensData.remainingFee1.sub(fee);
          _safeTransfer(tokensData.token1, referrer, fee);
        }
      }

      if(stableSwap){
        (uint ownerFeeShare, address feeTo) = IFlashpadFactory(factory).feeInfo();
        if(feeTo != address(0)) {
          ownerFeeShare = FEE_DENOMINATOR.sub(referrerInputFeeShare).mul(ownerFeeShare);
          if (amount0In > 0) {
            fee = amount0In.mul(ownerFeeShare).mul(_token0FeePercent) / (FEE_DENOMINATOR ** 3);
            tokensData.remainingFee0 = tokensData.remainingFee0.sub(fee);
            _safeTransfer(tokensData.token0, feeTo, fee);
          }
          if (amount1In > 0) {
            fee = amount1In.mul(ownerFeeShare).mul(_token1FeePercent) / (FEE_DENOMINATOR ** 3);
            tokensData.remainingFee1 = tokensData.remainingFee1.sub(fee);
            _safeTransfer(tokensData.token1, feeTo, fee);
          }
        }
      }
      // readjust tokens balance
      if (amount0In > 0) tokensData.balance0 = IERC20(tokensData.token0).balanceOf(address(this));
      if (amount1In > 0) tokensData.balance1 = IERC20(tokensData.token1).balanceOf(address(this));
    }
    {// scope for reserve{0,1}Adjusted, avoids stack too deep errors
      uint balance0Adjusted = tokensData.balance0.sub(tokensData.remainingFee0);
      uint balance1Adjusted = tokensData.balance1.sub(tokensData.remainingFee1);
      require(_k(balance0Adjusted, balance1Adjusted) >= _k(uint(_reserve0), uint(_reserve1)), "FlashpadPair: K");
    }
    _update(tokensData.balance0, tokensData.balance1);
    emit Swap(msg.sender, amount0In, amount1In, tokensData.amount0Out, tokensData.amount1Out, to);
  }

  function _k(uint balance0, uint balance1) internal view returns (uint) {
    if (stableSwap) {
      uint _x = balance0.mul(1e18) / precisionMultiplier0;
      uint _y = balance1.mul(1e18) / precisionMultiplier1;
      uint _a = (_x.mul(_y)) / 1e18;
      uint _b = (_x.mul(_x) / 1e18).add(_y.mul(_y) / 1e18);
      return  _a.mul(_b) / 1e18; // x3y+y3x >= k
    }
    return balance0.mul(balance1);
  }

  function _get_y(uint x0, uint xy, uint y) internal pure returns (uint) {
    for (uint i = 0; i < 255; i++) {
      uint y_prev = y;
      uint k = _f(x0, y);
      if (k < xy) {
        uint dy = (xy - k) * 1e18 / _d(x0, y);
        y = y + dy;
      } else {
        uint dy = (k - xy) * 1e18 / _d(x0, y);
        y = y - dy;
      }
      if (y > y_prev) {
        if (y - y_prev <= 1) {
          return y;
        }
      } else {
        if (y_prev - y <= 1) {
          return y;
        }
      }
    }
    return y;
  }

  function _f(uint x0, uint y) internal pure returns (uint) {
    return x0 * (y * y / 1e18 * y / 1e18) / 1e18 + (x0 * x0 / 1e18 * x0 / 1e18) * y / 1e18;
  }

  function _d(uint x0, uint y) internal pure returns (uint) {
    return 3 * x0 * (y * y / 1e18) / 1e18 + (x0 * x0 / 1e18 * x0 / 1e18);
  }

  function getAmountOut(uint amountIn, address tokenIn) external view returns (uint) {
    uint16 feePercent = tokenIn == token0 ? token0FeePercent : token1FeePercent;
    return _getAmountOut(amountIn, tokenIn, uint(reserve0), uint(reserve1), feePercent);
  }

  function _getAmountOut(uint amountIn, address tokenIn, uint _reserve0, uint _reserve1, uint feePercent) internal view returns (uint) {
    if (stableSwap) {
      amountIn = amountIn.sub(amountIn.mul(feePercent) / FEE_DENOMINATOR); // remove fee from amount received
      uint xy = _k(_reserve0, _reserve1);
      _reserve0 = _reserve0 * 1e18 / precisionMultiplier0;
      _reserve1 = _reserve1 * 1e18 / precisionMultiplier1;

      (uint reserveA, uint reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
      amountIn = tokenIn == token0 ? amountIn * 1e18 / precisionMultiplier0 : amountIn * 1e18 / precisionMultiplier1;
      uint y = reserveB - _get_y(amountIn + reserveA, xy, reserveB);
      return y * (tokenIn == token0 ? precisionMultiplier1 : precisionMultiplier0) / 1e18;

    } else {
      (uint reserveA, uint reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
      amountIn = amountIn.mul(FEE_DENOMINATOR.sub(feePercent));
      return (amountIn.mul(reserveB)) / (reserveA.mul(FEE_DENOMINATOR).add(amountIn));
    }
  }

  // force balances to match reserves
  function skim(address to) external lock {
    address _token0 = token0;
    // gas savings
    address _token1 = token1;
    // gas savings
    _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
    _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    emit Skim();
  }

  // force reserves to match balances
  function sync() external lock {
    uint token0Balance = IERC20(token0).balanceOf(address(this));
    uint token1Balance = IERC20(token1).balanceOf(address(this));
    require(token0Balance != 0 && token1Balance != 0, "FlashpadPair: liquidity ratio not initialized");
    _update(token0Balance, token1Balance);
  }

  /**
  * @dev Allow to recover token sent here by mistake
  *
  * Can only be called by factory's owner
  */
  function drainWrongToken(address token, address to) external lock {
    require(msg.sender == IFlashpadFactory(factory).owner(), "FlashpadPair: only factory's owner");
    require(token != token0 && token != token1, "FlashpadPair: invalid token");
    _safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
    emit DrainWrongToken(token, to);
  }

  /**
  * @dev Get time can remove liquidity
  */
  function getTimeCanRemoveLiquidity() public view returns (uint256) {
    return initTime + timeLock;
  }
}
