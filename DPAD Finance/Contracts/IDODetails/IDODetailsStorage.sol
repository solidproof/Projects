//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;
// @todo: update types in whole project as commented
library IDODetailsStorage {
    struct BasicIdoDetails {
        uint tokenPrice; // in BNB
        uint softCap; // in BNB
        uint hardCap; // in BNB
        uint minPurchasePerWallet; // in BNB
        uint maxPurchasePerWallet; // in BNB
        uint initialSupply; //
        uint64 saleStartTime; // unix // uint64
        uint64 saleEndTime; // unix // uint64
        uint32 headStart; // in Seconds // uint32
    }

    struct VotingDetails {
        uint64 voteStartTime; // unix // uint64
        uint64 voteEndTime; // unix // uint64
    }

    struct PCSListingDetails {
        uint listingRate; // in BNB
        uint64 lpLockDuration; // in seconds // uint64

        uint16 allocationToLPInBP; // in BP // uint16
    }

    struct ProjectInformation {
        string saleTitle;
        string saleDescription;
        string website;
        string telegram;
        string github;
        string twitter;
        string logo;
        string whitePaper;
        string kyc;
        string video;
        string audit;
    }
}
