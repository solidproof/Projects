// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IPancakeswapV2Factory.sol";
import "./IPancakeswapV2Router02.sol";

contract GoldRushToken is Context, IERC20, Ownable {
  using SafeMath for uint256;
  string private constant NAME = "GoldRushToken";
  string private constant SYMBOL = "$GRUSH";
  uint8 private constant DECIMALS = 18;

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;
  mapping (address => bool) private _isExcludedFromFee;

  uint256 private constant TOTAL = 1 * 10**9 * 10**18;

  uint256[3] public fees = [4, 1, 2];

  IPancakeswapV2Router02 public pancakeswapV2Router;
  address public pancakeswapV2Pair;

  uint256 public maxTxAmount =  2 * 10**5 * 10**18;
  uint256 public numTokensToSwap =  3 * 10**3 * 10**18;

  bool inSwapAndLiquify;
  bool public swapAndLiquifyEnabled = true;

  address public farmPool;
  address public rewardPool;

  event UpdatedFees(uint256[3] oldFees, uint256[3] newFees);
  event SwapAndLiquifyEnabledUpdated(bool enabled);
  event SwapAndLiquify(
      uint256 tokensSwapped,
      uint256 ethReceived,
      uint256 tokensIntoLiquidity
  );
  event ExcludedFromFee(address account);
  event IncludedToFee(address account);
  event UpdatedMaxTxAmount(uint256 maxTxAmount);
  event UpdateNumtokensToSwap(uint256 amount);
  event UpdateStakingPool(address oldPool, address newPool);
  event UpdateRewardPool(address oldPool, address newPool);

  modifier lockTheSwap {
    inSwapAndLiquify = true;
    _;
    inSwapAndLiquify = false;
  }

  constructor(address _rewardPool, address _farmPool) {
    // IPancakeswapV2Router02 _pancakeswapV2Router = IPancakeswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
    //Mian Net
    IPancakeswapV2Router02 _pancakeswapV2Router = IPancakeswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    pancakeswapV2Pair = IPancakeswapV2Factory(_pancakeswapV2Router.factory())
        .createPair(address(this), _pancakeswapV2Router.WETH());

    // set the rest of the contract variables
    pancakeswapV2Router = _pancakeswapV2Router;
    _isExcludedFromFee[_msgSender()] = true;
    _isExcludedFromFee[address(this)] = true;
    _balances[_msgSender()] = TOTAL;
    rewardPool = _rewardPool;
    farmPool = _farmPool;
    emit Transfer(address(0), owner(), TOTAL);
  }

  function symbol() external pure returns (string memory) {
    return SYMBOL;
  }

  function name() external pure returns (string memory) {
    return NAME;
  }

  function decimals() external pure returns (uint8) {
    return DECIMALS;
  }

  function totalSupply() external pure override returns (uint256) {
    return TOTAL;
  }

  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) external override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) external override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
    return true;
  }

  function _approve(address owner, address spender, uint256 amount) private {
    require(owner != address(0), "BEP20: approve from the zero address");
    require(spender != address(0), "BEP20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function isExcludedFromFee(address account) external view returns(bool) {
    return _isExcludedFromFee[account];
  }

  function excludeFromFee(address account) external onlyOwner {
    _isExcludedFromFee[account] = true;
    emit ExcludedFromFee(account);
  }

  function includeInFee(address account) external onlyOwner {
    _isExcludedFromFee[account] = false;
    emit IncludedToFee(account);
  }

  function setMaxTxAmount(uint256 amount) external onlyOwner() {
    require(amount > 10000 * 10**18, "Max tx amount should be over zero");
    maxTxAmount = amount;
    emit UpdatedMaxTxAmount(amount);
  }

  function setNumTokensToSwap(uint256 amount) external onlyOwner() {
    require(numTokensToSwap != amount, "This value was already set");
    numTokensToSwap = amount;
    emit UpdateNumtokensToSwap(amount);
  }


  function setSwapAndLiquifyEnabled(bool enabled) external onlyOwner {
    swapAndLiquifyEnabled = enabled;
    emit SwapAndLiquifyEnabledUpdated(enabled);
  }

    //to receive ETH from pancakeswapV2Router when swapping
  receive() external payable {}

  function setFees(uint256[3] memory _fees) external onlyOwner {
    require (_fees[0] + _fees[1] + _fees[2] < 20, "value can not be over 20");
    emit UpdatedFees(fees, _fees);
    fees = _fees;
  }

  function _transfer(
      address from,
      address to,
      uint256 amount
  ) private {
      require(from != address(0), "BEP20: transfer from the zero address");
      require(to != address(0), "BEP20: transfer to the zero address");
      require(amount > 0, "Transfer amount must be greater than zero");

      if(
          !_isExcludedFromFee[from] &&
          !_isExcludedFromFee[to] &&
          balanceOf(pancakeswapV2Pair) > 0 &&
          !inSwapAndLiquify &&
          from != address(pancakeswapV2Router) &&
          (from == pancakeswapV2Pair || to == pancakeswapV2Pair)
      ) {
          require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
      }

      uint256 tokenBalance = balanceOf(address(this));
      if(tokenBalance >= maxTxAmount)
      {
          tokenBalance = maxTxAmount;
      }

      bool overMinTokenBalance = tokenBalance >= numTokensToSwap;
      if (
          overMinTokenBalance &&
          !inSwapAndLiquify &&
          from != pancakeswapV2Pair &&
          swapAndLiquifyEnabled
      ) {
          tokenBalance = numTokensToSwap;
          swapAndLiquify(tokenBalance);
      }

      bool takeFee = false;
      if (balanceOf(pancakeswapV2Pair) > 0 && (from == pancakeswapV2Pair || to == pancakeswapV2Pair)) {
          takeFee = true;
      }

      if (_isExcludedFromFee[from] || _isExcludedFromFee[to]){
          takeFee = false;
      }

      _tokenTransfer(from,to,amount,takeFee);
  }

  function swapTokensForEth(uint256 tokenAmount) private {

    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = pancakeswapV2Router.WETH();

    _approve(address(this), address(pancakeswapV2Router), tokenAmount);

    pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokenAmount,
        0, // accept any amount of ETH
        path,
        address(this),
        block.timestamp
    );
  }

  function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

    _approve(address(this), address(pancakeswapV2Router), tokenAmount);

    pancakeswapV2Router.addLiquidityETH{value: ethAmount}(
        address(this),
        tokenAmount,
        0, // slippage is unavoidable
        0, // slippage is unavoidable
        address(this),
        block.timestamp
    );
  }
  function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
    // split the contract balance into halves
    uint256 half = contractTokenBalance.div(2);
    uint256 otherHalf = contractTokenBalance.sub(half);

    // capture the contract's current ETH balance.
    // this is so that we can capture exactly the amount of ETH that the
    // swap creates, and not make the liquidity event include any ETH that
    // has been manually sent to the contract
    uint256 initialBalance = address(this).balance;

    // swap tokens for ETH
    swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

    // how much ETH did we just swap into?
    uint256 newBalance = address(this).balance.sub(initialBalance);

    // add liquidity to uniswap
    addLiquidity(otherHalf, newBalance);

    emit SwapAndLiquify(half, newBalance, otherHalf);
  }

  function _takeFees(uint256 amount) internal returns(uint256) {
    uint256 rewardFee = amount.mul(fees[0]).div(100);
    uint256 stakingFee = amount.mul(fees[1]).div(100);
    uint256 liquidityFee = amount.mul(fees[2]).div(100);
    _balances[rewardPool] = _balances[rewardPool].add(rewardFee);
    _balances[farmPool] = _balances[farmPool].add(stakingFee);
    _balances[address(this)] = _balances[address(this)].add(liquidityFee);
    return amount.sub(rewardFee).sub(stakingFee).sub(liquidityFee);
  }

  function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {

    uint256 tTransferAmount = amount;
    if (takeFee) {
      tTransferAmount = _takeFees(amount);
    }
    _balances[sender] = _balances[sender].sub(amount);
    _balances[recipient] = _balances[recipient].add(tTransferAmount);
    emit Transfer(sender, recipient, tTransferAmount);
  }

}