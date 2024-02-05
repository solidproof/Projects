// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./ThunderPool.sol";
import "./interfaces/IThunderPoolFactory.sol";
import "./interfaces/tokens/IFlashToken.sol";
import "./interfaces/tokens/IXFlashToken.sol";


contract ThunderPoolFactory is Ownable, IThunderPoolFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  IFlashToken public flashToken; // FLASHToken contract's address
  IXFlashToken public xFlashToken; // xFLASHToken contract's address

  EnumerableSet.AddressSet internal _thunderPools; // all thunder pools
  EnumerableSet.AddressSet private _publishedThunderPools; // all published thunder pools
  mapping(address => EnumerableSet.AddressSet) private _nftPoolPublishedThunderPools; // published thunder pools per NFTPool
  mapping(address => EnumerableSet.AddressSet) internal _ownerThunderPools; // thunder pools per owner

  uint256 public constant MAX_DEFAULT_FEE = 100; // (1%) max authorized default fee
  uint256 public defaultFee; // default fee for thunder pools (*1e2)
  address public override feeAddress; // to receive fees when defaultFee is set
  EnumerableSet.AddressSet internal _exemptedAddresses; // owners or thunder addresses exempted from default fee

  address public override emergencyRecoveryAddress; // to recover rewards from emergency closed thunder pools


  constructor(IFlashToken flashToken_, IXFlashToken xFlashToken_, address emergencyRecoveryAddress_, address feeAddress_){
    require(emergencyRecoveryAddress_ != address(0) && feeAddress_ != address(0), "invalid");

    flashToken = flashToken_;
    xFlashToken = xFlashToken_;
    emergencyRecoveryAddress = emergencyRecoveryAddress_;
    feeAddress = feeAddress_;
  }


  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event CreateThunderPool(address thunderAddress);
  event PublishThunderPool(address thunderAddress);
  event SetDefaultFee(uint256 fee);
  event SetFeeAddress(address feeAddress);
  event SetEmergencyRecoveryAddress(address emergencyRecoveryAddress);
  event SetExemptedAddress(address exemptedAddress, bool isExempted);
  event SetThunderPoolOwner(address previousOwner, address newOwner);


  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  modifier thunderPoolExists(address thunderPoolAddress) {
    require(_thunderPools.contains(thunderPoolAddress), "unknown thunderPool");
    _;
  }


  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /**
   * @dev Returns the number of thunderPools
   */
  function thunderPoolsLength() external view returns (uint256) {
    return _thunderPools.length();
  }

  /**
   * @dev Returns a thunderPool from its "index"
   */
  function getThunderPool(uint256 index) external view returns (address) {
    return _thunderPools.at(index);
  }

  /**
   * @dev Returns the number of published thunderPools
   */
  function publishedThunderPoolsLength() external view returns (uint256) {
    return _publishedThunderPools.length();
  }

  /**
   * @dev Returns a published thunderPool from its "index"
   */
  function getPublishedThunderPool(uint256 index) external view returns (address) {
    return _publishedThunderPools.at(index);
  }

  /**
   * @dev Returns the number of published thunderPools linked to "nftPoolAddress" NFTPool
   */
  function nftPoolPublishedThunderPoolsLength(address nftPoolAddress) external view returns (uint256) {
    return _nftPoolPublishedThunderPools[nftPoolAddress].length();
  }

  /**
   * @dev Returns a published thunderPool linked to "nftPoolAddress" from its "index"
   */
  function getNftPoolPublishedThunderPool(address nftPoolAddress, uint256 index) external view returns (address) {
    return _nftPoolPublishedThunderPools[nftPoolAddress].at(index);
  }

  /**
   * @dev Returns the number of thunderPools owned by "userAddress"
   */
  function ownerThunderPoolsLength(address userAddress) external view returns (uint256) {
    return _ownerThunderPools[userAddress].length();
  }

  /**
   * @dev Returns a thunderPool owned by "userAddress" from its "index"
   */
  function getOwnerThunderPool(address userAddress, uint256 index) external view returns (address) {
    return _ownerThunderPools[userAddress].at(index);
  }

  /**
   * @dev Returns the number of exemptedAddresses
   */
  function exemptedAddressesLength() external view returns (uint256) {
    return _exemptedAddresses.length();
  }

  /**
   * @dev Returns an exemptedAddress from its "index"
   */
  function getExemptedAddress(uint256 index) external view returns (address) {
    return _exemptedAddresses.at(index);
  }

  /**
   * @dev Returns if a given address is in exemptedAddresses
   */
  function isExemptedAddress(address checkedAddress) external view returns (bool) {
    return _exemptedAddresses.contains(checkedAddress);
  }

  /**
   * @dev Returns the fee for "thunderPoolAddress" address
   */
  function getThunderPoolFee(address thunderPoolAddress, address ownerAddress) external view override returns (uint256) {
    if(_exemptedAddresses.contains(thunderPoolAddress) || _exemptedAddresses.contains(ownerAddress)) {
      return 0;
    }
    return defaultFee;
  }


  /*****************************************************************/
  /******************  EXTERNAL PUBLIC FUNCTIONS  ******************/
  /*****************************************************************/

  /**
   * @dev Deploys a new Thunder Pool
   */
  function createThunderPool(
    address nftPoolAddress, IERC20 rewardsToken1, IERC20 rewardsToken2, ThunderPool.Settings calldata settings
  ) external virtual returns (address thunderPool) {

    // Initialize new thunder pool
    thunderPool = address(
      new ThunderPool(
        flashToken, xFlashToken, msg.sender, INFTPool(nftPoolAddress),
          rewardsToken1, rewardsToken2, settings
      )
    );

    // Add new thunder
    _thunderPools.add(thunderPool);
    _ownerThunderPools[msg.sender].add(thunderPool);

    emit CreateThunderPool(thunderPool);
  }

  /**
   * @dev Publish a Thunder Pool
   *
   * Must only be called by the Thunder Pool contract
   */
  function publishThunderPool(address nftAddress) external override thunderPoolExists(msg.sender) {
    _publishedThunderPools.add(msg.sender);

    _nftPoolPublishedThunderPools[nftAddress].add(msg.sender);

    emit PublishThunderPool(msg.sender);
  }

  /**
   * @dev Transfers a Thunder Pool's ownership
   *
   * Must only be called by the ThunderPool contract
   */
  function setThunderPoolOwner(address previousOwner, address newOwner) external override thunderPoolExists(msg.sender) {
    require(_ownerThunderPools[previousOwner].remove(msg.sender), "invalid owner");
    _ownerThunderPools[newOwner].add(msg.sender);

    emit SetThunderPoolOwner(previousOwner, newOwner);
  }

  /**
   * @dev Set thunderPools default fee (when adding rewards)
   *
   * Must only be called by the owner
   */
  function setDefaultFee(uint256 newFee) external onlyOwner {
    require(newFee <= MAX_DEFAULT_FEE, "invalid amount");

    defaultFee = newFee;
    emit SetDefaultFee(newFee);
  }

  /**
   * @dev Set fee address
   *
   * Must only be called by the owner
   */
  function setFeeAddress(address feeAddress_) external onlyOwner {
    require(feeAddress_ != address(0), "zero address");

    feeAddress = feeAddress_;
    emit SetFeeAddress(feeAddress_);
  }

  /**
   * @dev Add or remove exemptedAddresses
   *
   * Must only be called by the owner
   */
  function setExemptedAddress(address exemptedAddress, bool isExempted) external onlyOwner {
    require(exemptedAddress != address(0), "zero address");

    if(isExempted) _exemptedAddresses.add(exemptedAddress);
    else _exemptedAddresses.remove(exemptedAddress);

    emit SetExemptedAddress(exemptedAddress, isExempted);
  }

  /**
   * @dev Set emergencyRecoveryAddress
   *
   * Must only be called by the owner
   */
  function setEmergencyRecoveryAddress(address emergencyRecoveryAddress_) external onlyOwner {
    require(emergencyRecoveryAddress_ != address(0), "zero address");

    emergencyRecoveryAddress = emergencyRecoveryAddress_;
    emit SetEmergencyRecoveryAddress(emergencyRecoveryAddress_);
  }


  /********************************************************/
  /****************** INTERNAL FUNCTIONS ******************/
  /********************************************************/

  /**
   * @dev Utility function to get the current block timestamp
   */
  function _currentBlockTimestamp() internal view virtual returns (uint256) {
    /* solhint-disable not-rely-on-time */
    return block.timestamp;
  }
}