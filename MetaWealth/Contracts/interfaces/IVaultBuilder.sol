// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

/// @title MetaWealth Asset Fractionalizer Factory
/// @author Ghulam Haider
/// @notice Creates AssetVault ERC20 smart contracts for any NFT
interface IVaultBuilder {
    /// @notice Fired when an asset is fractionalized into vault
    /// @param collection is the NFT collection address
    /// @param tokenId is the NFT token ID within that collection
    /// @param totalShares is the amount of shares the asset is fractionalized in
    /// @param vaultAddress is the address of new vault
    event AssetFractionalized(
        address collection,
        uint256 tokenId,
        uint256 totalShares,
        address vaultAddress
    );

    /// @notice Takes an NFT and creates the fractional contract of it
    /// @notice If inactive, no trades can occur for this asset
    /// @dev todo Transfer the asset from the collection to the newly minted asset vault contract
    /// @param collection is the address of NFT collection being brought in
    /// @param tokenId is the specific token ID within NFT collection
    /// @param totalShares is the number of shares to split this asset to
    /// @param _merkleProof is the sender's proof of being in MetaWealth's whitelist
    /// @return newVault is the reference to the newly created asset vault
    function fractionalize(
        address collection,
        uint256 tokenId,
        uint256 totalShares,
        bytes32[] calldata _merkleProof
    ) external returns (address newVault);
}
