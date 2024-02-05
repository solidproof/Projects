// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library SharedStructs {
    struct LaunchpadInfo {
        address icoToken;
        address feeToken;
        uint256 softCap;
        uint256 hardCap;
        uint256 presaleRate;
        uint256 minInvest;
        uint256 maxInvest;
        uint256 startTime;
        uint256 endTime;
        uint256 whitelistPool; //0 public, 1 whitelist, 2 public anti bot
        uint256 poolType; //0 burn, 1 refund
    }

    struct ClaimInfo {
        uint256 cliffVesting;
        uint256 lockAfterCliffVesting;
        uint256 firstReleasePercent;
        uint256 vestingPeriodEachCycle;
        uint256 tokenReleaseEachCycle;//percent
    }

    struct TeamVestingInfo {
        uint256 teamTotalVestingTokens;
        uint256 teamCliffVesting; //First token release after listing (minutes)
        uint256 teamFirstReleasePercent;
        uint256 teamVestingPeriodEachCycle;
        uint256 teamTokenReleaseEachCycle;
    }

    struct DexInfo {
        address routerAddress;
        address factoryAddress;
        uint256 listingPrice;
        uint256 listingPercent;// 1=> 10000
        uint256 lpLockTime;
    }


    struct LaunchpadReturnInfo {
        uint256 softCap;
        uint256 hardCap;
        uint256 startTime;
        uint256 endTime;
        uint256 state;
        uint256 raisedAmount;
        uint256 balance;
        address feeToken;
        uint256 listingTime;
        uint256 whitelistPool;
        address holdingToken;
        uint256 holdingTokenAmount;
    }

    struct OwnerZoneInfo {
        bool isOwner;
        uint256 whitelistPool;
        bool canFinalize;
        bool canCancel;
    }

    struct FeeSystem {
        uint256 initFee;
        uint256 raisedFeePercent; //BNB With Raised Amount
        uint256 raisedTokenFeePercent;
        uint256 penaltyFee;
    }

    struct SettingAccount {
        address deployer;
        address signer;
        address superAccount; //BNB With Raised Amount
        address payable fundAddress;
        address waveLock;
    }

    struct CalculateTokenInput {
        address feeToken;
        uint256 presaleRate;
        uint256 hardCap;
        uint256 raisedTokenFeePercent;
        uint256 raisedFeePercent;
        uint256 teamTotalVestingTokens;
        uint256 listingPercent;
        uint256 listingPrice;

    }
}



