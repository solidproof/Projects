// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title Walker World Staking Manager

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./VaultInterface.sol";
import "hardhat/console.sol";

contract WWStakingManager is Ownable {
    using MerkleProof for bytes32[];

    /// @notice If set to 'Archived', users will not be able to stake. Existing stakers can still unstake.
    enum State {
        Archived,
        Public
    }
    State private activeState;

    /// @notice 'pointsAdmin' is an assigned wallet with permissions to add a limited amount of points.
    address private pointsAdmin;

    /// @notice A reference to the vault contract that holds marketplace items to claim.
    /// @dev Vault interface contains one funciton that transfers items to eligible claimer upon redeeming points.
    VaultInterface public vault;

    /// @dev Used for comparisons
    enum StakeType {
        ERC721,
        ERC1155,
        ERC20
    }

    uint16[] private collectionIds;
    uint256[] private leagueHurdles;
    uint256 public squadMultiplier;

    /// @dev premiumLevel and secondaryLevel are index references of multipliers for _collections[x].premiumMultipliers[y] and _collections[x].secondaryMultipliers[y]
    // + 1 to use without zero comparison
    struct StakingInfo {
        uint256 timestamp;
        uint16 premiumLevel;
        uint16 secondaryLevel;
    }

    struct Non721amounts {
        uint256 timestamp;
        uint256 amount;
    }

    /// @dev Collection based info stored with this data structure.
    /// @notice Staker will benefit from additional points if they own an ID with a trait that has been defined as premium. Premium traits are predefined and verified here using Merkle Proofs.
    struct CollectionInfo {
        bool isSet;
        IERC721 collection721;
        IERC1155 collection1155;
        IERC20 token20;
        StakeType stakeType;
        uint16 index; // 1155 ID or 721 start index
        bytes32 rootHash;
        uint16 pointMultiplier; // The multiplier for how many points accrued each day.
        uint16[] premiumMultipliers; // The multiplier for premium traits added on top 'pointMultiplier'
        uint16[] secondaryMultipliers; // Stackable multiplier like 'Zombie' or others traits
        mapping(uint16 => StakingInfo) stakingInfo;
        mapping(address => Non721amounts) non721amounts; // Used to store ERC1155 or ERC20 balance at time of stake
        uint16 squadHurdle;
    }
    mapping(uint16 => CollectionInfo) private _collections;

    /// @dev An item ID will be pushed to 'itemsClaimed' for every item claimed. Points are not stored on-chain but calculated based on a timestamp when staked. When items are claimed, redeemed points are stored in 'pointsRedeemed'. pointsAddOns is used by team to adjust points to addresses.
    struct UserItems {
        uint256 pointsRedeemed;
        uint256 pointsAfterUnstake;
        uint256 pointsAddOns;
        mapping(uint16 => uint16) totalItemsClaimed; // uint16 is vault id
    }
    mapping(address => UserItems) private userItems;

    /// @notice Claiming address is stored every time a 'PHYSICAL' marketplace item is claimed. Enables team to iterate over userItems off chain and award item IRL.
    /// @dev Mapping key is reference to vault ID
    struct ClaimedPhysical {
        address[] redeemer;
        uint16[] qty;
        uint256[] timestamp;
    }
    mapping(uint16 => ClaimedPhysical) private claimedPhysical;

    /// @dev Use this to limit amount of points a points admin can add
    uint256 private _maxAddablePoints = 5000;
    mapping(address => uint256) private pointsAdded;

    constructor() {
        activeState = State.Archived;
        pointsAdmin = msg.sender;
    }

    /// @notice Allows owner to update which vault to use.
    /// @param _vault Is the contract address of the new vault to set.
    function setVault(VaultInterface _vault) external onlyOwner {
        vault = _vault;
    }

    function isCollectionId(uint16 _cid) internal view returns (bool) {
        for (uint256 i = 0; i < collectionIds.length; i++) {
            if (collectionIds[i] == _cid) {
                return true;
            }
        }
        return false;
    }

    /// @dev Stakable collections set here. isSet create to later turn on/off collection if needed.
    function setERC721Collection(
        uint16 _cid,
        IERC721 _collection721,
        StakeType _type,
        uint16 _index
    ) external onlyOwner {
        _collections[_cid].isSet = true;
        _collections[_cid].collection721 = _collection721;
        _collections[_cid].stakeType = _type;
        _collections[_cid].index = _index;
        if (!isCollectionId(_cid)) {
            collectionIds.push(_cid);
        }
    }

    function setERC1155Collection(
        uint16 _cid,
        IERC1155 _collection1155,
        StakeType _type,
        uint16 _index
    ) external onlyOwner {
        _collections[_cid].isSet = true;
        _collections[_cid].collection1155 = _collection1155;
        _collections[_cid].stakeType = _type;
        _collections[_cid].index = _index;
        if (!isCollectionId(_cid)) {
            collectionIds.push(_cid);
        }
    }

    function setERC20Collection(
        uint16 _cid,
        IERC20 _token20,
        StakeType _type
    ) external onlyOwner {
        _collections[_cid].isSet = true;
        _collections[_cid].token20 = _token20;
        _collections[_cid].stakeType = _type;
        if (!isCollectionId(_cid)) {
            collectionIds.push(_cid);
        }
    }

    function setCollectionIds(uint16[] calldata _cids) external onlyOwner {
        delete collectionIds;
        for (uint256 i = 0; i < _cids.length; i++) {
            collectionIds.push(_cids[i]);
        }
    }

    /// @dev Combined setter for multipliers/hurdles on a collection basis
    function setPointsMultipliers(
        uint16 _cid,
        uint16 _pointMultiplier,
        uint16[] calldata _premiumMultipliers,
        uint16[] calldata _secondaryMultipliers,
        uint16 _squadHurdle
    ) external onlyOwner {
        _collections[_cid].pointMultiplier = _pointMultiplier;
        delete _collections[_cid].premiumMultipliers;
        delete _collections[_cid].secondaryMultipliers;
        for (uint16 i; i < _premiumMultipliers.length; ++i) {
            _collections[_cid].premiumMultipliers.push(_premiumMultipliers[i]);
        }
        for (uint16 i; i < _secondaryMultipliers.length; ++i) {
            _collections[_cid].secondaryMultipliers.push(
                _secondaryMultipliers[i]
            );
        }
        _collections[_cid].squadHurdle = _squadHurdle;
    }

    /// @dev This multiplier is at the contract level
    function setSquadMultiplier(uint256 _multiplier) external onlyOwner {
        squadMultiplier = _multiplier;
    }

    /// @dev Leagues are defined at the contract level
    function setLeagueHurdles(uint256[] calldata _vals) external onlyOwner {
        delete leagueHurdles;
        for (uint16 i; i < _vals.length; ++i) {
            leagueHurdles.push(_vals[i]);
        }
    }

    /// @dev Defined at the contract level. Also used when periodic updates needed to sets of premium traits needed.
    function setRootHash(uint16 _cid, bytes32 _rootHash) external onlyOwner {
        _collections[_cid].rootHash = _rootHash;
    }

    /// @dev Override premium traits on an individual basis. Root hash needs to be updated after this has been set.
    function overridePremiumIds(
        uint16 _cid,
        uint16[] calldata _tokenIds,
        uint16[] calldata _premiumMultipliers,
        uint16[] calldata _secondaryMultipliers,
        bytes32 _rootHash
    ) external onlyOwner {
        _collections[_cid].rootHash = _rootHash;
        for (uint16 i; i < _tokenIds.length; ++i) {
            _collections[_cid]
                .stakingInfo[_tokenIds[i]]
                .premiumLevel = _premiumMultipliers[i];
            _collections[_cid]
                .stakingInfo[_tokenIds[i]]
                .premiumLevel = _secondaryMultipliers[i];
        }
    }

    function setPointsAdmin(address _pointsAdmin, uint256 _maxPoints)
        external
        onlyOwner
    {
        pointsAdmin = _pointsAdmin;
        _maxAddablePoints = _maxPoints;
    }

    /// @notice Used by designated admin to compensate staker in case of error.
    function addPoints(address _staker, uint256 _pointsToAdd) external {
        require(msg.sender == pointsAdmin, "Not authorized");
        require(
            _pointsToAdd + pointsAdded[_staker] < _maxAddablePoints,
            "You have exceed the max points allowed to add to this address"
        );
        userItems[_staker].pointsAddOns += _pointsToAdd;
    }

    /// @notice Used by owner to compensate staker in case of error.
    function adminAddPoints(
        address[] calldata _staker,
        uint256[] calldata _pointsToAdd
    ) external onlyOwner {
        for (uint16 i; i < _staker.length; ++i) {
            userItems[_staker[i]].pointsAddOns += _pointsToAdd[i];
        }
    }

    /// @notice Used by owner in case of error from adding points
    function removePoints(address _staker, uint256 _pointsToRemove)
        external
        onlyOwner
    {
        require(
            _pointsToRemove <= userItems[_staker].pointsAddOns,
            "Points balance less than points to remove"
        );
        userItems[_staker].pointsAddOns -= _pointsToRemove;
    }

    function verifyTrait(
        bytes32 _rootHash,
        uint16 _tokenId,
        uint16 _premiumLevel,
        uint16 _secondaryLevel,
        bytes32[] calldata _proofs
    ) internal pure returns (bool) {
        return
            _proofs.verifyCalldata(
                _rootHash,
                keccak256(
                    abi.encodePacked(
                        uint256(_tokenId),
                        uint256(_premiumLevel),
                        uint256(_secondaryLevel)
                    )
                )
            );
    }

    function verifySquad(address _staker)
        internal
        view
        returns (bool hasSquad)
    {
        for (uint16 i; i < collectionIds.length; ++i) {
            uint16 cid = collectionIds[i];
            if (_collections[cid].squadHurdle > 0) {
                hasSquad = true;
                uint256 balance = _collections[cid].collection721.balanceOf(
                    _staker
                );
                if (balance < _collections[cid].squadHurdle) {
                    return false;
                }
            }
        }
        // Prevent false positive in the event all collection squadHurdle's are 0
        if (hasSquad) {
            return true;
        }
    }

    /// @notice Staking function for multiple collections.
    function stakeMultiple(
        uint16[] calldata _collectionIds,
        uint16[][] calldata _tokenIds,
        uint16[][] calldata _premiumMultipliers,
        uint16[][] calldata _secondaryMultipliers,
        bytes32[][][] calldata _proofs
    ) external {
        require(activeState == State.Public, "Staking system inactive");
        for (uint16 i; i < _collectionIds.length; ++i) {
            uint16 cid = _collectionIds[i];
            if (
                _collections[cid].isSet &&
                _collections[cid].stakeType == StakeType.ERC721
            ) {
                for (uint16 j; j < _tokenIds[i].length; ++j) {
                    uint16 tokenId = _tokenIds[i][j];
                    require(
                        _collections[cid].stakingInfo[tokenId].timestamp == 0,
                        "Already staked (ERC721)"
                    );
                    require(
                        _collections[cid].collection721.ownerOf(tokenId) ==
                            msg.sender,
                        "Not owner (ERC721)"
                    );
                    if (
                        _proofs[i].length != 0 &&
                        verifyTrait(
                            _collections[cid].rootHash,
                            tokenId,
                            _premiumMultipliers[i][j],
                            _secondaryMultipliers[i][j],
                            _proofs[i][j]
                        )
                    ) {
                        _collections[cid]
                            .stakingInfo[tokenId]
                            .premiumLevel = _premiumMultipliers[i][j];
                        _collections[cid]
                            .stakingInfo[tokenId]
                            .secondaryLevel = _secondaryMultipliers[i][j];
                    }

                    _collections[cid].stakingInfo[tokenId].timestamp = block
                        .timestamp;
                }
            }
            if (
                _collections[cid].isSet &&
                _collections[cid].stakeType == StakeType.ERC1155
            ) {
                uint256 amount = _tokenIds[i][0];
                uint256 balance = _collections[cid].collection1155.balanceOf(
                    msg.sender,
                    _collections[cid].index
                );
                require(balance >= amount, "Not owner (ERC1155)");
                require(
                    _collections[cid].non721amounts[msg.sender].timestamp == 0,
                    "Already staked (ERC1155)"
                );

                _collections[cid].non721amounts[msg.sender].amount = amount;
                _collections[cid].non721amounts[msg.sender].timestamp = block
                    .timestamp;
            }
            if (
                _collections[cid].isSet &&
                _collections[cid].stakeType == StakeType.ERC20
            ) {
                uint256 amount = _tokenIds[i][0];
                uint256 balance = _collections[cid].token20.balanceOf(
                    msg.sender
                );
                require(balance >= amount, "Not owner (ERC20)");
                require(
                    _collections[cid].non721amounts[msg.sender].timestamp == 0,
                    "Already staked (ERC20)"
                );

                _collections[cid].non721amounts[msg.sender].amount = amount;
                _collections[cid].non721amounts[msg.sender].timestamp = block
                    .timestamp;
            }
        }
    }

    /// @notice _unStake and _adminUnstake will use this fn to unstake.
    function unstakeTokens(
        address _staker,
        uint16[] calldata _collectionIds,
        uint16[][] calldata _idsToUnstake
    ) internal {
        bool isSquad = verifySquad(_staker);
        for (uint16 i; i < _collectionIds.length; ++i) {
            uint16 cid = _collectionIds[i];
            uint256 points;
            if (_collections[cid].stakeType == StakeType.ERC721) {
                for (uint16 j; j < _idsToUnstake[i].length; ++j) {
                    uint16 tokenId = _idsToUnstake[i][j];

                    require(
                        _collections[cid].stakingInfo[tokenId].timestamp >
                            1672560000,
                        "Token not staked (unstake 721)"
                    );
                    address tokenOwner = _collections[cid]
                        .collection721
                        .ownerOf(tokenId);

                    require(tokenOwner == _staker, "Not owner (unstake 721)");
                    points = getPoint(cid, tokenId, isSquad);
                    _collections[cid].stakingInfo[tokenId].timestamp = 0;
                    userItems[_staker].pointsAfterUnstake += points;
                }
            }
            if (
                _collections[cid].stakeType == StakeType.ERC1155 ||
                _collections[cid].stakeType == StakeType.ERC20
            ) {
                require(
                    _collections[cid].non721amounts[msg.sender].timestamp >= 0,
                    "Not staked (1155)"
                );
                points = getNon721Points(_staker, cid);
                userItems[_staker].pointsAfterUnstake += points;
                _collections[cid].non721amounts[msg.sender].amount = 0;
                _collections[cid].non721amounts[msg.sender].timestamp = 0;
            }
        }
    }

    /// @notice Allows staker to unstake their assets.
    function unStake(
        uint16[] calldata _collectionIds,
        uint16[][] calldata _tokenIds
    ) external {
        unstakeTokens(msg.sender, _collectionIds, _tokenIds);
    }

    function adminUnstake(
        address _staker,
        uint16[] calldata _collectionIds,
        uint16[][] calldata _tokenIds
    ) external onlyOwner {
        unstakeTokens(_staker, _collectionIds, _tokenIds);
    }

    function getCollectionInfo(uint16 _cid)
        external
        view
        returns (
            bool,
            StakeType,
            bytes32,
            uint16[] memory,
            uint16[] memory,
            uint16[] memory
        )
    {
        uint16[] memory grouped = new uint16[](3);
        grouped[0] = _collections[_cid].index;
        grouped[1] = _collections[_cid].pointMultiplier;
        grouped[2] = _collections[_cid].squadHurdle;
        return (
            _collections[_cid].isSet,
            _collections[_cid].stakeType,
            _collections[_cid].rootHash,
            _collections[_cid].premiumMultipliers,
            _collections[_cid].secondaryMultipliers,
            grouped
        );
    }

    function getCollectionAddresses(uint16 _cid)
        external
        view
        returns (
            IERC721,
            IERC1155,
            IERC20
        )
    {
        return (
            _collections[_cid].collection721,
            _collections[_cid].collection1155,
            _collections[_cid].token20
        );
    }

    function getTokenIdInfo(uint16 _cid, uint16 _tokenId)
        external
        view
        returns (
            uint256,
            uint16,
            uint16
        )
    {
        return (
            _collections[_cid].stakingInfo[_tokenId].timestamp,
            _collections[_cid].stakingInfo[_tokenId].premiumLevel,
            _collections[_cid].stakingInfo[_tokenId].secondaryLevel
        );
    }

    function getStakingInfo(uint16 _cid, address _staker)
        external
        view
        returns (
            //uint16[] calldata _tokenIds
            uint256 pointsAfterUnstake,
            uint256 pointsAddOns,
            uint256 pointsRedeemed,
            uint256 amount
        )
    {
        return (
            userItems[_staker].pointsAfterUnstake,
            userItems[_staker].pointsAddOns,
            userItems[_staker].pointsRedeemed,
            _collections[_cid].non721amounts[_staker].amount
        );
    }

    function getStakedTimestampsAndAmounts(
        uint16 _cid,
        address _staker,
        uint16[] calldata _tokenIds
    ) external view returns (uint256 amount, uint256[] memory) {
        uint256[] memory timestamps = new uint256[](_tokenIds.length);
        for (uint16 i; i < _tokenIds.length; ++i) {
            timestamps[i] = _collections[_cid]
                .stakingInfo[_tokenIds[i]]
                .timestamp;
        }
        return (_collections[_cid].non721amounts[_staker].amount, timestamps);
    }

    function getTotalItemsClaimed(address _staker, uint16 _vid)
        external
        view
        returns (uint16)
    {
        return userItems[_staker].totalItemsClaimed[_vid];
    }

    function getClaimedPhysical(uint16 _vid)
        external
        view
        returns (
            address[] memory redeemer,
            uint16[] memory qty,
            uint256[] memory timestamp
        )
    {
        return (
            claimedPhysical[_vid].redeemer,
            claimedPhysical[_vid].qty,
            claimedPhysical[_vid].timestamp
        );
    }

    function getPointsAdmin()
        external
        view
        onlyOwner
        returns (address, uint256)
    {
        return (pointsAdmin, _maxAddablePoints);
    }

    /// @notice Called when user with staked assets (Staker) intends to claim an item from the marketplace (vault). Points used here are stored in userItems.pointsRedeemed and later deducted from future points calculations.
    /// @dev Staker can claim multiple items from multiple collections at once.
    /// @param _vaultCollectionIds Array of collection indexes.
    /// @param _qtysToClaim Amount of a particular vault item a staker wishes to claim. Index of this array must match index of '_vaultCollectionIds' array.
    function claimItems(
        uint16[] calldata _vaultCollectionIds,
        uint16[] calldata _qtysToClaim,
        uint16[] calldata _collectionIds,
        uint16[][] calldata _tokenIds
    ) external {
        // Use pointsToRedeem to calculate required points to claim total requested items from marketpalce.
        uint256 pointsToRedeem;

        require(activeState == State.Public, "Staking system inactive");

        uint256 points = getPoints(msg.sender, _collectionIds, _tokenIds, true);

        uint16 league = getLeague(points);
        require(points > 0, "No points");

        // Loop through each vault collection user wants to claim from.
        for (uint16 i; i < _vaultCollectionIds.length; ++i) {
            uint16 vc = _vaultCollectionIds[i];
            uint16 q = _qtysToClaim[i];
            bool isPhysical;
            uint256 usedPoints;

            uint16 totalClaimed = userItems[msg.sender].totalItemsClaimed[vc] +
                q;
            userItems[msg.sender].totalItemsClaimed[vc] += q;

            (usedPoints, isPhysical) = vault.transferItems(
                msg.sender,
                vc,
                q,
                league,
                totalClaimed
            );
            pointsToRedeem += usedPoints;

            // If item is physical/virtual, use claimedPhysical and redeemerPointers to access data off chain
            if (isPhysical) {
                claimedPhysical[vc].redeemer.push(msg.sender);
                claimedPhysical[vc].qty.push(_qtysToClaim[i]);
                claimedPhysical[vc].timestamp.push(block.timestamp);
            }
        }
        require(pointsToRedeem <= points, "Insufficient points");
        // Store points redeemed from claiming to subtract from further points calculations
        userItems[msg.sender].pointsRedeemed += pointsToRedeem;
    }

    function getCollectionIds() external view returns (uint256[] memory) {
        uint256 collectionsLen = collectionIds.length;
        uint256[] memory cids = new uint256[](collectionsLen);
        for (uint16 i; i < collectionsLen; ++i) {
            cids[i] = collectionIds[i];
        }
        return cids;
    }

    function getLeagueHurdles() external view returns (uint256[] memory) {
        uint256 leagueLen = leagueHurdles.length;
        uint256[] memory hurdles = new uint256[](leagueLen);
        for (uint16 i; i < leagueLen; ++i) {
            hurdles[i] = leagueHurdles[i];
        }
        return hurdles;
    }

    function getLeague(uint256 _points) internal view returns (uint16) {
        uint16 league;
        for (uint16 i; i < leagueHurdles.length; ++i) {
            if (_points >= leagueHurdles[i]) {
                league = i;
            }
        }
        return league;
    }

    /// @dev Get points for specific token ID and called when getting all points for a staker
    function getPoint(
        //address _staker,
        uint16 _cid,
        uint16 _tokenId,
        bool isSquad
    ) internal view returns (uint256 points) {
        uint256 pointsDiff;
        if (_collections[_cid].stakingInfo[_tokenId].timestamp > 1672560000) {
            pointsDiff =
                (block.timestamp -
                    _collections[_cid].stakingInfo[_tokenId].timestamp) /
                1 days;
            // Used to suppress multiplication on result of a division warning
            uint256 pointsDiffCalc = 0 + pointsDiff;
            uint16 premiumBonus;
            uint16 secondaryBonus;
            uint256 squadBonus;

            if (_collections[_cid].stakingInfo[_tokenId].premiumLevel > 0) {
                uint16 level = _collections[_cid]
                    .stakingInfo[_tokenId]
                    .premiumLevel - 1;
                premiumBonus = _collections[_cid].premiumMultipliers[level];
            }

            if (_collections[_cid].stakingInfo[_tokenId].secondaryLevel > 0) {
                uint16 level = _collections[_cid]
                    .stakingInfo[_tokenId]
                    .secondaryLevel - 1;
                secondaryBonus = _collections[_cid].secondaryMultipliers[level];
            }

            if (isSquad) {
                squadBonus = squadMultiplier;
            }

            points +=
                pointsDiffCalc *
                ((_collections[_cid].pointMultiplier +
                    premiumBonus +
                    secondaryBonus) + squadBonus);
        }
        return points;
    }

    function getNon721Points(address _staker, uint16 _cid)
        internal
        view
        returns (uint256 points)
    {
        if (_collections[_cid].non721amounts[_staker].timestamp > 1672560000) {
            uint256 pointsDiff = (block.timestamp -
                _collections[_cid].non721amounts[_staker].timestamp) / 1 days;
            // Used to suppress multiplication on result of a division warning
            uint256 pointsDiffCalc = 0 + pointsDiff;
            return
                (pointsDiffCalc * _collections[_cid].pointMultiplier) *
                _collections[_cid].non721amounts[_staker].amount;
        }
        return 0;
    }

    /// @notice Returns points calculated on all staked assets for a particular user.
    function getPoints(
        address _staker,
        uint16[] calldata _collectionIds,
        uint16[][] calldata _tokenIds,
        bool _verifyOwnership
    ) public view returns (uint256 points) {
        bool isSquad = verifySquad(_staker);
        for (uint16 i; i < _collectionIds.length; ++i) {
            uint16 cid = _collectionIds[i];
            if (
                _collections[cid].isSet &&
                _collections[cid].stakeType == StakeType.ERC721
            ) {
                for (uint256 j; j < _tokenIds[i].length; ++j) {
                    uint16 tokenId = _tokenIds[i][j];
                    if (_verifyOwnership) {
                        address tokenOwner = _collections[cid]
                            .collection721
                            .ownerOf(tokenId);
                        require(tokenOwner == _staker, "Not owner (ERC721)");
                    }
                    points += getPoint(cid, tokenId, isSquad);
                }
            }
            if (
                _collections[cid].isSet &&
                _collections[cid].stakeType == StakeType.ERC1155 &&
                _collections[cid].non721amounts[_staker].amount > 0
            ) {
                if (_verifyOwnership) {
                    require(
                        (_collections[cid].collection1155.balanceOf(
                            _staker,
                            _collections[cid].index
                        ) >= _collections[cid].non721amounts[_staker].amount),
                        "Not owner (ERC1155)"
                    );
                }
                points += getNon721Points(_staker, cid);
            }
            if (
                _collections[cid].isSet &&
                _collections[cid].stakeType == StakeType.ERC20 &&
                _collections[cid].non721amounts[_staker].amount > 0
            ) {
                if (_verifyOwnership) {
                    require(
                        (_collections[cid].token20.balanceOf(_staker) >=
                            _collections[cid].non721amounts[_staker].amount),
                        "Not owner (ERC20)"
                    );
                }
                points += getNon721Points(_staker, cid);
            }
        }
        points += userItems[_staker].pointsAfterUnstake;
        points += userItems[_staker].pointsAddOns;
        if (points < userItems[_staker].pointsRedeemed) {
            return 0;
        } else {
            return points - userItems[_staker].pointsRedeemed;
        }
    }

    function getState() external view returns (State) {
        return activeState;
    }

    function setStateToPublic() external onlyOwner {
        activeState = State.Public;
    }

    function setStateToArchived() external onlyOwner {
        activeState = State.Archived;
    }
}
