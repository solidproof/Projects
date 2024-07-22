// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract IConnectContract {
  function getContractsForVersion(uint256 violinID_)
    public
    view
    virtual
    returns (RCLib.ContractCombination memory cc);

  function violinAddress() public view virtual returns (address violinAddress);

  function getControllerContract(uint256 violinID_)
    public
    view
    virtual
    returns (address controllerContract);

  function getMoveRoleContract(uint256 violinID_)
    public
    view
    virtual
    returns (address moveRoleContract);

  function getAccessControlContract(uint256 violinID_)
    public
    view
    virtual
    returns (address accessControlContract);

  function getMetadataContract(uint256 violinID_)
    public
    view
    virtual
    returns (address metadataContract);

  function versionIsActive(uint256 version) external view virtual returns (bool);
}

abstract contract IConfigurationContract {
  function getConfigForVersion(uint256 version_)
    public
    view
    virtual
    returns (RCLib.RequestConfig[] memory);

  function checkTasks(RCLib.Tasks task_)
    public
    pure
    virtual
    returns (RCLib.TaskCluster cluster);

  function returnRoleConfig(uint256 version_, RCLib.Tasks configId_)
    public
    view
    virtual
    returns (RCLib.RequestConfig memory);

  function violinToVersion(uint256 tokenId) external view virtual returns (uint256);
}

abstract contract IViolines {
  function mintViolin(uint256 tokenId_, address addr_) external virtual;

  function ownerOf(uint256 tokenId) public view virtual returns (address);

  function balanceOf(address owner) public view virtual returns (uint256);
}

abstract contract IViolineMetadata {
  struct EventType {
    string name;
    string description;
    string role;
    address attendee;
    uint256 eventTimestamp;
  }

  function createNewDocument(
    uint256 requestId_,
    string memory docType_,
    int256 date_,
    string memory cid_,
    string memory title_,
    string memory description_,
    string memory source_,
    uint256 value_,
    uint256 value_original_currency_,
    string memory currency_,
    uint256 tokenID_
  ) external virtual;

  function changeMetadata(
    string memory name_,
    string memory description_,
    string memory longDescription_,
    string memory image_,
    string[] memory media_,
    string[] memory model3d_,
    string[] memory attributeNames_,
    string[] memory attributeValues_,
    uint256 tokenId_
  ) external virtual;

  function readManager(uint256 tokenID_) public view virtual returns (address);

  function readLocation(uint256 tokenID_) public view virtual returns (address);

  function setTokenManager(uint256 tokenID_, address manager_) external virtual;

  function setTokenArtist(uint256 tokenID_, address artist_) external virtual;

  function setTokenOwner(uint256 tokenID_, address owner_) external virtual;

  function setExhibitor(uint256 tokenID_, address exhibitor_) external virtual;

  function setTokenViolinMaker(uint256 tokenID_, address violinMaker_) external virtual;

  function setViolinLocation(uint256 tokenID_, address violinLocation_) external virtual;

  function createNewEvent(
    uint256 requestId_,
    string memory name_,
    string memory description_,
    RCLib.Role role_,
    address attendee_,
    uint256 eventStartTimestamp_,
    uint256 eventEndTimestamp_,
    string memory link,
    string memory geolocation,
    string[] memory file,
    RCLib.Tasks eventType_,
    uint256 tokenID_
  ) external virtual;
}

abstract contract IAccessControl {
  function mintRole(
    address assignee_,
    RCLib.Role role_,
    uint256 contractValidUntil_,
    uint256 violinID_,
    string memory image,
    string memory description
  ) external virtual;

  function roleAlreadyActive(uint256 violinId_, RCLib.Role role_)
    public
    virtual
    returns (bool);

  function changeMetadata(
    uint256 tokenId_,
    string memory description_,
    string memory image_
  ) public virtual;

  function checkIfAddressHasAccess(
    address addr_,
    RCLib.Role role_,
    uint256 violinID_
  ) public view virtual returns (bool);

  function setTimestamp(
    uint256 violinID_,
    uint256 timestamp_,
    address targetAccount_,
    RCLib.Role role_
  ) external virtual;

  function burnTokens(
    address targetAccount,
    RCLib.Role affectedRole,
    uint256 violinId
  ) external virtual;

  function administrativeCleanup(uint256 violinId) external virtual;

  function returnCorrespondingTokenID(
    address addr_,
    RCLib.Role role_,
    uint256 violinID_
  ) public view virtual returns (uint256);

  function administrativeMove(
    address from,
    address to,
    uint256 violinId,
    uint256 tokenId
  ) public virtual;
}

