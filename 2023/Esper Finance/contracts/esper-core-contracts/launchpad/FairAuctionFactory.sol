// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FairAuction.sol";

contract FairAuctionFactory is Ownable {

    address[] public fairAuctions;

    event FairAuctionCreation(
        address indexed fairAuction,
        address indexed projectToken,
        uint256 hardcap,
        uint256 maxTokenToDistribute,
        address indexed saleToken,
        uint256 startTime,
        uint256 endTime
    );

    struct AuctionDetails {
        address projectToken1;
        address projectToken2;
        address saleToken;
        address lpToken;
        uint256 startTime;
        uint256 endTime;
        address treasury_;
        uint256 maxToDistribute1;
        uint256 maxToDistribute2;
        uint256 minToRaise;
        uint256 maxToRaise;
        uint256 capPerWallet;
    }

    function createFairAuction(AuctionDetails memory details) external onlyOwner returns (address) {
        FairAuction _fairAuction = new FairAuction(
            details.projectToken1,
            details.projectToken2,
            details.saleToken,
            details.lpToken,
            details.startTime,
            details.endTime,
            details.treasury_,
            details.maxToDistribute1,
            details.maxToDistribute2,
            details.minToRaise,
            details.maxToRaise,
            details.capPerWallet
        );

        address instance = address(_fairAuction);
        fairAuctions.push(instance);

        emit FairAuctionCreation(
            instance,
            details.projectToken1,
            details.maxToRaise,
            details.maxToDistribute1 + details.maxToDistribute2,
            details.saleToken,
            details.startTime,
            details.endTime
        );

        return instance;
    }
}
