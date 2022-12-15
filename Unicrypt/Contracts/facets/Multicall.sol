// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "./Storage.sol";

import "../libraries/Ownable.sol";

contract MulticallFacet is Storage, Ownable { 
    struct MulticallAdminUpdateParams {
        TaxSettings _taxSettings;
        TaxSettings _lockSettings;
        CustomTax[] _customTaxes;
        Fees _fees;
        address _transactionTaxWallet;
        uint256 _maxBalanceAfterBuy;
    }

    function multicallAdminUpdate(MulticallAdminUpdateParams calldata params) public onlyOwner {
        // Tax Settings
        if(!isLocked.transactionTax && taxSettings.transactionTax != params._taxSettings.transactionTax) {
            taxSettings.transactionTax = params._taxSettings.transactionTax;
        }
        if(!isLocked.holderTax && taxSettings.holderTax != params._taxSettings.holderTax && !params._taxSettings.canMint) {
            taxSettings.holderTax = params._taxSettings.holderTax;
        }
        if(!isLocked.buyBackTax && taxSettings.buyBackTax != params._taxSettings.buyBackTax) {
            taxSettings.buyBackTax = params._taxSettings.buyBackTax;
        }
        if(!isLocked.lpTax && taxSettings.lpTax != params._taxSettings.lpTax) {
            taxSettings.lpTax = params._taxSettings.lpTax;
        }
        if(!isLocked.canMint && taxSettings.canMint != params._taxSettings.canMint && !taxSettings.holderTax) {
            taxSettings.canMint = params._taxSettings.canMint;
        }
        if(!isLocked.canPause && taxSettings.canPause != params._taxSettings.canPause) {
            taxSettings.canPause = params._taxSettings.canPause;
        }
        if(!isLocked.canBlacklist && taxSettings.canBlacklist != params._taxSettings.canBlacklist) {
            taxSettings.canBlacklist = params._taxSettings.canBlacklist;
        }
        if(!isLocked.maxBalanceAfterBuy && taxSettings.maxBalanceAfterBuy != params._taxSettings.maxBalanceAfterBuy) {
            taxSettings.maxBalanceAfterBuy = params._taxSettings.maxBalanceAfterBuy;
        }
        emit UpdatedSettings(taxSettings);


        // Lock Settings
        if(!isLocked.transactionTax) {
            isLocked.transactionTax = params._lockSettings.transactionTax;
        }
        if(!isLocked.holderTax) {
            isLocked.holderTax = params._lockSettings.holderTax;
        }
        if(!isLocked.buyBackTax) {
            isLocked.buyBackTax = params._lockSettings.buyBackTax;
        }
        if(!isLocked.lpTax) {
            isLocked.lpTax = params._lockSettings.lpTax;
        }
        if(!isLocked.canMint) {
            isLocked.canMint = params._lockSettings.canMint;
        }
        if(!isLocked.canPause) {
            isLocked.canPause = params._lockSettings.canPause;
        }
        if(!isLocked.canBlacklist) {
            isLocked.canBlacklist = params._lockSettings.canBlacklist;
        }
        if(!isLocked.maxBalanceAfterBuy) {
            isLocked.maxBalanceAfterBuy = params._lockSettings.maxBalanceAfterBuy;
        }
        emit UpdatedLockedSettings(isLocked);


        // Custom Taxes
        require(params._customTaxes.length < MaxCustom + 1, "MCT");
        delete customTaxes;

        for(uint i = 0; i < params._customTaxes.length; i++) {
            require(params._customTaxes[i].wallet != address(0), "ZA");
            customTaxes.push(params._customTaxes[i]);
        }
        customTaxLength = params._customTaxes.length;
        emit UpdatedCustomTaxes(params._customTaxes);

        // Fees        
        fees.transactionTax.buy = params._fees.transactionTax.buy;
        fees.transactionTax.sell = params._fees.transactionTax.sell;

        fees.buyBackTax = params._fees.buyBackTax;

        fees.holderTax = params._fees.holderTax;

        fees.lpTax = params._fees.lpTax;

        require(checkMaxTax(true), "BF");
        require(checkMaxTax(false), "SF");
        emit UpdatedTaxFees(params._fees);
        
        // transactionTax address
        require(params._transactionTaxWallet != address(0), "ZA");
        transactionTaxWallet = params._transactionTaxWallet;
        emit UpdatedTransactionTaxAddress(params._transactionTaxWallet);

        // maxBalanceAfterBuy
        if(taxSettings.maxBalanceAfterBuy) {
            maxBalanceAfterBuy = params._maxBalanceAfterBuy;
            emit UpdatedMaxBalanceAfterBuy(params._maxBalanceAfterBuy);
        }
    }

    function checkMaxTax(bool isBuy) internal view returns (bool) {
        uint256 totalTaxes;
        if(isBuy) {
            totalTaxes += fees.transactionTax.buy;
            totalTaxes += fees.holderTax;
            for(uint i = 0; i < customTaxes.length; i++) {
                totalTaxes += customTaxes[i].fee.buy;
            }
        } else {
            totalTaxes += fees.transactionTax.sell;
            totalTaxes += fees.lpTax;
            totalTaxes += fees.holderTax;
            totalTaxes += fees.buyBackTax;
            for(uint i = 0; i < customTaxes.length; i++) {
                totalTaxes += customTaxes[i].fee.sell;
            }
        }
        if(totalTaxes <= MaxTax) {
            return true;
        }
        return false;
    }

    struct AntiBotUpdateParams {
        AntiBotSettings _antiBotSettings;
        SwapWhitelistingSettings _swapWhitelistingSettings;
    }

    // Multicall AntiBot Update
    function multicallAntiBotUpdate(AntiBotUpdateParams calldata params) public onlyOwner {
        // AntiBot
        antiBotSettings.increment = params._antiBotSettings.increment;
        emit UpdatedAntiBotIncrement(antiBotSettings.increment);

        require(params._antiBotSettings.endDate <= 48, "ED");
        antiBotSettings.endDate = params._antiBotSettings.endDate;
        emit UpdatedAntiBotEndDate(antiBotSettings.endDate);

        antiBotSettings.initialMaxHold = params._antiBotSettings.initialMaxHold;
        emit UpdatedAntiBotInitialMaxHold(antiBotSettings.initialMaxHold);

        if(!marketInit) {
            antiBotSettings.isActive = params._antiBotSettings.isActive;
            emit UpdatedAntiBotActiveStatus(antiBotSettings.isActive);
        }

        // SwapWhitelisting
        require(params._swapWhitelistingSettings.endDate <= 48, "ED");
        swapWhitelistingSettings.endDate = params._swapWhitelistingSettings.endDate;
        emit UpdatedSwapWhitelistingEndDate(antiBotSettings.endDate);

        if(!marketInit) {
            swapWhitelistingSettings.isActive = params._swapWhitelistingSettings.isActive;
            emit UpdatedSwapWhitelistingActiveStatus(swapWhitelistingSettings.isActive);
        }
    }
}