// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./MerlinPool.sol";
import "./interfaces/IMerlinPoolFactory.sol";
import "./interfaces/tokens/IArtToken.sol";
import "./interfaces/tokens/IXArtToken.sol";


contract MerlinPoolFactory is Ownable, IMerlinPoolFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  IArtToken public artToken; // ARTToken contract's address
  IXArtToken public xArtToken; // xARTToken contract's address

  EnumerableSet.AddressSet internal _merlinPools; // all merlin pools
  EnumerableSet.AddressSet private _publishedMerlinPools; // all published merlin pools
  mapping(address => EnumerableSet.AddressSet) private _nftPoolPublishedMerlinPools; // published merlin pools per NFTPool
  mapping(address => EnumerableSet.AddressSet) internal _ownerMerlinPools; // merlin pools per owner

  uint256 public constant MAX_DEFAULT_FEE = 100; // (1%) max authorized default fee
  uint256 public defaultFee; // default fee for merlin pools (*1e2)
  address public override feeAddress; // to receive fees when defaultFee is set
  EnumerableSet.AddressSet internal _exemptedAddresses; // owners or merlin addresses exempted from default fee

  address public override emergencyRecoveryAddress; // to recover rewards from emergency closed merlin pools


  constructor(IArtToken artToken_, IXArtToken xArtToken_, address emergencyRecoveryAddress_, address feeAddress_){
    require(emergencyRecoveryAddress_ != address(0) && feeAddress_ != address(0), "invalid");

    artToken = artToken_;
    xArtToken = xArtToken_;
    emergencyRecoveryAddress = emergencyRecoveryAddress_;
    feeAddress = feeAddress_;
  }


  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event CreateMerlinPool(address merlinAddress);
  event PublishMerlinPool(address merlinAddress);
  event SetDefaultFee(uint256 fee);
  event SetFeeAddress(address feeAddress);
  event SetEmergencyRecoveryAddress(address emergencyRecoveryAddress);
  event SetExemptedAddress(address exemptedAddress, bool isExempted);
  event SetMerlinPoolOwner(address previousOwner, address newOwner);


  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  modifier merlinPoolExists(address merlinPoolAddress) {
    require(_merlinPools.contains(merlinPoolAddress), "unknown merlinPool");
    _;
  }


  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /**
   * @dev Returns the number of merlinPools
   */
  function merlinPoolsLength() external view returns (uint256) {
    return _merlinPools.length();
  }

  /**
   * @dev Returns a merlinPool from its "index"
   */
  function getMerlinPool(uint256 index) external view returns (address) {
    return _merlinPools.at(index);
  }

  /**
   * @dev Returns the number of published merlinPools
   */
  function publishedMerlinPoolsLength() external view returns (uint256) {
    return _publishedMerlinPools.length();
  }

  /**
   * @dev Returns a published merlinPool from its "index"
   */
  function getPublishedMerlinPool(uint256 index) external view returns (address) {
    return _publishedMerlinPools.at(index);
  }

  /**
   * @dev Returns the number of published merlinPools linked to "nftPoolAddress" NFTPool
   */
  function nftPoolPublishedMerlinPoolsLength(address nftPoolAddress) external view returns (uint256) {
    return _nftPoolPublishedMerlinPools[nftPoolAddress].length();
  }

  /**
   * @dev Returns a published merlinPool linked to "nftPoolAddress" from its "index"
   */
  function getNftPoolPublishedMerlinPool(address nftPoolAddress, uint256 index) external view returns (address) {
    return _nftPoolPublishedMerlinPools[nftPoolAddress].at(index);
  }

  /**
   * @dev Returns the number of merlinPools owned by "userAddress"
   */
  function ownerMerlinPoolsLength(address userAddress) external view returns (uint256) {
    return _ownerMerlinPools[userAddress].length();
  }

  /**
   * @dev Returns a merlinPool owned by "userAddress" from its "index"
   */
  function getOwnerMerlinPool(address userAddress, uint256 index) external view returns (address) {
    return _ownerMerlinPools[userAddress].at(index);
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
   * @dev Returns the fee for "merlinPoolAddress" address
   */
  function getMerlinPoolFee(address merlinPoolAddress, address ownerAddress) external view override returns (uint256) {
    if(_exemptedAddresses.contains(merlinPoolAddress) || _exemptedAddresses.contains(ownerAddress)) {
      return 0;
    }
    return defaultFee;
  }


  /*****************************************************************/
  /******************  EXTERNAL PUBLIC FUNCTIONS  ******************/
  /*****************************************************************/

  /**
   * @dev Deploys a new Merlin Pool
   */
  function createMerlinPool(
    address nftPoolAddress, IERC20 rewardsToken1, IERC20 rewardsToken2, MerlinPool.Settings calldata settings
  ) external virtual returns (address merlinPool) {

    // Initialize new merlin pool
    merlinPool = address(
      new MerlinPool(
        artToken, xArtToken, msg.sender, INFTPool(nftPoolAddress),
          rewardsToken1, rewardsToken2, settings
      )
    );

    // Add new merlin
    _merlinPools.add(merlinPool);
    _ownerMerlinPools[msg.sender].add(merlinPool);

    emit CreateMerlinPool(merlinPool);
  }

  /**
   * @dev Publish a Merlin Pool
   *
   * Must only be called by the Merlin Pool contract
   */
  function publishMerlinPool(address nftAddress) external override merlinPoolExists(msg.sender) {
    _publishedMerlinPools.add(msg.sender);

    _nftPoolPublishedMerlinPools[nftAddress].add(msg.sender);

    emit PublishMerlinPool(msg.sender);
  }

  /**
   * @dev Transfers a Merlin Pool's ownership
   *
   * Must only be called by the MerlinPool contract
   */
  function setMerlinPoolOwner(address previousOwner, address newOwner) external override merlinPoolExists(msg.sender) {
    require(_ownerMerlinPools[previousOwner].remove(msg.sender), "invalid owner");
    _ownerMerlinPools[newOwner].add(msg.sender);

    emit SetMerlinPoolOwner(previousOwner, newOwner);
  }

  /**
   * @dev Set merlinPools default fee (when adding rewards)
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