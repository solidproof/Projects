// ██████╗ ██████╗ ██╗███████╗███╗   ███╗ █████╗     ███████╗██╗███╗   ██╗ █████╗ ███╗   ██╗ ██████╗███████╗
// ██╔══██╗██╔══██╗██║██╔════╝████╗ ████║██╔══██╗    ██╔════╝██║████╗  ██║██╔══██╗████╗  ██║██╔════╝██╔════╝
// ██████╔╝██████╔╝██║███████╗██╔████╔██║███████║    █████╗  ██║██╔██╗ ██║███████║██╔██╗ ██║██║     █████╗
// ██╔═══╝ ██╔══██╗██║╚════██║██║╚██╔╝██║██╔══██║    ██╔══╝  ██║██║╚██╗██║██╔══██║██║╚██╗██║██║     ██╔══╝
// ██║     ██║  ██║██║███████║██║ ╚═╝ ██║██║  ██║    ██║     ██║██║ ╚████║██║  ██║██║ ╚████║╚██████╗███████╗
// ╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝    ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝

// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./IPrismaToken.sol";
import "./IPrismaDividendTracker.sol";

contract PrismaToken is IPrismaToken, ERC20Upgradeable, OwnableUpgradeable {
  /////////////////
  /// VARIABLES ///
  /////////////////

  IPrismaDividendTracker private _prismaDividendTracker; // Interface for Prisma Dividend Tracker

  address private _treasuryReceiver; // Treasury account for marketing and team expenses
  address private _itfReceiver; // ITF account for investments
  address private _prismaDividendToken; // Dividend Token for payouts

  mapping(address => uint256) private _balances_; // Prisma Token balances
  mapping(address => mapping(address => uint256)) private _allowances_; // Prisma Token spending allowances
  mapping(address => bool) private _isFeeExempt; // Prisma Token accounts exempt from fees
  mapping(address => bool) private _automatedMarketMakerPairs; // Prisma Token Liquidity Pools addresses
  mapping(address => uint256) private _stakedPrisma; // Amount of Prisma Token staked by a given user

  uint256 private _totalSupply_; // Total Prisma Token supply
  uint256 private _totalStakedAmount; // Total Prisma Tokens staked
  uint256 private _minSwapFees; // Minimum fees to trigger swap to stablecoin
  uint256 private _buyLiquidityFee; // Buy fee for the Liquidity Pool
  uint256 private _buyTreasuryFee; // Buy fee for the Treasury
  uint256 private _buyItfFee; // Buy fee for the ITF
  uint256 private _sellLiquidityFee; // Sell fee for the Liquidity Pool
  uint256 private _sellTreasuryFee; // Sell fee for the Treasury
  uint256 private _sellItfFee; // Sell fee for the ITF

  bool private _isInternalTransaction; // Used to bypass fees when swapping previously accrued ones

  uint256 private vestingSchedulesTotalAmount; // Total amount of vested tokens across all schedules
  bytes32[] private vestingSchedulesIds; // Vesting schedule IDs
  mapping(address => uint256) private holdersVestingCount; // Amount of vesting schedules for the given account
  mapping(bytes32 => VestingSchedule) private vestingSchedules; // Vesting schedules accessed by ID

  struct VestingSchedule {
    bool initialized; // set to true once created
    address beneficiary; // beneficiary of tokens after they are released
    uint256 cliff; // cliff period in seconds
    uint256 start; // start time of the vesting period
    uint256 duration; // duration of the vesting period in seconds
    uint256 slicePeriodSeconds; // duration of a slice period for the vesting in seconds
    bool revocable; // whether or not the vesting is revocable
    uint256 amountTotal; // total amount of tokens to be released at the end of the vesting
    uint256 released; // amount of tokens released
    bool revoked; // whether or not the vesting has been revoked
  }

  //////////////
  /// EVENTS ///
  //////////////

  /**
   * @notice Emitted when Prisma has been compounded
   * @param totalStakedAmount The total amount of Prisma staked
   * @param staker The address of the account that staked the Prisma
   * @param prismaCompounded The amount of Prisma that was compounded
   */
  event PrismaCompounded(
      uint256 indexed totalStakedAmount,
      address indexed staker,
      uint256 indexed prismaCompounded
    );

  /**
   * @notice Emitted when a new vesting schedule is created
   * @param totalVestingAmount The total amount of tokens to be vested
   * @param beneficiary The address that will receive the vested tokens
   * @param vestedAmount The amount of tokens vested in this vesting schedule
   * @param scheduleId The unique identifier for this vesting schedule
   */
  event VestingScheduleCreated(
      uint256 indexed totalVestingAmount,
      address indexed beneficiary,
      uint256 indexed vestedAmount,
      bytes32 scheduleId
    );

  /**
   * @notice Emitted when the buy fee for the liquidity is updated
   * @param newFee The new buy fee for the liquidity
   * @param oldFee The previous buy fee for the liquidity
   */
  event BuyLiquidityFeeUpdated(uint256 indexed newFee, uint256 indexed oldFee);

  /**
   * @notice Emitted when the buy fee for the treasury is updated
   * @param newFee The new buy fee for the treasury
   * @param oldFee The previous buy fee for the treasury
   */
  event BuyTreasuryFeeUpdated(uint256 indexed newFee, uint256 indexed oldFee);

  /**
   * @notice Emitted when the buy fee for the ITF is updated
   * @param newFee The new buy fee for the ITF
   * @param oldFee The previous buy fee for the ITF
   */
  event BuyItfFeeUpdated(uint256 indexed newFee, uint256 indexed oldFee);

  /**
   * @notice Emitted when the sell fee for the liquidity is updated
   * @param newFee The new sell fee for the liquidity
   * @param oldFee The previous sell fee for the liquidity
   */
  event SellLiquidityFeeUpdated(uint256 indexed newFee, uint256 indexed oldFee);

  /**
   * @notice Emitted when the sell fee for the treasury is updated
   * @param newFee The new sell fee for the treasury
   * @param oldFee The previous sell fee for the treasury
   */
  event SellTreasuryFeeUpdated(uint256 indexed newFee, uint256 indexed oldFee);

  /**
   * @notice Emitted when the sell fee for the ITF is updated
   * @param newFee The new sell fee for the ITF
   * @param oldFee The previous sell fee for the ITF
   */
  event SellItfFeeUpdated(uint256 indexed newFee, uint256 indexed oldFee);

  /**
   * @notice Emitted when the minimum swap fees for conversion to stablecoin are updated
   * @param newMin The new minimum swap fees
   * @param oldMin The previous minimum swap fees
   */
  event MinSwapFeesUpdated(uint256 indexed newMin, uint256 indexed oldMin);

  ///////////////////
  /// INITIALIZER ///
  ///////////////////

  /**
   * @notice Initializes the contract with the specified Prisma Dividend Token and Tracker addresses
   * @dev This function can only be called once, during contract initialization
   * @dev It sets up the ownership, ERC20 details, receiver addresses, total supply, minimum swap fees, buy/sell fees, and fee exemptions
   * @dev Also requires that neither the prismaDividendToken_ nor tracker_ addresses are the zero address
   * @param prismaDividendToken_ The address of the Prisma Dividend Token
   * @param tracker_ The address of the Prisma Dividend Tracker
   */
  function init(
    address prismaDividendToken_,
    address tracker_
  ) public initializer {
    require(
      prismaDividendToken_ != address(0x0),
      "Cannot set dividend token as zero address"
    );
    require(
      tracker_ != address(0x0),
      "Cannot set Prisma Dividend Tracker as zero address"
    );

    __Ownable_init();
    __ERC20_init("Prisma Finance", "PRISMA");

    // LOCAL TESTNET ONLY
    _treasuryReceiver = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    _itfReceiver = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    _totalSupply_ = 10_000_000 * (10 ** 18);
    _minSwapFees = 1_000 * (10 ** 18);
    _buyLiquidityFee = 1;
    _buyTreasuryFee = 1;
    _buyItfFee = 2;
    _sellLiquidityFee = 1;
    _sellTreasuryFee = 1;
    _sellItfFee = 2;

    _prismaDividendToken = prismaDividendToken_;
    _prismaDividendTracker = IPrismaDividendTracker(tracker_);

    _balances_[msg.sender] = _totalSupply_;

    _isFeeExempt[tracker_] = true;
  }

  /////////////
  /// ERC20 ///
  /////////////

  /**
   * @notice Returns the total number of tokens in existance.
   * @return uint256 token total supply
   */
  function totalSupply() public view virtual override returns (uint256) {
    return _totalSupply_;
  }

  /**
   * @notice Returns the balance of a user.
   * @return uint256 account balance
   */
  function balanceOf(
    address account
  ) public view virtual override returns (uint256) {
    return _balances_[account];
  }

  /**
   * @notice Transfers tokens from the caller to another user.
   * Requirements:
   * - to cannot be the zero address.
   * - the caller must have a balance of at least `amount`.
   * @return bool transfer success
   */
  function transfer(
    address to,
    uint256 amount
  ) public virtual override returns (bool) {
    address owner = _msgSender();
    _transferFrom(owner, to, amount);
    return true;
  }

  /**
   * @notice Returns how much a user can spend using a certain address.
   * @return uint256 amount allowed
   */
  function allowance(
    address owner,
    address spender
  ) public view virtual override returns (uint256) {
    return _allowances_[owner][spender];
  }

  /**
   * @notice Approves an address to spend a certain amount of tokens.
   * Requirements:
   * - `spender` cannot be the zero address.
   * @dev If `amount` is the maximum `uint256`, the allowance is not updated on
   * `transferFrom`. This is semantically equivalent to an infinite approval.
   * @return bool success
   */
  function approve(
    address spender,
    uint256 amount
  ) public virtual override returns (bool) {
    address owner = _msgSender();
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances_[owner][spender] = amount;
    emit Approval(owner, spender, amount);
    return true;
  }

  /**
   * @notice Transfers tokens from one address to another.
   * Requirements:
   * - `from` and `to` cannot be the zero address.
   * - `from` must have a balance of at least `amount`.
   * - the caller must have allowance for ``from``'s tokens of at least
   * `amount`.
   * @dev Emits an {Approval} event indicating the updated allowance. This is not
   * required by the EIP. See the note at the beginning of {ERC20}.
   * Does not update the allowance if the current allowance is the maximum `uint256`.
   * @return bool success
   */
  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public virtual override returns (bool) {
    address spender = _msgSender();
    _spendAllowance(from, spender, amount);
    _transferFrom(from, to, amount);
    return true;
  }

  /**
   * @dev Moves `amount` of tokens from `from` to `to`.
   *
   * This internal function is equivalent to {transfer}, and can be used to
   * e.g. implement automatic token fees, slashing mechanisms, etc.
   *
   * Emits a {Transfer} event.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `to` cannot be the zero address.
   * - `from` must have a balance of at least `amount`.
   *
   * Additional details:
   *
   * - This function checks if the transaction is a buy or sell order.
   * - In case of a buy order, it checks if `to` is not fee exempt. If true, it calculates the fee based on the total buy fees and transfers the fee to the dividend tracker.
   * - In case of a sell order, it ensures the user doesn't sell more than their unstaked amount. If `from` is not fee exempt, it calculates the fee based on the total sell fees, transfers the fee to the dividend tracker, and if the balance of the dividend tracker is more than the minimum swap fees, it swaps the fees.
   * - For other transfers, it ensures the user doesn't transfer more than their unstaked amount.
   * - After the transfer, it updates the balance of `from` and `to` in the dividend tracker.
   */
  function _transferFrom(address from, address to, uint256 amount) internal {
    require(from != address(0), "ERC20: transfer from the zero address");
    require(to != address(0), "ERC20: transfer to the zero address");

    uint256 fromBalance = _balances_[from];

    bool overMinSwapFees = balanceOf(address(_prismaDividendTracker)) >=
      _minSwapFees;

    uint256 fee;

    if (!_isInternalTransaction) {
      // Buy order
      if (_automatedMarketMakerPairs[from] && !_isFeeExempt[to]) {
        if (getTotalBuyFees() > 0) {
          fee = (amount * getTotalBuyFees()) / 100;
          _balances_[address(_prismaDividendTracker)] += fee;
        }
      }
      // Sell order
      else if (_automatedMarketMakerPairs[to]) {
        if (_stakedPrisma[from] > 0) {
          uint256 nonStakedAmount = fromBalance - _stakedPrisma[from];
          require(nonStakedAmount >= amount, "You need to unstake first");
        }

        if (!_isFeeExempt[from]) {
          if (getTotalSellFees() > 0) {
            fee = (amount * getTotalSellFees()) / 100;
            _balances_[address(_prismaDividendTracker)] += fee;
            if (overMinSwapFees) {
              _isInternalTransaction = true;
              _prismaDividendTracker.swapFees();
              _isInternalTransaction = false;
            }
          }
        }
      } else {
        // Token Transfer
        if (_stakedPrisma[from] > 0) {
          uint256 nonStakedAmount = fromBalance - _stakedPrisma[from];
          require(nonStakedAmount >= amount, "You need to unstake first");
        }
      }
    }

    uint256 amountReceived = amount - fee;
    unchecked {
      _balances_[from] = fromBalance - amount;
      // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
      // decrementing then incrementing.
      _balances_[to] += amountReceived;
    }

    try _prismaDividendTracker.setBalance(from, balanceOf(from)) {} catch {}
    try _prismaDividendTracker.setBalance(to, balanceOf(to)) {} catch {}

    emit Transfer(from, to, amountReceived);
  }

  ///////////////
  /// Staking ///
  ///////////////

  /**
   * @notice Stakes a specified amount of Prisma Tokens for the sender
   * @dev Requires that the user's balance is greater than or equal to the sum of the stake amount and their currently staked amount
   * @param _amount The amount of Prisma Tokens to stake
   */
  function stakePrisma(uint256 _amount) external {
    address _user = msg.sender;
    require(
      _balances_[_user] >= _amount + _stakedPrisma[_user],
      "Not enough tokens to stake"
    );

    _stakedPrisma[_user] += _amount;
    _totalStakedAmount += _amount;
  }

  /**
   * @notice Unstakes a specified amount of Prisma Tokens for the sender
   * @dev Requires that the user's staked amount is greater than or equal to the unstake amount
   * @param _amount The amount of Prisma Tokens to unstake
   */
  function unstakePrisma(uint256 _amount) external {
    address _user = msg.sender;
    require(_stakedPrisma[_user] >= _amount, "Not enough tokens to unstake");

    _stakedPrisma[_user] -= _amount;
    _totalStakedAmount -= _amount;

    if (_stakedPrisma[_user] == 0) {
      delete _stakedPrisma[_user];
    }
  }

  /**
   * @notice Compounds a specified amount of Prisma Tokens for a specified staker
   * @dev This function is only callable by the Prisma Dividend Tracker, following a user's choice to reinvest their tokens
   * @dev It adjusts the balances and staked amounts accordingly, and tries to set the balances on the dividend tracker
   * @param _staker The address of the user to compound Prisma Tokens for
   * @param _prismaToCompound The amount of Prisma Tokens to compound
   */
  function compoundPrisma(
    address _staker,
    uint256 _prismaToCompound
  ) external override {
    require(
      msg.sender == address(_prismaDividendTracker),
      "NOT PRISMA_TRACKER"
    );
    _balances_[_staker] += _prismaToCompound;
    _balances_[msg.sender] -= _prismaToCompound;
    _stakedPrisma[_staker] += _prismaToCompound;
    _totalStakedAmount += _prismaToCompound;

    try
      _prismaDividendTracker.setBalance(msg.sender, balanceOf(msg.sender))
    {} catch {}
    try
      _prismaDividendTracker.setBalance(_staker, balanceOf(_staker))
    {} catch {}

    emit PrismaCompounded(_totalStakedAmount, _staker, _prismaToCompound);
  }

  ///////////////
  /// Vesting ///
  ///////////////

  /**
   * @notice Creates a new vesting schedule for a beneficiary.
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _start start time of the vesting period
   * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
   * @param _duration duration in seconds of the period in which the tokens will vest
   * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
   * @param _revocable whether the vesting is revocable or not
   * @param _amount total amount of tokens to be released at the end of the vesting
   */
  function createVestingSchedule(
    address _beneficiary,
    uint256 _start,
    uint256 _cliff,
    uint256 _duration,
    uint256 _slicePeriodSeconds,
    bool _revocable,
    uint256 _amount
  ) external onlyOwner {
    require(balanceOf(address(this)) >= _amount, "Insufficient tokens");
    require(_duration > 0, "Duration must be > 0");
    require(_amount > 0, "Amount must be > 0");
    require(_slicePeriodSeconds >= 1, "Period seconds must be >= 1");
    require(_duration >= _cliff, "Duration must be >= cliff");
    bytes32 vestingScheduleId = computeVestingScheduleIdForAddressAndIndex(
      _beneficiary,
      holdersVestingCount[_beneficiary]
    );
    uint256 cliff = _start + _cliff;
    vestingSchedules[vestingScheduleId] = VestingSchedule(
      true,
      _beneficiary,
      cliff,
      _start,
      _duration,
      _slicePeriodSeconds,
      _revocable,
      _amount,
      0,
      false
    );
    vestingSchedulesTotalAmount = vestingSchedulesTotalAmount + _amount;
    vestingSchedulesIds.push(vestingScheduleId);
    uint256 currentVestingCount = holdersVestingCount[_beneficiary];
    holdersVestingCount[_beneficiary] = currentVestingCount + 1;
    emit VestingScheduleCreated(
      vestingSchedulesTotalAmount,
      _beneficiary,
      _amount,
      vestingScheduleId
    );
  }

  /**
   * @notice Release vested amount of tokens.
   * @param vestingScheduleId the vesting schedule identifier
   * @param amount the amount to release
   */
  function release(bytes32 vestingScheduleId, uint256 amount) public {
    VestingSchedule storage vestingSchedule = vestingSchedules[
      vestingScheduleId
    ];
    bool isBeneficiary = msg.sender == vestingSchedule.beneficiary;

    address owner = owner();
    bool isReleasor = (msg.sender == owner);
    require(
      isBeneficiary || isReleasor,
      "Only beneficiary and owner can release vested tokens"
    );
    uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
    require(vestedAmount >= amount, "Insufficient tokens to release available");
    vestingSchedule.released = vestingSchedule.released + amount;
    vestingSchedulesTotalAmount = vestingSchedulesTotalAmount - amount;
    transfer(vestingSchedule.beneficiary, amount);
  }

  /**
   * @dev Computes the releasable amount of tokens for a vesting schedule.
   * @return the amount of releasable tokens
   */
  function _computeReleasableAmount(
    VestingSchedule memory vestingSchedule
  ) internal view returns (uint256) {
    // Retrieve the current time.
    uint256 currentTime = block.timestamp;
    // If the current time is before the cliff, no tokens are releasable.
    if ((currentTime < vestingSchedule.cliff) || vestingSchedule.revoked) {
      return 0;
    }
    // If the current time is after the vesting period, all tokens are releasable,
    // minus the amount already released.
    else if (currentTime >= vestingSchedule.start + vestingSchedule.duration) {
      return vestingSchedule.amountTotal - vestingSchedule.released;
    }
    // Otherwise, some tokens are releasable.
    else {
      // 10% of tokens are immediately available.
      uint256 initialRelease = (vestingSchedule.amountTotal * 10) / 100;
      // Compute the number of full vesting periods that have elapsed.
      uint256 timeFromStart = currentTime - vestingSchedule.start;
      uint256 secondsPerSlice = vestingSchedule.slicePeriodSeconds;
      uint256 vestedSlicePeriods = timeFromStart / secondsPerSlice;
      uint256 vestedSeconds = vestedSlicePeriods * secondsPerSlice;
      // Compute the amount of tokens that are vested.
      uint256 vestedAmount = (vestingSchedule.amountTotal * vestedSeconds) /
        vestingSchedule.duration;
      // Subtract the amount already released and return.
      return vestedAmount + initialRelease - vestingSchedule.released;
    }
  }

  /**
   * @dev Computes the vesting schedule identifier for an address and an index.
   */
  function computeVestingScheduleIdForAddressAndIndex(
    address holder,
    uint256 index
  ) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(holder, index));
  }

  ////////////////////////
  /// Setter Functions ///
  ////////////////////////

  /**
   * @notice Changes the buy liquidity fee to a new value
   * @dev Can only be called by the owner. Ensures that the total of buy and sell fees is less than or equal to 10%
   * @param newValue The new value for the buy liquidity fee
   */
  function setBuyLiquidityFee(uint256 newValue) external onlyOwner {
    uint256 oldValue = _buyLiquidityFee;
    _buyLiquidityFee = newValue;
    require(
      getTotalBuyFees() + getTotalSellFees() <= 10,
      "Cannot set fees higher than 10%"
    );
    emit BuyLiquidityFeeUpdated(newValue, oldValue);
  }

  /**
   * @notice Changes the buy treasury fee to a new value
   * @dev Can only be called by the owner. Ensures that the total of buy and sell fees is less than or equal to 10%
   * @param newValue The new value for the buy treasury fee
   */
  function setBuyTreasuryFee(uint256 newValue) external onlyOwner {
    uint256 oldValue = _buyTreasuryFee;
    _buyTreasuryFee = newValue;
    require(
      getTotalBuyFees() + getTotalSellFees() <= 10,
      "Cannot set fees higher than 10%"
    );
    emit BuyTreasuryFeeUpdated(newValue, oldValue);
  }

  /**
   * @notice Changes the buy ITF fee to a new value
   * @dev Can only be called by the owner. Ensures that the total of buy and sell fees is less than or equal to 10%
   * @param newValue The new value for the buy ITF fee
   */
  function setBuyItfFee(uint256 newValue) external onlyOwner {
    uint256 oldValue = _buyItfFee;
    _buyItfFee = newValue;
    require(
      getTotalBuyFees() + getTotalSellFees() <= 10,
      "Cannot set fees higher than 10%"
    );
    emit BuyItfFeeUpdated(newValue, oldValue);
  }

  /**
   * @notice Changes the sell liquidity fee to a new value
   * @dev Can only be called by the owner. Ensures that the total of buy and sell fees is less than or equal to 10%
   * @param newValue The new value for the sell liquidity fee
   */
  function setSellLiquidityFee(uint256 newValue) external onlyOwner {
    uint256 oldValue = _sellLiquidityFee;
    _sellLiquidityFee = newValue;
    require(
      getTotalBuyFees() + getTotalSellFees() <= 10,
      "Cannot set fees higher than 10%"
    );
    emit SellLiquidityFeeUpdated(newValue, oldValue);
  }

  /**
   * @notice Changes the sell treasury fee to a new value
   * @dev Can only be called by the owner. Ensures that the total of buy and sell fees is less than or equal to 10%
   * @param newValue The new value for the sell treasury fee
   */
  function setSellTreasuryFee(uint256 newValue) external onlyOwner {
    uint256 oldValue = _sellTreasuryFee;
    _sellTreasuryFee = newValue;
    require(
      getTotalBuyFees() + getTotalSellFees() <= 10,
      "Cannot set fees higher than 10%"
    );
    emit SellTreasuryFeeUpdated(newValue, oldValue);
  }

  /**
   * @notice Changes the sell ITF fee to a new value
   * @dev Can only be called by the owner. Ensures that the total of buy and sell fees is less than or equal to 10%
   * @param newValue The new value for the sell ITF fee
   */
  function setSellItfFee(uint256 newValue) external onlyOwner {
    uint256 oldValue = _sellItfFee;
    _sellItfFee = newValue;
    require(
      getTotalBuyFees() + getTotalSellFees() <= 10,
      "Cannot set fees higher than 10%"
    );
    emit SellItfFeeUpdated(newValue, oldValue);
  }

  /**
   * @notice Changes the minimum swap fees for conversion to stablecoin to a new value
   * @dev Can only be called by the owner
   * @param newValue The new value for the minimum swap fees
   */
  function setMinSwapFees(uint256 newValue) external onlyOwner {
    uint256 oldValue = _minSwapFees;
    _minSwapFees = newValue;
    emit MinSwapFeesUpdated(newValue, oldValue);
  }

  /**
   * @notice Updates whether a pair is an automated market maker pair
   * @dev Can only be called by the owner
   * @param _pair The pair to update
   * @param _active Whether the pair is an automated market maker pair
   */
  function setAutomatedMarketPair(
    address _pair,
    bool _active
  ) external onlyOwner {
    _automatedMarketMakerPairs[_pair] = _active;
  }

  /**
   * @notice Updates the Prisma Dividend Tracker to a new address
   * @dev Can only be called by the owner. Excludes the new tracker and this contract from dividends
   * @param newAddress The new address for the Prisma Dividend Tracker
   */
  function updatePrismaDividendTracker(address newAddress) external onlyOwner {
    require(
      newAddress != address(_prismaDividendTracker),
      "The dividend tracker already has that address"
    );
    IPrismaDividendTracker new_IPrismaDividendTracker = IPrismaDividendTracker(
      newAddress
    );
    new_IPrismaDividendTracker.excludeFromDividends(
      address(new_IPrismaDividendTracker)
    );
    new_IPrismaDividendTracker.excludeFromDividends(address(this));
    _prismaDividendTracker = new_IPrismaDividendTracker;
  }

  /**
   * @notice Excludes an account from dividends
   * @dev Can only be called by the owner
   * @param account The account to exclude
   */
  function excludeFromDividend(address account) external onlyOwner {
    _prismaDividendTracker.excludeFromDividends(account);
  }

  /**
   * @notice Includes an account in dividends
   * @dev Can only be called by the owner
   * @param account The account to include
   */
  function includeFromDividend(address account) external onlyOwner {
    _prismaDividendTracker.includeFromDividends(account);
  }

  /**
   * @notice Updates the minimum balance required for dividends
   * @dev Can only be called by the owner. Ensures that the new minimum balance is less than 1% of the supply
   * @param newMinimumBalance The new minimum balance for dividends
   */
  function updateMinimumBalanceForDividends(
    uint256 newMinimumBalance
  ) external onlyOwner {
    require(
      newMinimumBalance < 100_000 * (10 ** 18),
      "Cannot set minimum balance for dividends higher than 1% of supply"
    );
    _prismaDividendTracker.updateMinimumTokenBalanceForDividends(
      newMinimumBalance
    );
  }

  /**
   * @notice Updates the Prisma Dividend Token to a new contract address
   * @dev Can only be called by the owner. Ensures that the new contract address is not a zero address
   * @param _newContract The new contract address for the Prisma Dividend Token
   */
  function updatePrismaDividendToken(address _newContract) external onlyOwner {
    require(
      _newContract != address(0x0),
      "Cannot set dividend token as zero address"
    );
    _prismaDividendToken = _newContract;
    _prismaDividendTracker.setDividendTokenAddress(_newContract);
  }

  /**
   * @notice Updates the amount of gas for processing dividends
   * @dev Can only be called by the owner
   * @param newValue The new amount of gas for processing dividends
   */
  function updateGasForDividendsProcessing(
    uint256 newValue
  ) external onlyOwner {
    _prismaDividendTracker.updateGasForProcessing(newValue);
  }

  ////////////////////////
  /// Getter Functions ///
  ////////////////////////

  /**
   * @notice Get the total buy fees, which is the sum of liquidity fee, treasury fee, and ITF fee for buys
   * @return The total buy fees
   */
  function getTotalBuyFees() public view returns (uint256) {
    return _buyLiquidityFee + _buyTreasuryFee + _buyItfFee;
  }

  /**
   * @notice Get the total sell fees, which is the sum of liquidity fee, treasury fee, and ITF fee for sells
   * @return The total sell fees
   */
  function getTotalSellFees() public view returns (uint256) {
    return _sellLiquidityFee + _sellTreasuryFee + _sellItfFee;
  }

  /**
   * @notice Get the buy liquidity fee
   * @return The buy liquidity fee
   */
  function getBuyLiquidityFee() external view returns (uint256) {
    return _buyLiquidityFee;
  }

  /**
   * @notice Get the buy treasury fee
   * @return The buy treasury fee
   */
  function getBuyTreasuryFee() external view returns (uint256) {
    return _buyTreasuryFee;
  }

  /**
   * @notice Get the buy ITF fee
   * @return The buy ITF fee
   */
  function getBuyItfFee() external view returns (uint256) {
    return _buyItfFee;
  }

  /**
   * @notice Get the sell liquidity fee
   * @return The sell liquidity fee
   */
  function getSellLiquidityFee() external view returns (uint256) {
    return _sellLiquidityFee;
  }

  /**
   * @notice Get the sell treasury fee
   * @return The sell treasury fee
   */
  function getSellTreasuryFee() external view returns (uint256) {
    return _sellTreasuryFee;
  }

  /**
   * @notice Get the sell ITF fee
   * @return The sell ITF fee
   */
  function getSellItfFee() external view returns (uint256) {
    return _sellItfFee;
  }

  /**
   * @notice Get the minimum swap fees for conversion to stablecoin
   * @return The minimum swap fees
   */
  function getMinSwapFees() external view returns (uint256) {
    return _minSwapFees;
  }

  /**
   * @notice Get the owner of the contract
   * @return The address of the owner
   */
  function getOwner() external view returns (address) {
    return owner();
  }

  /**
   * @notice Get the treasury receiver
   * @return The address of the treasury receiver
   */
  function getTreasuryReceiver() external view returns (address) {
    return _treasuryReceiver;
  }

  /**
   * @notice Get the ITF receiver
   * @return The address of the ITF receiver
   */
  function getItfReceiver() external view returns (address) {
    return _itfReceiver;
  }

  /**
   * @notice Get the Prisma Dividend Tracker
   * @return The address of the Prisma Dividend Tracker
   */
  function getPrismaDividendTracker() external view returns (address) {
    return address(_prismaDividendTracker);
  }

  /**
   * @notice Get the total Prisma dividends distributed
   * @return The total amount of Prisma dividends distributed
   */
  function getTotalPrismaDividendsDistributed()
    external
    view
    returns (uint256)
  {
    return _prismaDividendTracker.getTotalDividendsDistributed();
  }

  /**
   * @notice Get the withdrawable Prisma dividend of a specific account
   * @param account The account to check
   * @return The withdrawable Prisma dividend of the account
   */
  function withdrawablePrismaDividendOf(
    address account
  ) external view returns (uint256) {
    return _prismaDividendTracker.withdrawableDividendOf(account);
  }

  /**
   * @notice Get the Prisma dividend tracker balance of a specific account
   * @param account The account to check
   * @return The Prisma dividend tracker balance of the account
   */
  function prismaDividendTrackerBalanceOf(
    address account
  ) public view returns (uint256) {
    return _prismaDividendTracker.balanceOf(account);
  }

  /**
   * @notice Get the Prisma dividends info of a specific account
   * @param account The account to check
   * @return The Prisma dividends info of the account
   */
  function getAccountPrismaDividendsInfo(
    address account
  ) external view returns (address, int256, int256, uint256, uint256) {
    return _prismaDividendTracker.getAccount(account);
  }

  /**
   * @notice Get the Prisma dividends info at a specific index
   * @param index The index to check
   * @return The Prisma dividends info at the index
   */
  function getAccountPrismaDividendsInfoAtIndex(
    uint256 index
  ) external view returns (address, int256, int256, uint256, uint256) {
    return _prismaDividendTracker.getAccountAtIndex(index);
  }

  /**
   * @notice Get the last processed index for Prisma dividends
   * @return The last processed index
   */
  function getLastPrismaDividendProcessedIndex()
    external
    view
    returns (uint256)
  {
    return _prismaDividendTracker.getLastProcessedIndex();
  }

  /**
   * @notice Get the number of Prisma dividend token holders
   * @return The number of Prisma dividend token holders
   */
  function getNumberOfPrismaDividendTokenHolders()
    external
    view
    returns (uint256)
  {
    return _prismaDividendTracker.getNumberOfTokenHolders();
  }

  /**
   * @notice Get the staked Prisma of a specific user
   * @param _user The user to check
   * @return The staked Prisma of the user
   */
  function getStakedPrisma(address _user) external view returns (uint256) {
    return _stakedPrisma[_user];
  }

  /**
   * @notice Get the total amount of staked Prisma
   * @return The total staked Prisma amount
   */
  function getTotalStakedAmount() external view returns (uint256) {
    return _totalStakedAmount;
  }

  /**
   * @notice Get the vesting schedule for a specific id
   * @param vestingScheduleId The id of the vesting schedule to retrieve
   * @return The vesting schedule
   */
  function getVestingSchedule(
    bytes32 vestingScheduleId
  ) public view returns (VestingSchedule memory) {
    return vestingSchedules[vestingScheduleId];
  }

  /**
   * @notice Get the count of vesting schedules for a specific beneficiary
   * @param _beneficiary The beneficiary to check
   * @return The number of vesting schedules for the beneficiary
   */
  function getVestingSchedulesCountByBeneficiary(
    address _beneficiary
  ) external view returns (uint256) {
    return holdersVestingCount[_beneficiary];
  }

  /**
   * @notice Get the total amount across all vesting schedules
   * @return The total amount across all vesting schedules
   */
  function getVestingSchedulesTotalAmount() external view returns (uint256) {
    return vestingSchedulesTotalAmount;
  }

  /**
   * @notice Get the count of all vesting schedules
   * @return The ids of all vesting schedules
   */
  function getVestingSchedulesCount() public view returns (bytes32[] memory) {
    return vestingSchedulesIds;
  }
}