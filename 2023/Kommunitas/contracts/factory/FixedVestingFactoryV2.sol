// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';

import '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';
import '@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol';

import '../util/AdminProxyManager.sol';
import '../interface/IFixedVestingFactoryV2.sol';
import '../interface/IFixedVestingV2.sol';
import '../vesting/FixedVestingV2.sol';

contract FixedVestingFactoryV2 is
  Initializable,
  UUPSUpgradeable,
  OwnableUpgradeable,
  PausableUpgradeable,
  AdminProxyManager,
  IFixedVestingFactoryV2
{
  address public override beacon;
  address[] public override allVestings; // all vestings created

  function init(address _beacon) external proxied initializer {
    __UUPSUpgradeable_init();
    __Pausable_init();
    __Ownable_init();
    __AdminProxyManager_init(_msgSender());

    beacon = _beacon;
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override proxied {}

  /**
   * @dev Get total number of vestings created
   */
  function allVestingsLength() public view virtual override returns (uint256) {
    return allVestings.length;
  }

  /**
   * @dev Get owner
   */
  function owner() public view virtual override(IFixedVestingFactoryV2, OwnableUpgradeable) returns (address) {
    return super.owner();
  }

  /**
   * @dev Create new vesting to distribute token
   * @param _token Token project address
   * @param _stable Stable token address
   * @param _tokenPrice Token price (in stable decimal)
   * @param _lastRefundAt Last datetime to refund (epoch)
   * @param _projectOwner Project owner address
   * @param _datetime Vesting datetime in epoch
   * @param _ratio_d2 Vesting ratio in percent (decimal 2)
   */
  function createVesting(
    address _token,
    address _stable,
    address _projectOwner,
    uint256 _tokenPrice,
    uint256 _lastRefundAt,
    uint256[] calldata _datetime,
    uint256[] calldata _ratio_d2
  ) public virtual override onlyOwner whenNotPaused returns (address vesting) {
    bytes memory data = abi.encodeWithSelector(
      IFixedVestingV2.init.selector,
      _token,
      _stable,
      _projectOwner,
      _tokenPrice,
      _lastRefundAt,
      _datetime,
      _ratio_d2
    );

    vesting = address(new BeaconProxy(beacon, data));

    allVestings.push(vesting);

    emit VestingCreated(vesting, allVestings.length - 1);
  }

  /**
   * @dev Pause factory activity
   */
  function togglePause() external virtual onlyOwner {
    if (paused()) {
      _unpause();
    } else {
      _pause();
    }
  }
}
