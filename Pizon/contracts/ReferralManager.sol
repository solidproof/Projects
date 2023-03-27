// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/*
    Designed, developed by DEntwickler
    @LongToBurn
*/

interface IRefKing {
    function refKingUnlockP()
        external
        view
        returns(uint);

    function maxSelfUnlockP()
        external
        view
        returns(uint);

    function refKing()
        external
        view
        returns(address);

    function refKingBalance()
        external
        view
        returns(uint);
}

interface IReferral is IRefKing {

    struct SReferrer {
        address addr;
        uint invValue;
        uint updatedAt;
    }

    function warDuration()
        external
        view
        returns(uint);

    function expInterval()
        external
        view
        returns(uint);

    function requiredInvValue(
        address child_
    )
        external
        view
        returns(uint);

    function referrerUnlockA(
        uint referrerBalance_,
        uint lockedA_
    )
        external
        view
        returns(uint);

    function selfUnlockA(
        uint balance_,
        uint lockedA_
    )
        external
        view
        returns(uint);

    function referrerOf(
        address child_
    )
        external
        view
        returns(SReferrer memory referrer);

    function totalChildren(
        address referrer
    )
        external
        view
        returns(uint);

    function returnPOf(
        address referrer_
    )
        external
        view
        returns(uint);

    function minRefInvValue()
        external
        view
        returns(uint);

    function referralManager()
        external
        view
        returns(address);

    function setReturnP(
        uint percent_
    )
        external;

    function setReturnPWithManager(
        address referrer_,
        uint percent_
    )
        external;
}

interface ILockable {
    enum UnlockType{
        AS_REF,
        AS_CHILD,
        SELF,
        OTHER
    }

    function unlockedSumOf(
        address account_,
        UnlockType unlockType_
    )
        external
        view
        returns(uint unlockedSum);

    function lockDurationOf(
        address account_
    )
        external
        view
        returns(uint restLockDuration);

    function lockedAOf(
        address account_
    )
        external
        view
        returns(uint lockedA);
}

interface IFairLaunchToken is IReferral, ILockable {
    function getTaxs()
        external
        view
        returns(
            uint buyTaxP,
            uint sellTaxP,
            uint transferTaxP,
            address taxReceiver
        );
}

contract ReferralManager is IFairLaunchToken {
    string constant public VERSION = "mainnet-arbitrum-v2";
    IFairLaunchToken immutable public fairLaunchToken;

    string constant public HINT = "all percentage values are with 100 multiplied i.e 110 = 1.1 %";

    constructor(
        IFairLaunchToken fairLaunchToken_
    )
    {
        fairLaunchToken = fairLaunchToken_;
    }

    function refKingUnlockP()
        external
        override
        view
        returns(uint)
    {
        return fairLaunchToken.refKingUnlockP();
    }

    function maxSelfUnlockP()
        external
        override
        view
        returns(uint)
    {
        return fairLaunchToken.maxSelfUnlockP();
    }

    function refKing()
        external
        override
        view
        returns(address)
    {
        return fairLaunchToken.refKing();
    }

    function refKingBalance()
        external
        override
        view
        returns(uint)
    {
        return fairLaunchToken.refKingBalance();
    }

    function warDuration()
        external
        override
        view
        returns(uint)
    {
        return fairLaunchToken.warDuration();
    }
    function expInterval()
        external
        override
        view
        returns(uint)
    {
        return fairLaunchToken.expInterval();
    }

    function requiredInvValue(
        address child_
    )
        public
        override
        view
        returns(uint)
    {
        return fairLaunchToken.requiredInvValue(child_);
    }

    function referrerUnlockA(
        uint referrerBalance_,
        uint lockedA_
    )
        external
        override
        view
        returns(uint)
    {
        return fairLaunchToken.referrerUnlockA(referrerBalance_, lockedA_);
    }

    function selfUnlockA(
        uint balance_,
        uint lockedA_
    )
        external
        override
        view
        returns(uint)
    {
        return fairLaunchToken.selfUnlockA(balance_, lockedA_);
    }

    function referrerOf(
        address child_
    )
        public
        override
        view
        returns(SReferrer memory referrer)
    {
        return fairLaunchToken.referrerOf(child_);
    }

    function totalChildren(
        address referrer
    )
        public
        override
        view
        returns(uint)
    {
        return fairLaunchToken.totalChildren(referrer);
    }

    function returnPOf(
        address referrer_
    )
        public
        override
        view
        returns(uint)
    {
        return fairLaunchToken.returnPOf(referrer_);
    }

    function minRefInvValue()
        external
        override
        view
        returns(uint)
    {
        return fairLaunchToken.minRefInvValue();
    }

    function referralManager()
        external
        override
        view
        returns(address)
    {
        return fairLaunchToken.referralManager();
    }

    function setReturnP(
        uint percent_
    )
        external
        override
    {
        return fairLaunchToken.setReturnPWithManager(msg.sender, percent_);
    }

    function setReturnPWithManager(
        address referrer_,
        uint percent_
    )
        external
        override
    {
    }

    function unlockedSumOf(
        address account_,
        UnlockType unlockType_
    )
        public
        override
        view
        returns(uint unlockedSum)
    {
        return fairLaunchToken.unlockedSumOf(account_, unlockType_);
    }

    function lockDurationOf(
        address account_
    )
        external
        override
        view
        returns(uint restLockDuration)
    {
        return fairLaunchToken.lockDurationOf(account_);
    }

    function lockedAOf(
        address account_
    )
        external
        override
        view
        returns(uint lockedA)
    {
        return fairLaunchToken.lockedAOf(account_);
    }

    // enum UnlockType{
    //     AS_REF,
    //     AS_CHILD,
    //     SELF,
    //     OTHER
    // }

    function getAccountDetails(
        address account_
    )
        public
        view
        returns(
            SReferrer memory referrer,
            uint asRefUnlockedSum,
            uint asChildUnlockedSum,
            uint selfUnlockedSum,
            uint otherUnlockedSum,
            uint totalChild,
            uint returnP,
            uint requiredInv
        )
    {
            referrer = referrerOf(account_);
            asRefUnlockedSum = unlockedSumOf(account_, UnlockType.AS_REF);
            asChildUnlockedSum = unlockedSumOf(account_, UnlockType.AS_CHILD);
            selfUnlockedSum = unlockedSumOf(account_, UnlockType.SELF);
            otherUnlockedSum = unlockedSumOf(account_, UnlockType.OTHER);
            totalChild = totalChildren(account_);
            returnP = returnPOf(account_);
            requiredInv = requiredInvValue(account_);
    }

    function getTaxs()
        public
        override
        view
        returns(
            uint buyTaxP,
            uint sellTaxP,
            uint transferTaxP,
            address taxReceiver
        )
    {
        return fairLaunchToken.getTaxs();
    }
}