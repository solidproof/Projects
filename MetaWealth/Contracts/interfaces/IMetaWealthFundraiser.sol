// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

interface IMetaWealthFundraiser {
    /// @notice Fired when a campaign is started
    /// @param owner is the address of campaign starter
    /// @param collection is the NFT collection address
    /// @param tokenId is the id of the NFT for which funds are raised
    /// @param numberShares is the amount of shares the campaign is offering
    /// @param raiseGoal is the goal of the raise for this campaign
    /// @param raiseCurrency is the ERC20 currency the funds are being raised in
    event CampaignStarted(
        address owner,
        address collection,
        uint256 tokenId,
        uint64 numberShares,
        uint256 raiseGoal,
        address raiseCurrency
    );

    /// @notice Fired when a campaign receives investment
    /// @param investor is the address of campaign starter
    /// @param collection is the NFT collection address
    /// @param tokenId is the id of the NFT for which funds are raised
    /// @param amount is the amount invested
    /// @param raiseCompleted is the boolean representing whether the raise completed after this investment
    event InvestmentReceived(
        address investor,
        address collection,
        uint256 tokenId,
        uint256 amount,
        bool raiseCompleted
    );

    /// @notice Fired when the owner cancels an ongoing campaign
    /// @param collection is the NFT collection address
    /// @param tokenId is the id of the NFT for which funds were being raised
    event CampaignCancelled(address owner, address collection, uint256 tokenId);

    /// @notice Starts a new fundraiser capmaign
    /// @param collection is the NFT collection address of which an asset is being put up for raise
    /// @param tokenId is the NFT id within the collection above
    /// @param numberShares is the number of shares the above NFT will be split into
    /// @param raiseGoal is the fundraise goal of this campaign
    /// @param raiseCurrency is the ERC20 currency that the raise is being held in
    /// @param _merkleProof is the sender's proof of being KYC'd
    /// @dev The function should immediately transfer the asset to the contract itself
    function startCampaign(
        address collection,
        uint256 tokenId,
        uint64 numberShares,
        uint256 raiseGoal,
        address raiseCurrency,
        bytes32[] memory _merkleProof
    ) external;

    /// @notice Allows users to invest into ongoing campaigns
    /// @param collection is the collection address of the collection whose asset is being invested for
    /// @param tokenId is the NFT ID within that collection
    /// @param amount is the ERC20 token amount being invested
    /// @param _merkleProof is the proof of message sender being KYC'd in MetaWealth
    /// @param _contractMerkleProof is the proof of MetaWealthFundraiser contract's merkle proof
    /// @dev The function should immediately transfer ERC20 currency into the contract itself
    function invest(
        address collection,
        uint256 tokenId,
        uint256 amount,
        bytes32[] memory _merkleProof,
        bytes32[] memory _contractMerkleProof
    ) external;

    /// @notice Allows campaign starter AND MetaWealth moderator to cancel an ongoing raise
    /// @param collection is the NFT collection address
    /// @param tokenId is the token ID within that collection
    /// @param _merkleProof is the proof of message sender being KYC'd in platform
    /// @dev This function should return the investments AND the starter's NFT back to them
    function cancelRaise(
        address collection,
        uint256 tokenId,
        bytes32[] memory _merkleProof
    ) external;
}
