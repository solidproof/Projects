// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

abstract contract IMetadata {
  function callTokenURI(uint256 tokenId_) external view virtual returns (string memory);
}

abstract contract IConnectContract {
  struct LatestMintableVersion {
    uint256 versionNumber;
    address controllerContract;
  }

  function setViolinToContractVersion(uint256 violinID_, uint256 version_)
    external
    virtual;

  function getMetadataContract(uint256 violinID_)
    external
    view
    virtual
    returns (address metadataContract);

  function latest() public view virtual returns (LatestMintableVersion memory latest);
}

/// @title Vountain – Violin
/// @notice Manage the Violins

contract Violin is Ownable, ERC721Enumerable {
  address private _allowedContract;
  IConnectContract connectContract;

  event MintEvent(address indexed minter, uint256 tokenId);

  constructor(address connectContract_) ERC721("Vountain String Instrument", "VSI") {
    connectContract = IConnectContract(connectContract_);
  }

  //Functions to check allowed contract for state changes:
  //-----------------------------------------------------

  function tokenURI(uint256 tokenId_)
    public
    view
    virtual
    override
    returns (string memory)
  {
    _requireMinted(tokenId_);
    IMetadata metadata = IMetadata(connectContract.getMetadataContract(tokenId_));
    return metadata.callTokenURI(tokenId_);
  }

  /// @param tokenId_ which violin ID to mint
  /// @param addr_ receiving address
  function mintViolin(uint256 tokenId_, address addr_) external {
    require(
      connectContract.latest().controllerContract == msg.sender,
      "only latest version can mint"
    );
    connectContract.setViolinToContractVersion(
      tokenId_,
      connectContract.latest().versionNumber
    );
    _safeMint(addr_, tokenId_);
    emit MintEvent(addr_, tokenId_);
  }
}
