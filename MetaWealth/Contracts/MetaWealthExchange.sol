// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IMetaWealthModerator.sol";
import "./interfaces/IMetaWealthExchange.sol";
import "./interfaces/IAssetVault.sol";
import "./utils/Heap.sol";

contract MetaWealthExchange is
    IMetaWealthExchange,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /// @notice MetaWealth moderator contract for currency and whitelist checks
    IMetaWealthModerator public metawealthMod;

    /// @notice Maintain all bids and asks in heaps
    mapping(IAssetVault => IMinHeap) public bids;
    mapping(IAssetVault => IMaxHeap) public asks;

    /// @notice Unified modifier for both bid and ask prechecks
    /// @param asset is the fractional asset being passed
    /// @param _merkleProof is user's whitelist proof in merkle tree
    modifier prechecked(IAssetVault asset, bytes32[] calldata _merkleProof) {
        require(
            metawealthMod.checkWhitelist(_merkleProof, _msgSender()),
            "MetaWealthExchange: Access forbidden"
        );
        require(asset.isActive(), "MetaWealthExchange: Asset not being traded");
        require(
            metawealthMod.isSupportedCurrency(asset.getTradingCurrency()),
            "MetaWealthExchange: Asset listing currency not supported"
        );
        _;
    }

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

    function bid(
        IAssetVault asset,
        uint256 shares_,
        uint256 price_,
        bytes32[] calldata _merkleProof
    )
        external
        override
        prechecked(asset, _merkleProof)
        returns (uint256 matchedUnits)
    {
        if (address(bids[asset]) == address(0)) {
            bids[asset] = new MinHeap();
        }
        if (address(asks[asset]) == address(0)) {
            bids[asset].insert(
                order(_msgSender(), shares_, price_, block.timestamp)
            );
            emit OrderPlaced(true, address(asset), shares_, price_, 0);
            return 0;
        }
        /// @dev Counter the edge case where partial bid is met at the highest heap value
        bool isError = true;
        try asks[asset].getMax() returns (order memory max) {
            if (max.price >= price_) isError = false;
            while (max.price >= price_ && shares_ > 0 && !isError) {
                if (max.shares == shares_) {
                    matchedUnits += max.shares;
                    shares_ = 0;
                    asks[asset].removeMax();
                    break;
                } else if (max.shares < shares_) {
                    order memory oldMax = max;
                    matchedUnits += max.shares;
                    shares_ -= max.shares;
                    asks[asset].removeMax();
                    try asks[asset].getMax() returns (order memory _max) {
                        max = _max;
                    } catch {}
                    if (
                        (oldMax.price == max.price &&
                            oldMax.sender == max.sender &&
                            oldMax.timestamp == max.timestamp) ||
                        max.price < price_
                    ) {
                        isError = true;
                    }
                } else if (max.shares > shares_) {
                    matchedUnits += shares_;
                    max.shares -= shares_;
                    max.price -= price_;
                    asks[asset].removeMax();
                    asks[asset].insert(max);
                    break;
                }
            }
        } catch {}
        if (shares_ > 0 && isError) {
            bids[asset].insert(
                order(_msgSender(), shares_, price_, block.timestamp)
            );
        }

        emit OrderPlaced(true, address(asset), shares_, price_, matchedUnits);
    }

    function ask(
        IAssetVault asset,
        uint256 shares_,
        uint256 price_,
        bytes32[] calldata _merkleProof
    )
        external
        override
        prechecked(asset, _merkleProof)
        returns (uint256 matchedUnits)
    {
        if (address(asks[asset]) == address(0)) {
            asks[asset] = new MaxHeap();
        }
        if (address(bids[asset]) == address(0)) {
            asks[asset].insert(
                order(_msgSender(), shares_, price_, block.timestamp)
            );
            emit OrderPlaced(false, address(asset), shares_, price_, 0);
            return 0;
        }
        bool isError = true;
        try bids[asset].getMin() returns (order memory min) {
            if (min.price <= price_) isError = false;
            while (min.price <= price_ && shares_ > 0 && !isError) {
                /// @dev todo: Perform currency checks
                if (min.shares == shares_) {
                    matchedUnits += min.shares;
                    shares_ = 0;
                    bids[asset].removeMin();
                    break;
                } else if (min.shares < shares_) {
                    order memory oldMin = min;
                    matchedUnits += min.shares;
                    shares_ -= min.shares;
                    bids[asset].removeMin();
                    if (shares_ == 0) {
                        break;
                    }
                    price_ -= min.price;
                    try bids[asset].getMin() returns (order memory _min) {
                        min = _min;
                    } catch {}
                    if (
                        (oldMin.price == min.price &&
                            oldMin.sender == min.sender &&
                            oldMin.timestamp == min.timestamp) ||
                        min.price > price_
                    ) {
                        isError = true;
                    }
                } else if (min.shares > shares_) {
                    matchedUnits += shares_;
                    min.shares -= shares_;
                    bids[asset].removeMin();
                    bids[asset].insert(min);
                    break;
                }
            }
        } catch {}
        if (shares_ > 0 && isError) {
            asks[asset].insert(
                order(_msgSender(), shares_, price_, block.timestamp)
            );
        }

        emit OrderPlaced(false, address(asset), shares_, price_, matchedUnits);
    }
}