library RCLib {
  enum Role {
    OWNER_ROLE, //0
    VOUNTAIN, //1
    INSTRUMENT_MANAGER_ROLE, //2
    MUSICIAN_ROLE, //3
    VIOLIN_MAKER_ROLE, //4
    CUSTODIAL, //5
    EXHIBITOR_ROLE //6
  }

  enum TaskCluster {
    CREATION,
    CHANGE_DURATION,
    DELISTING,
    DELEGATING,
    EVENTS,
    DOCUMENTS,
    METADATA,
    MINTING
  }

  enum Tasks {
    CREATE_INSTRUMENT_MANAGER_ROLE, // 0
    CREATE_MUSICIAN_ROLE, // 1
    CREATE_VIOLIN_MAKER_ROLE, // 2
    CREATE_OWNER_ROLE, // 3
    CREATE_EXHIBITOR_ROLE, // 4
    CHANGE_DURATION_MUSICIAN_ROLE, // 4
    CHANGE_DURATION_INSTRUMENT_MANAGER_ROLE, // 6
    CHANGE_DURATION_VIOLIN_MAKER_ROLE, // 7
    CHANGE_DURATION_OWNER_ROLE, // 8
    CHANGE_DURATION_EXHIBITOR_ROLE, // 9
    DELIST_INSTRUMENT_MANAGER_ROLE, // 10
    DELIST_MUSICIAN_ROLE, // 11
    DELIST_VIOLIN_MAKER_ROLE, // 12
    DELIST_OWNER_ROLE, // 13
    DELIST_EXHIBITOR_ROLE, // 14
    DELEGATE_INSTRUMENT_MANAGER_ROLE, // 15
    DELEGATE_MUSICIAN_ROLE, // 16
    DELEGATE_VIOLIN_MAKER_ROLE, // 17
    DELEGATE_EXHIBITOR_ROLE, // 18
    DELEGATE_OWNER_ROLE, // 19
    ADD_CONCERT, // 20
    ADD_EXHIBITION, // 21
    ADD_REPAIR, // 22
    ADD_DOCUMENT, // 23
    MINT_NEW_VIOLIN, // 24
    CHANGE_METADATA_VIOLIN, // 25
    CHANGE_METADATA_ACCESSCONTROL // 26
  }

  struct TokenAttributes {
    address owner;
    address manager;
    address artist;
    address violinMaker;
    address violinLocation;
    address exhibitor;
    RCLib.CreatedEvent[] concert;
    RCLib.CreatedEvent[] exhibition;
    RCLib.CreatedEvent[] repair;
    RCLib.CreatedDocument[] document;
    RCLib.Metadata metadata;
  }

  struct RequestConfig {
    uint256 approvalsNeeded; //Amount of Approver
    RCLib.Role affectedRole; //z.B. MUSICIAN_ROLE
    RCLib.Role[] canApprove;
    RCLib.Role[] canInitiate;
    uint256 validity; //has to be in hours!!!
  }

  struct RoleNames {
    Role role;
    string[] names;
  }

  enum PROCESS_TYPE {
    IS_APPROVE_PROCESS,
    IS_CREATE_PROCESS
  }

  struct Request {
    uint256 requestId;
    uint256 violinId;
    uint256 contractValidUntil; //Timestamp
    address creator; //Initiator
    address targetAccount; //Get Role
    bool canBeApproved; //Is it already approved
    RCLib.Role affectedRole; //Role in AccessControl Contract
    Role[] canApprove; //Rollen, who can approve
    RCLib.Tasks approvalType; //e.g. CREATE_INSTRUMENT_MANAGER_ROLE
    uint256 approvalsNeeded; //Amount of approval needed
    uint256 approvalCount; //current approvals
    uint256 requestValidUntil; //how long is the request valid?
    address mintTarget; //optional for minting
    address[] approvedAddresses; //approvers
    RCLib.Event newEvent;
    RCLib.Documents newDocument;
    RCLib.Metadata newMetadata;
    RCLib.Role requesterRole;
  }

  struct AccessToken {
    string image;
    RCLib.Role role;
    uint256 violinID;
    uint256 contractValidUntil;
    string name;
    string description;
  }

  struct Event {
    string name;
    string description;
    RCLib.Role role;
    address attendee;
    uint256 eventStartTimestamp;
    uint256 eventEndTimestamp;
    string link;
    string geolocation;
    string[] file;
  }

  struct CreatedEvent {
    string name;
    string description;
    RCLib.Role role;
    address attendee;
    uint256 eventStartTimestamp;
    uint256 eventEndTimestamp;
    string link;
    string geolocation;
    string[] file;
    uint256 requestId;
  }

  struct Documents {
    string docType;
    int256 date;
    string cid;
    string title;
    string description;
    string source;
    uint256 value;
    uint256 valueOriginalCurrency;
    string originalCurrency;
  }

  struct CreatedDocument {
    string docType;
    int256 date;
    string cid;
    string title;
    string description;
    string source;
    uint256 value;
    uint256 valueOriginalCurrency;
    string originalCurrency;
    uint256 requestId;
  }

  struct Metadata {
    string name;
    string description;
    string longDescription;
    string image;
    string optionalOwnerImage;
    string[] media;
    string[] model3d;
    string[] attributeNames;
    string[] attributeValues;
  }

  struct ContractCombination {
    address controllerContract;
    address accessControlContract;
    address metadataContract;
    address moveRoleContract;
  }

  struct LatestMintableVersion {
    uint256 versionNumber;
    address controllerContract;
  }
}
