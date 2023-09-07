// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./NitroPool.sol";
import "../interfaces/INitroPoolFactory.sol";
import "../interfaces/tokens/IEsperToken.sol";
import "../interfaces/tokens/IXEsperToken.sol";

contract NitroPoolFactory is Ownable, INitroPoolFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  IEsperToken public esperToken; // ESPERToken contract's address
  IXEsperToken public xEsperToken; // xESPERToken contract's address

  EnumerableSet.AddressSet internal _nitroPools; // all nitro pools
  EnumerableSet.AddressSet private _publishedNitroPools; // all published nitro pools
  mapping(address => EnumerableSet.AddressSet) private _nftPoolPublishedNitroPools; // published nitro pools per NFTPool
  mapping(address => EnumerableSet.AddressSet) internal _ownerNitroPools; // nitro pools per owner

  uint256 public constant MAX_DEFAULT_FEE = 100; // (1%) max authorized default fee
  uint256 public defaultFee; // default fee for nitro pools (*1e2)
  address public override feeAddress; // to receive fees when defaultFee is set
  EnumerableSet.AddressSet internal _exemptedAddresses; // owners or nitro addresses exempted from default fee

  address public override emergencyRecoveryAddress; // to recover rewards from emergency closed nitro pools


  constructor(address esperToken_, address xEsperToken_, address emergencyRecoveryAddress_, address feeAddress_){
    require(emergencyRecoveryAddress_ != address(0) && feeAddress_ != address(0), "invalid");

    esperToken = IEsperToken(esperToken_);
    xEsperToken = IXEsperToken(xEsperToken_);
    emergencyRecoveryAddress = emergencyRecoveryAddress_;
    feeAddress = feeAddress_;
  }


  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event CreateNitroPool(address nitroAddress, address nftPool, NitroPool.Settings settings, address rewardsToken1, address rewardsToken2);
  event PublishNitroPool(address nitroAddress);
  event SetDefaultFee(uint256 fee);
  event SetFeeAddress(address feeAddress);
  event SetEmergencyRecoveryAddress(address emergencyRecoveryAddress);
  event SetExemptedAddress(address exemptedAddress, bool isExempted);
  event SetNitroPoolOwner(address previousOwner, address newOwner);


  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  modifier nitroPoolExists(address nitroPoolAddress) {
    require(_nitroPools.contains(nitroPoolAddress), "unknown nitroPool");
    _;
  }


  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /**
   * @dev Returns the number of nitroPools
   */
  function nitroPoolsLength() external view returns (uint256) {
    return _nitroPools.length();
  }

  /**
   * @dev Returns a nitroPool from its "index"
   */
  function getNitroPool(uint256 index) external view returns (address) {
    return _nitroPools.at(index);
  }

  /**
   * @dev Returns the number of published nitroPools
   */
  function publishedNitroPoolsLength() external view returns (uint256) {
    return _publishedNitroPools.length();
  }

  /**
   * @dev Returns a published nitroPool from its "index"
   */
  function getPublishedNitroPool(uint256 index) external view returns (address) {
    return _publishedNitroPools.at(index);
  }

  /**
   * @dev Returns the number of published nitroPools linked to "nftPoolAddress" NFTPool
   */
  function nftPoolPublishedNitroPoolsLength(address nftPoolAddress) external view returns (uint256) {
    return _nftPoolPublishedNitroPools[nftPoolAddress].length();
  }

  /**
   * @dev Returns a published nitroPool linked to "nftPoolAddress" from its "index"
   */
  function getNftPoolPublishedNitroPool(address nftPoolAddress, uint256 index) external view returns (address) {
    return _nftPoolPublishedNitroPools[nftPoolAddress].at(index);
  }

  /**
   * @dev Returns the number of nitroPools owned by "userAddress"
   */
  function ownerNitroPoolsLength(address userAddress) external view returns (uint256) {
    return _ownerNitroPools[userAddress].length();
  }

  /**
   * @dev Returns a nitroPool owned by "userAddress" from its "index"
   */
  function getOwnerNitroPool(address userAddress, uint256 index) external view returns (address) {
    return _ownerNitroPools[userAddress].at(index);
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
   * @dev Returns the fee for "nitroPoolAddress" address
   */
  function getNitroPoolFee(address nitroPoolAddress, address ownerAddress) external view override returns (uint256) {
    if(_exemptedAddresses.contains(nitroPoolAddress) || _exemptedAddresses.contains(ownerAddress)) {
      return 0;
    }
    return defaultFee;
  }


  /*****************************************************************/
  /******************  EXTERNAL PUBLIC FUNCTIONS  ******************/
  /*****************************************************************/

  /**
   * @dev Deploys a new Nitro Pool
   */
  function createNitroPool(
    address nftPoolAddress, address rewardsToken1, address rewardsToken2, NitroPool.Settings calldata settings
  ) external virtual returns (address nitroPool) {

    // Initialize new nitro pool
    nitroPool = address(
      new NitroPool(
        address(esperToken), address(xEsperToken), msg.sender, nftPoolAddress,
          rewardsToken1, rewardsToken2, settings
      )
    );

    // Add new nitro
    _nitroPools.add(nitroPool);
    _ownerNitroPools[msg.sender].add(nitroPool);

    emit CreateNitroPool(nitroPool, nftPoolAddress, settings, rewardsToken1, rewardsToken2);
  }

  /**
   * @dev Publish a Nitro Pool
   *
   * Must only be called by the Nitro Pool contract
   */
  function publishNitroPool(address nftAddress) external override nitroPoolExists(msg.sender) {
    _publishedNitroPools.add(msg.sender);

    _nftPoolPublishedNitroPools[nftAddress].add(msg.sender);

    emit PublishNitroPool(msg.sender);
  }

  /**
   * @dev Transfers a Nitro Pool's ownership
   *
   * Must only be called by the NitroPool contract
   */
  function setNitroPoolOwner(address previousOwner, address newOwner) external override nitroPoolExists(msg.sender) {
    require(_ownerNitroPools[previousOwner].remove(msg.sender), "invalid owner");
    _ownerNitroPools[newOwner].add(msg.sender);

    emit SetNitroPoolOwner(previousOwner, newOwner);
  }

  /**
   * @dev Set nitroPools default fee (when adding rewards)
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
