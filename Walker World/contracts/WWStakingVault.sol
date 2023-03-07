// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title Walker World Staking Vault
/// @notice This contract stores and transfers NFT's to eligible stakers.

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract WWStakingVault is Ownable, ERC721Holder, ERC1155Holder {
    /// @dev Use SafeERC20 to ensure checked transfers on ERC20 tokens
    using SafeERC20 for IERC20;

    /// @notice 'admin' is the contract address of the proxy contract that initiates redeeming points
    address public admin;

    /// @dev Defines type of marketplace items. 'PHYSICAL' doesn't payout from vault and is handled off-chain.
    enum ItemType {
        PHYSICAL,
        ERC721,
        ERC1155,
        ERC20
    }

    /// @dev Store info of each colleciton added. 'ownedIds' is each ID transferred into the vault for a given collection.
    struct Collections {
        IERC721 collection721;
        IERC1155 collection1155;
        IERC20 token20;
        ItemType itemType;
        string collectionName;
        uint256[] ownedIds;
        uint256 cost;
        uint16 index; // 1155 ID or 721 start index
        uint16 physicalStock;
        uint16 league;
        uint16 maxClaimsPerAddr;
    }

    /// @notice Mapping of each collection and relevant info added to vault.
    mapping(uint16 => Collections) public vaultCollections;

    constructor(address _admin) {
        admin = _admin;
    }

    /// @dev Should be a contract address that can redeem points of a staker.
    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    /// @notice Set and add details for a new collection being added to the vault.
    /// @dev Can pass in the same address for all collection params (_collection721, _collection1155, _token20) when calling this function. _collectionDetails contains multiple args to overcome arg limit.
    /// @param _collectionDetails[0] = vaultId: Must match the ID that was set in the proxy contract in setRedeemableItem().
    /// @param _collectionDetails[1] = index: If adding an ERC721 collection, use _index to store start index of collection. For ERC1155, use this for ID of token.
    /// @param _collectionDetails[2] = physicalStock
    /// @param _collectionDetails[3] = league: Limit access to marketplace items based on holdings
    /// @param _collectionDetails[4] = maxClaimsPerAddr
    /// @param _collection721 The address of the collection being added.
    /// @param _collection1155 The address of the collection ID being added.
    /// @param _token20 The address of the token being added.
    /// @param _type Refers to ItemType enum
    /// @param _collectionName Name of collection to match against name set in proxy
    function setVaultCollection(
        uint16[] calldata _collectionDetails,
        IERC721 _collection721,
        IERC1155 _collection1155,
        IERC20 _token20,
        ItemType _type,
        string calldata _collectionName,
        uint256 _cost
    ) external onlyOwner {
        uint16 vaultId = _collectionDetails[0];
        uint16 index = _collectionDetails[1];
        uint16 physicalStock = _collectionDetails[2];
        uint16 league = _collectionDetails[3];
        uint16 maxClaims = _collectionDetails[4];
        vaultCollections[vaultId].league = league;
        uint256 nameLen = bytes(vaultCollections[vaultId].collectionName)
            .length;
        string
            memory overwriteError = "Vault collection has a balance. Withdraw ID's before overwriting colleciton.";
        if (_type == ItemType.ERC721) {
            // Disallow overwitting vault collection with a balance
            if (nameLen > 0) {
                require(
                    vaultCollections[vaultId].collection721.balanceOf(
                        address(this)
                    ) < 1,
                    overwriteError
                );
            }
            vaultCollections[vaultId].collection721 = _collection721;
            vaultCollections[vaultId].itemType = ItemType.ERC721;
        }
        if (_type == ItemType.ERC1155) {
            if (nameLen > 0) {
                require(
                    vaultCollections[vaultId].collection1155.balanceOf(
                        address(this),
                        index
                    ) < 1,
                    overwriteError
                );
            }
            vaultCollections[vaultId].collection1155 = _collection1155;
            vaultCollections[vaultId].itemType = ItemType.ERC1155;
        }
        if (_type == ItemType.ERC20) {
            if (nameLen > 0) {
                require(
                    vaultCollections[vaultId].token20.balanceOf(address(this)) <
                        1,
                    overwriteError
                );
            }
            vaultCollections[vaultId].token20 = _token20;
            vaultCollections[vaultId].itemType = ItemType.ERC20;
        }
        if (_type == ItemType.PHYSICAL) {
            vaultCollections[vaultId].itemType = ItemType.PHYSICAL;
            vaultCollections[vaultId].physicalStock = physicalStock;
        }
        vaultCollections[vaultId].maxClaimsPerAddr = maxClaims;
        vaultCollections[vaultId].index = index;
        vaultCollections[vaultId].collectionName = _collectionName;
        vaultCollections[vaultId].cost = _cost;
    }

    // TODO: Add setter for vault collection > maxClaimsPerAddr (others?)

    function setCost(uint16 _vaultId, uint256 _cost) external onlyOwner {
        vaultCollections[_vaultId].cost = _cost;
    }

    function setPhysicalStock(uint16 _vaultId, uint16 physicalStock)
        external
        onlyOwner
    {
        vaultCollections[_vaultId].physicalStock = physicalStock;
    }

    function collectionNameExists(
        uint16 _collection,
        string calldata _collectionName
    ) internal view returns (bool exists) {
        if (
            keccak256(abi.encodePacked(_collectionName)) ==
            keccak256(
                abi.encodePacked(vaultCollections[_collection].collectionName)
            )
        ) {
            return true;
        }
        return false;
    }

    /// @notice Adds ERC721 NFT's to vault for a specific colleciton.
    /// @dev Must be contract owner that owns the assets and deposits to vault.
    function addERC721ToVault(
        uint16 _collection,
        string calldata _collectionName,
        uint256[] calldata _tokenIds
    ) external onlyOwner {
        //console.log("x x x x x PASS 1");
        require(
            collectionNameExists(_collection, _collectionName),
            "Collection name not found"
        );
        //console.log("x x x x x PASS 2");
        require(
            vaultCollections[_collection].collection721.balanceOf(msg.sender) >=
                _tokenIds.length,
            "Insufficient balance (ERC721) to transfer to vault"
        );
        //console.log("x x x x x PASS 3");
        for (uint256 i; i < _tokenIds.length; ++i) {
            uint256 tokenId = _tokenIds[i];
            //console.log("x x x x x tokenId", tokenId);
            // Use ownedIds to store each ID added in an array to later be iterate over
            vaultCollections[_collection].ownedIds.push(tokenId);
            vaultCollections[_collection].collection721.safeTransferFrom(
                msg.sender,
                address(this),
                tokenId
            );
        }
    }

    /// @notice Adds ERC1155 NFT's to vault for a specific ID of a colleciton.
    /// @dev Must be contract owner that owns the assets and deposits to vault.
    function addERC1155ToVault(
        uint16 _collection,
        string calldata _collectionName,
        uint256 _id,
        uint256 _amount
    ) external onlyOwner {
        require(
            collectionNameExists(_collection, _collectionName),
            "Collection name not found"
        );
        uint256 balance = vaultCollections[_collection]
            .collection1155
            .balanceOf(msg.sender, _id);
        require(
            balance >= _amount,
            "Insufficient balance (ERC1155) to transfer to vault"
        );
        vaultCollections[_collection].collection1155.safeTransferFrom(
            msg.sender,
            address(this),
            _id,
            _amount,
            ""
        );
    }

    /// @notice Adds ERC20 tokens to vault for a specific token.
    /// @dev Must be contract owner that owns the assets and deposits to vault.
    function addERC20ToVault(
        uint16 _collection,
        string calldata _collectionName,
        uint256 _amount
    ) external onlyOwner {
        require(
            collectionNameExists(_collection, _collectionName),
            "Collection name not found"
        );
        require(
            vaultCollections[_collection].token20.balanceOf(msg.sender) >=
                _amount,
            "Insufficient balance (ERC20) to transfer to vault"
        );
        vaultCollections[_collection].token20.safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
    }

    /// @notice Returns the vault balance of a specific colleciton or token.
    /// @dev Must pass in token ID if querying for an ERC1155 collection.
    function getCollectionBalance(uint16 _collection, uint256 _erc1155Id)
        external
        view
        returns (uint256 balance)
    {
        if (vaultCollections[_collection].itemType == ItemType.ERC721) {
            return
                vaultCollections[_collection].collection721.balanceOf(
                    address(this)
                );
        }
        if (vaultCollections[_collection].itemType == ItemType.ERC1155) {
            return
                vaultCollections[_collection].collection1155.balanceOf(
                    address(this),
                    _erc1155Id
                );
        }
        if (vaultCollections[_collection].itemType == ItemType.ERC20) {
            return
                vaultCollections[_collection].token20.balanceOf(address(this));
        }
    }

    /// @dev Helper to get random ID for each item being claimed
    function getRandom(uint256 _limit, uint256 _topLevelcounter)
        internal
        pure
        returns (uint256, uint256)
    {
        uint256 internalCounter = _topLevelcounter;
        uint256 id = (uint256(
            keccak256(abi.encodePacked(internalCounter++, _limit))
        ) % _limit);
        return (id, _topLevelcounter + internalCounter);
    }

    /// @notice Vault items are issued randomly when claimed.
    function randomId(
        uint16 _vaultId,
        uint256 _limit,
        uint256 _topLevelcounter
    ) internal returns (uint256 tokenId, uint256 returnedCounter) {
        // Get random number to verify below in loop
        returnedCounter = _topLevelcounter;
        uint256 id;
        (id, returnedCounter) = getRandom(_limit, returnedCounter);

        // Check if ID exists in collection
        for (
            uint256 i;
            i < vaultCollections[_vaultId].ownedIds.length * 10;
            ++i
        ) {
            if (vaultCollections[_vaultId].ownedIds[id] > 0) {
                tokenId = vaultCollections[_vaultId].ownedIds[id];

                // If it's last ID, delete array
                if (_limit == 1) {
                    delete vaultCollections[_vaultId].ownedIds;
                } else {
                    uint256 idsLength = vaultCollections[_vaultId]
                        .ownedIds
                        .length;
                    // Move selected ID to end of array and remove it
                    vaultCollections[_vaultId].ownedIds[id] = vaultCollections[
                        _vaultId
                    ].ownedIds[idsLength - 1];
                    vaultCollections[_vaultId].ownedIds.pop();
                }

                // Break from loop and return valid id
                return (tokenId, returnedCounter);
            } else {
                // Get a new random number
                (id, returnedCounter) = getRandom(_limit, returnedCounter);
            }
        }
    }

    /// @notice After points are deducted when claiming from proxy contract, vault items are transfered here. For ERC721 items, a random ID is issued.
    /// @dev Only the proxy contract address can call this function.
    function transferItems(
        address _recipient,
        uint16 _vaultId,
        uint16 _qtyToClaim,
        uint16 _league,
        uint16 _claimed
    )
        external
        returns (
            //bool pass,
            uint256 batchCost,
            bool isPhysical
        )
    {
        require(msg.sender == admin, "Not authorized");

        // Check that the item marketplace requested exists by checking if name has been set
        require(
            bytes(vaultCollections[_vaultId].collectionName).length > 0,
            "Non-existent vault collection"
        );

        require(_league >= vaultCollections[_vaultId].league, "Out of league");

        if (vaultCollections[_vaultId].maxClaimsPerAddr > 0) {
            require(
                _claimed + _qtyToClaim >=
                    vaultCollections[_vaultId].maxClaimsPerAddr,
                "Exceeds total allowable claims"
            );
        }

        // Calculate points required for an item * qty
        batchCost = vaultCollections[_vaultId].cost * _qtyToClaim;

        if (vaultCollections[_vaultId].itemType == ItemType.PHYSICAL) {
            require(
                vaultCollections[_vaultId].physicalStock >= _qtyToClaim,
                "Out of stock"
            );
            vaultCollections[_vaultId].physicalStock -= _qtyToClaim;
            //return (true, batchCost, true);
            return (batchCost, true);
        } else {
            if (vaultCollections[_vaultId].itemType == ItemType.ERC721) {
                uint256 balance = vaultCollections[_vaultId]
                    .collection721
                    .balanceOf(address(this));
                require(
                    balance >= _qtyToClaim,
                    "Insufficient tokens in vault to transfer(ERC721)"
                );
                // 'counter' increments with every loop and is then passed into the randomizer to ensure a random ID is returned
                uint256 counter;
                for (uint16 i; i < _qtyToClaim; ++i) {
                    (uint256 tokenId, uint256 counterInc) = randomId(
                        _vaultId,
                        vaultCollections[_vaultId].ownedIds.length,
                        counter
                    );
                    counter += counterInc;
                    vaultCollections[_vaultId].collection721.transferFrom(
                        address(this),
                        _recipient,
                        tokenId
                    );
                }
            }
            if (vaultCollections[_vaultId].itemType == ItemType.ERC1155) {
                uint256 balance = vaultCollections[_vaultId]
                    .collection1155
                    .balanceOf(address(this), vaultCollections[_vaultId].index);
                require(
                    balance >= _qtyToClaim,
                    "Insufficient tokens in vault (ERC1155)"
                );
                vaultCollections[_vaultId].collection1155.safeTransferFrom(
                    address(this),
                    _recipient,
                    vaultCollections[_vaultId].index,
                    _qtyToClaim,
                    ""
                );
            }
            if (vaultCollections[_vaultId].itemType == ItemType.ERC20) {
                uint256 balance = vaultCollections[_vaultId].token20.balanceOf(
                    address(this)
                );
                require(
                    balance >= _qtyToClaim,
                    "Insufficient tokens in vault (ERC20)"
                );
                vaultCollections[_vaultId].token20.safeTransfer(
                    _recipient,
                    _qtyToClaim
                );
            }
            //return (true, batchCost, false);
            return (batchCost, false);
        }
    }

    /// @notice Used in cases where the assets from a vault collection need to be remove altogther
    function withdrawTokens(
        address _recipient,
        uint256 _erc1155Id,
        uint16 _vaultId,
        uint16 _qty
    ) external onlyOwner {
        if (vaultCollections[_vaultId].itemType == ItemType.ERC721) {
            uint256 balance = vaultCollections[_vaultId]
                .collection721
                .balanceOf(address(this));
            for (uint16 i; i < _qty; ++i) {
                require(
                    balance >= _qty,
                    "Insufficient tokens in vault (ERC721)"
                );
                uint256 len = vaultCollections[_vaultId].ownedIds.length;
                uint256 tokenId = vaultCollections[_vaultId].ownedIds[len - 1];
                vaultCollections[_vaultId].ownedIds.pop();
                vaultCollections[_vaultId].collection721.transferFrom(
                    address(this),
                    _recipient,
                    tokenId
                );
            }
        }
        if (vaultCollections[_vaultId].itemType == ItemType.ERC1155) {
            uint256 balance = vaultCollections[_vaultId]
                .collection1155
                .balanceOf(address(this), _erc1155Id);

            require(balance > 0, "Insufficient tokens in vault (ERC1155)");

            for (uint16 i; i < _qty; ++i) {
                vaultCollections[_vaultId].collection1155.safeTransferFrom(
                    address(this),
                    _recipient,
                    _erc1155Id,
                    1,
                    ""
                );
            }
        }
        if (vaultCollections[_vaultId].itemType == ItemType.ERC20) {
            uint256 balance = vaultCollections[_vaultId].token20.balanceOf(
                address(this)
            );
            require(balance > 0, "Insufficient tokens in vault (ERC20)");
            for (uint16 i; i < _qty; ++i) {
                vaultCollections[_vaultId].token20.safeTransfer(_recipient, 1);
            }
        }
    }
}
