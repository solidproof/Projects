// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library PrivateSaleStructs {

    struct DeployInfo {
        address payable fundAddress;
        uint256 fundPercent;
        address superAccount;
        address deployer;
        address signer;
        uint256 penaltyFeePercent;
    }

    struct PrivateSaleInfo {
        address currency;
        bool isWhitelist;
        uint256 softCap;
        uint256 hardCap;
        uint256 minInvest;
        uint256 maxInvest;
        uint256 startTime;
        uint256 endTime;
    }

    struct VestingInfo {
        uint256 tgeBps;
        uint256 cycle;
        uint256 cycleBps;
    }

}



