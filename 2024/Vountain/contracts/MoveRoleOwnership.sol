// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "./ConnectContract.sol";
import "./Configuration.sol";
import "./TypeLibrary.sol";

/// @title Vountain – MoveRoleOwnership
/// @notice It should be possible, that in an emergency the access tokens can be moved by Vountain.
///         The owner token should be moveable by Vountain and by the asset owner.

contract MoveRoleOwnership is Ownable {
  IConfigurationContract configurationContract;
  IConnectContract connectContract;

  address public BURN = 0x000000000000000000000000000000000000dEaD;

  constructor(address configurationContract_, address connectContract_) {
    configurationContract = IConfigurationContract(configurationContract_);
    connectContract = IConnectContract(connectContract_);
  }

  /// @dev the owner role gets checked and
  /// @param to_ address of the receiver
  /// @param violinID_ token ID to check
  function sendOwnerToken(address to_, uint256 violinID_) public {
    RCLib.ContractCombination memory readContracts = connectContract
      .getContractsForVersion(violinID_);
    IAccessControl accessControl = IAccessControl(readContracts.accessControlContract);
    IViolineMetadata metadata = IViolineMetadata(readContracts.metadataContract);

    require(
      accessControl.checkIfAddressHasAccess(msg.sender, RCLib.Role.OWNER_ROLE, violinID_),
      "account has no owner role"
    );

    // Get ID for specific token
    uint256 roleTokenID = accessControl.returnCorrespondingTokenID(
      msg.sender,
      RCLib.Role.OWNER_ROLE,
      violinID_
    );
    metadata.setTokenOwner(violinID_, to_);

    if (metadata.readLocation(violinID_) == msg.sender) {
      metadata.setViolinLocation(violinID_, to_);
    }

    // if token was found then move the token
    accessControl.administrativeMove(msg.sender, to_, violinID_, roleTokenID);
  }

  /// @dev Owner can move his token
  /// @param from_ address of the owner
  /// @param to_ address of the receiver
  /// @param violinID_ which token to move
  function claimOwnerToken(
    address from_,
    address to_,
    uint256 violinID_
  ) public {
    RCLib.ContractCombination memory readContracts = connectContract
      .getContractsForVersion(violinID_);

    IAccessControl accessControl = IAccessControl(readContracts.accessControlContract);
    IViolines violin = IViolines(connectContract.violinAddress());
    IViolineMetadata metadata = IViolineMetadata(readContracts.metadataContract);

    require(
      accessControl.checkIfAddressHasAccess(from_, RCLib.Role.OWNER_ROLE, violinID_),
      "account has no owner role"
    );

    require(msg.sender == violin.ownerOf(violinID_), "you can only move your violins");

    uint256 roleTokenID = accessControl.returnCorrespondingTokenID(
      from_,
      RCLib.Role.OWNER_ROLE,
      violinID_
    );
    metadata.setTokenOwner(violinID_, to_);
    if (metadata.readLocation(violinID_) == from_) {
      metadata.setViolinLocation(violinID_, to_);
    }

    accessControl.administrativeMove(from_, to_, violinID_, roleTokenID);
  }

  /// @dev move a role token
  /// @param from_ address of the owner
  /// @param role_ which role token to move
  /// @param to_ address of the receiver
  /// @param violinID_ which token to moves
  function moveRoleToken(
    address from_,
    RCLib.Role role_,
    address to_,
    uint256 violinID_
  ) public {
    RCLib.ContractCombination memory readContracts = connectContract
      .getContractsForVersion(violinID_);
    IAccessControl accessControl = IAccessControl(readContracts.accessControlContract);
    IViolineMetadata metadata = IViolineMetadata(readContracts.metadataContract);

    require(msg.sender == owner(), "you can't move that token");

    uint256 roleTokenID = accessControl.returnCorrespondingTokenID(
      from_,
      role_,
      violinID_
    );

    if (role_ == RCLib.Role.MUSICIAN_ROLE) {
      metadata.setTokenArtist(violinID_, to_);
    } else if (role_ == RCLib.Role.INSTRUMENT_MANAGER_ROLE) {
      metadata.setTokenManager(violinID_, to_);
    } else if (role_ == RCLib.Role.VIOLIN_MAKER_ROLE) {
      metadata.setTokenViolinMaker(violinID_, to_);
    } else if (role_ == RCLib.Role.EXHIBITOR_ROLE) {
      metadata.setExhibitor(violinID_, to_);
    } else if (role_ == RCLib.Role.OWNER_ROLE) {
      metadata.setTokenOwner(violinID_, to_);
    }

    accessControl.administrativeMove(from_, to_, violinID_, roleTokenID);
    if (metadata.readLocation(violinID_) == from_) {
      metadata.setViolinLocation(violinID_, to_);
    }
  }

  function adminstrativeCleanup(uint256 violinID_) public {
    RCLib.ContractCombination memory readContracts = connectContract
      .getContractsForVersion(violinID_);
    IAccessControl accessControl = IAccessControl(readContracts.accessControlContract);
    IViolines violines = IViolines(connectContract.violinAddress());

    require(msg.sender == owner(), "only owner can clean");
    require(violines.ownerOf(violinID_) == BURN, "only for burned violines");

    accessControl.administrativeCleanup(violinID_);
  }
}
