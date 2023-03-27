// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/*
    Designed, developed by DEntwickler
    @LongToBurn
*/

interface IToken {
    function currentListingBuyTaxP()
        external
        view
        returns(uint);

    function listingInfo()
        external
        view
        returns(
            address activator,
            uint duration,
            uint activatedAt,
            uint maxListingBuyTaxP,
            uint minListingBuyTaxP
        );

    function isListingActivated()
        external
        view
        returns(bool);

    function isListingFinished()
        external
        view
        returns(bool);

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

contract Information {
    string constant public VERSION = "mainnet-arbitrum";
    string constant public HINT = "all percentage values are with 100 multiplied i.e 110 = 1.1 %";

    IToken immutable public mainToken;

    constructor(
        address mainTokenAddr_
    )
    {
        mainToken = IToken(mainTokenAddr_);
    }

    function currentListingBuyTaxP()
        external
        view
        returns(uint currentBuyPercent)
    {
        return mainToken.currentListingBuyTaxP();
    }

    function listingInfo()
        external
        view
        returns(
            address activator,
            uint duration,
            uint activatedAt,
            uint maxListingBuyTaxP,
            uint minListingBuyTaxP
        )
    {
        return mainToken.listingInfo();
    }

    function isListingActivated()
        external
        view
        returns(bool isActivated)
    {
        isActivated = mainToken.isListingActivated();
    }

    function isListingFinished()
        external
        view
        returns(bool isFinished)
    {
        return mainToken.isListingFinished();
    }

    function getTaxs()
        public
        view
        returns(
            uint buyTaxP,
            uint sellTaxP,
            uint transferTaxP,
            address taxReceiver
        )
    {
        return mainToken.getTaxs();
    }
}