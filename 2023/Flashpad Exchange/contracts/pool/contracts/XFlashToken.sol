// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/tokens/IFlashToken.sol";
import "./interfaces/tokens/IXFlashToken.sol";
import "./interfaces/IXFlashTokenUsage.sol";


/*
 * xFLASH is Flashpad's escrowed governance token obtainable by converting FLASH to it
 * It's non-transferable, except from/to whitelisted addresses
 * It can be converted back to FLASH through a vesting process
 * This contract is made to receive xFLASH deposits from users in order to allocate them to Usages (plugins) contracts
 */
contract XFlashToken is Ownable, ReentrancyGuard, ERC20("Flash escrowed token", "xFLASH"), IXFlashToken {
  using Address for address;
  using SafeMath for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IFlashToken;

  struct XFlashBalance {
    uint256 allocatedAmount; // Amount of xFLASH allocated to a Usage
    uint256 redeemingAmount; // Total amount of xFLASH currently being redeemed
  }

  struct RedeemInfo {
    uint256 artAmount; // FLASH amount to receive when vesting has ended
    uint256 xFlashAmount; // xFLASH amount to redeem
    uint256 endTime;
    IXFlashTokenUsage dividendsAddress;
    uint256 dividendsAllocation; // Share of redeeming xFLASH to allocate to the Dividends Usage contract
  }

  IFlashToken public immutable flashToken; // FLASH token to convert to/from
  IXFlashTokenUsage public dividendsAddress; // Flashpad dividends contract

  EnumerableSet.AddressSet private _transferWhitelist; // addresses allowed to send/receive xFLASH

  mapping(address => mapping(address => uint256)) public usageApprovals; // Usage approvals to allocate xFLASH
  mapping(address => mapping(address => uint256)) public override usageAllocations; // Active xFLASH allocations to usages

  uint256 public constant MAX_DEALLOCATION_FEE = 200; // 2%
  mapping(address => uint256) public usagesDeallocationFee; // Fee paid when deallocating xFLASH

  uint256 public constant MAX_FIXED_RATIO = 100; // 100%

  // Redeeming min/max settings
  uint256 public minRedeemRatio = 50; // 1:0.5
  uint256 public maxRedeemRatio = 100; // 1:1
  uint256 public minRedeemDuration = 15 days; // 1296000s
  uint256 public maxRedeemDuration = 90 days; // 7776000s
  // Adjusted dividends rewards for redeeming xFLASH
  uint256 public redeemDividendsAdjustment = 50; // 50%

  mapping(address => XFlashBalance) public xFlashBalances; // User's xFLASH balances
  mapping(address => RedeemInfo[]) public userRedeems; // User's redeeming instances


  constructor(IFlashToken flashToken_) {
    flashToken = flashToken_;
    _transferWhitelist.add(address(this));
  }

  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event ApproveUsage(address indexed userAddress, address indexed usageAddress, uint256 amount);
  event Convert(address indexed from, address to, uint256 amount);
  event UpdateRedeemSettings(uint256 minRedeemRatio, uint256 maxRedeemRatio, uint256 minRedeemDuration, uint256 maxRedeemDuration, uint256 redeemDividendsAdjustment);
  event UpdateDividendsAddress(address previousDividendsAddress, address newDividendsAddress);
  event UpdateDeallocationFee(address indexed usageAddress, uint256 fee);
  event SetTransferWhitelist(address account, bool add);
  event Redeem(address indexed userAddress, uint256 xFlashAmount, uint256 artAmount, uint256 duration);
  event FinalizeRedeem(address indexed userAddress, uint256 xFlashAmount, uint256 artAmount);
  event CancelRedeem(address indexed userAddress, uint256 xFlashAmount);
  event UpdateRedeemDividendsAddress(address indexed userAddress, uint256 redeemIndex, address previousDividendsAddress, address newDividendsAddress);
  event Allocate(address indexed userAddress, address indexed usageAddress, uint256 amount);
  event Deallocate(address indexed userAddress, address indexed usageAddress, uint256 amount, uint256 fee);

  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  /*
   * @dev Check if a redeem entry exists
   */
  modifier validateRedeem(address userAddress, uint256 redeemIndex) {
    require(redeemIndex < userRedeems[userAddress].length, "validateRedeem: redeem entry does not exist");
    _;
  }

  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /*
   * @dev Returns user's xFLASH balances
   */
  function getXFlashBalance(address userAddress) external view returns (uint256 allocatedAmount, uint256 redeemingAmount) {
    XFlashBalance storage balance = xFlashBalances[userAddress];
    return (balance.allocatedAmount, balance.redeemingAmount);
  }

  /*
   * @dev returns redeemable FLASH for "amount" of xFLASH vested for "duration" seconds
   */
  function getFlashByVestingDuration(uint256 amount, uint256 duration) public view returns (uint256) {
    if(duration < minRedeemDuration) {
      return 0;
    }

    // capped to maxRedeemDuration
    if (duration > maxRedeemDuration) {
      return amount.mul(maxRedeemRatio).div(100);
    }

    uint256 ratio = minRedeemRatio.add(
      (duration.sub(minRedeemDuration)).mul(maxRedeemRatio.sub(minRedeemRatio))
      .div(maxRedeemDuration.sub(minRedeemDuration))
    );

    return amount.mul(ratio).div(100);
  }

  /**
   * @dev returns quantity of "userAddress" pending redeems
   */
  function getUserRedeemsLength(address userAddress) external view returns (uint256) {
    return userRedeems[userAddress].length;
  }

  /**
   * @dev returns "userAddress" info for a pending redeem identified by "redeemIndex"
   */
  function getUserRedeem(address userAddress, uint256 redeemIndex) external view validateRedeem(userAddress, redeemIndex) returns (uint256 artAmount, uint256 xFlashAmount, uint256 endTime, address dividendsContract, uint256 dividendsAllocation) {
    RedeemInfo storage _redeem = userRedeems[userAddress][redeemIndex];
    return (_redeem.artAmount, _redeem.xFlashAmount, _redeem.endTime, address(_redeem.dividendsAddress), _redeem.dividendsAllocation);
  }

  /**
   * @dev returns approved xFlash to allocate from "userAddress" to "usageAddress"
   */
  function getUsageApproval(address userAddress, address usageAddress) external view returns (uint256) {
    return usageApprovals[userAddress][usageAddress];
  }

  /**
   * @dev returns allocated xFlash from "userAddress" to "usageAddress"
   */
  function getUsageAllocation(address userAddress, address usageAddress) external view returns (uint256) {
    return usageAllocations[userAddress][usageAddress];
  }

  /**
   * @dev returns length of transferWhitelist array
   */
  function transferWhitelistLength() external view returns (uint256) {
    return _transferWhitelist.length();
  }

  /**
   * @dev returns transferWhitelist array item's address for "index"
   */
  function transferWhitelist(uint256 index) external view returns (address) {
    return _transferWhitelist.at(index);
  }

  /**
   * @dev returns if "account" is allowed to send/receive xFLASH
   */
  function isTransferWhitelisted(address account) external override view returns (bool) {
    return _transferWhitelist.contains(account);
  }

  /*******************************************************/
  /****************** OWNABLE FUNCTIONS ******************/
  /*******************************************************/

  /**
   * @dev Updates all redeem ratios and durations
   *
   * Must only be called by owner
   */
  function updateRedeemSettings(uint256 minRedeemRatio_, uint256 maxRedeemRatio_, uint256 minRedeemDuration_, uint256 maxRedeemDuration_, uint256 redeemDividendsAdjustment_) external onlyOwner {
    require(minRedeemRatio_ <= maxRedeemRatio_, "updateRedeemSettings: wrong ratio values");
    require(minRedeemDuration_ < maxRedeemDuration_, "updateRedeemSettings: wrong duration values");
    // should never exceed 100%
    require(maxRedeemRatio_ <= MAX_FIXED_RATIO && redeemDividendsAdjustment_ <= MAX_FIXED_RATIO, "updateRedeemSettings: wrong ratio values");

    minRedeemRatio = minRedeemRatio_;
    maxRedeemRatio = maxRedeemRatio_;
    minRedeemDuration = minRedeemDuration_;
    maxRedeemDuration = maxRedeemDuration_;
    redeemDividendsAdjustment = redeemDividendsAdjustment_;

    emit UpdateRedeemSettings(minRedeemRatio_, maxRedeemRatio_, minRedeemDuration_, maxRedeemDuration_, redeemDividendsAdjustment_);
  }

  /**
   * @dev Updates dividends contract address
   *
   * Must only be called by owner
   */
  function updateDividendsAddress(IXFlashTokenUsage dividendsAddress_) external onlyOwner {
    // if set to 0, also set divs earnings while redeeming to 0
    if(address(dividendsAddress_) == address(0)) {
      redeemDividendsAdjustment = 0;
    }

    emit UpdateDividendsAddress(address(dividendsAddress), address(dividendsAddress_));
    dividendsAddress = dividendsAddress_;
  }

  /**
   * @dev Updates fee paid by users when deallocating from "usageAddress"
   */
  function updateDeallocationFee(address usageAddress, uint256 fee) external onlyOwner {
    require(fee <= MAX_DEALLOCATION_FEE, "updateDeallocationFee: too high");

    usagesDeallocationFee[usageAddress] = fee;
    emit UpdateDeallocationFee(usageAddress, fee);
  }

  /**
   * @dev Adds or removes addresses from the transferWhitelist
   */
  function updateTransferWhitelist(address account, bool add) external onlyOwner {
    require(account != address(this), "updateTransferWhitelist: Cannot remove xFlash from whitelist");

    if(add) _transferWhitelist.add(account);
    else _transferWhitelist.remove(account);

    emit SetTransferWhitelist(account, add);
  }

  /*****************************************************************/
  /******************  EXTERNAL PUBLIC FUNCTIONS  ******************/
  /*****************************************************************/

  /**
   * @dev Approves "usage" address to get allocations up to "amount" of xFLASH from msg.sender
   */
  function approveUsage(IXFlashTokenUsage usage, uint256 amount) external nonReentrant {
    require(address(usage) != address(0), "approveUsage: approve to the zero address");

    usageApprovals[msg.sender][address(usage)] = amount;
    emit ApproveUsage(msg.sender, address(usage), amount);
  }

  /**
   * @dev Convert caller's "amount" of FLASH to xFLASH
   */
  function convert(uint256 amount) external nonReentrant {
    _convert(amount, msg.sender);
  }

  /**
   * @dev Convert caller's "amount" of FLASH to xFLASH to "to" address
   */
  function convertTo(uint256 amount, address to) external override nonReentrant {
    require(address(msg.sender).isContract(), "convertTo: not allowed");
    _convert(amount, to);
  }

  /**
   * @dev Initiates redeem process (xFLASH to FLASH)
   *
   * Handles dividends' compensation allocation during the vesting process if needed
   */
  function redeem(uint256 xFlashAmount, uint256 duration) external nonReentrant {
    require(xFlashAmount > 0, "redeem: xFlashAmount cannot be null");
    require(duration >= minRedeemDuration, "redeem: duration too low");

    _transfer(msg.sender, address(this), xFlashAmount);
    XFlashBalance storage balance = xFlashBalances[msg.sender];

    // get corresponding FLASH amount
    uint256 artAmount = getFlashByVestingDuration(xFlashAmount, duration);
    emit Redeem(msg.sender, xFlashAmount, artAmount, duration);

    // if redeeming is not immediate, go through vesting process
    if(duration > 0) {
      // add to SBT total
      balance.redeemingAmount = balance.redeemingAmount.add(xFlashAmount);

      // handle dividends during the vesting process
      uint256 dividendsAllocation = xFlashAmount.mul(redeemDividendsAdjustment).div(100);
      // only if compensation is active
      if(dividendsAllocation > 0) {
        // allocate to dividends
        dividendsAddress.allocate(msg.sender, dividendsAllocation, new bytes(0));
      }

      // add redeeming entry
      userRedeems[msg.sender].push(RedeemInfo(artAmount, xFlashAmount, _currentBlockTimestamp().add(duration), dividendsAddress, dividendsAllocation));
    } else {
      // immediately redeem for FLASH
      _finalizeRedeem(msg.sender, xFlashAmount, artAmount);
    }
  }

  /**
   * @dev Finalizes redeem process when vesting duration has been reached
   *
   * Can only be called by the redeem entry owner
   */
  function finalizeRedeem(uint256 redeemIndex) external nonReentrant validateRedeem(msg.sender, redeemIndex) {
    XFlashBalance storage balance = xFlashBalances[msg.sender];
    RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];
    require(_currentBlockTimestamp() >= _redeem.endTime, "finalizeRedeem: vesting duration has not ended yet");

    // remove from SBT total
    balance.redeemingAmount = balance.redeemingAmount.sub(_redeem.xFlashAmount);
    _finalizeRedeem(msg.sender, _redeem.xFlashAmount, _redeem.artAmount);

    // handle dividends compensation if any was active
    if(_redeem.dividendsAllocation > 0) {
      // deallocate from dividends
      IXFlashTokenUsage(_redeem.dividendsAddress).deallocate(msg.sender, _redeem.dividendsAllocation, new bytes(0));
    }

    // remove redeem entry
    _deleteRedeemEntry(redeemIndex);
  }

  /**
   * @dev Updates dividends address for an existing active redeeming process
   *
   * Can only be called by the involved user
   * Should only be used if dividends contract was to be migrated
   */
  function updateRedeemDividendsAddress(uint256 redeemIndex) external nonReentrant validateRedeem(msg.sender, redeemIndex) {
    RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];

    // only if the active dividends contract is not the same anymore
    if(dividendsAddress != _redeem.dividendsAddress && address(dividendsAddress) != address(0)) {
      if(_redeem.dividendsAllocation > 0) {
        // deallocate from old dividends contract
        _redeem.dividendsAddress.deallocate(msg.sender, _redeem.dividendsAllocation, new bytes(0));
        // allocate to new used dividends contract
        dividendsAddress.allocate(msg.sender, _redeem.dividendsAllocation, new bytes(0));
      }

      emit UpdateRedeemDividendsAddress(msg.sender, redeemIndex, address(_redeem.dividendsAddress), address(dividendsAddress));
      _redeem.dividendsAddress = dividendsAddress;
    }
  }

  /**
   * @dev Cancels an ongoing redeem entry
   *
   * Can only be called by its owner
   */
  function cancelRedeem(uint256 redeemIndex) external nonReentrant validateRedeem(msg.sender, redeemIndex) {
    XFlashBalance storage balance = xFlashBalances[msg.sender];
    RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];

    // make redeeming xFLASH available again
    balance.redeemingAmount = balance.redeemingAmount.sub(_redeem.xFlashAmount);
    _transfer(address(this), msg.sender, _redeem.xFlashAmount);

    // handle dividends compensation if any was active
    if(_redeem.dividendsAllocation > 0) {
      // deallocate from dividends
      IXFlashTokenUsage(_redeem.dividendsAddress).deallocate(msg.sender, _redeem.dividendsAllocation, new bytes(0));
    }

    emit CancelRedeem(msg.sender, _redeem.xFlashAmount);

    // remove redeem entry
    _deleteRedeemEntry(redeemIndex);
  }


  /**
   * @dev Allocates caller's "amount" of available xFLASH to "usageAddress" contract
   *
   * args specific to usage contract must be passed into "usageData"
   */
  function allocate(address usageAddress, uint256 amount, bytes calldata usageData) external nonReentrant {
    _allocate(msg.sender, usageAddress, amount);

    // allocates xFLASH to usageContract
    IXFlashTokenUsage(usageAddress).allocate(msg.sender, amount, usageData);
  }

  /**
   * @dev Allocates "amount" of available xFLASH from "userAddress" to caller (ie usage contract)
   *
   * Caller must have an allocation approval for the required xFlash xFLASH from "userAddress"
   */
  function allocateFromUsage(address userAddress, uint256 amount) external override nonReentrant {
    _allocate(userAddress, msg.sender, amount);
  }

  /**
   * @dev Deallocates caller's "amount" of available xFLASH from "usageAddress" contract
   *
   * args specific to usage contract must be passed into "usageData"
   */
  function deallocate(address usageAddress, uint256 amount, bytes calldata usageData) external nonReentrant {
    _deallocate(msg.sender, usageAddress, amount);

    // deallocate xFLASH into usageContract
    IXFlashTokenUsage(usageAddress).deallocate(msg.sender, amount, usageData);
  }

  /**
   * @dev Deallocates "amount" of allocated xFLASH belonging to "userAddress" from caller (ie usage contract)
   *
   * Caller can only deallocate xFLASH from itself
   */
  function deallocateFromUsage(address userAddress, uint256 amount) external override nonReentrant {
    _deallocate(userAddress, msg.sender, amount);
  }

  /********************************************************/
  /****************** INTERNAL FUNCTIONS ******************/
  /********************************************************/

  /**
   * @dev Convert caller's "amount" of FLASH into xFLASH to "to"
   */
  function _convert(uint256 amount, address to) internal {
    require(amount != 0, "convert: amount cannot be null");

    // mint new xFLASH
    _mint(to, amount);

    emit Convert(msg.sender, to, amount);
    flashToken.safeTransferFrom(msg.sender, address(this), amount);
  }

  /**
   * @dev Finalizes the redeeming process for "userAddress" by transferring him "artAmount" and removing "xFlashAmount" from supply
   *
   * Any vesting check should be ran before calling this
   * FLASH excess is automatically burnt
   */
  function _finalizeRedeem(address userAddress, uint256 xFlashAmount, uint256 artAmount) internal {
    uint256 artExcess = xFlashAmount.sub(artAmount);

    // sends due FLASH tokens
    flashToken.safeTransfer(userAddress, artAmount);

    // burns FLASH excess if any
    flashToken.burn(artExcess);
    _burn(address(this), xFlashAmount);

    emit FinalizeRedeem(userAddress, xFlashAmount, artAmount);
  }

  /**
   * @dev Allocates "userAddress" user's "amount" of available xFLASH to "usageAddress" contract
   *
   */
  function _allocate(address userAddress, address usageAddress, uint256 amount) internal {
    require(amount > 0, "allocate: amount cannot be null");

    XFlashBalance storage balance = xFlashBalances[userAddress];

    // approval checks if allocation request amount has been approved by userAddress to be allocated to this usageAddress
    uint256 approvedXFlash = usageApprovals[userAddress][usageAddress];
    require(approvedXFlash >= amount, "allocate: non authorized amount");

    // remove allocated amount from usage's approved amount
    usageApprovals[userAddress][usageAddress] = approvedXFlash.sub(amount);

    // update usage's allocatedAmount for userAddress
    usageAllocations[userAddress][usageAddress] = usageAllocations[userAddress][usageAddress].add(amount);

    // adjust user's xFLASH balances
    balance.allocatedAmount = balance.allocatedAmount.add(amount);
    _transfer(userAddress, address(this), amount);

    emit Allocate(userAddress, usageAddress, amount);
  }

  /**
   * @dev Deallocates "amount" of available xFLASH to "usageAddress" contract
   *
   * args specific to usage contract must be passed into "usageData"
   */
  function _deallocate(address userAddress, address usageAddress, uint256 amount) internal {
    require(amount > 0, "deallocate: amount cannot be null");

    // check if there is enough allocated xFLASH to this usage to deallocate
    uint256 allocatedAmount = usageAllocations[userAddress][usageAddress];
    require(allocatedAmount >= amount, "deallocate: non authorized amount");

    // remove deallocated amount from usage's allocation
    usageAllocations[userAddress][usageAddress] = allocatedAmount.sub(amount);

    uint256 deallocationFeeAmount = amount.mul(usagesDeallocationFee[usageAddress]).div(10000);

    // adjust user's xFLASH balances
    XFlashBalance storage balance = xFlashBalances[userAddress];
    balance.allocatedAmount = balance.allocatedAmount.sub(amount);
    _transfer(address(this), userAddress, amount.sub(deallocationFeeAmount));
    // burn corresponding FLASH and XFLASH
    flashToken.burn(deallocationFeeAmount);
    _burn(address(this), deallocationFeeAmount);

    emit Deallocate(userAddress, usageAddress, amount, deallocationFeeAmount);
  }

  function _deleteRedeemEntry(uint256 index) internal {
    userRedeems[msg.sender][index] = userRedeems[msg.sender][userRedeems[msg.sender].length - 1];
    userRedeems[msg.sender].pop();
  }

  /**
   * @dev Hook override to forbid transfers except from whitelisted addresses and minting
   */
  function _beforeTokenTransfer(address from, address to, uint256 /*amount*/) internal view override {
    require(from == address(0) || _transferWhitelist.contains(from) || _transferWhitelist.contains(to), "transfer: not allowed");
  }

  /**
   * @dev Utility function to get the current block timestamp
   */
  function _currentBlockTimestamp() internal view virtual returns (uint256) {
    /* solhint-disable not-rely-on-time */
    return block.timestamp;
  }

}