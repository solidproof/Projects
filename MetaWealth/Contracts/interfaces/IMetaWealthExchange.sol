// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

import "./IAssetVault.sol";

/// @title MetaWealth exchange core orderbook implementation
/// @author Ghulam Haider
interface IMetaWealthExchange {
    /// @notice Fired when an order is placed on an asset
    /// @param isBid is the boolean representing if it was a bid or an ask
    /// @param asset is the address of the asset order was placed on
    /// @param shares is the amount of shares the order was placed for
    /// @param price is the unit price per share order was placed for
    /// @param matchedUnits is the number of units matched when order was placed
    event OrderPlaced(bool isBid, address asset, uint256 shares, uint256 price, uint256 matchedUnits);

    /// @notice Places bid for certain asset into bids ledger and matches any open Asks orders
    /// @param asset is the MetaWealth FractionalAsset contract
    /// @param shares_ is the number of shares the bid is being placed for
    /// @param price_ is the unit share price for the shares being traded
    /// @param _merkleProof is the sender's whitelist presence proof
    /// @return matchedUnits is the number of shares that have been matched with open orders in Asks
    function bid(
        IAssetVault asset,
        uint256 shares_,
        uint256 price_,
        bytes32[] calldata _merkleProof
    ) external returns (uint256 matchedUnits);

    /// @notice Places Ask for certain asset into asks ledger and matches any open Bids orders
    /// @param asset is the MetaWealth FractionalAsset contract
    /// @param shares_ is the number of shares the ask is being placed for
    /// @param price_ is the unit share price for the shares being traded
    /// @param _merkleProof is the sender's whitelist presence proof
    /// @return matchedUnits is the number of shares that have been matched with open orders in Bids
    function ask(
        IAssetVault asset,
        uint256 shares_,
        uint256 price_,
        bytes32[] calldata _merkleProof
    ) external returns (uint256 matchedUnits);
}
