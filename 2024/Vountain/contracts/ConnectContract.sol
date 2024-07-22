// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./TypeLibrary.sol";

/// @title Vountain – ConnectContract
/// @notice Connecting violin, metadata, access controls and

contract ConnectContract is Ownable {
  address public violinAddress;

  mapping(uint256 => RCLib.ContractCombination) public versionToContractCombination;
  mapping(uint256 => uint256) public violinToContractVersion;
  mapping(uint256 => bool) public versionIsActive;
  mapping(uint256 => bool) public freezeConfigVersion;

  RCLib.LatestMintableVersion public latest;

  constructor() {}

  /**
   * @dev after deployment the ConnectContract and the violin contract are tied together forever
   * @param violinAddress_ the address of the violin contract
   */
  function setViolinAddress(address violinAddress_) public onlyOwner {
    //once and forever
    require(violinAddress == address(0), "already initialized");
    violinAddress = violinAddress_;
  }

  /**
   * @dev Vountain can add a contract combination for the application. Itś not possible to change a contract combination once the version was set to active
   * @param id_ the version of the contract combination
   * @param controllerContract_  the request handling logic contract
   * @param accessControlContract_  the role token contract
   * @param metadataContract_  the metadata contract
   */
  function setContractConfig(
    uint256 id_,
    address controllerContract_,
    address accessControlContract_,
    address metadataContract_,
    address moveRoleContract_
  ) public onlyOwner {
    require(!freezeConfigVersion[id_], "don't change active versions");
    versionToContractCombination[id_].controllerContract = controllerContract_;
    versionToContractCombination[id_].accessControlContract = accessControlContract_;
    versionToContractCombination[id_].metadataContract = metadataContract_;
    versionToContractCombination[id_].moveRoleContract = moveRoleContract_;
  }

  /**
   * @dev Vountain can set a version to active. All contracts has to be initialized.
   * @dev The version is frozen and can not be changed later
   * @dev The latest version is set if the config has a higher number than the last latest version
   * @param version_ the version to set active
   */
  function setVersionActive(uint256 version_) public onlyOwner {
    RCLib.ContractCombination memory contracts = versionToContractCombination[version_];

    require(
      contracts.controllerContract != address(0) &&
        contracts.accessControlContract != address(0) &&
        contracts.metadataContract != address(0) &&
        contracts.moveRoleContract != address(0),
      "initialize contracts first"
    );
    versionIsActive[version_] = true;
    freezeConfigVersion[version_] = true;
    if (version_ >= latest.versionNumber) {
      latest.versionNumber = version_;
      latest.controllerContract = versionToContractCombination[version_]
        .controllerContract;
    }
  }

  /**
   * @dev function to set a version inactive
   * @param version_ the version to set inactive
   */
  function setVersionInactive(uint256 version_) public onlyOwner {
    versionIsActive[version_] = false;
  }

  /**
   * @dev an owner of the violin can set a version to active.
   * @dev it is not possible to choose an inactive version
   * @dev a downgrade is not possible
   * @param violinID_ the violin to change the combination
   * @param version_ the version to activate
   */
  function setViolinToContractVersion(uint256 violinID_, uint256 version_) public {
    IAccessControl accessControl = IAccessControl(getAccessControlContract(violinID_));
    require(
      accessControl.checkIfAddressHasAccess(
        msg.sender,
        RCLib.Role.OWNER_ROLE,
        violinID_
      ) || msg.sender == violinAddress,
      "account is not the owner"
    );
    require(versionIsActive[version_], "version not active");
    require(version_ >= violinToContractVersion[violinID_], "no downgrade possible");
    violinToContractVersion[violinID_] = version_;
  }

  /**
   * @dev returns the contract combination for a version
   * @param violinID_ the violin to check
   */
  function getContractsForVersion(uint256 violinID_)
    public
    view
    returns (RCLib.ContractCombination memory cc)
  {
    return versionToContractCombination[violinToContractVersion[violinID_]];
  }

  /**
   * @dev returns the controller contract for the violin
   * @param violinID_ the violin to check
   */
  function getControllerContract(uint256 violinID_)
    public
    view
    returns (address controllerContract)
  {
    RCLib.ContractCombination memory contracts = getContractsForVersion(violinID_);
    return contracts.controllerContract;
  }

  /**
   * @dev returns the moveRole contract for the violin
   * @param violinID_ the violin to check
   */
  function getMoveRoleContract(uint256 violinID_)
    public
    view
    returns (address moveRoleContract)
  {
    RCLib.ContractCombination memory contracts = getContractsForVersion(violinID_);
    return contracts.moveRoleContract;
  }

  /**
   * @dev returns the access control contract for the violin
   * @param violinID_ the violin to check
   */
  function getAccessControlContract(uint256 violinID_)
    public
    view
    returns (address accessControlContract)
  {
    RCLib.ContractCombination memory contracts = getContractsForVersion(violinID_);
    return contracts.accessControlContract;
  }

  /**
   * @dev returns the metadata contract for the violin
   * @param violinID_ the violin to check
   */
  function getMetadataContract(uint256 violinID_)
    public
    view
    returns (address metadataContract)
  {
    RCLib.ContractCombination memory contracts = getContractsForVersion(violinID_);
    return contracts.metadataContract;
  }
}
