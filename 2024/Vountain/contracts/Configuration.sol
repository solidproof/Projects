// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TypeLibrary.sol";
import "./ConnectContract.sol";

/// @title Vountain – Configuration
/// @notice Base Configuration for all contracts

contract Configuration is Ownable {
  mapping(uint256 => mapping(RCLib.Tasks => RCLib.RequestConfig)) config; //version -> config
  mapping(uint256 => uint256) public violinToVersion;
  mapping(uint256 => bool) public versionLive;
  mapping(uint256 => bool) public configFrozen;

  IConnectContract connectContract;

  constructor(address connectContract_) {
    connectContract = IConnectContract(connectContract_);
    /**
     * CREATE OWNER_ROLE
     */
    config[0][RCLib.Tasks.CREATE_OWNER_ROLE].canInitiate = [RCLib.Role.CUSTODIAL];
    config[0][RCLib.Tasks.CREATE_OWNER_ROLE].canApprove = [RCLib.Role.OWNER_ROLE];
    config[0][RCLib.Tasks.CREATE_OWNER_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.CREATE_OWNER_ROLE].affectedRole = RCLib.Role.OWNER_ROLE;
    config[0][RCLib.Tasks.CREATE_OWNER_ROLE].validity = 72;

    /**
     * CREATE INSTRUMENT_MANAGER_ROLE
     */

    config[0][RCLib.Tasks.CREATE_INSTRUMENT_MANAGER_ROLE].canInitiate = [
      RCLib.Role.OWNER_ROLE
    ];
    config[0][RCLib.Tasks.CREATE_INSTRUMENT_MANAGER_ROLE].canApprove = [
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CREATE_INSTRUMENT_MANAGER_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.CREATE_INSTRUMENT_MANAGER_ROLE].affectedRole = RCLib
      .Role
      .INSTRUMENT_MANAGER_ROLE;
    config[0][RCLib.Tasks.CREATE_INSTRUMENT_MANAGER_ROLE].validity = 72;

    /**
     * CREATE MUSICIAN_ROLE
     */

    config[0][RCLib.Tasks.CREATE_MUSICIAN_ROLE].canInitiate = [
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CREATE_MUSICIAN_ROLE].canApprove = [RCLib.Role.MUSICIAN_ROLE];
    config[0][RCLib.Tasks.CREATE_MUSICIAN_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.CREATE_MUSICIAN_ROLE].affectedRole = RCLib.Role.MUSICIAN_ROLE;
    config[0][RCLib.Tasks.CREATE_MUSICIAN_ROLE].validity = 72;

    /**
     * CREATE VIOLIN MAKER
     */

    config[0][RCLib.Tasks.CREATE_VIOLIN_MAKER_ROLE].canInitiate = [
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CREATE_VIOLIN_MAKER_ROLE].canApprove = [
      RCLib.Role.VIOLIN_MAKER_ROLE
    ];
    config[0][RCLib.Tasks.CREATE_VIOLIN_MAKER_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.CREATE_VIOLIN_MAKER_ROLE].affectedRole = RCLib
      .Role
      .VIOLIN_MAKER_ROLE;
    config[0][RCLib.Tasks.CREATE_VIOLIN_MAKER_ROLE].validity = 72;

    /**
     * CREATE EXHIBITOR_ROLE
     */

    config[0][RCLib.Tasks.CREATE_EXHIBITOR_ROLE].canInitiate = [
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CREATE_EXHIBITOR_ROLE].canApprove = [RCLib.Role.EXHIBITOR_ROLE];
    config[0][RCLib.Tasks.CREATE_EXHIBITOR_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.CREATE_EXHIBITOR_ROLE].affectedRole = RCLib.Role.EXHIBITOR_ROLE;
    config[0][RCLib.Tasks.CREATE_EXHIBITOR_ROLE].validity = 72;

    /**
     * CHANGE DURATION MUSICIAN_ROLE
     */

    config[0][RCLib.Tasks.CHANGE_DURATION_MUSICIAN_ROLE].canInitiate = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.MUSICIAN_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CHANGE_DURATION_MUSICIAN_ROLE].canApprove = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.MUSICIAN_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CHANGE_DURATION_MUSICIAN_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.CHANGE_DURATION_MUSICIAN_ROLE].affectedRole = RCLib
      .Role
      .MUSICIAN_ROLE;
    config[0][RCLib.Tasks.CHANGE_DURATION_MUSICIAN_ROLE].validity = 72;

    /**
     * CHANGE DURATION INSTRUMENT_MANAGER_ROLE
     */

    config[0][RCLib.Tasks.CHANGE_DURATION_INSTRUMENT_MANAGER_ROLE].canInitiate = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.OWNER_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CHANGE_DURATION_INSTRUMENT_MANAGER_ROLE].canApprove = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.OWNER_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CHANGE_DURATION_INSTRUMENT_MANAGER_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.CHANGE_DURATION_INSTRUMENT_MANAGER_ROLE].affectedRole = RCLib
      .Role
      .INSTRUMENT_MANAGER_ROLE;
    config[0][RCLib.Tasks.CHANGE_DURATION_INSTRUMENT_MANAGER_ROLE].validity = 72;

    /**
     * CHANGE DURATION VIOLIN MAKER
     */

    config[0][RCLib.Tasks.CHANGE_DURATION_VIOLIN_MAKER_ROLE].canInitiate = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.VIOLIN_MAKER_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CHANGE_DURATION_VIOLIN_MAKER_ROLE].canApprove = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.VIOLIN_MAKER_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CHANGE_DURATION_VIOLIN_MAKER_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.CHANGE_DURATION_VIOLIN_MAKER_ROLE].affectedRole = RCLib
      .Role
      .VIOLIN_MAKER_ROLE;
    config[0][RCLib.Tasks.CHANGE_DURATION_VIOLIN_MAKER_ROLE].validity = 72;

    /**
     * CHANGE DURATION EXHIBITOR
     */

    config[0][RCLib.Tasks.CHANGE_DURATION_EXHIBITOR_ROLE].canInitiate = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.EXHIBITOR_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CHANGE_DURATION_EXHIBITOR_ROLE].canApprove = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.EXHIBITOR_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.CHANGE_DURATION_EXHIBITOR_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.CHANGE_DURATION_EXHIBITOR_ROLE].affectedRole = RCLib
      .Role
      .EXHIBITOR_ROLE;
    config[0][RCLib.Tasks.CHANGE_DURATION_EXHIBITOR_ROLE].validity = 72;

    /**
     * DELIST INSTRUMENT_MANAGER_ROLE
     */

    config[0][RCLib.Tasks.DELIST_INSTRUMENT_MANAGER_ROLE].canInitiate = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.OWNER_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.DELIST_INSTRUMENT_MANAGER_ROLE].canApprove = [
      RCLib.Role.INSTRUMENT_MANAGER_ROLE,
      RCLib.Role.VOUNTAIN,
      RCLib.Role.OWNER_ROLE
    ];
    config[0][RCLib.Tasks.DELIST_INSTRUMENT_MANAGER_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.DELIST_INSTRUMENT_MANAGER_ROLE].affectedRole = RCLib
      .Role
      .INSTRUMENT_MANAGER_ROLE;
    config[0][RCLib.Tasks.DELIST_INSTRUMENT_MANAGER_ROLE].validity = 72;

    /**
     * DELIST MUSICIAN_ROLE
     */

    config[0][RCLib.Tasks.DELIST_MUSICIAN_ROLE].canInitiate = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE,
      RCLib.Role.MUSICIAN_ROLE
    ];
    config[0][RCLib.Tasks.DELIST_MUSICIAN_ROLE].canApprove = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE,
      RCLib.Role.MUSICIAN_ROLE
    ];
    config[0][RCLib.Tasks.DELIST_MUSICIAN_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.DELIST_MUSICIAN_ROLE].affectedRole = RCLib.Role.MUSICIAN_ROLE;
    config[0][RCLib.Tasks.DELIST_MUSICIAN_ROLE].validity = 72;

    /**
     * DELIST VIOLIN MAKER
     */

    config[0][RCLib.Tasks.DELIST_VIOLIN_MAKER_ROLE].canInitiate = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.VIOLIN_MAKER_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.DELIST_VIOLIN_MAKER_ROLE].canApprove = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE,
      RCLib.Role.VIOLIN_MAKER_ROLE
    ];
    config[0][RCLib.Tasks.DELIST_VIOLIN_MAKER_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.DELIST_VIOLIN_MAKER_ROLE].affectedRole = RCLib
      .Role
      .VIOLIN_MAKER_ROLE;
    config[0][RCLib.Tasks.DELIST_VIOLIN_MAKER_ROLE].validity = 72;

    /**
     * DELIST EXHIBITOR_ROLE
     */

    config[0][RCLib.Tasks.DELIST_EXHIBITOR_ROLE].canInitiate = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE,
      RCLib.Role.EXHIBITOR_ROLE
    ];
    config[0][RCLib.Tasks.DELIST_EXHIBITOR_ROLE].canApprove = [
      RCLib.Role.VOUNTAIN,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE,
      RCLib.Role.EXHIBITOR_ROLE
    ];
    config[0][RCLib.Tasks.DELIST_EXHIBITOR_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.DELIST_EXHIBITOR_ROLE].affectedRole = RCLib.Role.EXHIBITOR_ROLE;
    config[0][RCLib.Tasks.DELIST_EXHIBITOR_ROLE].validity = 72;

    /**
     * DELEGATE INSTRUMENT_MANAGER_ROLE
     */

    config[0][RCLib.Tasks.DELEGATE_INSTRUMENT_MANAGER_ROLE].canInitiate = [
      RCLib.Role.OWNER_ROLE,
      RCLib.Role.MUSICIAN_ROLE,
      RCLib.Role.EXHIBITOR_ROLE,
      RCLib.Role.VIOLIN_MAKER_ROLE
    ];
    config[0][RCLib.Tasks.DELEGATE_INSTRUMENT_MANAGER_ROLE].canApprove = [
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.DELEGATE_INSTRUMENT_MANAGER_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.DELEGATE_INSTRUMENT_MANAGER_ROLE].affectedRole = RCLib
      .Role
      .INSTRUMENT_MANAGER_ROLE;
    config[0][RCLib.Tasks.DELEGATE_INSTRUMENT_MANAGER_ROLE].validity = 72;

    /**
     * DELEGATE MUSICIAN_ROLE
     */

    config[0][RCLib.Tasks.DELEGATE_MUSICIAN_ROLE].canInitiate = [
      RCLib.Role.OWNER_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE,
      RCLib.Role.EXHIBITOR_ROLE,
      RCLib.Role.VIOLIN_MAKER_ROLE
    ];
    config[0][RCLib.Tasks.DELEGATE_MUSICIAN_ROLE].canApprove = [RCLib.Role.MUSICIAN_ROLE];
    config[0][RCLib.Tasks.DELEGATE_MUSICIAN_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.DELEGATE_MUSICIAN_ROLE].affectedRole = RCLib.Role.MUSICIAN_ROLE;
    config[0][RCLib.Tasks.DELEGATE_MUSICIAN_ROLE].validity = 72;

    /**
     * DELEGATE VIOLIN MAKER
     */

    config[0][RCLib.Tasks.DELEGATE_VIOLIN_MAKER_ROLE].canInitiate = [
      RCLib.Role.OWNER_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE,
      RCLib.Role.MUSICIAN_ROLE,
      RCLib.Role.EXHIBITOR_ROLE
    ];
    config[0][RCLib.Tasks.DELEGATE_VIOLIN_MAKER_ROLE].canApprove = [
      RCLib.Role.VIOLIN_MAKER_ROLE
    ];
    config[0][RCLib.Tasks.DELEGATE_VIOLIN_MAKER_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.DELEGATE_VIOLIN_MAKER_ROLE].affectedRole = RCLib
      .Role
      .VIOLIN_MAKER_ROLE;
    config[0][RCLib.Tasks.DELEGATE_VIOLIN_MAKER_ROLE].validity = 72;

    /**
     * DELEGATE EXHIBITOR_ROLE
     */

    config[0][RCLib.Tasks.DELEGATE_EXHIBITOR_ROLE].canInitiate = [
      RCLib.Role.OWNER_ROLE,
      RCLib.Role.INSTRUMENT_MANAGER_ROLE,
      RCLib.Role.MUSICIAN_ROLE,
      RCLib.Role.VIOLIN_MAKER_ROLE
    ];
    config[0][RCLib.Tasks.DELEGATE_EXHIBITOR_ROLE].canApprove = [
      RCLib.Role.EXHIBITOR_ROLE
    ];
    config[0][RCLib.Tasks.DELEGATE_EXHIBITOR_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.DELEGATE_EXHIBITOR_ROLE].affectedRole = RCLib
      .Role
      .EXHIBITOR_ROLE;
    config[0][RCLib.Tasks.DELEGATE_EXHIBITOR_ROLE].validity = 72;

    /**
     * DELEGATE OWNER_ROLE
     */

    config[0][RCLib.Tasks.DELEGATE_OWNER_ROLE].canInitiate = [
      RCLib.Role.INSTRUMENT_MANAGER_ROLE,
      RCLib.Role.MUSICIAN_ROLE,
      RCLib.Role.VIOLIN_MAKER_ROLE,
      RCLib.Role.EXHIBITOR_ROLE
    ];
    config[0][RCLib.Tasks.DELEGATE_OWNER_ROLE].canApprove = [RCLib.Role.OWNER_ROLE];
    config[0][RCLib.Tasks.DELEGATE_OWNER_ROLE].approvalsNeeded = 1;
    config[0][RCLib.Tasks.DELEGATE_OWNER_ROLE].affectedRole = RCLib.Role.OWNER_ROLE;
    config[0][RCLib.Tasks.DELEGATE_OWNER_ROLE].validity = 72;

    /**
     * ADD CONCERT
     */

    config[0][RCLib.Tasks.ADD_CONCERT].canInitiate = [RCLib.Role.MUSICIAN_ROLE];
    config[0][RCLib.Tasks.ADD_CONCERT].canApprove = [RCLib.Role.INSTRUMENT_MANAGER_ROLE];
    config[0][RCLib.Tasks.ADD_CONCERT].approvalsNeeded = 1;
    config[0][RCLib.Tasks.ADD_CONCERT].affectedRole = RCLib.Role.MUSICIAN_ROLE;
    config[0][RCLib.Tasks.ADD_CONCERT].validity = 72;

    /**
     * ADD EXHIBITION
     */

    config[0][RCLib.Tasks.ADD_EXHIBITION].canInitiate = [RCLib.Role.EXHIBITOR_ROLE];
    config[0][RCLib.Tasks.ADD_EXHIBITION].canApprove = [
      RCLib.Role.INSTRUMENT_MANAGER_ROLE
    ];
    config[0][RCLib.Tasks.ADD_EXHIBITION].approvalsNeeded = 1;
    config[0][RCLib.Tasks.ADD_EXHIBITION].affectedRole = RCLib.Role.EXHIBITOR_ROLE;
    config[0][RCLib.Tasks.ADD_EXHIBITION].validity = 72;

    /**
     * ADD REPAIR
     */

    config[0][RCLib.Tasks.ADD_REPAIR].canInitiate = [RCLib.Role.VIOLIN_MAKER_ROLE];
    config[0][RCLib.Tasks.ADD_REPAIR].canApprove = [RCLib.Role.INSTRUMENT_MANAGER_ROLE];
    config[0][RCLib.Tasks.ADD_REPAIR].approvalsNeeded = 1;
    config[0][RCLib.Tasks.ADD_REPAIR].affectedRole = RCLib.Role.VIOLIN_MAKER_ROLE;
    config[0][RCLib.Tasks.ADD_REPAIR].validity = 72;

    /**
     * ADD DOCUMENT
     */

    config[0][RCLib.Tasks.ADD_DOCUMENT].canInitiate = [RCLib.Role.VOUNTAIN];
    config[0][RCLib.Tasks.ADD_DOCUMENT].canApprove = [RCLib.Role.OWNER_ROLE];
    config[0][RCLib.Tasks.ADD_DOCUMENT].approvalsNeeded = 1;
    config[0][RCLib.Tasks.ADD_DOCUMENT].affectedRole = RCLib.Role.OWNER_ROLE;
    config[0][RCLib.Tasks.ADD_DOCUMENT].validity = 72;

    /**
     * CHANGE METADATA
     */

    config[0][RCLib.Tasks.CHANGE_METADATA_VIOLIN].canInitiate = [RCLib.Role.VOUNTAIN];
    config[0][RCLib.Tasks.CHANGE_METADATA_VIOLIN].canApprove = [RCLib.Role.OWNER_ROLE];
    config[0][RCLib.Tasks.CHANGE_METADATA_VIOLIN].approvalsNeeded = 1;
    config[0][RCLib.Tasks.CHANGE_METADATA_VIOLIN].affectedRole = RCLib
      .Role
      .INSTRUMENT_MANAGER_ROLE;
    config[0][RCLib.Tasks.CHANGE_METADATA_VIOLIN].validity = 72;

    config[0][RCLib.Tasks.CHANGE_METADATA_ACCESSCONTROL].canInitiate = [
      RCLib.Role.VOUNTAIN
    ];
    config[0][RCLib.Tasks.CHANGE_METADATA_ACCESSCONTROL].canApprove = [
      RCLib.Role.OWNER_ROLE
    ];
    config[0][RCLib.Tasks.CHANGE_METADATA_ACCESSCONTROL].approvalsNeeded = 1;
    config[0][RCLib.Tasks.CHANGE_METADATA_ACCESSCONTROL].affectedRole = RCLib
      .Role
      .OWNER_ROLE;
    config[0][RCLib.Tasks.CHANGE_METADATA_ACCESSCONTROL].validity = 72;

    /**
     * ADD MINT NEW VIOLIN
     */

    config[0][RCLib.Tasks.MINT_NEW_VIOLIN].canInitiate = [RCLib.Role.VOUNTAIN];
    config[0][RCLib.Tasks.MINT_NEW_VIOLIN].canApprove = [RCLib.Role.OWNER_ROLE];
    config[0][RCLib.Tasks.MINT_NEW_VIOLIN].approvalsNeeded = 1;
    config[0][RCLib.Tasks.MINT_NEW_VIOLIN].affectedRole = RCLib.Role.OWNER_ROLE;
    config[0][RCLib.Tasks.MINT_NEW_VIOLIN].validity = 72;
  }

  /**
   * @dev function for returning the configuration in a readable manner
   * @param violinID_ the violin to be checked
   * @param configID_ the task to check e.g. DELIST_MUSICIAN_ROLE
   */
  function returnRoleConfig(uint256 violinID_, RCLib.Tasks configID_)
    public
    view
    returns (RCLib.RequestConfig memory)
  {
    return (config[violinToVersion[violinID_]][configID_]);
  }

  /**
   * @dev function to set for all tasks at once
   * @param configs_ configuration with type RequestConfig containing all tasks
   * @param version_ the version number of the new configuration
   */
  function setConfigForTasks(RCLib.RequestConfig[] memory configs_, uint256 version_)
    public
    onlyOwner
  {
    require(!configFrozen[version_], "you can't change live configs");
    require(
      configs_.length == uint256(RCLib.Tasks.CHANGE_METADATA_ACCESSCONTROL) + 1,
      "Invalid number of configs"
    );
    for (uint256 i = 0; i <= uint256(RCLib.Tasks.CHANGE_METADATA_ACCESSCONTROL); i++) {
      config[version_][RCLib.Tasks(i)] = configs_[i];
    }
  }

  /**
   * @dev query the configuration for a specific version
   * @param version_ the version to query
   */
  function getConfigForVersion(uint256 version_)
    public
    view
    returns (RCLib.RequestConfig[] memory)
  {
    RCLib.RequestConfig[] memory configs = new RCLib.RequestConfig[](
      uint256(RCLib.Tasks.CHANGE_METADATA_ACCESSCONTROL) + 1
    );
    for (uint256 i = 0; i <= uint256(RCLib.Tasks.CHANGE_METADATA_ACCESSCONTROL); i++) {
      configs[i] = config[version_][RCLib.Tasks(i)];
    }
    return configs;
  }

  /**
   * @dev there are different task cluster. Means, that all creation tasks belong to the CREATION Cluster
   * @dev this is needed for handling the requests.
   */
  function checkTasks(RCLib.Tasks task_) public pure returns (RCLib.TaskCluster cluster) {
    if (
      task_ == RCLib.Tasks.CREATE_INSTRUMENT_MANAGER_ROLE ||
      task_ == RCLib.Tasks.CREATE_MUSICIAN_ROLE ||
      task_ == RCLib.Tasks.CREATE_VIOLIN_MAKER_ROLE ||
      task_ == RCLib.Tasks.CREATE_OWNER_ROLE ||
      task_ == RCLib.Tasks.CREATE_EXHIBITOR_ROLE
    ) {
      cluster = RCLib.TaskCluster.CREATION;
    } else if (
      task_ == RCLib.Tasks.CHANGE_DURATION_MUSICIAN_ROLE ||
      task_ == RCLib.Tasks.CHANGE_DURATION_INSTRUMENT_MANAGER_ROLE ||
      task_ == RCLib.Tasks.CHANGE_DURATION_VIOLIN_MAKER_ROLE ||
      task_ == RCLib.Tasks.CHANGE_DURATION_OWNER_ROLE ||
      task_ == RCLib.Tasks.CHANGE_DURATION_EXHIBITOR_ROLE
    ) {
      cluster = RCLib.TaskCluster.CHANGE_DURATION;
    } else if (
      task_ == RCLib.Tasks.DELIST_INSTRUMENT_MANAGER_ROLE ||
      task_ == RCLib.Tasks.DELIST_MUSICIAN_ROLE ||
      task_ == RCLib.Tasks.DELIST_VIOLIN_MAKER_ROLE ||
      task_ == RCLib.Tasks.DELIST_OWNER_ROLE ||
      task_ == RCLib.Tasks.DELIST_EXHIBITOR_ROLE
    ) {
      cluster = RCLib.TaskCluster.DELISTING;
    } else if (
      task_ == RCLib.Tasks.DELEGATE_INSTRUMENT_MANAGER_ROLE ||
      task_ == RCLib.Tasks.DELEGATE_MUSICIAN_ROLE ||
      task_ == RCLib.Tasks.DELEGATE_VIOLIN_MAKER_ROLE ||
      task_ == RCLib.Tasks.DELEGATE_EXHIBITOR_ROLE ||
      task_ == RCLib.Tasks.DELEGATE_OWNER_ROLE
    ) {
      cluster = RCLib.TaskCluster.DELEGATING;
    } else if (
      task_ == RCLib.Tasks.ADD_CONCERT ||
      task_ == RCLib.Tasks.ADD_EXHIBITION ||
      task_ == RCLib.Tasks.ADD_REPAIR
    ) {
      cluster = RCLib.TaskCluster.EVENTS;
    } else if (task_ == RCLib.Tasks.ADD_DOCUMENT) {
      cluster = RCLib.TaskCluster.DOCUMENTS;
    } else if (
      task_ == RCLib.Tasks.CHANGE_METADATA_VIOLIN ||
      task_ == RCLib.Tasks.CHANGE_METADATA_ACCESSCONTROL
    ) {
      cluster = RCLib.TaskCluster.METADATA;
    } else {
      cluster = RCLib.TaskCluster.MINTING;
    }

    return cluster;
  }

  /**
   * @dev function to activate a new version (users can only set active versions)
   * @param version_ the version to activate
   */
  function setVersionLive(uint256 version_) public onlyOwner {
    versionLive[version_] = true;
    configFrozen[version_] = true;
  }

  /**
   * @dev function to deactivate a version
   * @param version_ the version to deactivate
   */
  function setVersionInactive(uint256 version_) public onlyOwner {
    versionLive[version_] = false;
  }

  /**
   * @dev An owner of a violin can set the version for his violin.
   * @dev The configuration immeadiatly takes place for the violin.
   * @dev It is not possible to downgrade to an older version
   * @dev It is not possible to switch to an inactive version
   * @param violinID_ the violin to manage
   * @param version_ the version to upgrade to
   */
  function setVersionForViolin(uint256 violinID_, uint256 version_) public {
    RCLib.ContractCombination memory readContracts = connectContract
      .getContractsForVersion(violinID_);
    IAccessControl accessControl = IAccessControl(readContracts.accessControlContract);

    require(
      accessControl.checkIfAddressHasAccess(msg.sender, RCLib.Role.OWNER_ROLE, violinID_),
      "account is not the owner"
    );

    require(version_ > violinToVersion[violinID_], "downgrade not possible");
    require(versionLive[version_], "version not live");

    violinToVersion[violinID_] = version_;
  }
}
