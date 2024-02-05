// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./interfaces/IVaultBuilder.sol";
import "./interfaces/IMetaWealthModerator.sol";
import "./AssetVault.sol";

contract VaultBuilder is
    IVaultBuilder,
    Context,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /// @notice MetaWealth moderator contract for currency and whitelist checks
    IMetaWealthModerator public metawealthMod;

    /// @notice Maintain a list of all the tokens fractionalized by the factory
    /// @dev Mapping is from collection address => NFT ID => Fractional Asset address
    mapping(address => mapping(uint256 => address)) tokenFractions;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize exchange contract with necessary factories
    /// @param metawealthMod_ is the moderator contract of MetaWealth platform
    function initialize(IMetaWealthModerator metawealthMod_)
        public
        initializer
    {
        __Ownable_init();
        __UUPSUpgradeable_init();
        metawealthMod = metawealthMod_;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function fractionalize(
        address collection,
        uint256 tokenId,
        uint256 totalShares,
        bytes32[] calldata _merkleProof
    ) public override returns (address newVault) {
        require(
            metawealthMod.checkWhitelist(_merkleProof, _msgSender()),
            "FractionalizedAsset: Access forbidden"
        );
        require(
            IERC721(collection).ownerOf(tokenId) == _msgSender(),
            "Fractionalize: Not owner"
        );
        require(
            tokenFractions[collection][tokenId] == address(0),
            "Fractionalize: Already fractionalized"
        );

        newVault = address(
            new AssetVault(_msgSender(), totalShares, metawealthMod)
        );

        tokenFractions[collection][tokenId] = newVault;
        IERC721(collection).transferFrom(_msgSender(), newVault, tokenId);
        emit AssetFractionalized(collection, tokenId, totalShares, newVault);
    }

    function _msgSender()
        internal
        view
        virtual
        override(Context, ContextUpgradeable)
        returns (address)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(Context, ContextUpgradeable)
        returns (bytes calldata)
    {
        return super._msgData();
    }
}
