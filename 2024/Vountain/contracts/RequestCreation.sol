// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CheckRights.sol";
import "./TypeLibrary.sol";

/// @title Vountain – RequestCreation
/// @notice For different purposes different requests can be created.
///         The request types differ in the fields filled, but not in the structure.

contract RequestCreation is CheckRights {
  mapping(uint256 => mapping(uint256 => address[])) internal approvedAddresses;
  mapping(uint256 => mapping(uint256 => RCLib.Request))
    internal requestByViolinIdAndRequestId;
  uint256 public requestId;
  uint256 public mintCounter;

  event NewRequestCreated(
    uint256 indexed violinId_,
    address indexed sender,
    uint256 indexed requestId
  );

  constructor(address configurationContract, address connectContract)
    CheckRights(configurationContract, connectContract)
  {}

  function getRoleForTask(RCLib.Tasks task) internal pure returns (RCLib.Role) {
    if (task == RCLib.Tasks.DELEGATE_INSTRUMENT_MANAGER_ROLE) {
      return RCLib.Role.INSTRUMENT_MANAGER_ROLE;
    } else if (task == RCLib.Tasks.DELEGATE_MUSICIAN_ROLE) {
      return RCLib.Role.MUSICIAN_ROLE;
    } else if (task == RCLib.Tasks.DELEGATE_EXHIBITOR_ROLE) {
      return RCLib.Role.EXHIBITOR_ROLE;
    } else if (task == RCLib.Tasks.DELEGATE_VIOLIN_MAKER_ROLE) {
      return RCLib.Role.VIOLIN_MAKER_ROLE;
    } else if (task == RCLib.Tasks.DELEGATE_OWNER_ROLE) {
      return RCLib.Role.OWNER_ROLE;
    } else {
      revert("Invalid task");
    }
  }

  function requestChecks(
    uint256 violinId_,
    address targetAccount_,
    RCLib.Tasks requestType_
  ) internal view {
    address metadataContract = connectContract.getMetadataContract(violinId_);
    IViolineMetadata metadata = IViolineMetadata(metadataContract);

    IAccessControl accessControl = getAccessControlContractInterface(violinId_);
    RCLib.TaskCluster taskCluster = configurationContract.checkTasks(requestType_);

    if (
      RCLib.TaskCluster.DELISTING == taskCluster &&
      metadata.readLocation(violinId_) == targetAccount_
    ) {
      revert("Can't delist active location");
    }

    if (RCLib.TaskCluster.DELEGATING == taskCluster) {
      RCLib.Role targetCheck = getRoleForTask(requestType_);

      if (targetAccount_ == metadata.readLocation(violinId_)) {
        revert("Can't delegate to yourself");
      }

      if (
        !accessControl.checkIfAddressHasAccess(targetAccount_, targetCheck, violinId_)
      ) {
        revert("Can't delegate to wrong address");
      }
    }
  }

  /// @dev create new request
  /// @param violinId_ ID of violin
  /// @param contractValidUntil_ date for the ending of the contract
  /// @param targetAccount_ Affected Target Account
  /// @param requestType_ specify a type e.g CREATE_MANAGER
  ///                     see Configuration.sol Contract for Details of roles
  function createNewRequest(
    uint256 violinId_,
    uint256 contractValidUntil_,
    address targetAccount_,
    RCLib.Tasks requestType_,
    RCLib.Role requesterRole_
  ) public {
    RCLib.TaskCluster taskCluster = configurationContract.checkTasks(requestType_);

    require(
      RCLib.TaskCluster.CHANGE_DURATION == taskCluster ||
        RCLib.TaskCluster.DELISTING == taskCluster ||
        RCLib.TaskCluster.DELEGATING == taskCluster,
      "wrong request type"
    );

    if (RCLib.TaskCluster.DELEGATING == taskCluster) {
      if (targetAccount_ == msg.sender) revert("Can't delegate to yourself");
    }

    requestChecks(violinId_, targetAccount_, requestType_);

    createRequest(
      violinId_,
      contractValidUntil_,
      targetAccount_,
      requestType_,
      requesterRole_
    );
  }

  /// @dev create new request
  /// @param violinId_ ID of violin
  /// @param contractValidUntil_ date for the ending of the contract
  /// @param targetAccount_ Affected Target Account
  /// @param requestType_ specify a type e.g CREATE_MANAGER
  ///                     see Configuration.sol Contract for Details of roles
  function createRequest(
    uint256 violinId_,
    uint256 contractValidUntil_,
    address targetAccount_,
    RCLib.Tasks requestType_,
    RCLib.Role requesterRole_
  ) internal returns (uint256) {
    require(
      checkRole(
        requestType_,
        violinId_,
        RCLib.PROCESS_TYPE.IS_CREATE_PROCESS,
        targetAccount_,
        requesterRole_
      ),
      "you have the wrong role..."
    );

    requestId = requestId + 1;

    requestByViolinIdAndRequestId[violinId_][requestId].requestId = requestId;
    requestByViolinIdAndRequestId[violinId_][requestId].violinId = violinId_;
    requestByViolinIdAndRequestId[violinId_][requestId].approvalType = requestType_;
    requestByViolinIdAndRequestId[violinId_][requestId].creator = msg.sender;
    requestByViolinIdAndRequestId[violinId_][requestId].targetAccount = targetAccount_;
    requestByViolinIdAndRequestId[violinId_][requestId].mintTarget = targetAccount_;
    requestByViolinIdAndRequestId[violinId_][requestId].canBeApproved = true;
    requestByViolinIdAndRequestId[violinId_][requestId]
      .affectedRole = configurationContract
      .returnRoleConfig(violinId_, requestType_)
      .affectedRole;
    requestByViolinIdAndRequestId[violinId_][requestId].canApprove = configurationContract
      .returnRoleConfig(violinId_, requestType_)
      .canApprove;
    requestByViolinIdAndRequestId[violinId_][requestId]
      .approvalsNeeded = configurationContract
      .returnRoleConfig(violinId_, requestType_)
      .approvalsNeeded;
    requestByViolinIdAndRequestId[violinId_][requestId].approvalCount = 0;
    requestByViolinIdAndRequestId[violinId_][requestId].requestValidUntil =
      block.timestamp +
      (configurationContract.returnRoleConfig(violinId_, requestType_).validity *
        1 hours);
    requestByViolinIdAndRequestId[violinId_][requestId]
      .contractValidUntil = contractValidUntil_;
    requestByViolinIdAndRequestId[violinId_][requestId].requesterRole = requesterRole_;
    delete (approvedAddresses[violinId_][requestId]);

    emit NewRequestCreated(violinId_, msg.sender, requestId);
    return requestId;
  }

  /// @dev create new request
  /// @param violinId_ ID of violin
  /// @param requestValidUntil_ check valdity of contract with date
  /// @param targetAccount_ Affected Target Account
  /// @param requestType_ specify a type e.g CREATE_MANAGER
  ///                     see Configuration.sol Contract for Details of roles
  /// @param mintTarget_ specify a type e.g CREATE_MANAGER
  ///                     see Configuration.sol Contract for Details of roles
  /// @param metadata_ request metadata (specified in TypeLibrary.sol)
  ///                  string name;
  ///                  string description;
  ///                  string longdescription;
  ///                  string image;
  ///                  string model3d;
  ///                  string[] attributes;
  ///                  string[] metadataValues;
  function createNewMintOrRoleRequest(
    uint256 violinId_,
    uint256 requestValidUntil_,
    address targetAccount_,
    RCLib.Tasks requestType_,
    address mintTarget_,
    RCLib.Metadata memory metadata_,
    RCLib.Role requesterRole_
  ) public {
    IAccessControl accessControl = getAccessControlContractInterface(violinId_);
    RCLib.RequestConfig memory config = configurationContract.returnRoleConfig(
      violinId_,
      requestType_
    );

    require(
      RCLib.TaskCluster.CREATION == configurationContract.checkTasks(requestType_) ||
        RCLib.TaskCluster.MINTING == configurationContract.checkTasks(requestType_),
      "only for new roles"
    );

    require(
      metadata_.attributeNames.length == metadata_.attributeValues.length,
      "attributes length differ"
    );
    if (
      RCLib.TaskCluster.MINTING == configurationContract.checkTasks(requestType_) &&
      mintTarget_ == address(0)
    ) {
      revert("target is null address");
    }

    require(
      !accessControl.roleAlreadyActive(violinId_, config.affectedRole),
      "role already active"
    );

    if (RCLib.TaskCluster.MINTING == configurationContract.checkTasks(requestType_)) {
      requestValidUntil_ = 32472144000;
      mintCounter += 1;
      violinId_ = mintCounter;
    }

    uint256 createdRequestId = createRequest(
      violinId_,
      requestValidUntil_,
      targetAccount_,
      requestType_,
      requesterRole_
    );
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .name = metadata_.name;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .description = metadata_.description;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .longDescription = metadata_.longDescription;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .image = metadata_.image;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .optionalOwnerImage = metadata_.optionalOwnerImage;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .media = metadata_.media;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .model3d = metadata_.model3d;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .attributeNames = metadata_.attributeNames;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .attributeValues = metadata_.attributeValues;
    requestByViolinIdAndRequestId[violinId_][createdRequestId].mintTarget = mintTarget_;
  }

  /// @param violinId_ ID of violin
  /// @param requestType_ specify a type e.g CREATE_MANAGER
  ///                     see Configuration.sol Contract for Details of roles
  /// @param metadata_ request metadata (specified in TypeLibrary.sol)
  ///                  string name;
  ///                  string description;
  ///                  string longdescription;
  ///                  string image;
  ///                  string model3d;
  ///                  string[] attributes;
  ///                  string[] metadataValues;
  function createMetadataRequest(
    uint256 violinId_,
    RCLib.Tasks requestType_,
    RCLib.Metadata memory metadata_,
    RCLib.Role requesterRole_
  ) public {
    require(
      RCLib.TaskCluster.METADATA == configurationContract.checkTasks(requestType_),
      "only for changing metadata."
    );
    require(
      metadata_.attributeNames.length == metadata_.attributeValues.length,
      "attributes length differ"
    );
    uint256 createdRequestId = createRequest(
      violinId_,
      0,
      msg.sender,
      requestType_,
      requesterRole_
    );
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .name = metadata_.name;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .description = metadata_.description;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .longDescription = metadata_.longDescription;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .image = metadata_.image;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .media = metadata_.media;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .model3d = metadata_.model3d;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .attributeNames = metadata_.attributeNames;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newMetadata
      .attributeValues = metadata_.attributeValues;
  }

  /// @param violinId_ ID of violin
  /// @param requestType_ specify a type e.g CREATE_MANAGER
  ///                     see Configuration.sol Contract for Details of roles
  /// @param name_ name of the event
  /// @param description_ description of the event
  /// @param eventStartTimestamp_ when did the event happen
  /// @param eventStartTimestamp_ how long did it last
  function createNewEventRequest(
    uint256 violinId_,
    RCLib.Tasks requestType_,
    string memory name_,
    string memory description_,
    uint256 eventStartTimestamp_,
    uint256 eventEndTimestamp_,
    string memory link,
    string memory geolocation,
    string[] memory file,
    RCLib.Role requesterRole_
  ) public {
    require(
      RCLib.TaskCluster.EVENTS == configurationContract.checkTasks(requestType_),
      "only for adding events."
    );

    require(
      eventEndTimestamp_ == 0 || eventStartTimestamp_ <= eventEndTimestamp_,
      "wrong dates submitted"
    );

    if (requestType_ == RCLib.Tasks.ADD_REPAIR) {
      require(eventStartTimestamp_ <= block.timestamp, "only date in past allowed");
    }

    uint256 createdRequestId = createRequest(
      violinId_,
      eventStartTimestamp_,
      msg.sender,
      requestType_,
      requesterRole_
    ); //request will be created

    requestByViolinIdAndRequestId[violinId_][createdRequestId].newEvent.name = name_;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newEvent
      .description = description_;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newEvent
      .role = configurationContract
      .returnRoleConfig(violinId_, requestType_)
      .affectedRole;
    requestByViolinIdAndRequestId[violinId_][createdRequestId].newEvent.attendee = msg
      .sender;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newEvent
      .eventStartTimestamp = eventStartTimestamp_;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newEvent
      .eventEndTimestamp = eventEndTimestamp_;
    requestByViolinIdAndRequestId[violinId_][createdRequestId].newEvent.link = link;
    requestByViolinIdAndRequestId[violinId_][createdRequestId]
      .newEvent
      .geolocation = geolocation;
    requestByViolinIdAndRequestId[violinId_][createdRequestId].newEvent.file = file;
  }

  /// @param violinId_ ID of violin
  /// @param requestType_ specify a type e.g CREATE_MANAGER
  ///                     see Configuration.sol Contract for Details of roles
  /// @param eventStartTimestamp_ timestamp of the event
  /// @param document the document object
  function createNewDocumentRequest(
    uint256 violinId_,
    RCLib.Tasks requestType_,
    RCLib.Role requesterRole_,
    uint256 eventStartTimestamp_,
    RCLib.Documents memory document
  ) public {
    require(
      RCLib.TaskCluster.DOCUMENTS == configurationContract.checkTasks(requestType_),
      "only for adding documents."
    );
    require(document.date < int256(block.timestamp), "only date in past allowed");

    uint256 createdRequestId = createRequest(
      violinId_,
      eventStartTimestamp_,
      msg.sender,
      requestType_,
      requesterRole_
    ); //request will be created

    {
      requestByViolinIdAndRequestId[violinId_][createdRequestId].newDocument = document;
    }
  }

  function returnRequestByViolinIdAndRequestId(uint256 violinId_, uint256 request_)
    public
    view
    returns (RCLib.Request memory)
  {
    return (requestByViolinIdAndRequestId[violinId_][request_]);
  }
}
