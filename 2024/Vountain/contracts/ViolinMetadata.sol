// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./TypeLibrary.sol";

/// @title Vountain – Violin
/// @notice Manage the Violins

contract ViolinMetadata is Ownable {
  using Strings for uint256;

  IConnectContract connectContract;

  mapping(uint256 => RCLib.TokenAttributes) public _tokenState;

  string public baseURL = "https://vountain.io/asset/";

  constructor(address connectContract_) {
    connectContract = IConnectContract(connectContract_);
  }

  event ChangedRole(address indexed user, uint256 indexed tokenID, string roleType);
  event ChangedLocation(address indexed user, uint256 indexed tokenID, string message);
  event CreatedEvent(
    uint256 indexed tokenId,
    uint256 indexed requestId,
    RCLib.Tasks eventType,
    string message
  );
  event CreatedDocument(
    uint256 indexed tokenId,
    uint256 indexed requestId,
    string message
  );
  event ChangedMetadata(uint256 indexed tokenID, string message);

  //Functions to check allowed contract for state changes:
  //-----------------------------------------------------
  modifier onlyAllowedContract(uint256 tokenId_) {
    address controller = connectContract.getControllerContract(tokenId_);
    address mover = connectContract.getMoveRoleContract(tokenId_);
    require(
      msg.sender == controller || msg.sender == mover,
      "Ownable: caller is not the allowed contract"
    );
    _;
  }

  function setBaseURL(string memory baseURL_) public onlyOwner {
    baseURL = baseURL_;
  }

  function readManager(uint256 tokenId_) public view returns (address) {
    return (_tokenState[tokenId_].manager);
  }

  function readLocation(uint256 tokenId_) public view returns (address) {
    return (_tokenState[tokenId_].violinLocation);
  }

  /// @param tokenId_ token ID
  /// @param owner_ new owner address
  function setTokenOwner(uint256 tokenId_, address owner_)
    external
    onlyAllowedContract(tokenId_)
  {
    _tokenState[tokenId_].owner = owner_;
    emit ChangedRole(owner_, tokenId_, "Owner");
  }

  /// @param tokenId_ token ID
  /// @param manager_ new manager address
  function setTokenManager(uint256 tokenId_, address manager_)
    external
    onlyAllowedContract(tokenId_)
  {
    _tokenState[tokenId_].manager = manager_;
    emit ChangedRole(manager_, tokenId_, "Manager");
  }

  // @param tokenId_ token ID
  /// @param exhibitor_ new exhibitor address
  function setExhibitor(uint256 tokenId_, address exhibitor_)
    external
    onlyAllowedContract(tokenId_)
  {
    _tokenState[tokenId_].exhibitor = exhibitor_;
    emit ChangedRole(exhibitor_, tokenId_, "Exhibitor");
  }

  /// @param tokenId_ token ID
  /// @param artist_ new artist address
  function setTokenArtist(uint256 tokenId_, address artist_)
    external
    onlyAllowedContract(tokenId_)
  {
    _tokenState[tokenId_].artist = artist_;
    emit ChangedRole(artist_, tokenId_, "Musician");
  }

  /// @param tokenId_ token ID
  /// @param violinMaker_ new violin maker address
  function setTokenViolinMaker(uint256 tokenId_, address violinMaker_)
    external
    onlyAllowedContract(tokenId_)
  {
    _tokenState[tokenId_].violinMaker = violinMaker_;
    emit ChangedRole(violinMaker_, tokenId_, "Violin Maker");
  }

  /// @param tokenId_ token ID
  /// @param violinLocation_ new violin location address
  function setViolinLocation(uint256 tokenId_, address violinLocation_)
    external
    onlyAllowedContract(tokenId_)
  {
    _tokenState[tokenId_].violinLocation = violinLocation_;
    emit ChangedLocation(violinLocation_, tokenId_, "Changed Location");
  }

  function getViolinByTokenId(uint256 tokenId_)
    public
    view
    returns (RCLib.TokenAttributes memory)
  {
    return _tokenState[tokenId_];
  }

  /// @param docType_ specify the document type: PROVENANCE, DOCUMENT, SALES
  /// @param date_ timestamp of the event
  /// @param cid_ file attachments
  /// @param title_ title of the Document
  /// @param description_ description of the doc
  /// @param source_ source of the doc
  /// @param value_ amount of the object
  /// @param valueOriginalCurrency_ in which currency it was sold
  /// @param originalCurrency_ inital currency the item was sold
  /// @param tokenId_ token ID

  function createNewDocument(
    uint256 requestId_,
    string memory docType_,
    int256 date_,
    string memory cid_,
    string memory title_,
    string memory description_,
    string memory source_,
    uint256 value_,
    uint256 valueOriginalCurrency_,
    string memory originalCurrency_,
    uint256 tokenId_
  ) external onlyAllowedContract(tokenId_) {
    RCLib.CreatedDocument memory createdDocument;

    createdDocument.docType = docType_;
    createdDocument.date = date_;
    createdDocument.cid = cid_;
    createdDocument.title = title_;
    createdDocument.description = description_;
    createdDocument.source = source_;
    createdDocument.value = value_;
    createdDocument.valueOriginalCurrency = valueOriginalCurrency_;
    createdDocument.originalCurrency = originalCurrency_;
    createdDocument.requestId = requestId_;

    _tokenState[tokenId_].document.push(createdDocument);
    emit CreatedDocument(tokenId_, requestId_, "Created Document");
  }

  /// @param name_ event name
  /// @param description_ description of event
  /// @param role_ a role which is affected by the change
  /// @param attendee_ event attendees
  /// @param eventStartTimestamp_ timestamp of the event
  /// @param eventEndTimestamp_ timestamp end of the event
  /// @param eventType_ type of the event
  /// @param tokenId_ token ID
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
    uint256 tokenId_
  ) external onlyAllowedContract(tokenId_) {
    RCLib.CreatedEvent memory createdEvent;

    createdEvent.name = name_;
    createdEvent.description = description_;
    createdEvent.role = role_;
    createdEvent.attendee = attendee_;
    createdEvent.eventStartTimestamp = eventStartTimestamp_;
    createdEvent.eventEndTimestamp = eventEndTimestamp_;
    createdEvent.link = link;
    createdEvent.geolocation = geolocation;
    createdEvent.file = file;
    createdEvent.requestId = requestId_;

    if (eventType_ == RCLib.Tasks.ADD_CONCERT) {
      _tokenState[tokenId_].concert.push(createdEvent);
    } else if (eventType_ == RCLib.Tasks.ADD_EXHIBITION) {
      _tokenState[tokenId_].exhibition.push(createdEvent);
    } else if (eventType_ == RCLib.Tasks.ADD_REPAIR) {
      _tokenState[tokenId_].repair.push(createdEvent);
    }
    emit CreatedEvent(tokenId_, requestId_, eventType_, "Created Event");
  }

  /// @param name_ violin name
  /// @param description_ description of violin
  /// @param longDescription_ long description of violin
  /// @param image_ image uri to the asset
  /// @param media_ media_ uri to the asset
  /// @param model3d_ 3D model file of the asset
  /// @param attributeNames_ array of attributes based in NFT STandard
  /// @param attributeValues_ array of values based in NFT STandard
  /// @param tokenId_ token ID
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
  ) external onlyAllowedContract(tokenId_) {
    RCLib.Metadata memory metadata;

    metadata.name = name_;
    metadata.description = description_;
    metadata.longDescription = longDescription_;
    metadata.image = image_;
    metadata.media = media_;
    metadata.model3d = model3d_;
    metadata.attributeNames = attributeNames_;
    metadata.attributeValues = attributeValues_;

    _tokenState[tokenId_].metadata = metadata;

    emit ChangedMetadata(tokenId_, "Changed Metadata");
  }

  /// @param tokenId_ token ID
  function callTokenURI(uint256 tokenId_) public view virtual returns (string memory) {
    RCLib.Metadata memory meta = _tokenState[tokenId_].metadata;
    string memory imagePath = meta.image;
    string memory description = meta.description;
    string memory violinName = meta.name;

    string memory comma = ",";
    string memory attributes = "[";
    if (meta.attributeNames.length > 0) {
      for (uint256 i = 0; i < meta.attributeNames.length; i++) {
        if (i == meta.attributeNames.length - 1) {
          comma = "";
        }
        attributes = string.concat(
          attributes,
          '{"trait_type": "',
          meta.attributeNames[i],
          '","value":"',
          meta.attributeValues[i],
          '"}',
          comma
        );
      }
    }
    attributes = string.concat(attributes, "]");

    string memory externalLink = string.concat(
      baseURL,
      Strings.toHexString(uint256(uint160(connectContract.violinAddress())), 20),
      "/",
      tokenId_.toString()
    );

    bytes memory dataURI = abi.encodePacked(
      "{",
      '"name":"',
      violinName,
      '",'
      '"description":'
      '"',
      description,
      '",',
      '"external_link":'
      '"',
      externalLink,
      '",',
      '"image": "',
      imagePath,
      '",',
      '"attributes": ',
      attributes,
      "}"
    );
    return
      string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
  }
}
