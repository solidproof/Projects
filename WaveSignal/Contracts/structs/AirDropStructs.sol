// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library AirDropStructs {
   struct Social {
        string title;
        string logoUrl;
        string website;
        string facebook;
        string twitter;
        string github;
        string telegram;
        string instagram;
        string discord;
        string reddit;
        string description;

    }


struct AirDropFlashInfo {
        address tokenAddress;
        uint256 totalAllocations;
        uint256 totalClaimedAllocations;
        uint256 totalTokens;
        uint256 tgeDate;
        uint256 state;
    }
}



