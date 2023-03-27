// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/*
    Designed, developed by DEntwickler
    @LongToBurn
*/

import "./FairLaunchToken.sol";
import "./ReferralManager.sol";
import "./LoyaltyToken.sol";
// import "./Information.sol";

import "./Pause.sol";

contract Deploy {
    FairLaunchToken public fairLaunchToken;
    ReferralManager public referralManager;
    LoyaltyToken public loyaltyToken;
    // Information public information;

    Pause public pause;

    address constant public prevTokenAddress = address(0x167fC786FB4D9CD5f8B3E2a2D258a88ea03b3E63);

    constructor() {
        uint initSupplyInEther = 0;
        uint oneEther = 1 ether;
        uint initSupply = initSupplyInEther * oneEther;
        fairLaunchToken = new FairLaunchToken(
            "Pizon",
            "PZT",
            initSupplyInEther,
            prevTokenAddress
        );

        referralManager = new ReferralManager(IFairLaunchToken(address(fairLaunchToken)));
        loyaltyToken = new LoyaltyToken(ILockableERC20(address(fairLaunchToken)));
        
        // information = new Information(address(fairLaunchToken));

        pause = new Pause();
        pause.transferOwnership(msg.sender);

        ITokenCallback[] memory beforeTargets = new ITokenCallback[](1);
        beforeTargets[0] = ITokenCallback(address(pause));
        fairLaunchToken.setBeforeTransferTargets(beforeTargets);


        // fairLaunchToken.transfer(msg.sender, initSupply);

        fairLaunchToken.setReferralManager(address(referralManager));

        ITokenCallback[] memory afterTargets = new ITokenCallback[](2);
        afterTargets[0] = ITokenCallback(address(fairLaunchToken));
        afterTargets[1] = ITokenCallback(address(loyaltyToken));
        fairLaunchToken.setAfterTransferTargets(afterTargets);

        fairLaunchToken.setDefaultLockPeriod(365 days);

        fairLaunchToken.setTaxs(
            1 * 100,
            1 * 100,
            1 * 100,
            msg.sender
        );

        fairLaunchToken.setRefKingUnlockP(10 * 100);
        fairLaunchToken.setMaxSelfUnlockP(10 * 100);

        uint warDuration = 7 days;
        uint expInterval = 1 days;
        uint minRefInvValue = 1 ether;
        fairLaunchToken.configWar(warDuration, expInterval, minRefInvValue);

        fairLaunchToken.setValidApprDuration(48 hours);

        fairLaunchToken.transferOwnership(msg.sender);
    }
}

/*
    Enable optimization: 200
    sol: 0.8.0
*/