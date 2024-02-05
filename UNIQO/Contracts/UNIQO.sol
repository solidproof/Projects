// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/IDEXRouter.sol";
import "./interfaces/IDEXFactory.sol";
import "./interfaces/IDEXPair.sol";

/**
 * @title UNIQO ERC20 token
 */
contract Uniqo is IERC20, Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
      _disableInitializers();
  }

  using SafeMath for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  string private constant _name = "Uniqo";
  string private constant _symbol = "UNIQO";
  uint8 private constant _decimals = 18;

  uint256 private constant ONE_UNIT = 10**_decimals;
  uint256 private constant INITIAL_FRAGMENTS_SUPPLY = (10**9 ) * ONE_UNIT; // 1 billion
  uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);
  uint256 private constant DEFAULT_GONSWAP_THRESHOLD = TOTAL_GONS / 1000;

  /**
   * @notice The max possible number that fits uint256. This constant is used throughout the project.
   * @return The max uint256 value (2^256 - 1).
   */
  uint256 public constant MAX_UINT256 = ~uint256(0);
  /**
   * @notice The so-called `dead` address that is commonly used to send burned tokens to.
   * @return The `dead` address.
   */
  address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
  /**
   * @notice The zero address that is commonly used for burning tokens. You can think about it as `/dev/null`.
   * @return The zero address.
   */
  address public constant ZERO = 0x0000000000000000000000000000000000000000;
  /**
   * @notice The upper limit of the factor that is used to calculate the max amount of tokens a user can sell during 24 hours.
   * @return The upper limit of the factor.
   */
  uint256 public constant MAX_DAILY_TAKE_PROFIT_FACTOR = 100;
  /**
   * @notice The lower limit of the factor that is used to calculate the max amount of tokens a user can sell during 24 hours.
   * @return The lower limit of the factor.
   */
  uint256 public constant MIN_DAILY_TAKE_PROFIT_FACTOR = 10;
  /**
   * @notice The upper limit of sell fee
   */
  uint256 public constant MAX_SELL_FEE = 20;
  /**
   * @notice The upper limit of buy fee
   */
  uint256 public constant MAX_BUY_FEE = 15;
  /**
   * @notice The upper limit of transfer fee
   */
  uint256 public constant MAX_TRANSFER_FEE = 50;

  uint256 private _totalSupply;
  uint256 private _gonsPerFragment;
  bool private _inSwap;
  uint256 private _gonsCollectedFeeThreshold;

  mapping(address => uint256) public transferTimelock;
  /**
   * @notice The automated market maker pairs.
   * @return The mapping with automated market maker pairs.
   */
  mapping(address => bool) public automatedMarketMakerPairs;
  mapping(address => uint256) private _gonBalances;
  mapping(address => mapping(address => uint256)) private _allowedFragments;
  mapping(address => bool) private _noCheckDailyTakeProfit;
  mapping(address => SaleHistory) internal _saleHistories;
  /**
   * @notice Indicates by how much the total supply should be increased, when the reward mechanism is POSITIVE.
   * @return The reward rate value. Is denominated by the `rewardRateDenominator` variable.
   */
  uint256 public rewardRate;
  /**
   * @notice The denominator that is used with the reward rate in calculations.
   * @return The reward denominator value.
   */
  uint256 public rewardRateDenominator;
  /**
   * @notice Indicates by how much should the inflation increase to trigger a rebound routine.
   * @return The value in percentage of the all-time-high token price. Is denominated by the `negativeFromAthPercentDenominator` variable.
   */
  uint256 public negativeFromAthPercent;
  /**
   * @notice The denominator that is used with the `negativeFromAthPercent` in calculations.
   * @return The denominator value.
   */
  uint256 public negativeFromAthPercentDenominator;
  /**
   * @notice The time of the last reward action.
   * @return The time value as a UNIX timestamp.
   */
  uint256 public lastRewardTime;

  /**
   * @notice The fee applied to buys.
   * @return The value of the buy fee. The value is denominated by the `feeDenominator` variable.
   */
  uint256 public buyFee;
  /**
   * @notice The fee applied to sells.
   * @return The value of the sell fee. The value is denominated by the `feeDenominator` variable.
   */
  uint256 public sellFee;
  /**
   * @notice The fee applied to transfers.
   * @return The value of the transfer fee. The value is denominated by the `feeDenominator` variable.
   */
  uint256 public transferFee;
  /**
   * @notice The denominator used with fee calculations.
   * @return The value of the fee denominator.
   */
  uint256 public feeDenominator;
  /**
   * @notice The coefficient `a` of the equation that is used to calculate take profit limit.
   * @return The value of the coefficient. The value is denominated by the `takeProfitDenominator` variable.
   */
  uint256 public coefficientA;
  /**
   * @notice The max permyriad that could be applied when calculating the daily take profit limits.
   * @return The max value in permyriad.
   */
  uint256 public maxHoldingPermyriadTakeProfitApplied;
  /**
   * @notice The fee applied during transfers that goes to the liquidity pool.
   * @return The value of the auto-liquidity fee in percentage.
   */
  uint256 public autoLiquidityFeePercent;
  /**
   * @notice The fee applied during transfers that goes to the treasury.
   * @return The value of the treasury fee in percentage.
   */
  uint256 public treasuryFeePercent;
  /**
   * @notice The fee that describes the amount of tokens that are burnt during transfers.
   * @return The value of the burn fee in percentage.
   */
  uint256 public burnFeePercent;
  /**
   * @notice The denominator used with take profit's equation's coefficients calculations.
   * @return The value of the denominator.
   */
  uint256 public takeProfitDenominator;
  /**
   * @notice The address of the BUSD token.
   * @return The address.
   */
  address public BUSD;
  /**
   * @notice The DEX router that is used with token operations.
   * @return The router.
   */
  IDEXRouter public router;
  /**
   * @notice The address of the UNIQO/BUSD pair on the DEX.
   * @return The pair address.
   */
  address public pair;
  /**
   * @notice The all-time-high BUSD price of the UNIQO token.
   * @return The price in BUSD.
   */
  uint256 public athPrice;
  /**
   * @notice The permille value used with ATH price calculations.
   * @return The permille value.
   */
  uint256 public athPriceDeltaPermille;
  /**
   * @notice The ATH token price during the latest rebound.
   * @return The token price in BUSD.
   */
  uint256 public lastReboundTriggerAthPrice;
  /**
   * @notice The frequency of rewards in seconds.
   * @return The frequency in seconds.
   */
  uint256 public rewardFrequency;
  /**
   * @notice The receiver of the auto-liquidity.
   * @return The address of the auto-liquidity receiving wallet.
   */
  address public autoLiquidityReceiver;
  /**
   * @notice The treasury.
   * @return The address of the treasury wallet.
   */
  address public treasury;
  /**
   * @notice The person who deployed the current smart contract.
   * @return The address of the smart contract deployer.
   */
  address public deployer;
  /**
   * @notice The flag that indicates if the smart contract is launched.
   * @return True, if the smart contract is launched, else - false.
   */
  bool public launched;
  /**
   * @notice The flag that indicates if the automatic rewarding on transfers should be enabled.
   * @return True, if auto-rewarding is enabled, else - false.
   */
  bool public autoReward;
  /**
   * @notice The flag that indicates if swapbacks are enabled.
   * @return True, if swapbacks are enabled, else - false.
   */
  bool public swapBackEnabled;
  /**
   * @notice The flag that indicates if daily take profit limits should be checked during transfers.
   * @return True, if the check is enabled, else - false.
   */
  bool public dailyTakeProfitEnabled;
  /**
   * @notice The flag that indicates if the token price in BUSD should be calculated with each transfer.
   * @return True, if the calculation is enabled, else - false.
   */
  bool public priceEnabled;
  /**
   * @notice The flag that indicates if transfer fees are enabled.
   * @return True, if the fees are enabled, else - false.
   */
  bool public transferFeeEnabled;
  /**
   * @notice The mapping of wallet addresses that are free of fee charges.
   * @return For each wallet address provided - true, if the address is in the exemption list, else - false.
   */
  mapping(address => bool) public isFeeExempt;
  /**
   * @notice The array of UNIQO pairs.
   * @return The pairs array.
   */
  address[] public _makerPairs;
  // INFO: add new state variables here. Don't modify orders of old variables to avoid storage collision.

  enum RewardType {
    POSITIVE,
    NEGATIVE
  }

  enum TransactionType {
    BUY,
    SELL,
    TRANSFER
  }

  // SaleHistory tracking how many tokens that a user has sold within a span of 24hs
  struct SaleHistory {
    uint256 lastDailyTakeProfitAmount;
    uint256 lastSoldTimestamp;
    uint256 totalSoldAmountLast24h;
  }

  /**
   * @notice Event.
   * @dev Is emitted from the `_reward` function when rewards take place.
   * @param epoch The UNIX timestamp of the block when the reward has happened.
   * @param rewardType The type of the reward (reward or rebound).
   * @param lastTotalSupply The last total supply value before the reward.
   * @param currentTotalSupply The current total supply value after the reward.
   */
  event LogReward(uint256 indexed epoch, RewardType rewardType, uint256 lastTotalSupply, uint256 currentTotalSupply);
  /**
   * @notice Event.
   * @dev Is emitted from the `SetAutomatedMarketMakerPair` function when the owner sets automated market maker pairs.
   * @param pair The pair address.
   * @param value True to set the pair, false to unset the pair.
   */
  event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
  /**
   * @notice Event.
   * @dev Is emitted from the `launch` function. Shows the timestamp of the block when the smart contract was launched.
   * @param launchedAt The UNIX timestamp of the contract launch date and time.
   */
  event Launched(uint256 launchedAt);
  /**
   * @notice Event.
   * @dev Is emitted from the `withdrawFeesToTreasury` function which is called by the owner. Shows that fees were withdrawn to the treasury.
   * @param amount The amount that was withdrawn to the treasury.
   */
  event WithdrawFeesToTreasury(uint256 amount);
  /**
   * @notice Event.
   * @dev Is emitted from the `setPriceEnabled` function which is called by the owner. Shows that the value of the `priceEnabled` variable was changed by the owner.
   * @param value The new value of the `priceEnabled` flag.
   */
  event SetPriceEnabled(bool value);
  /**
   * @notice Event.
   * @dev Is emitted from the `setRewardFrequency` function which is called by the owner. Shows that the value of the `rewardFrequency` variable was changed by the owner.
   * @param valueInSeconds The new value of the `rewardFrequency` variable in seconds.
   */
  event SetRewardFrequency(uint256 valueInSeconds);
  /**
   * @notice Event.
   * @dev Is emitted from the `setAutoReward` function which is called by the owner. Shows that the value of the `autoReward` variable was changed by the owner.
   * @param flag The new value of the `autoReward` flag.
   */
  event SetAutoReward(bool flag);
  /**
   * @notice Event.
   * @dev Is emitted from the `setDailyTakeProfitEnabled` function which is called by the owner. Shows that the value of the `dailyTakeProfitEnabled` variable was changed by the owner.
   * @param flag The new value of the `dailyTakeProfitEnabled` flag.
   */
  event SetDailyTakeProfitEnabled(bool flag);
  /**
   * @notice Event.
   * @dev Is emitted from the `setNoCheckDailyTakeProfit` function which is called by the owner. Shows that the owner has changed the status of an address.
   * @param address_ The wallet address.
   * @param flag The new status of the wallet address.
   */
  event SetNoCheckDailyTakeProfit(address indexed address_, bool flag);
  /**
   * @notice Event.
   * @dev Is emitted from the `setTransferFeeEnabled` function which is called by the owner. Shows that the value of the `transferFeeEnabled` variable was changed by the owner.
   * @param flag The new value of the `transferFeeEnabled` flag.
   */
  event SetTransferFeeEnabled(bool flag);
  /**
   * @notice Event.
   * @dev Is emitted from the `setSwapBackEnabled` function which is called by the owner. Shows that the value of the `swapBackEnabled` variable was changed by the owner.
   * @param flag The new value of the `swapBackEnabled` flag.
   */
  event SetSwapBackEnabled(bool flag);
  /**
   * @notice Event.
   * @dev Is emitted from the `setCollectedFeeThreshold` function which is called by the owner. Shows that the value of the `_gonsCollectedFeeThreshold` variable was changed by the owner.
   * @param amount The new value of the threshold.
   */
  event SetCollectedFeeThreshold(uint256 amount);
  /**
   * @notice Event.
   * @dev Is emitted from the `setDailyTakeProfitCoefficients` function which is called by the owner. Shows that the values of the equation used to calculate take profit factor were changed by the owner.
   * @param a The new value of the `a` coefficient of the equation.
   * @param denominator The new value of the equation coefficient denominator.
   */
  event SetDailyTakeProfitCoefficients(uint256 a, uint256 denominator);
  /**
   * @notice Event.
   * @dev Is emitted from the `setReboundTriggerFromAth` function which is called by the owner. Shows that the owner has set new rebound trigger values.
   * @param percent The new rebound percentage value.
   * @param denominator The new value of the rebound denominator.
   */
  event SetReboundFromAth(uint256 percent, uint256 denominator);
  /**
   * @notice Event.
   * @dev Is emitted from the `setRewardRate` function which is called by the owner. Shows that the owner has set the new reward rate.
   * @param rate The new reward rate value.
   * @param denominator The new value of the reward denominator.
   */
  event SetRewardRate(uint256 rate, uint256 denominator);
  /**
   * @notice Event.
   * @dev Is emitted from the `setMaxHoldingPermyriadTakeProfitApplied` function which is called by the owner. Shows that the value of the `maxHoldingPermyriadTakeProfitApplied` variable was changed by the owner.
   * @param permyriad The new value of the `maxHoldingPermyriadTakeProfitApplied` variable.
   */
  event SetMaxHoldingPermyriadTakeProfitApplied(uint256 permyriad);
  /**
   * @notice Event.
   * @dev Is emitted from the `setTreasuryWallet` function which is called by the owner. Shows that the owner has changed the treasury wallet address.
   * @param wallet The new treasury wallet address.
   */
  event SetTreasuryWallet(address wallet);
  /**
   * @notice Event.
   * @dev Is emitted from the `setAutoLiquidityReceiver` function which is called by the owner. Shows that the owner has changed the auto-liquidity receiver wallet address.
   * @param wallet The wallet address of the new auto-liquidity receiver.
   */
  event SetAutoLiquidityReceiver(address wallet);
  /**
   * @notice Event.
   * @dev Is emitted from the `setFeeExemptAddress` function which is called by the owner. Shows that the owner has changed the fee exemption status of a wallet address.
   * @param address_ The address of the wallet the exemption status of which has changed.
   * @param flag True, if the wallet address was exempted, else - false.
   */
  event SetFeeExemptAddress(address address_, bool flag);
  /**
   * @notice Event.
   * @dev Is emitted from the `setBackingLPToken` function which is called by the owner. Shows that the owner has set the UNIQO/BUSD pair address.
   * @param lpAddress The address of the UNIQO/BUSD pair.
   */
  event SetBackingLPToken(address lpAddress);
  /**
   * @notice Event.
   * @dev Is emitted from the `pause` function which is called by the owner. Shows that the smart contract operations were paused.
   */
  event Pause();
  /**
   * @notice Event.
   * @dev Is emitted from the `unpause` function which is called by the owner. Shows that the smart contract operations were resumed.
   */
  event Unpause();
  /**
   * @notice Event.
   * @dev Is emitted from the `setFeeSplit` function which is called by the owner. Shows that the fee splits were changed.
   * @param autoLiquidityPercent The new auto-liquidity fee percentage of the total fee.
   * @param treasuryPercent The new treasury fee percentage of the total fee.
   * @param burnPercent The new burn fee percentage of the total fee.
   */
  event SetFeeSplit(uint256 autoLiquidityPercent, uint256 treasuryPercent, uint256 burnPercent);
  /**
   * @notice Event.
   * @dev Is emitted when the BUSD price of the UNIQO token reaches its all time high.
   * @param lastAthPrice The previous ATH value.
   * @param newAthPrice The current ATH value.
   */
  event NewAllTimeHigh(uint256 lastAthPrice, uint256 newAthPrice);
  /**
   * @notice Event.
   * @dev Is emitted from the `setFees` function which is called by the owner. Shows that the owner has changed the fees.
   * @param buyFee The new buy fee value.
   * @param sellFee The new sell fee value.
   * @param transferFee The new transfer fee value.
   */
  event SetFees(uint256 buyFee, uint256 sellFee, uint256 transferFee);
    /**
   * @notice Event.
   * @dev Is emitted from the `setAthDeltaPermille` function which is called by the owner.
   * @param permille The new ATH threshold.
   */
  event SetAthDeltaPerMille(uint256 permille);

  modifier swapping() {
    _inSwap = true;
    _;
    _inSwap = false;
  }

  modifier validRecipient(address to) {
    require(to != address(0x0), "INVALID_ADDRESS");
    _;
  }

  /**
   * @notice Initializes the smart contract.
   * @dev This function sets the initial values of the state variables and creates a UNIQO/BUSD pair. Emits a `Transfer` event.
   * @param _dexRouter The DEX router that is used with token operations.
   * @param _busd The address of the BUSD token.
   * @param _autoLiquidityReceiver The wallet address of the receiver of auto-liquidity.
   * @param _treasury The treasury wallet address.
   */
  function initialize(
    address _dexRouter,
    address _busd,
    address _autoLiquidityReceiver,
    address _treasury
  ) public initializer {
    require(_dexRouter != address(0x0) && _busd != address(0x0) && _autoLiquidityReceiver != address(0x0) && _treasury != address(0x0), "INVALID_ADDRESS");
    __Ownable_init();
    __Pausable_init();
    __UUPSUpgradeable_init();

    router = IDEXRouter(_dexRouter);
    BUSD = _busd;
    pair = IDEXFactory(router.factory()).createPair(_busd, address(this));

    autoLiquidityReceiver = _autoLiquidityReceiver;
    treasury = _treasury;

    setAutomatedMarketMakerPair(pair, true);

    _allowedFragments[address(this)][address(router)] = MAX_UINT256;

    _totalSupply = INITIAL_FRAGMENTS_SUPPLY;

    address _deployer = msg.sender;
    deployer = _deployer;
    _gonBalances[_deployer] = TOTAL_GONS;
    _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

    isFeeExempt[deployer] = true;

    _gonsCollectedFeeThreshold = DEFAULT_GONSWAP_THRESHOLD;
    rewardRate = 2073;
    rewardRateDenominator = 10**7;

    negativeFromAthPercent = 7;
    negativeFromAthPercentDenominator = 100;

    // Transaction fees
    buyFee = 12;
    sellFee = 15;
    transferFee = 35;
    feeDenominator = 100;

    coefficientA = 10000;
    maxHoldingPermyriadTakeProfitApplied = 1000;

    // Fee split
    autoLiquidityFeePercent = 50;
    treasuryFeePercent = 30;
    burnFeePercent = 20;

    // Take Profit
    takeProfitDenominator = 10000;
    athPriceDeltaPermille = 10;
    rewardFrequency = 30 minutes;

    emit Transfer(address(0x0), deployer, _totalSupply);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  /**
   * @notice Gets the current version of the smart contract.
   * @return The version of the smart contract.
   */
  function getVersion() external pure returns (string memory) {
    return "1.0";
  }

  /**
   * @notice Transfers the specified amount of tokens from a function caller (msg.sender) to a desired wallet address.
   * @dev The function checks if the `to` address is valid and if the smart contract is not paused.
   * @param to The receiver wallet address.
   * @param value The amount of tokens to transfer.
   * @return True, if the operation was successful, else - false.
   */
  function transfer(address to, uint256 value) external override validRecipient(to) whenNotPaused returns (bool) {
    _transferFrom(msg.sender, to, value);
    return true;
  }

  /**
   * @notice Transfers the specified amount of tokens from one wallet address to another.
   * @dev The function checks if the `to` address is valid, if the smart contract is not paused, and the allowance of the sender.
   * @param from The sender wallet address.
   * @param to The receiver wallet address.
   * @param value The amount of tokens to transfer.
   * @return True, if the operation was successful, else - false.
   */
  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external override validRecipient(to) whenNotPaused returns (bool) {
    uint256 currentAllowance = allowance(from, msg.sender);
    if (currentAllowance != MAX_UINT256) {
      _allowedFragments[from][msg.sender] = currentAllowance.sub(value, "ERC20: insufficient allowance");
    }
    _transferFrom(from, to, value);
    return true;
  }

  /**
   * @notice Decreases the allowance of a spender.
   * @dev Emits an `Approval` event.
   * @param spender The wallet address to decrease the allowance of.
   * @param subtractedValue The amount to decrease the allowance by.
   * @return True, if the operation was successful, else - false.
   */
  function decreaseAllowance(address spender, uint256 subtractedValue) external whenNotPaused returns (bool) {
    uint256 oldValue = _allowedFragments[msg.sender][spender];
    uint256 newValue;
    if (subtractedValue >= oldValue) {
      newValue = 0;
      _allowedFragments[msg.sender][spender] = newValue;
    } else {
      newValue = oldValue.sub(subtractedValue);
      _allowedFragments[msg.sender][spender] = newValue;
    }
    emit Approval(msg.sender, spender, newValue);
    return true;
  }

  /**
   * @notice Increases the allowance of a spender.
   * @dev Emits an `Approval` event.
   * @param spender The wallet address to increase the allowance of.
   * @param addedValue The amount to increase the allowance by.
   * @return True, if the operation was successful, else - false.
   */
  function increaseAllowance(address spender, uint256 addedValue) external whenNotPaused returns (bool) {
    uint256 oldValue = _allowedFragments[msg.sender][spender];
    uint256 newValue = oldValue.add(addedValue);
    _allowedFragments[msg.sender][spender] = newValue;
    emit Approval(msg.sender, spender, newValue);
    return true;
  }

  /**
   * @notice Approves a wallet address to spend funds of the sender.
   * @dev Emits an `Approval` event. Checks if the smart contract is not paused.
   * @param spender The wallet address to approve.
   * @param value The amount of funds to allow the spender to spend.
   * @return True, if the operation was successful, else - false.
   */
  function approve(address spender, uint256 value) public override whenNotPaused returns (bool) {
    _allowedFragments[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  /**
   * @notice The smart contract launch routine.
   * @dev Is only available to be called by the contract owner. Emits a `Launched` event.
   */
  function launch() external onlyOwner {
    require(balanceOf(pair) > 0, "LIQUIDITY_NOT_ADDED");
    require(IERC20(BUSD).allowance(autoLiquidityReceiver, address(this)) > 0, "INSUFFICIENT_BUSD_ALLOWANCE_FROM_LIQUIDITY_RECEIVER");

    autoReward = true;
    swapBackEnabled = true;

    dailyTakeProfitEnabled = true;
    transferFeeEnabled = true;
    priceEnabled = true;

    uint256 currentTime = block.timestamp;
    lastRewardTime = currentTime;
    launched = true;
    emit Launched(currentTime);
  }

  /**
   * @notice Sets the `athPriceDeltaPermille` value.
   * @dev Is only available to be called by the contract owner.
   * @param permille The new value to set.
   */
  function setAthDeltaPermille(uint256 permille) external onlyOwner {
    require(permille > 0 && permille < 1000, "INVALID_PERMILLE");
    athPriceDeltaPermille = permille;
    emit SetAthDeltaPerMille(permille);
  }

  /**
   * @notice The trigger to run reward or rebound routines.
   */
  function reward() external whenNotPaused {
    require(_shouldReward(), "SHOULD_NOT_REWARD");
    _reward();
  }

  /**
   * @notice Collect all fees, remaining BUSD of the smart contract, and sends them to the treasury.
   * @dev Is only available to be called by the contract owner. Emits a `WithdrawFeesToTreasury` event.
   */
  function withdrawFeesToTreasury() external swapping onlyOwner {
    uint256 amountToSwap = _gonBalances[address(this)].div(_gonsPerFragment);
    IDEXRouter _router = router;
    address _treasury = treasury;
    address _busd = BUSD;

    if (amountToSwap > 0) {
      address[] memory path = new address[](2);
      path[0] = address(this);
      path[1] = _busd;

      if (allowance(address(this), address(_router)) < amountToSwap) {
        approve(address(_router), type(uint256).max);
      }

      uint256 beforeTreasuryBalance = IERC20(_busd).balanceOf(_treasury);
      router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountToSwap, 0, path, _treasury, block.timestamp);
      emit WithdrawFeesToTreasury(IERC20(_busd).balanceOf(_treasury).sub(beforeTreasuryBalance));
    }
  }

  /* ========== FUNCTIONS FOR OWNER ========== */

  /**
   * @notice Sets the `priceEnabled` flag.
   * @dev Is only available to be called by the contract owner. Emits a `SetPriceEnabled` event.
   * @param flag The new `priceEnabled` value to set.
   */
  function setPriceEnabled(bool flag) external onlyOwner {
    priceEnabled = flag;
    emit SetPriceEnabled(flag);
  }

  /**
   * @notice Sets the `rewardFrequency`.
   * @dev Is only available to be called by the contract owner. Emits a `SetRewardFrequency` event.
   * @param valueInSeconds The new `rewardFrequency` value to set.
   */
  function setRewardFrequency(uint256 valueInSeconds) external onlyOwner {
    require(valueInSeconds <= 1 days && valueInSeconds > 0, "INVALID_REWARD_FREQUENCY");
    rewardFrequency = valueInSeconds;
    emit SetRewardFrequency(valueInSeconds);
  }

  /**
   * @notice Sets the `autoReward` flag.
   * @dev Is only available to be called by the contract owner. Emits a `SetAutoReward` event.
   * @param flag The new `autoReward` flag to set.
   */
  function setAutoReward(bool flag) external onlyOwner {
    if (flag) {
      lastRewardTime = block.timestamp;
    }

    autoReward = flag;
    emit SetAutoReward(flag);
  }

  /**
   * @notice Sets the `dailyTakeProfitEnabled` flag.
   * @dev Is only available to be called by the contract owner. Emits a `SetDailyTakeProfitEnabled` event.
   * @param flag The new `dailyTakeProfitEnabled` value.
   */
  function setDailyTakeProfitEnabled(bool flag) external onlyOwner {
    dailyTakeProfitEnabled = flag;
    emit SetDailyTakeProfitEnabled(flag);
  }

  /**
   * @notice Adds or removes a wallet address from a list of wallet addresses that are exempted from a daily take profit checks.
   * @dev Is only available to be called by the contract owner. Emits a `SetNoCheckDailyTakeProfit` event.
   * @param _address The wallet address to change the status of.
   * @param flag True, to add to the exemption list, else - false.
   */
  function setNoCheckDailyTakeProfit(address _address, bool flag) external onlyOwner {
    _noCheckDailyTakeProfit[_address] = flag;
    emit SetNoCheckDailyTakeProfit(_address, flag);
  }

  /**
   * @notice Sets the `transferFeeEnabled` flag which enables or disables fees on transfers.
   * @dev Is only available to be called by the contract owner. Emits a `SetTransferFeeEnabled` event.
   * @param flag True, to enable fees, else - false.
   */
  function setTransferFeeEnabled(bool flag) external onlyOwner {
    transferFeeEnabled = flag;
    emit SetTransferFeeEnabled(flag);
  }

  /**
   * @notice Sets the `swapBackEnabled` flag which enables or disables swapbacks transfers.
   * @dev Is only available to be called by the contract owner. Emits a `SetSwapBackEnabled` event.
   * @param flag True, to enable swapbacks, else - false.
   */
  function setSwapBackEnabled(bool flag) external onlyOwner {
    swapBackEnabled = flag;
    emit SetSwapBackEnabled(flag);
  }

  /**
   * @notice Sets the `_gonsCollectedFeeThreshold` threshold.
   * @dev If balance of the contract surpasses the threshold, a swapback will be triggered. Is only available to be called by the contract owner. Emits a `SetCollectedFeeThreshold` event.
   * @param amount The new threshold value.
   */
  function setCollectedFeeThreshold(uint256 amount) external onlyOwner {
    _gonsCollectedFeeThreshold = amount.mul(_gonsPerFragment);
    emit SetCollectedFeeThreshold(amount);
  }

  /**
   * @notice Sets the values of the equation used to calculate take profit factors.
   * @dev The equation is as follows: y = a/x. Is only available to be called by the contract owner. Checks the coefficients before settings them. Emits a `SetDailyTakeProfitCoefficients` event.
   * @param _coefficientA The new value of the `a` coefficient.
   * @param denominator The new value of the equation coefficient denominator.
   */
  function setDailyTakeProfitCoefficients(
    uint256 _coefficientA,
    uint256 denominator
  ) external onlyOwner {
    require(denominator > 0 && _coefficientA > 0, "INVALID_COEFFICIENTS");
    coefficientA = _coefficientA;
    takeProfitDenominator = denominator;

    emit SetDailyTakeProfitCoefficients(_coefficientA, denominator);
  }

  /**
   * @notice Sets the `maxHoldingPermyriadTakeProfitApplied` value.
   * @dev Sets set the max permyriad that could be applied when calculating the daily take profit factor to avoid math overflow. The value is the permyriad of a holder's balance comparing to the balance of liquidity pool. Is only available to be called by the contract owner. Emits a `SetMaxHoldingPermyriadTakeProfitApplied` event.
   * @param permyriad The new permyriad value to set.
   */
  function setMaxHoldingPermyriadTakeProfitApplied(uint256 permyriad) external onlyOwner {
    require(permyriad > 0 && permyriad <= 10000, "INVALID_PERMYRIAD");
    maxHoldingPermyriadTakeProfitApplied = permyriad;
    emit SetMaxHoldingPermyriadTakeProfitApplied(permyriad);
  }

  /**
   * @notice Sets the `negativeFromAthPercent` value and its denominator.
   * @dev The values show how much should the inflation increase before triggering a rebound routine. Is only available to be called by the contract owner. Emits a `SetReboundFromAth` event.
   * @param percent The new percentage value to set.
   * @param denominator The new denominator value to set.
   */
  function setReboundTriggerFromAth(uint256 percent, uint256 denominator) external onlyOwner {
    require(percent > 0 && denominator > 0, "INVALID_VALUES");
    negativeFromAthPercent = percent;
    negativeFromAthPercentDenominator = denominator;
    emit SetReboundFromAth(percent, denominator);
  }

  /**
   * @notice Sets the `rewardRate` value and its denominator.
   * @dev The values are used with the reward mechanism. Is only available to be called by the contract owner. Emits a `SetRewardRate` event.
   * @param rate The new rate value to set.
   * @param denominator The new denominator value to set.
   */
  function setRewardRate(uint256 rate, uint256 denominator) external onlyOwner {
    require(rewardRate > 0, "INVALID_REWARD_RATE");
    require(denominator > 0, "INVALID_REWARD_RATE_DENOMINATOR");
    uint256 supply = _totalSupply;
    // check overflow
    require(supply.mul(denominator.add(rate)).div(denominator) > supply, "INVALID_REWARD_RATE_PARAMS");

    rewardRate = rate;
    rewardRateDenominator = denominator;

    emit SetRewardRate(rate, denominator);
  }

  /**
   * @notice Sets the new treasury wallet address.
   * @dev Is only available to be called by the contract owner. Emits a `SetTreasuryWallet` event.
   * @param wallet The treasury wallet address to set.
   */
  function setTreasuryWallet(address wallet) external onlyOwner {
    require(wallet != address(0x0), "INVALID_ADDRESS");
    treasury = wallet;
    emit SetTreasuryWallet(wallet);
  }

  /**
   * @notice Sets the new auto-liquidity receiver wallet address.
   * @dev Is only available to be called by the contract owner. Emits a `SetAutoLiquidityReceiver` event.
   * @param wallet The wallet address of the receiver.
   */
  function setAutoLiquidityReceiver(address wallet) external onlyOwner {
    require(wallet != address(0x0), "INVALID_ADDRESS");
    autoLiquidityReceiver = wallet;
    emit SetAutoLiquidityReceiver(wallet);
  }

  /**
   * @notice Adds or removes wallet addresses from the list of addresses that are exempted from fees.
   * @dev Is only available to be called by the contract owner. Emits a `SetFeeExemptAddress` event.
   * @param address_ The wallet address to add or remove from the fee exemption list.
   * @param flag True, to add the wallet address to the list, false - to remove it from the list.
   */
  function setFeeExemptAddress(address address_, bool flag) external onlyOwner {
    require(address_ != address(0x0), "INVALID_ADDRESS");
    isFeeExempt[address_] = flag;
    emit SetFeeExemptAddress(address_, flag);
  }

  /**
   * @notice Sets the address of the UNIQO/BUSD pair.
   * @dev Is only available to be called by the contract owner. Emits a `SetBackingLPToken` event.
   * @param lpAddress The new address of the UNIQO/BUSD pair to set.
   */
  function setBackingLPToken(address lpAddress) external onlyOwner {
    require(lpAddress != address(0x0), "INVALID_ADDRESS");
    pair = lpAddress;
    emit SetBackingLPToken(lpAddress);
  }

  /**
   * @notice Pauses the smart contract functionality and operations.
   * @dev Is only available to be called by the contract owner. Emits a `Pause` event.
   */
  function pause() external onlyOwner {
    _pause();
    emit Pause();
  }

  /**
   * @notice Resumes the smart contract functionality and operations.
   * @dev Is only available to be called by the contract owner. Emits an `Unpause` event.
   */
  function unpause() external onlyOwner {
    _unpause();
    emit Unpause();
  }

  /**
   * @notice Allows the smart contract owner to withdraw tokens accidentally transferred to the contract.
   * @dev Is only available to be called by the contract owner.
   * @param tokenAddress The address of the token to rescue.
   * @param amount The amount of tokens to withdraw.
   */
  function rescueToken(address tokenAddress, uint256 amount) external onlyOwner {
    require(tokenAddress != address(this), "CANNOT_WITHDRAW_UNIQO");
    IERC20Upgradeable(tokenAddress).safeTransfer(msg.sender, amount);
  }

  /**
   * @notice Sets the fee percentage split between auto-liquidity, treasury, and burn wallets.
   * @dev Is only available to be called by the contract owner. Checks the splits to sum up to 100 percent. Emits a `SetFeeSplit` event.
   * @param autoLiquidityPercent The new auto-liquidity fee percentage of the total fee.
   * @param treasuryPercent The new treasury fee percentage of the total fee.
   * @param burnPercent The new burn fee percentage of the total fee.
   */
  function setFeeSplit(
    uint256 autoLiquidityPercent,
    uint256 treasuryPercent,
    uint256 burnPercent
  ) external onlyOwner {
    require(autoLiquidityPercent + treasuryPercent + burnPercent == 100, "INVALID_FEE_SPLIT");
    autoLiquidityFeePercent = autoLiquidityPercent;
    treasuryFeePercent = treasuryPercent;
    burnFeePercent = burnPercent;

    emit SetFeeSplit(autoLiquidityPercent, treasuryPercent, burnPercent);
  }

  /**
   * @notice Sets new fees.
   * @dev Is only available to be called by the contract owner. Emits a `SetFees` event.
   * @param _buyFee The new buy fee value.
   * @param _sellFee The new sell fee value.
   * @param _transferFee The new transfer fee value.
   */
  function setFees(
    uint256 _buyFee,
    uint256 _sellFee,
    uint256 _transferFee
  ) external onlyOwner {
    require(_sellFee >= 0 && _sellFee <= MAX_SELL_FEE, "INVALID_SELL_FEE");
    require(_buyFee >= 0 && _buyFee <= MAX_BUY_FEE, "INVALID_BUY_FEE");
    require(_transferFee >= 0 && _transferFee <= MAX_TRANSFER_FEE, "INVALID_TRANSFER_FEE");
    buyFee = _buyFee;
    sellFee = _sellFee;
    transferFee = _transferFee;
    emit SetFees(_buyFee, _sellFee, _transferFee);
  }

  /**
   * @notice Gets the balance of a user.
   * @param who The wallet address of the user.
   * @return The balance of the user.
   */
  function balanceOf(address who) public view override returns (uint256) {
    return _gonBalances[who].div(_gonsPerFragment);
  }

  /**
   * @notice Checks collected fee threshold amount.
   * @dev If balance of the contract surpasses the threshold, a swapback will be triggered.
   * @return The threshold.
   */
  function checkCollectedFeeThreshold() external view returns (uint256) {
    return _gonsCollectedFeeThreshold.div(_gonsPerFragment);
  }

  /**
   * @notice Sets an automated market maker pair.
   * @dev Is only available to be called by the contract owner. Emits a `SetAutomatedMarketMakerPair` event.
   * @param _pair The pair address to set.
   * @param _value True to set, false to unset.
   */
  function setAutomatedMarketMakerPair(address _pair, bool _value) public onlyOwner {
    require(automatedMarketMakerPairs[_pair] != _value, "Value already set");

    automatedMarketMakerPairs[_pair] = _value;

    if (_value) {
      _makerPairs.push(_pair);
    } else {
      require(_makerPairs.length > 1, "Required 1 pair");
      for (uint256 i = 0; i < _makerPairs.length; i++) {
        if (_makerPairs[i] == _pair) {
          _makerPairs[i] = _makerPairs[_makerPairs.length - 1];
          _makerPairs.pop();
          break;
        }
      }
    }

    emit SetAutomatedMarketMakerPair(_pair, _value);
  }

  /**
   * @notice Calculates the take profit factor.
   * @dev A user can only sell a portion of his total balance within a span of 24h. This factor is used to calculate the max token amount that the holder can sell in 24h.
   * @param holdingPermyriad The permyriad of a wallet balance over the liquidity pool balance.
   * @return The factor value.
   */
  function calculateTakeProfitFactor(uint256 holdingPermyriad) public view returns (uint256) {
    uint256 _maxHoldingPermyriad = maxHoldingPermyriadTakeProfitApplied;
    uint256 permyriadApplied = holdingPermyriad > _maxHoldingPermyriad ? _maxHoldingPermyriad : holdingPermyriad;
    permyriadApplied = permyriadApplied < 100 ? 100 : permyriadApplied;  
    uint256 takeProfitFactor = (coefficientA / permyriadApplied);

    if (takeProfitFactor > MAX_DAILY_TAKE_PROFIT_FACTOR) {
      return MAX_DAILY_TAKE_PROFIT_FACTOR;
    } else if (takeProfitFactor < MIN_DAILY_TAKE_PROFIT_FACTOR) {
      return MIN_DAILY_TAKE_PROFIT_FACTOR;
    }
    return takeProfitFactor;
  }

  /**
   * @dev Get daily take profit factor for a wallet address
   */
  function getDailyTakeProfitFactor(address _address) public view returns (uint256) {
    uint256 balance = balanceOf(_address);
    uint256 balanceOfPair = balanceOf(pair);
    if (balanceOfPair == 0) {
      return 0;
    }

    uint256 holdingPermyriad = balance.mul(10000).div(balanceOfPair);
    return calculateTakeProfitFactor(holdingPermyriad);
  }

  /**
   * @dev Gets the daily take profit amount in gons.
   */
  function _getDailyTakeProfitAmountInternalInGons(address _address) internal view returns (uint256) {
    uint256 factor = getDailyTakeProfitFactor(_address);
    uint256 bal = _gonBalances[_address];
    return bal.div(takeProfitDenominator).mul(factor);
  }

  /**
   * @notice Gets the daily take profit amount.
   * @param _address The wallet address to get the limit of.
   * @return The daily take profit amount.
   */
  function getDailyTakeProfitAmount(address _address) public view returns (uint256) {
    return _getDailyTakeProfitAmountInternalInGons(_address).div(_gonsPerFragment);
  }

  /**
   * @notice Gets the remaining daily take profit amount.
   * @param _address The wallet address to get the available amount of.
   * @return The remaining daily take profit amount.
   */
  function getAvailableDailyTakeProfitAmount(address _address) public view returns (uint256) {
    SaleHistory storage history = _saleHistories[_address];
    uint256 timeElapsed = block.timestamp.sub(history.lastSoldTimestamp);
    uint256 currentDTP = getCurrentDailyTakeProfitAmount(_address);
    if (timeElapsed > 1 days) {
      return currentDTP;
    }
    uint256 availableTakeProfitAmount = currentDTP - history.totalSoldAmountLast24h.div(_gonsPerFragment);
    return availableTakeProfitAmount;
  }

  /**
   * @notice Get current DTP.
   * @param _address The wallet address to get the limit of.
   * @return The DTP.
   */
  function getCurrentDailyTakeProfitAmount(address _address) public view returns (uint256) {
    SaleHistory storage history = _saleHistories[_address];
    uint256 timeElapsed = block.timestamp.sub(history.lastSoldTimestamp);
    if (timeElapsed > 1 days) {
      return _getDailyTakeProfitAmountInternalInGons(_address).div(_gonsPerFragment);
    }
    uint256 lastDTP = history.lastDailyTakeProfitAmount;
    return lastDTP.div(_gonsPerFragment);
  }

  /**
   * @notice Gets the price that will trigger a rebound.
   * @return The price that triggers a rebound.
   */
  function getTriggerReboundPrice() public view returns (uint256) {
      uint256 _athPrice = athPrice;
      return _athPrice.sub(_athPrice.mul(negativeFromAthPercent).div(negativeFromAthPercentDenominator));
  }

  /**
   * @notice Checks the allowance of a `spender`.
   * @param owner_ The owner address.
   * @param spender The spender address.
   * @return The allowance.
   */
  function allowance(address owner_, address spender) public view override returns (uint256) {
    return _allowedFragments[owner_][spender];
  }

  /**
   * @notice Manually updates the AMM pair reserve balance.
   */
  function manualSync() public {
    uint256 length = _makerPairs.length;
    for (uint256 i = 0; i < length; i++) {
      IDEXPair(_makerPairs[i]).sync();
    }
  }

  /* ========== PUBLIC AND EXTERNAL VIEW FUNCTIONS ========== */

  /**
   * @notice Gets the total supply including burned amount.
   * @return The total supply including burned amount.
   */
  function totalSupplyIncludingBurnAmount() public view returns (uint256) {
    return _totalSupply;
  }

  /**
   * @notice Gets the total supply excluding burned amount.
   * @return The total supply excluding burned amount.
   */
  function totalSupply() public view override returns (uint256) {
    return (TOTAL_GONS.sub(_gonBalances[DEAD]).sub(_gonBalances[ZERO])).div(_gonsPerFragment);
  }

  /**
   * @notice Gets liquidity backing.
   * @param accuracy The accuracy value.
   * @return The liquidity backing amount.
   */
  function getLiquidityBacking(uint256 accuracy) public view returns (uint256) {
    uint256 liquidityBalance = 0;
    uint256 length = _makerPairs.length;
    for (uint256 i = 0; i < length; i++) {
      liquidityBalance = liquidityBalance.add(_gonBalances[_makerPairs[i]].div(_gonsPerFragment));
    }

    return accuracy.mul(liquidityBalance.mul(2)).div(totalSupply());
  }

  /**
   * @notice Gets the name of the current token.
   * @return The name of the token.
   */
  function name() public pure returns (string memory) {
    return _name;
  }

  /**
   * @notice Gets the symbol of the current token.
   * @return The symbol of the token.
   */
  function symbol() public pure returns (string memory) {
    return _symbol;
  }

  /**
   * @dev Returns the number of decimals used to get its user representation.
   * For example, if `decimals` equals `2`, a balance of `505` tokens should
   * be displayed to a user as `5.05` (`505 / 10 ** 2`).
   *
   * Tokens usually opt for a value of 18, imitating the relationship between
   * Ether and Wei. This is the value {ERC20} uses, unless this function is
   * overridden;
   *
   * NOTE: This information is only used for _display_ purposes: it in
   * no way affects any of the arithmetic of the contract, including
   * {IERC20-balanceOf} and {IERC20-transfer}.
   */
  function decimals() public pure returns (uint8) {
    return _decimals;
  }

  /* ========== PRIVATE FUNCTIONS ========== */
  function _transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) private returns (bool) {
    require(launched || sender == deployer, "TOKEN_NOT_LAUNCHED_YET");

    if (_inSwap) {
      return _basicTransfer(sender, recipient, amount);
    }

    uint256 gonAmount = amount.mul(_gonsPerFragment);

    uint256 timeElapsed = block.timestamp.sub(transferTimelock[sender]);
    require(timeElapsed > 1 days, "TIMELOCK_ACTIVATED");

    if (dailyTakeProfitEnabled && _isSellTx(recipient) && !_noCheckDailyTakeProfit[sender]) {
      _checkDailyTakeProfitAndUpdateSaleHistory(sender, gonAmount);
    }

    if (_shouldReward()) {
      _reward();
    }

    if (_shouldSwapBack()) {
      _swapBack();
    }

    uint256 gonAmountToRecipient = _shouldTakeFee(sender, recipient) ? _takeFee(sender, recipient, gonAmount) : gonAmount;
    _gonBalances[sender] = _gonBalances[sender].sub(gonAmount, "ERC20: transfer amount exceeds balance");
    _gonBalances[recipient] = _gonBalances[recipient].add(gonAmountToRecipient);

    _updateATH();

    emit Transfer(sender, recipient, gonAmountToRecipient.div(_gonsPerFragment));

    return true;
  }

  function _basicTransfer(
    address from,
    address to,
    uint256 amount
  ) private returns (bool) {
    uint256 gonAmount = amount.mul(_gonsPerFragment);
    _gonBalances[from] = _gonBalances[from].sub(gonAmount, "ERC20: transfer amount exceeds balance");
    _gonBalances[to] = _gonBalances[to].add(gonAmount);
    emit Transfer(from, to, amount);

    return true;
  }

  /**
   * @dev Internal function to check if transfer amount surpasses the daily take profit amount
   * @param sender address of the sender that execute the transaction
   * @param gonAmount transfer amount
   */
  function _checkDailyTakeProfitAndUpdateSaleHistory(address sender, uint256 gonAmount) private {
    SaleHistory storage history = _saleHistories[sender];
    uint256 timeElapsed = block.timestamp.sub(history.lastSoldTimestamp);
    if (timeElapsed < 1 days) {
      require(history.totalSoldAmountLast24h.add(gonAmount) <= history.lastDailyTakeProfitAmount, "EXCEEDS_DAILY_TAKE_PROFIT");
      history.totalSoldAmountLast24h += gonAmount;
    } else {
      uint256 limitAmount = _getDailyTakeProfitAmountInternalInGons(sender);
      require(gonAmount <= limitAmount, "EXCEEDS_DAILY_TAKE_PROFIT");
      history.lastSoldTimestamp = block.timestamp;
      history.lastDailyTakeProfitAmount = limitAmount;
      history.totalSoldAmountLast24h = gonAmount;
    }
  }

  /**
   * @dev _swapBack collect fees and swap fees into BUSD
   * A portion of BUSD amount will be added to liquidity, the rest will be transferred to the treasury
   */
  function _swapBack() internal swapping {
    uint256 _autoLiquidityFeePercent = autoLiquidityFeePercent;
    uint256 totalFee = _autoLiquidityFeePercent.add(treasuryFeePercent);
    uint256 balance = _gonBalances[address(this)].div(_gonsPerFragment);
    uint256 amountForAutoLiquidity = balance.mul(_autoLiquidityFeePercent).div(totalFee);
    uint256 amountToLiquify = amountForAutoLiquidity.div(2);
    uint256 amountToSwap = balance.sub(amountToLiquify);
    _swapAndLiquidify(totalFee, amountToSwap, amountToLiquify);
  }

  /**
   * @dev _swapAndLiquidify swap fees into BUSD and add liquidity
   * @param totalFee is the total percent of fee for a transaction except burn fee
   * @param amountToSwap is the amount of tokens that will be swapped into BUSD
   * @param amountToLiquify is the amount of tokens will be added liquidity
   */
  function _swapAndLiquidify(
    uint256 totalFee,
    uint256 amountToSwap,
    uint256 amountToLiquify
  ) internal {
    IDEXRouter _router = router;
    address _busd = BUSD;
    address _autoLiquidityReceiver = autoLiquidityReceiver;
    uint256 balanceBUSDBefore = IERC20(BUSD).balanceOf(autoLiquidityReceiver);
    uint256 _autoLiquidityFeePercent = autoLiquidityFeePercent;

    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = _busd;
    // this contract can't receive BUSD so it delegates received BUSD to autoLiquidityReceiver
    router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountToSwap, 0, path, _autoLiquidityReceiver, block.timestamp);

    uint256 amountBUSD = IERC20(_busd).balanceOf(_autoLiquidityReceiver).sub(balanceBUSDBefore);
    IERC20(_busd).transferFrom(_autoLiquidityReceiver, address(this), amountBUSD);

    uint256 totalBUSDFee = totalFee.sub(_autoLiquidityFeePercent.div(2));
    uint256 amountBUSDLiquidity = amountBUSD.mul(_autoLiquidityFeePercent).div(totalBUSDFee).div(2);

    if (IERC20(_busd).allowance(address(this), address(_router)) < amountBUSDLiquidity) {
      IERC20(_busd).approve(address(_router), type(uint256).max);
    }

    if (allowance(address(this), address(_router)) < amountToLiquify) {
      approve(address(_router), type(uint256).max);
    }

    if (amountToLiquify > 0) {
      _router.addLiquidity(_busd, address(this), amountBUSDLiquidity, amountToLiquify, 0, 0, _autoLiquidityReceiver, block.timestamp);
    }

    uint256 amountBUSDTreasury = IERC20(_busd).balanceOf(address(this));
    IERC20(_busd).transfer(treasury, amountBUSDTreasury);
  }

  /**
   * @dev _takeFee take fees of a transaction
   *
   */
  function _takeFee(
    address sender,
    address recipient,
    uint256 gonAmount
  ) private returns (uint256) {
    uint256 fee;

    TransactionType txType = _getTransactionType(sender, recipient);
    if (txType == TransactionType.BUY) {
      fee = buyFee;
    } else if (txType == TransactionType.SELL) {
      fee = sellFee;
    } else if (txType == TransactionType.TRANSFER) {
      if(_shouldApplyTransferFee(sender, gonAmount, recipient)) {
        fee = transferFee;
      } else {
        fee = 0;
        transferTimelock[recipient] = block.timestamp;
      }
    }

    if (fee == 0) {
      return gonAmount;
    }

    uint256 _feeDenominator = feeDenominator;
    uint256 gonsPerFragment = _gonsPerFragment;
    uint256 feeAmount = gonAmount.div(_feeDenominator).mul(fee);
    // burn tokens
    uint256 burnAmount = feeAmount.div(_feeDenominator).mul(burnFeePercent);
    uint256 liquidityAndTreasuryAmount = feeAmount.sub(burnAmount);

    _gonBalances[DEAD] = _gonBalances[DEAD].add(burnAmount);
    _gonBalances[address(this)] = _gonBalances[address(this)].add(liquidityAndTreasuryAmount);

    emit Transfer(sender, DEAD, burnAmount.div(gonsPerFragment));
    emit Transfer(sender, address(this), liquidityAndTreasuryAmount.div(gonsPerFragment));

    return gonAmount.sub(feeAmount);
  }

  function _getTokenPriceInBUSD() private view returns (uint256) {
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = BUSD;
    uint256[] memory amounts = router.getAmountsOut(ONE_UNIT, path);
    return amounts[1];
  }

  /**
   * @dev _isSellTx check if a transaction is a sell transaction by comparing the recipient to the pair address
   */
  function _isSellTx(address recipient) private view returns (bool) {
    return recipient == pair;
  }

  /**
   * @dev _shouldReward checks if the contract should do a reward after a reward frequency period has passed
   */
  function _shouldReward() private view returns (bool) {
    return autoReward && !_inSwap && msg.sender != pair && block.timestamp >= (lastRewardTime + rewardFrequency);
  }

  /**
   * @dev _shouldSwapBack check if swap back should be applied to a transaction.
   */
  function _shouldSwapBack() private view returns (bool) {
    return swapBackEnabled && !_inSwap && msg.sender != pair && _gonBalances[address(this)] >= _gonsCollectedFeeThreshold;
  }

  /**
   * @dev _shouldTakeFee check if a transaction should be applied fee or not
   * an address that exists in the fee exempt mapping will be excluded from fee
   */
  function _shouldTakeFee(address from, address to) private view returns (bool) {
    if (isFeeExempt[from] || isFeeExempt[to]) {
      return false;
    }

    return true;
  }

  /**
   * @dev Check if the transfer fee will be applied on a transfer
   * Transfer fee is only applied to users that transfer less than 100% of their holdings
   * from their wallet to another wallet
   *
   * @param sender the sender of transfer
   * @param gonAmount transfer amount in `gonAmount` unit
   */
  function _shouldApplyTransferFee(address sender, uint256 gonAmount, address recipient) private view returns (bool) {
    if (!transferFeeEnabled) {
      return false;
    }

    uint256 gonsPerFragment = _gonsPerFragment;

    uint256 balance = _gonBalances[sender].div(gonsPerFragment);
    uint256 transferAmount = gonAmount.div(gonsPerFragment);
    if (balance == transferAmount && _gonBalances[recipient] == 0) {
      return false;
    }

    return true;
  }

  /**
   * @dev Internal reward method that notifies token contract about a new reward cycle
   * this will trigger either reward or rebound depending on the current inflation level
   * If it detects a significant increase in inflation, it will trigger a rebound to reduce the totalSupply
   * otherwise it would increase the totalSupply
   * After increase/reduce the totalSupply, it executes syncing to update values of the pair's reserve.
   */
  function _reward() private {
    uint256 currentPrice = priceEnabled ? _getTokenPriceInBUSD() : 0;
    RewardType rewardType = RewardType.POSITIVE;
    uint256 _athPrice = athPrice;
    uint256 triggerReboundPrice = getTriggerReboundPrice();

    if (currentPrice != 0 && currentPrice < triggerReboundPrice && lastReboundTriggerAthPrice < _athPrice) {
      rewardType = RewardType.NEGATIVE;
      // make sure only one rebound is triggered when the inflation increases above the set threshold.
      lastReboundTriggerAthPrice = _athPrice;
    }

    uint256 lastTotalSupply = _totalSupply;
    uint256 _lastRewardTime = lastRewardTime;
    uint256 _rewardFrequency = rewardFrequency;
    uint256 deltaTime = block.timestamp - _lastRewardTime;
    uint256 times = deltaTime.div(_rewardFrequency);
    uint256 tmpTotalSupply = _totalSupply;
    uint256 tmpRewardRate = rewardRate;

    if (rewardType == RewardType.POSITIVE) {
      for (uint256 i = 0; i < times; i++) {
        tmpTotalSupply = tmpTotalSupply.mul(rewardRateDenominator.add(tmpRewardRate)).div(rewardRateDenominator);
      }
      _totalSupply = tmpTotalSupply;
    } else {
      // if rebound, trigger reward once
      _totalSupply = _estimateReboundSupply();
    }

    _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
    lastRewardTime = _lastRewardTime.add(times.mul(_rewardFrequency));

    manualSync();

    uint256 epoch = block.timestamp;
    emit LogReward(epoch, rewardType, lastTotalSupply, _totalSupply);

    _updateATH();
  }

  /**
   * @dev _updateATH updates the All-time-high price.
   */
  function _updateATH() private {
    if (priceEnabled) {
      uint256 newPrice = _getTokenPriceInBUSD();
      if (newPrice > athPrice) {
        uint256 lastAthPrice = athPrice;
        athPrice = newPrice;
        emit NewAllTimeHigh(lastAthPrice, newPrice);
      }
    }
  }


  /**
   * @dev _getTransactionType detects if a transaction is a buy or sell/ transfer transaction buy checking if the sender/recipient matches the pair address
   */
  function _getTransactionType(address sender, address recipient) private view returns (TransactionType) {
    address _pair = pair;
    if (_pair == sender) {
      return TransactionType.BUY;
    } else if (_pair == recipient) {
      return TransactionType.SELL;
    }

    return TransactionType.TRANSFER;
  }

  /**
   * @dev Estimate the new supply for a rebound
   */
  function _estimateReboundSupply() private view returns (uint256) {
    if (athPrice == 0) {
      return _totalSupply;
    }

    address token0 = IDEXPair(pair).token0();
    (uint256 reserve0, uint256 reserve1, ) = IDEXPair(pair).getReserves();
    uint256 reserveIn = token0 == address(this) ? reserve0 : reserve1;
    uint256 reserveOut = token0 == BUSD ? reserve0 : reserve1;

    // this is a reverse computation of getAmountOut to find reserveIn
    // https://github.com/pancakeswap/pancake-smart-contracts/blob/d8f55093a43a7e8913f7730cfff3589a46f5c014/projects/exchange-protocol/contracts/libraries/PancakeLibrary.sol#L63
    uint256 expectedAmountOut = athPrice.add(athPrice.mul(athPriceDeltaPermille).div(1000));
    uint256 amountIn = ONE_UNIT;
    uint256 amountInWithFee = amountIn.mul(9975);
    uint256 numerator = amountInWithFee.mul(reserveOut);
    uint256 expectedDenominator = numerator.div(expectedAmountOut);
    // calculate expectedReserveIn to achieve expectedAmountOut
    uint256 expectedReserveIn = expectedDenominator.sub(amountInWithFee).div(10000);
    // reserveIn / _totalSupply  = expectedReserveIn / new totalSupply
    uint256 newTotalSupply = expectedReserveIn.mul(_totalSupply).div(reserveIn);
    return newTotalSupply;
  }
}
