// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ConnectContract.sol";

/// @title Vountain – CheckRights
/// @notice Contract for checking the rights for the request and approval logic.
///         Reads the config and applies the rules.

contract CheckRights is Ownable {
  IConfigurationContract configurationContract;
  IConnectContract connectContract;

  constructor(address configurationContract_, address connectContract_) {
    configurationContract = IConfigurationContract(configurationContract_);
    connectContract = IConnectContract(connectContract_);
  }

  function getAccessControlContractInterface(uint256 violinId_)
    internal
    view
    returns (IAccessControl)
  {
    address accessControlContract = connectContract.getAccessControlContract(violinId_);
    IAccessControl accessControl = IAccessControl(accessControlContract);
    return accessControl;
  }

  function getViolinMetadata(uint256 violinId_) internal view returns (IViolineMetadata) {
    IViolineMetadata violinMetadata = IViolineMetadata(
      connectContract.getMetadataContract(violinId_)
    );
    return violinMetadata;
  }

  function checkRole(
    RCLib.Tasks requestType_,
    uint256 violinId_,
    RCLib.PROCESS_TYPE approve,
    address targetAccount,
    RCLib.Role requesterRole_
  ) public view returns (bool) {
    IAccessControl accessControl = getAccessControlContractInterface(violinId_);
    IViolineMetadata violinMetadata = getViolinMetadata(violinId_);
    IViolines violin = IViolines(connectContract.violinAddress());

    RCLib.Role[] memory _role;

    if (approve == RCLib.PROCESS_TYPE.IS_APPROVE_PROCESS) {
      _role = configurationContract.returnRoleConfig(violinId_, requestType_).canApprove;

      if (
        RCLib.TaskCluster.CREATION == configurationContract.checkTasks(requestType_) ||
        RCLib.TaskCluster.MINTING == configurationContract.checkTasks(requestType_)
      ) {
        return (msg.sender == targetAccount);
      }
    } else {
      _role = configurationContract.returnRoleConfig(violinId_, requestType_).canInitiate;

      if (
        RCLib.TaskCluster.DELEGATING == configurationContract.checkTasks(requestType_)
      ) {
        return (msg.sender == violinMetadata.readLocation(violinId_));
      }
    }

    for (uint256 i = 0; i < _role.length; i++) {
      if (approve == RCLib.PROCESS_TYPE.IS_APPROVE_PROCESS && _role[i] == requesterRole_)
        continue;
      if (approve != RCLib.PROCESS_TYPE.IS_APPROVE_PROCESS && _role[i] != requesterRole_)
        continue;

      if (_role[i] == RCLib.Role.CUSTODIAL && violin.ownerOf(violinId_) == msg.sender)
        return true;
      if (_role[i] == RCLib.Role.VOUNTAIN && msg.sender == owner()) return true;
      if (accessControl.checkIfAddressHasAccess(msg.sender, _role[i], violinId_))
        return true;
    }
    return false;
  }
}
