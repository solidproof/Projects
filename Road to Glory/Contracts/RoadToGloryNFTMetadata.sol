// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./IRoadToGloryNFTMetadata.sol";
import "./BarbarianMetadata.sol";
import "./Random.sol";

contract RoadToGloryNFTMetadata is
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IRoadToGloryNFTMetadata
{
    using BarbarianMetadataLib for BarbarianMetadataLib.BarbarianMetadataStruct;
    bool private _initialized;

    uint256[] private _raritiesRate;
    uint256[] private _perksRate;
    uint256[] private _numberOfPerksPerRarity;


    function initialize(address _owner) public initializer {
            require(!_initialized, "Contract already initialized.");
            _initialized = true;

            __AccessControl_init();
            __Context_init();
            __Pausable_init();
            _setupRole(DEFAULT_ADMIN_ROLE, _owner);

            _raritiesRate = [1800, 7423, 588, 124, 60, 5];
            _perksRate = [5000, 3500, 1500];
            _numberOfPerksPerRarity = [1, 3, 6, 9, 12, 17];
    }

    function create_random_metadata(uint256 seed, uint256 id, uint256 rarity) external view override returns (BarbarianMetadataLib.BarbarianMetadataStruct memory) {
        BarbarianMetadataLib.BarbarianMetadataStruct memory data;
        data.id = id;

        if (rarity != 255) {
            require(rarity <= 5, "Rarity over limit");
            data.rarity = uint8(rarity);
        }
        else {
            uint256 tmp;
            (seed, tmp) = Random.randWeighted(seed, _raritiesRate);
            data.rarity = uint8(tmp);
        }
        uint256 tmp256;
        (seed, tmp256) = Random.rand(seed, 50);
        data.skin = uint16(tmp256);
        (seed, tmp256) = Random.randRange(seed, 50, 250);
        data.vitality = uint16(tmp256);
        (seed, tmp256) = Random.randRange(seed, 50, 250);
        data.force = uint16(tmp256);
        (seed, tmp256) = Random.randRange(seed, 50, 250);
        data.agility = uint16(tmp256);
        (seed, tmp256) = Random.randRange(seed, 50, 250);
        data.speed = uint16(tmp256);
        data.perks = create_random_perks(seed, data.rarity);
        return data;
    }

    function create_random_perks(uint256 seed, uint256 rarity) internal view returns (uint16[] memory perks) {
        perks = new uint16[](_numberOfPerksPerRarity[rarity]);
        uint256 tmp256;
        uint256 j = 0;
        for (uint256 i = 0; i < _numberOfPerksPerRarity[rarity]; ++i) {
            (seed, tmp256) = Random.randWeighted(seed, _perksRate);
            uint256 tmpPerk = 0;
            if (tmp256 == 0) {
                (seed, tmpPerk) = Random.randRange(seed, 0, 36);
                perks[j++] = uint16(tmpPerk);
            } else if (tmp256 == 1) {
                (seed, tmpPerk) = Random.randRange(seed, 37, 52);
                perks[j++] = uint16(tmpPerk);
            } else {
                (seed, tmpPerk) = Random.randRange(seed, 53, 56);
                perks[j++] = uint16(tmpPerk);
            }
        }
    }
}