// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IFlashpadMaster.sol";
import "./interfaces/INFTPool.sol";
import "./interfaces/IYieldBooster.sol";
import "./interfaces/tokens/IFlashToken.sol";


/*
 * This contract centralizes Flashpad's yield incentives distribution.
 * Pools that should receive those incentives are defined here, along with their allocation.
 * All rewards are claimed from the FLASHToken contract.
 */
contract FlashpadMaster is Ownable, IFlashpadMaster {
  using SafeERC20 for IFlashToken;
  using SafeMath for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;

  // Info of each NFT pool
  struct PoolInfo {
    uint256 allocPoint; // How many allocation points assigned to this NFT pool
    uint256 lastRewardTime; // Last time that distribution to this NFT pool occurs
    uint256 reserve; // Pending rewards to distribute to the NFT pool
  }

  IFlashToken private immutable _flashToken; // Address of the FLASH token contract
  IYieldBooster private _yieldBooster; // Contract address handling yield boosts

  mapping(address => PoolInfo) private _poolInfo; // Pools' information
  EnumerableSet.AddressSet private _pools; // All existing pool addresses
  EnumerableSet.AddressSet private _activePools; // Only contains pool addresses w/ allocPoints > 0

  uint256 public totalAllocPoint; // Total allocation points. Must be the sum of all allocation points in all pools
  uint256 public immutable startTime; // The time at which farming starts

  bool public override emergencyUnlock; // Used by pools to release all their locks at once in case of emergency

  constructor(
    IFlashToken flashToken_,
    uint256 startTime_
  ) {
    require(address(flashToken_) != address(0), "FlashpadMaster: flashToken cannot be set to zero address");
    require(_currentBlockTimestamp() < startTime_ && startTime_ >= flashToken_.lastEmissionTime(), "FlashpadMaster: invalid startTime");
    _flashToken = flashToken_;
    startTime = startTime_; // Must be set with the same time as FlashToken emission start
  }


  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event ClaimRewards(address indexed poolAddress, uint256 amount);
  event PoolAdded(address indexed poolAddress, uint256 allocPoint);
  event PoolSet(address indexed poolAddress, uint256 allocPoint);
  event SetYieldBooster(address previousYieldBooster, address newYieldBooster);
  event PoolUpdated(address indexed poolAddress, uint256 reserve, uint256 lastRewardTime);
  event SetEmergencyUnlock(bool emergencyUnlock);


  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  /*
   * @dev Check if a pool exists
   */
  modifier validatePool(address poolAddress) {
    require(_pools.contains(poolAddress), "validatePool: pool does not exist");
    _;
  }


  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /*
   * @dev Returns FlashToken address
   */
  function flashToken() external view override returns (address) {
    return address(_flashToken);
  }

  /*
   * @dev Returns FlashToken's emission rate (allocated to this contract)
   */
  function emissionRate() public view returns (uint256) {
    return _flashToken.masterEmissionRate();
  }

  /**
   * @dev Returns current owner's address
   */
  function owner() public view virtual override(IFlashpadMaster, Ownable) returns (address) {
    return Ownable.owner();
  }

  /**
   * @dev Returns YieldBooster's address
   */
  function yieldBooster() external view override returns (address) {
    return address(_yieldBooster);
  }

  /**
   * @dev Returns the number of available pools
   */
  function poolsLength() external view returns (uint256) {
    return _pools.length();
  }

  /**
   * @dev Returns a pool from its "index"
   */
  function getPoolAddressByIndex(uint256 index) external view returns (address) {
    if (index >= _pools.length()) return address(0);
    return _pools.at(index);
  }

  /**
   * @dev Returns the number of active pools
   */
  function activePoolsLength() external view returns (uint256) {
    return _activePools.length();
  }

  /**
   * @dev Returns an active pool from its "index"
   */
  function getActivePoolAddressByIndex(uint256 index) external view returns (address) {
    if (index >= _activePools.length()) return address(0);
    return _activePools.at(index);
  }

  /**
   * @dev Returns data of a given pool
   */
  function getPoolInfo(address poolAddress_) external view override returns (
    address poolAddress, uint256 allocPoint, uint256 lastRewardTime, uint256 reserve, uint256 poolEmissionRate
  ) {
    PoolInfo memory pool = _poolInfo[poolAddress_];

    poolAddress = poolAddress_;
    allocPoint = pool.allocPoint;
    lastRewardTime = pool.lastRewardTime;
    reserve = pool.reserve;

    if (totalAllocPoint == 0) {
      poolEmissionRate = 0;
    } else {
      poolEmissionRate = emissionRate().mul(allocPoint).div(totalAllocPoint);
    }
  }


  /*******************************************************/
  /****************** OWNABLE FUNCTIONS ******************/
  /*******************************************************/

  /**
   * @dev Set YieldBooster contract's address
   *
   * Must only be called by the owner
   */
  function setYieldBooster(IYieldBooster yieldBooster_) external onlyOwner {
    require(address(yieldBooster_) != address(0), "setYieldBooster: cannot be set to zero address");
    emit SetYieldBooster(address(_yieldBooster), address(yieldBooster_));
    _yieldBooster = yieldBooster_;
  }

  /**
   * @dev Set emergency unlock status for all pools
   *
   * Must only be called by the owner
   */
  function setEmergencyUnlock(bool emergencyUnlock_) external onlyOwner {
    emergencyUnlock = emergencyUnlock_;
    emit SetEmergencyUnlock(emergencyUnlock);
  }

  /**
   * @dev Adds a new pool
   * param withUpdate should be set to true every time it's possible
   *
   * Must only be called by the owner
   */
  function add(INFTPool nftPool, uint256 allocPoint, bool withUpdate) external onlyOwner {
    address poolAddress = address(nftPool);
    require(!_pools.contains(poolAddress), "add: pool already exists");
    uint256 currentBlockTimestamp = _currentBlockTimestamp();

    if (allocPoint > 0) {
      if (withUpdate) {
        // Update all pools if new pool allocPoint > 0
        _massUpdatePools();
      }
      _activePools.add(poolAddress);
    }

    // update lastRewardTime if startTime has already been passed
    uint256 lastRewardTime = currentBlockTimestamp > startTime ? currentBlockTimestamp : startTime;

    // update totalAllocPoint with the new pool's points
    totalAllocPoint = totalAllocPoint.add(allocPoint);

    // add new pool
    _poolInfo[poolAddress] = PoolInfo({
    allocPoint : allocPoint,
    lastRewardTime : lastRewardTime,
    reserve : 0
    });
    _pools.add(poolAddress);

    emit PoolAdded(poolAddress, allocPoint);
  }

  /**
   * @dev Updates configuration on existing pool
   * param withUpdate should be set to true every time it's possible
   *
   * Must only be called by the owner
   */
  function set(address poolAddress, uint256 allocPoint, bool withUpdate) external validatePool(poolAddress) onlyOwner {
    PoolInfo storage pool = _poolInfo[poolAddress];
    uint256 prevAllocPoint = pool.allocPoint;

    if (withUpdate) {
      _massUpdatePools();
    }
    _updatePool(poolAddress);

    // update (pool's and total) allocPoints
    pool.allocPoint = allocPoint;
    totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(allocPoint);

    // if request is activating the pool
    if (prevAllocPoint == 0 && allocPoint > 0) {
      _activePools.add(poolAddress);
    }
    // if request is deactivating the pool
    else if (prevAllocPoint > 0 && allocPoint == 0) {
      _activePools.remove(poolAddress);
    }

    emit PoolSet(poolAddress, allocPoint);
  }


  /****************************************************************/
  /****************** EXTERNAL PUBLIC FUNCTIONS  ******************/
  /****************************************************************/

  /**
   * @dev Updates rewards states of the given pool to be up-to-date
   */
  function updatePool(address nftPool) external validatePool(nftPool) {
    _updatePool(nftPool);
  }

  /**
   * @dev Updates rewards states for all pools
   *
   * Be careful of gas spending
   */
  function massUpdatePools() external {
    _massUpdatePools();
  }

  /**
   * @dev Transfer to a pool its pending rewards in reserve, can only be called by the NFT pool contract itself
   */
  function claimRewards() external override returns (uint256 rewardsAmount) {
    // check if caller is a listed pool
    if (!_pools.contains(msg.sender)) {
      return 0;
    }

    _updatePool(msg.sender);

    // updates caller's reserve
    PoolInfo storage pool = _poolInfo[msg.sender];
    uint256 reserve = pool.reserve;
    if (reserve == 0) {
      return 0;
    }
    pool.reserve = 0;

    emit ClaimRewards(msg.sender, reserve);
    return _safeRewardsTransfer(msg.sender, reserve);
  }


  /********************************************************/
  /****************** INTERNAL FUNCTIONS ******************/
  /********************************************************/

  /**
   * @dev Safe token transfer function, in case rounding error causes pool to not have enough tokens
   */
  function _safeRewardsTransfer(address to, uint256 amount) internal returns (uint256 effectiveAmount) {
    uint256 artBalance = _flashToken.balanceOf(address(this));

    if (amount > artBalance) {
      amount = artBalance;
    }

    _flashToken.safeTransfer(to, amount);
    return amount;
  }

  /**
   * @dev Updates rewards states of the given pool to be up-to-date
   *
   * Pool should be validated prior to calling this
   */
  function _updatePool(address poolAddress) internal {
    PoolInfo storage pool = _poolInfo[poolAddress];

    uint256 currentBlockTimestamp = _currentBlockTimestamp();

    uint256 lastRewardTime = pool.lastRewardTime; // gas saving
    uint256 allocPoint = pool.allocPoint; // gas saving

    if (currentBlockTimestamp <= lastRewardTime) {
      return;
    }

    // do not allocate rewards if pool is not active
    if (allocPoint > 0 && INFTPool(poolAddress).hasDeposits()) {
      // calculate how much FLASH rewards are expected to be received for this pool
      uint256 rewards = currentBlockTimestamp.sub(lastRewardTime) // nbSeconds
        .mul(emissionRate()).mul(allocPoint).div(totalAllocPoint);

      // claim expected rewards from the token
      // use returns effective minted amount instead of expected amount
      (rewards) = _flashToken.claimMasterRewards(rewards);

      // updates pool data
      pool.reserve = pool.reserve.add(rewards);
    }

    pool.lastRewardTime = currentBlockTimestamp;

    emit PoolUpdated(poolAddress, pool.reserve, currentBlockTimestamp);
  }

  /**
   * @dev Updates rewards states for all pools
   *
   * Be careful of gas spending
   */
  function _massUpdatePools() internal {
    uint256 length = _activePools.length();
    for (uint256 index = 0; index < length; ++index) {
      _updatePool(_activePools.at(index));
    }
  }

  /**
   * @dev Utility function to get the current block timestamp
   */
  function _currentBlockTimestamp() internal view virtual returns (uint256) {
    /* solhint-disable not-rely-on-time */
    return block.timestamp;
  }
}