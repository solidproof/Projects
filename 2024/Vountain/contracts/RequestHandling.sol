// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "./ApproveRequest.sol";

/// @title Vountain – RequestHandling
/// @notice Managing different requests

contract RequestHandling is ApproveRequest {
  constructor(address configurationContract, address connectContract)
    ApproveRequest(configurationContract, connectContract)
  {}

  event ExecutedRequest(
    uint256 indexed violinId_,
    address indexed sender,
    uint256 requestId
  );

  /// @dev managing the states which the violin can have
  /// @param affectedRole available roles OWNER_ROLE, VOUNTAIN, INSTRUMENT_MANAGER_ROLE, MUSICIAN_ROLE, VIOLIN_MAKER_ROLE
  /// @param metadata passing the instanciated ViolineMetadata
  /// @param violinId_ id of the violin
  /// @param targetAccount_ receiver account
  function setViolinState(
    RCLib.Role affectedRole,
    IViolineMetadata metadata,
    uint256 violinId_,
    address targetAccount_
  ) internal {
    if ((affectedRole) == (RCLib.Role.MUSICIAN_ROLE)) {
      metadata.setTokenArtist(violinId_, targetAccount_);
    } else if ((affectedRole == RCLib.Role.INSTRUMENT_MANAGER_ROLE)) {
      metadata.setTokenManager(violinId_, targetAccount_);
    } else if ((affectedRole == (RCLib.Role.VIOLIN_MAKER_ROLE))) {
      metadata.setTokenViolinMaker(violinId_, targetAccount_);
    } else if ((affectedRole == (RCLib.Role.EXHIBITOR_ROLE))) {
      metadata.setExhibitor(violinId_, targetAccount_);
    } else if ((affectedRole == (RCLib.Role.OWNER_ROLE))) {
      metadata.setTokenOwner(violinId_, targetAccount_);
    }
  }

  /// @dev executing the request from requestByViolinId mapping (RequestCreation.sol)
  /// @param violinId_ id of the violin
  function executeRequest(uint256 violinId_, uint256 requestId_) external {
    // Inherited Contracts
    IAccessControl accessControl = getAccessControlContractInterface(violinId_);
    IViolines violin = IViolines(connectContract.violinAddress());
    IViolineMetadata violinMetadata = getViolinMetadata(violinId_);

    // requestByViolinId is created in RequestCreation.sol
    RCLib.Request storage request = requestByViolinIdAndRequestId[violinId_][requestId_];
    require(request.canBeApproved, "there is nothing to execute!"); //wenn der request auf executed steht, dann gibt es nichts zu approven...
    require(request.approvalCount >= request.approvalsNeeded, "you need more approvals!"); //wenn noch nicht genug approvals existieren, dann kann nicht approved werden
    require(request.requestValidUntil > block.timestamp, "request expired.");

    requestChecks(violinId_, request.targetAccount, request.approvalType);

    request.canBeApproved = false;
    request.requestValidUntil = block.timestamp;
    delete (approvedAddresses[violinId_][requestId_]);

    RCLib.TaskCluster currentTask = configurationContract.checkTasks(
      request.approvalType
    );

    if (RCLib.TaskCluster.MINTING == currentTask) {
      violin.mintViolin(request.violinId, request.mintTarget);
      violinMetadata.setViolinLocation(request.violinId, request.targetAccount);
    }
    if (
      request.approvalType == RCLib.Tasks.CHANGE_METADATA_VIOLIN ||
      RCLib.TaskCluster.MINTING == currentTask
    ) {
      violinMetadata.changeMetadata(
        request.newMetadata.name,
        request.newMetadata.description,
        request.newMetadata.longDescription,
        request.newMetadata.image,
        request.newMetadata.media,
        request.newMetadata.model3d,
        request.newMetadata.attributeNames,
        request.newMetadata.attributeValues,
        request.violinId
      );
    }

    if (request.approvalType == RCLib.Tasks.CHANGE_METADATA_ACCESSCONTROL) {
      accessControl.changeMetadata(
        request.violinId,
        request.newMetadata.description,
        request.newMetadata.image
      );
    }

    if (
      RCLib.TaskCluster.CREATION ==
      configurationContract.checkTasks(request.approvalType) ||
      RCLib.TaskCluster.MINTING == currentTask
    ) {
      require(
        !accessControl.checkIfAddressHasAccess(
          request.targetAccount,
          request.affectedRole,
          request.violinId
        ),
        "you already have that role!"
      );

      string memory metadataImage = request.newMetadata.image;

      // Check if optionalOwnerImage is not empty
      if (
        bytes(request.newMetadata.optionalOwnerImage).length > 0 &&
        RCLib.TaskCluster.MINTING == currentTask
      ) {
        metadataImage = request.newMetadata.optionalOwnerImage;
      }

      accessControl.mintRole(
        request.targetAccount,
        request.affectedRole,
        request.contractValidUntil,
        violinId_,
        metadataImage,
        request.newMetadata.description
      );

      setViolinState(
        request.affectedRole,
        violinMetadata,
        violinId_,
        request.targetAccount
      );
    } else if (
      RCLib.TaskCluster.CHANGE_DURATION == currentTask
    ) //Change the validity in AccessControl Contract
    {
      accessControl.setTimestamp(
        request.violinId,
        request.contractValidUntil,
        request.targetAccount,
        request.affectedRole
      );
    } else if (RCLib.TaskCluster.DELISTING == currentTask) {
      accessControl.burnTokens(
        request.targetAccount,
        request.affectedRole,
        request.violinId
      );

      setViolinState(request.affectedRole, violinMetadata, violinId_, address(0));
    } else if (RCLib.TaskCluster.DELEGATING == currentTask) {
      violinMetadata.setViolinLocation(violinId_, request.targetAccount);
    } else if (RCLib.TaskCluster.EVENTS == currentTask) {
      violinMetadata.createNewEvent(
        request.requestId,
        request.newEvent.name,
        request.newEvent.description,
        request.newEvent.role,
        request.newEvent.attendee,
        request.newEvent.eventStartTimestamp,
        request.newEvent.eventEndTimestamp,
        request.newEvent.link,
        request.newEvent.geolocation,
        request.newEvent.file,
        request.approvalType,
        request.violinId
      );
    } else if (RCLib.TaskCluster.DOCUMENTS == currentTask) {
      violinMetadata.createNewDocument(
        request.requestId,
        request.newDocument.docType,
        request.newDocument.date,
        request.newDocument.cid,
        request.newDocument.title,
        request.newDocument.description,
        request.newDocument.source,
        request.newDocument.value,
        request.newDocument.valueOriginalCurrency,
        request.newDocument.originalCurrency,
        request.violinId
      );
    }

    emit ExecutedRequest(violinId_, msg.sender, request.requestId);
  }
}
