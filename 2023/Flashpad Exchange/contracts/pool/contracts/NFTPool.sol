// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/INFTHandler.sol";
import "./interfaces/IFlashpadMaster.sol";
import "./interfaces/INFTPool.sol";
import "./interfaces/IYieldBooster.sol";
import "./interfaces/tokens/IXFlashToken.sol";


/*
 * This contract wraps ERC20 assets into non-fungible staking positions called spNFTs
 * spNFTs add the possibility to create an additional layer on liquidity providing lock features
 * spNFTs are yield-generating positions when the NFTPool contract has allocations from the Flashpad Master
 */
contract NFTPool is ReentrancyGuard, INFTPool, ERC721("Flashpad staking position NFT", "spNFT") {
  using Address for address;
  using Counters for Counters.Counter;
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeMath for uint256;
  using SafeERC20 for IERC20;


  // Info of each NFT (staked position).
  struct StakingPosition {
    uint256 amount; // How many lp tokens the user has provided
    uint256 amountWithMultiplier; // Amount + lock bonus faked amount (amount + amount*multiplier)
    uint256 startLockTime; // The time at which the user made his deposit
    uint256 lockDuration; // The lock duration in seconds
    uint256 lockMultiplier; // Active lock multiplier (times 1e2)
    uint256 rewardDebt; // Reward debt
    uint256 boostPoints; // Allocated xFLASH from yieldboost contract (optional)
    uint256 totalMultiplier; // lockMultiplier + allocated xFLASH boostPoints multiplier
    uint256 pendingXArtRewards; // Not harvested xFlash rewards
    uint256 pendingArtRewards; // Not harvested Art rewards
  }

  Counters.Counter private _tokenIds;

  EnumerableSet.AddressSet private _unlockOperators; // Addresses allowed to forcibly unlock locked spNFTs
  address public operator; // Used to delegate multiplier settings to project's owners
  IFlashpadMaster public master; // Address of the master
  address public immutable factory; // NFTPoolFactory contract's address
  bool public initialized;

  IERC20 private _lpToken; // Deposit token contract's address
  IERC20 private _flashToken; // FlashToken contract's address
  IXFlashToken private _xFlashToken; // XFlashToken contract's address
  uint256 private _lpSupply; // Sum of deposit tokens on this pool
  uint256 private _lpSupplyWithMultiplier; // Sum of deposit token on this pool including the user's total multiplier (lockMultiplier + boostPoints)
  uint256 private _accRewardsPerShare; // Accumulated Rewards (staked token) per share, times 1e18. See below

  // readable via getMultiplierSettings
  uint256 public constant MAX_GLOBAL_MULTIPLIER_LIMIT = 25000; // 250%, high limit for maxGlobalMultiplier (100 = 1%)
  uint256 public constant MAX_LOCK_MULTIPLIER_LIMIT = 15000; // 150%, high limit for maxLockMultiplier (100 = 1%)
  uint256 public constant MAX_BOOST_MULTIPLIER_LIMIT = 15000; // 150%, high limit for maxBoostMultiplier (100 = 1%)
  uint256 private _maxGlobalMultiplier = 20000; // 200%
  uint256 private _maxLockDuration = 183 days; // 6 months, Capped lock duration to have the maximum bonus lockMultiplier
  uint256 private _maxLockMultiplier = 10000; // 100%, Max available lockMultiplier (100 = 1%)
  uint256 private _maxBoostMultiplier = 10000; // 100%, Max boost that can be earned from xFlash yieldBooster

  uint256 private constant _TOTAL_REWARDS_SHARES = 10000; // 100%, high limit for xFlashRewardsShare
  uint256 public xFlashRewardsShare = 8000; // 80%, directly defines artShare with the remaining value to 100%

  bool public emergencyUnlock; // Release all locks in case of emergency

  // readable via getStakingPosition
  mapping(uint256 => StakingPosition) internal _stakingPositions; // Info of each NFT position that stakes LP tokens

  constructor() {
    factory = msg.sender;
  }

  function initialize(IFlashpadMaster master_, IERC20 flashToken, IXFlashToken xFlashToken, IERC20 lpToken) external {
    require(msg.sender == factory && !initialized, "FORBIDDEN");
    _lpToken = lpToken;
    master = master_;
    _flashToken = flashToken;
    _xFlashToken = xFlashToken;
    initialized = true;

    // to convert FLASH to xFLASH
   _flashToken.approve(address(_xFlashToken), type(uint256).max);
  }


  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event AddToPosition(uint256 indexed tokenId, address user, uint256 amount);
  event CreatePosition(uint256 indexed tokenId, uint256 amount, uint256 lockDuration);
  event WithdrawFromPosition(uint256 indexed tokenId, uint256 amount);
  event EmergencyWithdraw(uint256 indexed tokenId, uint256 amount);
  event LockPosition(uint256 indexed tokenId, uint256 lockDuration);
  event SplitPosition(uint256 indexed tokenId, uint256 splitAmount, uint256 newTokenId);
  event MergePositions(address indexed user, uint256[] tokenIds);
  event HarvestPosition(uint256 indexed tokenId, address to, uint256 pending);
  event SetBoost(uint256 indexed tokenId, uint256 boostPoints);

  event PoolUpdated(uint256 lastRewardTime, uint256 accRewardsPerShare);

  event SetLockMultiplierSettings(uint256 maxLockDuration, uint256 maxLockMultiplier);
  event SetBoostMultiplierSettings(uint256 maxGlobalMultiplier, uint256 maxBoostMultiplier);
  event SetXArtRewardsShare(uint256 xFlashRewardsShare);
  event SetUnlockOperator(address operator, bool isAdded);
  event SetEmergencyUnlock(bool emergencyUnlock);
  event SetOperator(address operator);


  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  /**
   * @dev Check if caller has operator rights
   */
  function _requireOnlyOwner() internal view {
    require(msg.sender == owner(), "FORBIDDEN");
    // onlyOwner: caller is not the owner
  }

  /**
   * @dev Check if caller is a validated YieldBooster contract
   */
  function _requireOnlyYieldBooster() internal view {
    // onlyYieldBooster: caller has no yield boost rights
    require(msg.sender == yieldBooster(), "FORBIDDEN");
  }


  /**
   * @dev Check if a userAddress has privileged rights on a spNFT
   */
  function _requireOnlyOperatorOrOwnerOf(uint256 tokenId) internal view {
    // isApprovedOrOwner: caller has no rights on token
    require(ERC721._isApprovedOrOwner(msg.sender, tokenId), "FORBIDDEN");
  }


  /**
   * @dev Check if a userAddress has privileged rights on a spNFT
   */
  function _requireOnlyApprovedOrOwnerOf(uint256 tokenId) internal view {
    require(_exists(tokenId), "ERC721: operator query for nonexistent token");
    require(_isOwnerOf(msg.sender, tokenId) || getApproved(tokenId) == msg.sender, "FORBIDDEN");
  }

  /**
   * @dev Check if a msg.sender is owner of a spNFT
   */
  function _requireOnlyOwnerOf(uint256 tokenId) internal view {
    require(_exists(tokenId), "ERC721: operator query for nonexistent token");
    // onlyOwnerOf: caller has no rights on token
    require(_isOwnerOf(msg.sender, tokenId), "not owner");
  }


  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /**
   * @dev Returns this contract's owner (= master contract's owner)
   */
  function owner() public view returns (address) {
    return master.owner();
  }

  /**
   * @dev Returns the number of unlockOperators
   */
  function unlockOperatorsLength() external view returns (uint256) {
    return _unlockOperators.length();
  }

  /**
   * @dev Returns an unlockOperator from its "index"
   */
  function unlockOperator(uint256 index) external view returns (address) {
    if (_unlockOperators.length() <= index) return address(0);
    return _unlockOperators.at(index);
  }

  /**
   * @dev Returns true if "_operator" address is an unlockOperator
   */
  function isUnlockOperator(address _operator) external view returns (bool) {
    return _unlockOperators.contains(_operator);
  }

  /**
   * @dev Get master-defined yield booster contract address
   */
  function yieldBooster() public view returns (address) {
    return master.yieldBooster();
  }

  /**
   * @dev Returns true if "tokenId" is an existing spNFT id
   */
  function exists(uint256 tokenId) external view override returns (bool) {
    return ERC721._exists(tokenId);
  }

  /**
   * @dev Returns last minted NFT id
   */
  function lastTokenId() external view returns (uint256) {
    return _tokenIds.current();
  }

  /**
   * @dev Returns true if emergency unlocks are activated on this pool or on the master
   */
  function isUnlocked() public view returns (bool) {
    return emergencyUnlock || master.emergencyUnlock();
  }

  /**
   * @dev Returns true if this pool currently has deposits
   */
  function hasDeposits() external view override returns (bool) {
    return _lpSupplyWithMultiplier > 0;
  }

  /**
   * @dev Returns general "pool" info for this contract
   */
  function getPoolInfo() external view override returns (
    address lpToken, address flashToken, address xFlashToken, uint256 lastRewardTime, uint256 accRewardsPerShare,
    uint256 lpSupply, uint256 lpSupplyWithMultiplier, uint256 allocPoint
  ) {
    (, allocPoint, lastRewardTime,,) = master.getPoolInfo(address(this));
    return (
    address(_lpToken), address(_flashToken), address(_xFlashToken), lastRewardTime, _accRewardsPerShare,
    _lpSupply, _lpSupplyWithMultiplier, allocPoint
    );
  }

  /**
   * @dev Returns all multiplier settings for this contract
   */
  function getMultiplierSettings() external view returns (uint256 maxGlobalMultiplier, uint256 maxLockDuration, uint256 maxLockMultiplier, uint256 maxBoostMultiplier) {
    return (_maxGlobalMultiplier, _maxLockDuration, _maxLockMultiplier, _maxBoostMultiplier);
  }

  /**
   * @dev Returns bonus multiplier from YieldBooster contract for given "amount" (LP token staked) and "boostPoints" (result is *1e4)
   */
  function getMultiplierByBoostPoints(uint256 amount, uint256 boostPoints) public view returns (uint256) {
    if(boostPoints == 0 || amount == 0) return 0;

    address yieldBoosterAddress = yieldBooster();
    // only call yieldBooster contract if defined on master
    return yieldBoosterAddress != address(0) ? IYieldBooster(yieldBoosterAddress).getMultiplier(address(this), _maxBoostMultiplier, amount, _lpSupply, boostPoints) : 0;
  }

  /**
   * @dev Returns expected multiplier for a "lockDuration" duration lock (result is *1e4)
   */
  function getMultiplierByLockDuration(uint256 lockDuration) public view returns (uint256) {
    // in case of emergency unlock
    if (isUnlocked()) return 0;

    if (_maxLockDuration == 0 || lockDuration == 0) return 0;

    // capped to maxLockDuration
    if (lockDuration >= _maxLockDuration) return _maxLockMultiplier;

    return _maxLockMultiplier.mul(lockDuration).div(_maxLockDuration);
  }

  /**
   * @dev Returns a position info
   */
  function getStakingPosition(uint256 tokenId) external view override returns (
    uint256 amount, uint256 amountWithMultiplier, uint256 startLockTime,
    uint256 lockDuration, uint256 lockMultiplier, uint256 rewardDebt,
    uint256 boostPoints, uint256 totalMultiplier
  ) {
    StakingPosition storage position = _stakingPositions[tokenId];
    return (
    position.amount, position.amountWithMultiplier, position.startLockTime,
    position.lockDuration, position.lockMultiplier, position.rewardDebt,
    position.boostPoints, position.totalMultiplier
    );
  }

  /**
   * @dev Returns pending rewards for a position
   */
  function pendingRewards(uint256 tokenId) external view returns (uint256) {
    StakingPosition storage position = _stakingPositions[tokenId];

    uint256 accRewardsPerShare = _accRewardsPerShare;
    (,,uint256 lastRewardTime, uint256 reserve, uint256 poolEmissionRate) = master.getPoolInfo(address(this));

    // recompute accRewardsPerShare if not up to date
    if ((reserve > 0 || _currentBlockTimestamp() > lastRewardTime) && _lpSupplyWithMultiplier > 0) {
      uint256 duration = _currentBlockTimestamp().sub(lastRewardTime);
      // adding reserve here in case master has been synced but not the pool
      uint256 tokenRewards = duration.mul(poolEmissionRate).add(reserve);
      accRewardsPerShare = accRewardsPerShare.add(tokenRewards.mul(1e18).div(_lpSupplyWithMultiplier));
    }

    return position.amountWithMultiplier.mul(accRewardsPerShare).div(1e18).sub(position.rewardDebt)
      .add(position.pendingXArtRewards).add(position.pendingArtRewards);
  }


  /*******************************************************/
  /****************** OWNABLE FUNCTIONS ******************/
  /*******************************************************/

  /**
   * @dev Set lock multiplier settings
   *
   * maxLockMultiplier must be <= MAX_LOCK_MULTIPLIER_LIMIT
   * maxLockMultiplier must be <= _maxGlobalMultiplier - _maxBoostMultiplier
   *
   * Must only be called by the owner
   */
  function setLockMultiplierSettings(uint256 maxLockDuration, uint256 maxLockMultiplier) external {
    require(msg.sender == owner() || msg.sender == operator, "FORBIDDEN");
    // onlyOperatorOrOwner: caller has no operator rights
    require(maxLockMultiplier <= MAX_LOCK_MULTIPLIER_LIMIT && maxLockMultiplier.add(_maxBoostMultiplier) <= _maxGlobalMultiplier, "too high");
    // setLockSettings: maxGlobalMultiplier is too high
    _maxLockDuration = maxLockDuration;
    _maxLockMultiplier = maxLockMultiplier;

    emit SetLockMultiplierSettings(maxLockDuration, maxLockMultiplier);
  }

  /**
   * @dev Set global and boost multiplier settings
   *
   * maxGlobalMultiplier must be <= MAX_GLOBAL_MULTIPLIER_LIMIT
   * maxBoostMultiplier must be <= MAX_BOOST_MULTIPLIER_LIMIT
   * (maxBoostMultiplier + _maxLockMultiplier) must be <= _maxGlobalMultiplier
   *
   * Must only be called by the owner
   */
  function setBoostMultiplierSettings(uint256 maxGlobalMultiplier, uint256 maxBoostMultiplier) external {
    _requireOnlyOwner();
    require(maxGlobalMultiplier <= MAX_GLOBAL_MULTIPLIER_LIMIT, "too high");

    // setMultiplierSettings: maxGlobalMultiplier is too high
    require(maxBoostMultiplier <= MAX_BOOST_MULTIPLIER_LIMIT && maxBoostMultiplier.add(_maxLockMultiplier) <= maxGlobalMultiplier, "too high");
    // setLockSettings: maxGlobalMultiplier is too high
    _maxGlobalMultiplier = maxGlobalMultiplier;
    _maxBoostMultiplier = maxBoostMultiplier;

    emit SetBoostMultiplierSettings(maxGlobalMultiplier, maxBoostMultiplier);
  }

  /**
   * @dev Set the share of xFLASH for the distributed rewards
   * The share of FLASH will incidently be 100% - xFlashRewardsShare
   *
   * Must only be called by the owner
   */
  function setXArtRewardsShare(uint256 xFlashRewardsShare_) external {
    _requireOnlyOwner();
    require(xFlashRewardsShare_ <= _TOTAL_REWARDS_SHARES, "too high");

    xFlashRewardsShare = xFlashRewardsShare_;
    emit SetXArtRewardsShare(xFlashRewardsShare_);
  }

  /**
   * @dev Add or remove unlock operators
   *
   * Must only be called by the owner
   */
  function setUnlockOperator(address _operator, bool add) external {
    _requireOnlyOwner();

    if (add) {
      _unlockOperators.add(_operator);
    }
    else {
      _unlockOperators.remove(_operator);
    }
    emit SetUnlockOperator(_operator, add);
  }

  /**
   * @dev Set emergency unlock status
   *
   * Must only be called by the owner
   */
  function setEmergencyUnlock(bool emergencyUnlock_) external {
    _requireOnlyOwner();

    emergencyUnlock = emergencyUnlock_;
    emit SetEmergencyUnlock(emergencyUnlock);
  }

  /**
   * @dev Set operator (usually deposit token's project's owner) to adjust contract's settings
   *
   * Must only be called by the owner
   */
  function setOperator(address operator_) external {
    _requireOnlyOwner();

    operator = operator_;
    emit SetOperator(operator_);
  }


  /****************************************************************/
  /****************** EXTERNAL PUBLIC FUNCTIONS  ******************/
  /****************************************************************/

  /**
   * @dev Add nonReentrant to ERC721.transferFrom
   */
  function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) nonReentrant {
    ERC721.transferFrom(from, to, tokenId);
  }

  /**
   * @dev Add nonReentrant to ERC721.safeTransferFrom
   */
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override(ERC721, IERC721) nonReentrant {
    ERC721.safeTransferFrom(from, to, tokenId, _data);
  }

  /**
   * @dev Updates rewards states of the given pool to be up-to-date
   */
  function updatePool() external nonReentrant {
    _updatePool();
  }

  /**
   * @dev Create a staking position (spNFT) with an optional lockDuration
   */
  function createPosition(uint256 amount, uint256 lockDuration) external nonReentrant {
    // no new lock can be set if the pool has been unlocked
    if (isUnlocked()) {
      require(lockDuration == 0, "locks disabled");
    }

    _updatePool();

    // handle tokens with transfer tax
    amount = _transferSupportingFeeOnTransfer(_lpToken, msg.sender, amount);
    require(amount != 0, "zero amount"); // createPosition: amount cannot be null

    // mint NFT position token
    uint256 currentTokenId = _mintNextTokenId(msg.sender);

    // calculate bonuses
    uint256 lockMultiplier = getMultiplierByLockDuration(lockDuration);
    uint256 amountWithMultiplier = amount.mul(lockMultiplier.add(1e4)).div(1e4);

    // create position
    _stakingPositions[currentTokenId] = StakingPosition({
      amount : amount,
      rewardDebt : amountWithMultiplier.mul(_accRewardsPerShare).div(1e18),
      lockDuration : lockDuration,
      startLockTime : _currentBlockTimestamp(),
      lockMultiplier : lockMultiplier,
      amountWithMultiplier : amountWithMultiplier,
      boostPoints : 0,
      totalMultiplier : lockMultiplier,
      pendingArtRewards: 0,
      pendingXArtRewards: 0
    });

    // update total lp supply
    _lpSupply = _lpSupply.add(amount);
    _lpSupplyWithMultiplier = _lpSupplyWithMultiplier.add(amountWithMultiplier);

    emit CreatePosition(currentTokenId, amount, lockDuration);
  }

  /**
   * @dev Add to an existing staking position
   *
   * Can only be called by spNFT's owner or operators
   */
  function addToPosition(uint256 tokenId, uint256 amountToAdd) external nonReentrant {
    _requireOnlyOperatorOrOwnerOf(tokenId);
    require(amountToAdd > 0, "0 amount"); // addToPosition: amount cannot be null

    _updatePool();
    address nftOwner = ERC721.ownerOf(tokenId);
    _harvestPosition(tokenId, nftOwner);

    StakingPosition storage position = _stakingPositions[tokenId];

    // if position is locked, renew the lock
    if (position.lockDuration > 0) {
      position.startLockTime = _currentBlockTimestamp();
      position.lockMultiplier = getMultiplierByLockDuration(position.lockDuration);
    }

    // handle tokens with transfer tax
    amountToAdd = _transferSupportingFeeOnTransfer(_lpToken, msg.sender, amountToAdd);

    // update position
    position.amount = position.amount.add(amountToAdd);
    _lpSupply = _lpSupply.add(amountToAdd);
    _updateBoostMultiplierInfoAndRewardDebt(position);

    _checkOnAddToPosition(nftOwner, tokenId, amountToAdd);
    emit AddToPosition(tokenId, msg.sender, amountToAdd);
  }

  /**
   * @dev Assign "amount" of boost points to a position
   *
   * Can only be called by the master-defined YieldBooster contract
   */
  function boost(uint256 tokenId, uint256 amount) external override nonReentrant {
    _requireOnlyYieldBooster();
    require(ERC721._exists(tokenId), "invalid tokenId");
    
    _updatePool();
    _harvestPosition(tokenId, address(0));

    StakingPosition storage position = _stakingPositions[tokenId];

    // update position
    uint256 boostPoints = position.boostPoints.add(amount);
    position.boostPoints = boostPoints;
    _updateBoostMultiplierInfoAndRewardDebt(position);
    emit SetBoost(tokenId, boostPoints);
  }

  /**
   * @dev Remove "amount" of boost points from a position
   *
   * Can only be called by the master-defined YieldBooster contract
   */
  function unboost(uint256 tokenId, uint256 amount) external override nonReentrant {
    _requireOnlyYieldBooster();
    
    _updatePool();
    _harvestPosition(tokenId, address(0));

    StakingPosition storage position = _stakingPositions[tokenId];

    // update position
    uint256 boostPoints = position.boostPoints.sub(amount);
    position.boostPoints = boostPoints;
    _updateBoostMultiplierInfoAndRewardDebt(position);
    emit SetBoost(tokenId, boostPoints);
  }

  /**
   * @dev Harvest from a staking position
   *
   * Can only be called by spNFT's owner or approved address
   */
  function harvestPosition(uint256 tokenId) external nonReentrant {
    _requireOnlyApprovedOrOwnerOf(tokenId);
    
    _updatePool();
    _harvestPosition(tokenId, ERC721.ownerOf(tokenId));
    _updateBoostMultiplierInfoAndRewardDebt(_stakingPositions[tokenId]);
  }

  /**
   * @dev Harvest from a staking position to "to" address
   *
   * Can only be called by spNFT's owner or approved address
   * spNFT's owner must be a contract
   */
  function harvestPositionTo(uint256 tokenId, address to) external nonReentrant {
    _requireOnlyApprovedOrOwnerOf(tokenId);
    require(ERC721.ownerOf(tokenId).isContract(), "FORBIDDEN");
    
    _updatePool();
    _harvestPosition(tokenId, to);
    _updateBoostMultiplierInfoAndRewardDebt(_stakingPositions[tokenId]);
  }

  /**
   * @dev Harvest from multiple staking positions to "to" address
   *
   * Can only be called by spNFT's owner or approved address
   */
  function harvestPositionsTo(uint256[] calldata tokenIds, address to) external nonReentrant {
    _updatePool();

    uint256 length = tokenIds.length;

    for (uint256 i = 0; i < length; ++i) {
      uint256 tokenId = tokenIds[i];
      _requireOnlyApprovedOrOwnerOf(tokenId);
      address tokenOwner = ERC721.ownerOf(tokenId);
      // if sender is the current owner, must also be the harvest dst address
      // if sender is approved, current owner must be a contract
      require((msg.sender == tokenOwner && msg.sender == to) || tokenOwner.isContract(), "FORBIDDEN");

      _harvestPosition(tokenId, to);
      _updateBoostMultiplierInfoAndRewardDebt(_stakingPositions[tokenId]);
    }
  }

  /**
   * @dev Withdraw from a staking position
   *
   * Can only be called by spNFT's owner or approved address
   */
  function withdrawFromPosition(uint256 tokenId, uint256 amountToWithdraw) external nonReentrant {
    _requireOnlyApprovedOrOwnerOf(tokenId);
    
    _updatePool();
    address nftOwner = ERC721.ownerOf(tokenId);
    _withdrawFromPosition(nftOwner, tokenId, amountToWithdraw);
    _checkOnWithdraw(nftOwner, tokenId, amountToWithdraw);
  }

  /**
   * @dev Renew lock from a staking position
   *
   * Can only be called by spNFT's owner or approved address
   */
  function renewLockPosition(uint256 tokenId) external nonReentrant {
    _requireOnlyApprovedOrOwnerOf(tokenId);
    
    _updatePool();
    _lockPosition(tokenId, _stakingPositions[tokenId].lockDuration);
  }

  /**
   * @dev Lock a staking position (can be used to extend a lock)
   *
   * Can only be called by spNFT's owner or approved address
   */
  function lockPosition(uint256 tokenId, uint256 lockDuration) external nonReentrant {
    _requireOnlyApprovedOrOwnerOf(tokenId);
    
    _updatePool();
    _lockPosition(tokenId, lockDuration);
  }

  /**
   * @dev Split a staking position into two
   *
   * Can only be called by nft's owner
   */
  function splitPosition(uint256 tokenId, uint256 splitAmount) external nonReentrant {
    _requireOnlyOwnerOf(tokenId);

    _updatePool();
    _harvestPosition(tokenId, ERC721.ownerOf(tokenId));

    StakingPosition storage position = _stakingPositions[tokenId];
    // can't have the original token completely emptied
    require(splitAmount < position.amount, "invalid splitAmount");

    // sub from existing position
    position.amount = position.amount.sub(splitAmount);
    _updateBoostMultiplierInfoAndRewardDebt(position);

    // create new position
    uint256 currentTokenId = _mintNextTokenId(msg.sender);
    uint256 lockDuration = position.lockDuration;
    uint256 lockMultiplier = position.lockMultiplier;
    uint256 amountWithMultiplier = splitAmount.mul(lockMultiplier.add(1e4)).div(1e4);
    _stakingPositions[currentTokenId] = StakingPosition({
      amount : splitAmount,
      rewardDebt : amountWithMultiplier.mul(_accRewardsPerShare).div(1e18),
      lockDuration : lockDuration,
      startLockTime : position.startLockTime,
      lockMultiplier : lockMultiplier,
      amountWithMultiplier : amountWithMultiplier,
      boostPoints : 0,
      totalMultiplier : lockMultiplier,
      pendingArtRewards: 0,
      pendingXArtRewards: 0
    });

    _lpSupplyWithMultiplier = _lpSupplyWithMultiplier.add(amountWithMultiplier);

    emit SplitPosition(tokenId, splitAmount, currentTokenId);
  }

  /**
   * @dev Merge an array of staking positions into a single one with "lockDuration"
   * Can't be used on positions with a higher lock duration than "lockDuration" param
   *
   * Can only be called by spNFT's owner
   */
  function mergePositions(uint256[] calldata tokenIds, uint256 lockDuration) external nonReentrant {
    _updatePool();

    uint256 length = tokenIds.length;
    require(length > 1, "invalid");
    // mergePositions: array must have at least two items

    // set the destination position into which the others will be merged (using first item of the list)
    uint256 dstTokenId = tokenIds[0];
    _requireOnlyOwnerOf(dstTokenId);

    StakingPosition storage dstPosition = _stakingPositions[dstTokenId];
    require(dstPosition.lockDuration <= lockDuration, "can't merge");
    _harvestPosition(dstTokenId, msg.sender);

    dstPosition.lockDuration = lockDuration;
    dstPosition.lockMultiplier = getMultiplierByLockDuration(lockDuration);

    // loop starts at 2nd element
    for (uint256 i = 1; i < length; ++i) {
      uint256 tokenId = tokenIds[i];
      _requireOnlyOwnerOf(tokenId);
      require(tokenId != dstTokenId, "invalid token id");

      _harvestPosition(tokenId, msg.sender);
      StakingPosition storage position = _stakingPositions[tokenId];

      // positions must have a lower lock duration than param
      require(position.lockDuration <= lockDuration, "can't merge");
      // mergePositions: positions cannot be merged

      // we want to use the latest startLockTime
      if (dstPosition.startLockTime < position.startLockTime) {
        dstPosition.startLockTime = position.startLockTime;
      }

      // aggregate amounts to the destination position
      dstPosition.amount = dstPosition.amount.add(position.amount);

      // destroy position
      _lpSupplyWithMultiplier = _lpSupplyWithMultiplier.sub(position.amountWithMultiplier);
      _destroyPosition(tokenId, position.boostPoints);
    }

    _updateBoostMultiplierInfoAndRewardDebt(dstPosition);
    emit MergePositions(msg.sender, tokenIds);
  }

  /**
   * Withdraw without caring about rewards, EMERGENCY ONLY
   *
   * Can only be called by spNFT's owner
   */
  function emergencyWithdraw(uint256 tokenId) external nonReentrant {
    _requireOnlyOwnerOf(tokenId);

    StakingPosition storage position = _stakingPositions[tokenId];

    // position should be unlocked
    require(
      _unlockOperators.contains(msg.sender) || position.startLockTime.add(position.lockDuration) <= _currentBlockTimestamp() || isUnlocked(), "locked");
    // emergencyWithdraw: locked

    uint256 amount = position.amount;

    // update total lp supply
    _lpSupply = _lpSupply.sub(amount);
    _lpSupplyWithMultiplier = _lpSupplyWithMultiplier.sub(position.amountWithMultiplier);

    // destroy position (ignore boost points)
    _destroyPosition(tokenId, 0);

    emit EmergencyWithdraw(tokenId, amount);
    _lpToken.safeTransfer(msg.sender, amount);
  }

  /********************************************************/
  /****************** INTERNAL FUNCTIONS ******************/
  /********************************************************/

  /**
   * @dev Returns whether "userAddress" is the owner of "tokenId" spNFT
   */
  function _isOwnerOf(address userAddress, uint256 tokenId) internal view returns (bool){
    return userAddress == ERC721.ownerOf(tokenId);
  }

  /**
   * @dev Updates rewards states of this pool to be up-to-date
   */
  function _updatePool() internal {
    // gets allocated rewards from Master and updates
    (uint256 rewards) = master.claimRewards();

    if (rewards > 0) {
      _accRewardsPerShare = _accRewardsPerShare.add(rewards.mul(1e18).div(_lpSupplyWithMultiplier));
    }

    emit PoolUpdated(_currentBlockTimestamp(), _accRewardsPerShare);
  }

  /**
   * @dev Destroys spNFT
   *
   * "boostPointsToDeallocate" is set to 0 to ignore boost points handling if called during an emergencyWithdraw
   * Users should still be able to deallocate xFLASH from the YieldBooster contract
   */
  function _destroyPosition(uint256 tokenId, uint256 boostPoints) internal {
    // calls yieldBooster contract to deallocate the spNFT's owner boost points if any
    if (boostPoints > 0) {
      IYieldBooster(yieldBooster()).deallocateAllFromPool(msg.sender, tokenId);
    }

    // burn spNFT
    delete _stakingPositions[tokenId];
    ERC721._burn(tokenId);
  }

  /**
   * @dev Computes new tokenId and mint associated spNFT to "to" address
   */
  function _mintNextTokenId(address to) internal returns (uint256 tokenId) {
    _tokenIds.increment();
    tokenId = _tokenIds.current();
    _safeMint(to, tokenId);
  }

  /**
   * @dev Withdraw from a staking position and destroy it
   *
   * _updatePool() should be executed before calling this
   */
  function _withdrawFromPosition(address nftOwner, uint256 tokenId, uint256 amountToWithdraw) internal {
    require(amountToWithdraw > 0, "null");
    // withdrawFromPosition: amount cannot be null

    StakingPosition storage position = _stakingPositions[tokenId];
    require(_unlockOperators.contains(nftOwner) || position.startLockTime.add(position.lockDuration) <= _currentBlockTimestamp() || isUnlocked(), "locked");
    // withdrawFromPosition: invalid amount
    require(position.amount >= amountToWithdraw, "invalid");

    _harvestPosition(tokenId, nftOwner);

    // update position
    position.amount = position.amount.sub(amountToWithdraw);

    // update total lp supply
    _lpSupply = _lpSupply.sub(amountToWithdraw);

    if (position.amount == 0) {
      // destroy if now empty
      _lpSupplyWithMultiplier = _lpSupplyWithMultiplier.sub(position.amountWithMultiplier);
      _destroyPosition(tokenId, position.boostPoints);
    } else {
      _updateBoostMultiplierInfoAndRewardDebt(position);
    }

    emit WithdrawFromPosition(tokenId, amountToWithdraw);
    _lpToken.safeTransfer(nftOwner, amountToWithdraw);
  }

  /**
   * @dev updates position's boost multiplier, totalMultiplier, amountWithMultiplier (_lpSupplyWithMultiplier)
   * and rewardDebt without updating lockMultiplier
   */
  function _updateBoostMultiplierInfoAndRewardDebt(StakingPosition storage position) internal {
    // keep the original lock multiplier and recompute current boostPoints multiplier
    uint256 newTotalMultiplier = getMultiplierByBoostPoints(position.amount, position.boostPoints).add(position.lockMultiplier);
    if (newTotalMultiplier > _maxGlobalMultiplier) newTotalMultiplier = _maxGlobalMultiplier;

    position.totalMultiplier = newTotalMultiplier;
    uint256 amountWithMultiplier = position.amount.mul(newTotalMultiplier.add(1e4)).div(1e4);
    // update global supply
    _lpSupplyWithMultiplier = _lpSupplyWithMultiplier.sub(position.amountWithMultiplier).add(amountWithMultiplier);
    position.amountWithMultiplier = amountWithMultiplier;

    position.rewardDebt = amountWithMultiplier.mul(_accRewardsPerShare).div(1e18);
  }

  /**
   * @dev Harvest rewards from a position
   * Will also update the position's totalMultiplier
   */
  function _harvestPosition(uint256 tokenId, address to) internal {
    StakingPosition storage position = _stakingPositions[tokenId];

    // compute position's pending rewards
    uint256 pending = position.amountWithMultiplier.mul(_accRewardsPerShare).div(1e18).sub(
      position.rewardDebt
    );

    // unlock the position if pool has been unlocked or position is unlocked
    if (isUnlocked() || position.startLockTime.add(position.lockDuration) <= _currentBlockTimestamp()) {
      position.lockDuration = 0;
      position.lockMultiplier = 0;
    }

    // transfer rewards
    if (pending > 0 || position.pendingXArtRewards > 0 || position.pendingArtRewards > 0) {
      uint256 xFlashRewards = pending.mul(xFlashRewardsShare).div(_TOTAL_REWARDS_SHARES);
      uint256 artAmount = pending.add(position.pendingArtRewards).sub(xFlashRewards);

      xFlashRewards = xFlashRewards.add(position.pendingXArtRewards);

      // Stack rewards in a buffer if to is equal to address(0)
      if (address(0) == to) {
        position.pendingXArtRewards = xFlashRewards;
        position.pendingArtRewards = artAmount;
      }
      else {
        // convert and send xFLASH + FLASH rewards
        position.pendingXArtRewards = 0;
        position.pendingArtRewards = 0;

        if(xFlashRewards > 0) xFlashRewards = _safeConvertTo(to, xFlashRewards);
        // send share of FLASH rewards
        artAmount= _safeRewardsTransfer(to, artAmount);

        // forbidden to harvest if contract has not explicitly confirmed it handle it
        _checkOnNFTHarvest(to, tokenId, artAmount, xFlashRewards);
      }
    }
    emit HarvestPosition(tokenId, to, pending);
  }

  /**
   * @dev Renew lock from a staking position with "lockDuration"
   */
  function _lockPosition(uint256 tokenId, uint256 lockDuration) internal {
    require(!isUnlocked(), "locks disabled");

    StakingPosition storage position = _stakingPositions[tokenId];

    // for renew only, check if new lockDuration is at least = to the remaining active duration
    uint256 endTime = position.startLockTime.add(position.lockDuration);
    uint256 currentBlockTimestamp = _currentBlockTimestamp();
    if(endTime > currentBlockTimestamp){
      require(lockDuration >= endTime.sub(currentBlockTimestamp) && lockDuration > 0, "invalid");
    }

    _harvestPosition(tokenId, msg.sender);

    // update position and total lp supply
    position.lockDuration = lockDuration;
    position.lockMultiplier = getMultiplierByLockDuration(lockDuration);
    position.startLockTime = currentBlockTimestamp;
    _updateBoostMultiplierInfoAndRewardDebt(position);

    emit LockPosition(tokenId, lockDuration);
  }


  /**
  * @dev Handle deposits of tokens with transfer tax
  */
  function _transferSupportingFeeOnTransfer(IERC20 token, address user, uint256 amount) internal returns (uint256 receivedAmount) {
    uint256 previousBalance = token.balanceOf(address(this));
    token.safeTransferFrom(user, address(this), amount);
    return token.balanceOf(address(this)).sub(previousBalance);
  }

  /**
   * @dev Safe token transfer function, in case rounding error causes pool to not have enough tokens
   */
  function _safeRewardsTransfer(address to, uint256 amount) internal returns (uint256) {
    uint256 balance = _flashToken.balanceOf(address(this));
    // cap to available balance
    if (amount > balance) {
      amount = balance;
    }
    _flashToken.safeTransfer(to, amount);
    return amount;
  }

  /**
   * @dev Safe convert FLASH to xFLASH function, in case rounding error causes pool to not have enough tokens
   */
  function _safeConvertTo(address to, uint256 amount) internal returns (uint256) {
    uint256 balance = _flashToken.balanceOf(address(this));
    // cap to available balance
    if (amount > balance) {
      amount = balance;
    }
    if(amount > 0 ) _xFlashToken.convertTo(amount, to);
    return amount;
  }

  /**
   * @dev If NFT's owner is a contract, confirm whether it's able to handle rewards harvesting
   */
  function _checkOnNFTHarvest(address to, uint256 tokenId, uint256 artAmount, uint256 xFlashAmount) internal {
    address nftOwner = ERC721.ownerOf(tokenId);
    if (nftOwner.isContract()) {
      bytes memory returndata = nftOwner.functionCall(abi.encodeWithSelector(
          INFTHandler(nftOwner).onNFTHarvest.selector, msg.sender, to, tokenId, artAmount, xFlashAmount), "non implemented");
      require(abi.decode(returndata, (bool)), "FORBIDDEN");
    }
  }

  /**
   * @dev If NFT's owner is a contract, confirm whether it's able to handle addToPosition
   */
  function _checkOnAddToPosition(address nftOwner, uint256 tokenId, uint256 lpAmount) internal {
    if (nftOwner.isContract()) {
      bytes memory returndata = nftOwner.functionCall(abi.encodeWithSelector(
          INFTHandler(nftOwner).onNFTAddToPosition.selector, msg.sender, tokenId, lpAmount), "non implemented");
      require(abi.decode(returndata, (bool)), "FORBIDDEN");
    }
  }

  /**
   * @dev If NFT's owner is a contract, confirm whether it's able to handle withdrawals
   */
  function _checkOnWithdraw(address nftOwner, uint256 tokenId, uint256 lpAmount) internal {
    if (nftOwner.isContract()) {
      bytes memory returndata = nftOwner.functionCall(abi.encodeWithSelector(
          INFTHandler(nftOwner).onNFTWithdraw.selector, msg.sender, tokenId, lpAmount), "non implemented");
      require(abi.decode(returndata, (bool)), "FORBIDDEN");
    }
  }

  /**
  * @dev Forbid transfer when spNFT's owner is a contract and an operator is trying to transfer it
  * This is made to avoid unintended side effects
  *
  * Contract owner can still implement it by itself if needed
  */
  function _beforeTokenTransfer(address from, address /*to*/, uint256 /*tokenId*/) internal view override {
    require(!from.isContract() || msg.sender == from, "FORBIDDEN");
  }

  /**
   * @dev Utility function to get the current block timestamp
   */
  function _currentBlockTimestamp() internal view virtual returns (uint256) {
    /* solhint-disable not-rely-on-time */
    return block.timestamp;
  }

}