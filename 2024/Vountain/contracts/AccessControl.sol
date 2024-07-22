// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./TypeLibrary.sol";

/// @title Vountain – AccessControl
/// @notice Contract for managing access roles.
/// Access roles are needed for interaction with violin states and metadata.
/// Contract has to be connected with the Controller Contract.

contract AccessControl is Ownable, ERC721Enumerable {
  IConnectContract connectContract;

  constructor(
    address connectContract_
  ) ERC721("Vountain String Instrument Role", "VSIR") {
    connectContract = IConnectContract(connectContract_);
  }

  using Strings for uint256;
  using Counters for Counters.Counter;
  Counters.Counter tokensMinted;

  event MintedRole(
    address indexed assignee,
    uint256 indexed violinID,
    uint256 indexed tokenID,
    string roleType
  );

  event ChangedValidity(
    address indexed assignee,
    uint256 indexed violinID,
    uint256 timestamp,
    string roleType
  );

  event ChangedMetadata(uint256 indexed violinID);

  event BurnedToken(
    address indexed targetAccount_,
    uint256 indexed violinId_,
    string affectedRole_
  );

  mapping(uint256 => RCLib.AccessToken) public _accessTokenProperties;
  mapping(uint256 => uint256[]) public _accessTokensOfViolin;

  function removeTokenFromViolin(uint256 violinId, uint256 tokenId) internal {
    uint256[] storage tokens = _accessTokensOfViolin[violinId];
    uint256 length = tokens.length;

    for (uint256 i = 0; i < length; i++) {
      if (tokens[i] == tokenId) {
        tokens[i] = tokens[length - 1];
        tokens.pop();
        return;
      }
    }
  }

  /// @dev Only if the Controller Contract is set the functions can be called.
  /// The modifier checks, if the caller has the correct address.

  modifier onlyAllowedContract(uint256 tokenID_) {
    address controller = connectContract.getControllerContract(tokenID_);
    require(msg.sender == controller, "Caller is not the allowed contract");
    _;
  }

  modifier onlyAdministrativeContract(uint256 tokenID_) {
    address controller = connectContract.getMoveRoleContract(tokenID_);
    require(msg.sender == controller, "Caller is not the allowed contract");
    _;
  }

  function changeMetadata(
    uint256 tokenId_,
    string memory description_,
    string memory image_
  ) public onlyAllowedContract(tokenId_) {
    _accessTokenProperties[tokenId_].description = description_;
    _accessTokenProperties[tokenId_].image = image_;
    emit ChangedMetadata(tokenId_);
  }

  /// @dev Function [setTimestamp]
  /// If the function finds a matching token, the new timestamp is set.
  /// @param violinId_ a corresponding violin token id as input.
  /// @param timestamp_ a timestamp which defines the new validity of the token
  /// @param targetAccount_ a target address which is affected by the change
  /// @param role_ a role which is affected by the change
  function setTimestamp(
    uint256 violinId_,
    uint256 timestamp_,
    address targetAccount_,
    RCLib.Role role_
  ) external onlyAllowedContract(violinId_) {
    uint256[] memory tokens = tokensOfOwner(targetAccount_);
    require(tokens.length > 0, "no token found");
    for (uint256 i = 0; i < tokens.length; i++) {
      RCLib.AccessToken memory token = _accessTokenProperties[tokens[i]];
      if (role_ == token.role && violinId_ == token.violinID) {
        _accessTokenProperties[tokens[i]].contractValidUntil = timestamp_;
        emit ChangedValidity(
          targetAccount_,
          violinId_,
          timestamp_,
          getRolenameByRole(role_)
        );
      }
    }
  }

  /// @dev Function[tokensOfOwner]
  /// If the functions finds tokens and returns the corresponding token ids in an array.
  /// @param owner_ an address of a role owner, which should be checked
  function tokensOfOwner(address owner_) public view returns (uint256[] memory) {
    uint256 tokenCount = balanceOf(owner_);

    uint256[] memory tokensId = new uint256[](tokenCount);
    for (uint256 i; i < tokenCount; i++) {
      tokensId[i] = tokenOfOwnerByIndex(owner_, i);
    }
    return tokensId;
  }

  /// @dev Function[tokensOfViolin]
  /// If the functions finds tokens and returns the corresponding token ids in an array.
  /// @param violinId_ the violinId to be checked
  function tokensOfViolin(uint256 violinId_) public view returns (uint256[] memory) {
    return _accessTokensOfViolin[violinId_];
  }

  /// @dev Function[returnCorrespondingTokenID]
  /// It will be checked if the account already has a token.
  /// It is not dependend on a validity of the token.
  /// @param addr_ an address to be checked for a specific token
  /// @param role_ the corresponding role which should be checked
  /// @param violinId_ the corresponding violin id which should be checked
  /// @return foundToken the the tokenId if token was found
  function returnCorrespondingTokenID(
    address addr_,
    RCLib.Role role_,
    uint256 violinId_
  ) public view returns (uint256 foundToken) {
    //check which tokens the address has
    uint256[] memory tokens = tokensOfOwner(addr_);

    //loop through the tokens and check if a token matches the query
    for (uint256 i = 0; i < tokens.length; i++) {
      if (
        role_ == _accessTokenProperties[tokens[i]].role &&
        violinId_ == _accessTokenProperties[tokens[i]].violinID
      ) {
        foundToken = tokens[i];
        return foundToken;
      }
    }
    revert("no token found");
  }

  /// @dev Function[checkIfAddressHasAccess]
  /// It will be checked if a specific address has the right role with a valid date.
  /// @param addr_ an address to check
  /// @param role_ the corresponding role to check
  /// @param violinId_ the corresponding violion ID to check
  function checkIfAddressHasAccess(
    address addr_,
    RCLib.Role role_,
    uint256 violinId_
  ) public view returns (bool) {
    //extracts all tokens with ids from the owner
    uint256[] memory tokens = tokensOfOwner(addr_);
    for (uint256 i = 0; i < tokens.length; i++) {
      RCLib.AccessToken memory token = _accessTokenProperties[tokens[i]];

      if (
        role_ == token.role &&
        violinId_ == token.violinID &&
        block.timestamp < token.contractValidUntil
      ) {
        return true;
      }
    }
    return false;
  }

  /// @dev Function[getRolenameByRole]
  /// Function returns the corresponding string.
  /// This is needed for the metadata generation.
  /// @param role_ a role is given
  function getRolenameByRole(RCLib.Role role_) public pure returns (string memory) {
    if (role_ == RCLib.Role.OWNER_ROLE) {
      return "Owner";
    } else if (role_ == RCLib.Role.VOUNTAIN) {
      return "Vountain";
    } else if (role_ == RCLib.Role.INSTRUMENT_MANAGER_ROLE) {
      return "Manager";
    } else if (role_ == RCLib.Role.MUSICIAN_ROLE) {
      return "Artist";
    } else if (role_ == RCLib.Role.VIOLIN_MAKER_ROLE) {
      return "Violin Maker";
    } else if (role_ == RCLib.Role.EXHIBITOR_ROLE) {
      return "Exhibitor";
    } else {
      revert("No role found");
    }
  }

  /// @dev Function[mintRole]
  /// Function mints the token and sets the attributes as state in a mapping.
  /// @param assignee_ an assignee who should get the role
  /// @param role_ the role which should be minted
  /// @param contractValidUntil_ the contract validity date
  /// @param violinId_ the corresponding violin
  /// @param image_ an image for the metadata
  /// @param description_ a description for the metadata
  function mintRole(
    address assignee_,
    RCLib.Role role_,
    uint256 contractValidUntil_,
    uint256 violinId_,
    string memory image_,
    string memory description_
  ) external onlyAllowedContract(violinId_) {
    tokensMinted.increment();
    uint256 nextToken = tokensMinted.current();
    _safeMint(assignee_, nextToken);
    _accessTokenProperties[nextToken].role = role_;
    _accessTokenProperties[nextToken].violinID = violinId_;
    _accessTokenProperties[nextToken].contractValidUntil = contractValidUntil_;
    _accessTokenProperties[nextToken].description = description_;
    _accessTokenProperties[nextToken].image = image_;
    _accessTokensOfViolin[violinId_].push(nextToken);

    emit MintedRole(assignee_, violinId_, nextToken, getRolenameByRole(role_));
  }

  /// @dev Function[tokenURI]
  /// returns the metadata of the token in ERC721 standard
  /// @param tokenId_ a token id to generate the metadata
  function tokenURI(
    uint256 tokenId_
  ) public view virtual override returns (string memory) {
    _requireMinted(tokenId_);

    string memory image = _accessTokenProperties[tokenId_].image;
    uint256 valid = _accessTokenProperties[tokenId_].contractValidUntil;
    string memory role = getRolenameByRole(_accessTokenProperties[tokenId_].role);
    uint256 violinID = _accessTokenProperties[tokenId_].violinID;
    string memory description = _accessTokenProperties[tokenId_].description;

    string memory attributes = string.concat(
      '[{"trait_type": "Contract Valid Until", "value":"',
      valid.toString(),
      '"},{"trait_type": "Role", "value":"',
      role,
      '"},{"trait_type": "ViolinID", "value":"',
      violinID.toString(),
      '"}]'
    );

    bytes memory dataURI = abi.encodePacked(
      "{",
      '"name": "',
      role,
      " Access Token: Violin #",
      violinID.toString(),
      '",',
      '"description":'
      '"',
      description,
      '",',
      '"image": "',
      image,
      '",',
      '"attributes": ',
      attributes,
      "}"
    );

    return
      string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
  }

  /// @dev Function[burnTokens]
  /// Only the allowed contract can initiate the burn.
  /// @param targetAccount_ target account who holds the token to be burned
  /// @param affectedRole_ affected role of the token which should be burned
  /// @param violinId_ corresponding violin id of the token which should be burned
  function burnTokens(
    address targetAccount_,
    RCLib.Role affectedRole_,
    uint256 violinId_
  ) public onlyAllowedContract(violinId_) {
    uint256 tokenToBurn = returnCorrespondingTokenID(
      targetAccount_,
      affectedRole_,
      violinId_
    );
    _burn(tokenToBurn);
    removeTokenFromViolin(violinId_, tokenToBurn);
    emit BurnedToken(targetAccount_, violinId_, getRolenameByRole(affectedRole_));
  }

  function administrativeCleanup(
    uint256 violinId_
  ) public onlyAdministrativeContract(violinId_) {
    uint256[] memory tokens = _accessTokensOfViolin[violinId_];
    for (uint256 i = 0; i < tokens.length; i++) {
      _burn(tokens[i]);
      _accessTokenProperties[tokens[i]].contractValidUntil = block.timestamp;
    }
    delete _accessTokensOfViolin[violinId_];
  }

  /**
   * @dev function to check if a role already matched to a violin
   * @param violinId_ the violin to check
   * @param role_ the role to check
   */
  function roleAlreadyActive(
    uint256 violinId_,
    RCLib.Role role_
  ) public view returns (bool) {
    uint256[] memory tokens = tokensOfViolin(violinId_);
    for (uint256 i = 0; i < tokens.length; i++) {
      if (
        _accessTokenProperties[tokens[i]].role == role_ &&
        _accessTokenProperties[tokens[i]].contractValidUntil > block.timestamp
      ) {
        return true;
      }
    }
    return false;
  }

  /// @dev Function[administrativeMove]
  /// Only the allowed contract can move the tokens.
  /// @param from_ a source address which helds the token
  /// @param to_ a destination address
  /// @param tokenId_ the corresponding tokenid
  function administrativeMove(
    address from_,
    address to_,
    uint256 violinId_,
    uint256 tokenId_
  ) public onlyAdministrativeContract(violinId_) {
    _transfer(from_, to_, tokenId_);
  }

  /// @dev Function[_beforeTokenTransfer]
  /// function overrides the _beforeTokenTransfer to make it semi soulbound
  /// only the allowed contract can move the tokens users can burn their tokens by themself
  /// @param from_ address of the sender
  /// @param to_ address of the receiver
  /// @param tokenId_ which token Id to transfer
  /// @param batchSize_ is non-zero
  function _beforeTokenTransfer(
    address from_,
    address to_,
    uint256 tokenId_,
    uint256 batchSize_
  ) internal virtual override(ERC721Enumerable) {
    address controller = connectContract.getControllerContract(
      _accessTokenProperties[tokenId_].violinID
    );
    address mover = connectContract.getMoveRoleContract(
      _accessTokenProperties[tokenId_].violinID
    );
    require(
      from_ == address(0) ||
        to_ == address(0) ||
        msg.sender == controller ||
        msg.sender == mover,
      "NonTransferrableERC721Token: non transferrable"
    );

    super._beforeTokenTransfer(from_, to_, tokenId_, batchSize_);
  }
}
